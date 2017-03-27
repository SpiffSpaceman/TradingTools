/*
  Copyright (C) 2015  SpiffSpaceman

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>
*/

class TradeClass{
	
	scrip			 := ""
	direction		 := ""													// B/S
	index			 := -1													// tab index
	
	newEntryOrder	 := -1
	stopOrder  		 := -1
	target		 	 := new TargetClass
	
	isStopPending 	 := false												// Is Stop Waiting for Entry/Add order to trigger?
	positionSize	 := 0													// Open Position Size
	averageEntryPrice := 0													// Average Entry Price for completed orders weighted by qty

	executedEntryOrderList := []											// List of executed entry/add orders
																			// entryOrder contains details of current unexecuted order shown in GUI and _entryOrderList has all of executed orders
	
	InitialStopDistance  := 0	
	InitialEntry 		 := 0
	
	
	
	/*	open new Trade by creating Entry/Stop/Target orders	
	*/
	create( inScrip, entryOrderType, stopOrderType, direction, qty, prodType, entryPrice, stopPrice, targetPrice, targetQty ){
		
		global contextObj
		
		this.index  	:= contextObj.getCurrentIndex()
		this.scrip  	:= inScrip
		this.direction	:= direction
		
		this.newEntryOrder := new OrderClass
		this._setupEntryOrderInput( entryOrderType, qty, prodType, entryPrice, direction, inScrip )
		this.newEntryOrder.create()											// Create Entry Order and update Details from Orderbook
		
		if( ! this.newEntryOrder.isCreated  )
			return
		
		isNewStopPending  := this._isStopPending( entryOrderType )
		stopDirection	  := UtilClass.reverseDirection(direction)
		
		if( this.stopOrder.isCreated   ){										
			
			this._setStopPrice( stopPrice )										// 1) Already have a position - update its stop price
			if( !isNewStopPending) {											// 2) If Add order stop is not pending, increase existing stop size	
				this._mergeStopSize()												// Else it will be set as pending below and merged when entry trigger				
			}
			
			this.stopOrder.update()
		}
		else{																	// Stop order not yet created => This is Stop for initial Entry order
																				// 	When adding, we will always have stop of Existing position			
			this.stopOrder 	:= new OrderClass									// Create Stop Order. Keep it pending if entry waiting for trigger		
			this._setupStopOrderInput(  stopOrderType,  qty, prodType, stopPrice, stopDirection, inScrip )
			if( !isNewStopPending )
				this.stopOrder.create()
		}

		this.isStopPending := isNewStopPending									// Just mark as pending. Actual Size of Pending Stop will be set when triggered
		
		this.target.handleTargetOrder( targetPrice, targetQty, this.stopOrder, this.positionSize )

		this.save()
		updateStatus()
		contextObj.refreshQtyPercFromContext( this.index )						// Refresh Target Qty % keeping actual qty unchanged
	}
	
	/*	Update Trade - Update Entry/Stop/Target orders			
	*/
	update( inScrip, entryOrderType, stopOrderType, qty, prodType, entryPrice, stopPrice, targetPrice, targetQty  ){
		global contextObj
		
		if( this.isNewEntryLinked() && entryPrice != "" ){		
			
			orderDirection  := this.newEntryOrder.getGUIDirection()				// same direction as linked order			
			this._setupEntryOrderInput( entryOrderType, qty, prodType, entryPrice, orderDirection, inScrip )
			this.newEntryOrder.update()
		}
		
		this._updateStop( inScrip, stopOrderType, qty, prodType, stopPrice )
		
		if( targetPrice !=-1 )													// -1 indicates no change. Else create/delete target order
			this.target.handleTargetOrder( targetPrice, targetQty, this.stopOrder, this.positionSize )

		this.save()	
		updateStatus()
		contextObj.refreshTargetQtyPercFromContext( this.index )				// Refresh Target Qty % keeping actual qty unchanged
	}
		
	/*	Called by Tracker Thread - orderStatusTracker()
		Create pending SL order when entry completes
		Handle Target-Stop OCO
		Handle Stop update after Target partial fill
	*/
	trackerCallback(){
		global contextObj
		
		if( this.newEntryOrder.isClosed() ){									// Entry Finished

			if( this.isEntrySuccessful()  ){									// Entry Successful - Add Entry Order to Position by inserting in executedEntryOrderList

				if( this.isStopPending )										// We have pending stop order - Create/Update Stop order if Entry was successful
					this._triggerPendingStop()

				this.averageEntryPrice := this._getAveragePrice( this.positionSize, this.averageEntryPrice, this.newEntryOrder.getOrderDetails() )
				this.positionSize 	   += this.newEntryOrder.getOrderDetails().totalQty
				this.executedEntryOrderList.Push( this.newEntryOrder )

				this.target.onEntrySuccessful( this.stopOrder, this.positionSize )
																				// If Entry successful, update target order - Increase target order size
				contextObj.clearQtyFromContext( this.index  )					// Reset Qty to 0 after Entry/Add
			}
			else{																// Entry Order Failed
				if( this.isStopPending  ){
					this.isStopPending := false
					MsgBox, 262144,,  Breakout Entry Order has failed. Pending stop cancelled
				}
				else{
					if( this.isEntryOrderExecuted() ){							// LIMIT/Market Order Failed - Reduce Stop Qty
						this._updateStopSize()									// Reset stop size to current position size, without entryOrder
						this.stopOrder.update()
						MsgBox, 262144,, Add Order Failed. Stop order has been reverted
					}
					else{														// Position empty, cancel stop order
						if( this.stopOrder.cancel() )
							MsgBox, 262144,, Entry/Add Order Failed. Stop order has been cancelled
						else
							MsgBox, 262144,, Entry/Add Order Failed. Stop order cancellation failed
					}
				}
			}
			
			contextObj.refreshQtyPercFromContext( this.index )					// Refresh Target Qty % keeping actual qty unchanged
			this.newEntryOrder := -1 											// Unlink Entry Order to allow adds
			this.save()
		}

		if( this.stopOrder.isClosed() ){										// Stop hit/cancelled, close all open orders
			this.onTradeClose()
			return
		}
		
		targetOrder := this.target.getOpenOrder()
		if( targetOrder.isClosed() ){
			this.positionSize -= targetOrder.getFilledQty()						// Target Executed, Reduce position size
			this._updateStopSize()												// Update Stop size. If position closed, stop size will be 0 which will cancel the order in update()
			this.stopOrder.update()
			
			this.target.onTargetClose( this.index )								// Notify Open target order closure
			this.save()

			if(this.positionSize <= 0 ){										// Position closed, cancel all open orders
				this.onTradeClose()
				return
			}
		}
		// TODO 
		// Target update price/qty sometimes triggers stop order update with incorrect size
		// Below code causes it
		/*
		else{																	// If Target LIMIT order is filled partially, update stop order
			filledQty := this.target.isPartiallyFilled()
			if( filledQty > 0  ){
				this.positionSize -= filledQty									// Reduce Position size and update Stop qty
				this._updateStopSize()
				this.stopOrder.update()
			}
		}
		*/
	}

	/* Close orders if open and unlink
	*/
	onTradeClose(){																// OCO Stop, Target Order
	
		entry  := this.isNewEntryLinked() ? this.newEntryOrder.cancel() : true	// If position closed, then cancel Add order if open
		stop   := this.stopOrder.cancel()
		target := this.isTargetLinked()   ? this.target.cancel() : true
		
		if( !entry || !stop || !target )
			MsgBox, 262144,, % "Trade " . this.index . " Closed - OCO Failed"
		else
			MsgBox, 262144,, % "Trade " . this.index . " Closed - Verify"
		this.unlinkOrders()														// Unlink After close
	}
	
	/*	cancel open orders - Entry/Stop/Pending Stop
		Executed orders cannot be cancelled - so no change in TargetOrder
	*/
	cancel(){
		
		if( this.isEntrySuccessful() ){										// Should never happen
			MsgBox, % 262144+4,,  Entry Order has already been Executed. Do you still want to cancel Stop order?
				IfMsgBox No
					return -1	
		}	
		
		toggleStatusTracker( "off" )										// Turn off tracker before cancelling orders
		
		if( this.isNewEntryLinked() ){
			if( ! this.newEntryOrder.cancel() ){
				toggleStatusTracker( "on" )
				MsgBox, 262144,, Entry cancellation failed
				return
			}
			this.newEntryOrder := -1
		}

		if( this.isStopLinked() ){
			if( this.isEntryOrderExecuted() ){								// Reduce Stop size to size of executed orders
				this.stopOrder.setInputQty( this.positionSize )
				this.stopOrder.update()				
			}
			else{
				if( ! this.stopOrder.cancel() ){
					toggleStatusTracker( "on" )
					MsgBox, 262144,, Entry cancellation failed
					return
				}
				this.stopOrder := -1				
			}
		}
		
		this.isStopPending  := false
		
		this.save()
		updateStatus()
		
		toggleStatusTracker( "on" )											// Turn back on, if no more trades left it will turn off 
	}

	saveInitialStopDistance( risk, entry  ){
		this.InitialStopDistance  := risk		
		this.InitialEntry 		  := entry
	}
	
	/*	Save linked order nos to ini
		Used on startup to link to open orders on last exit
		Format:		Alias:EntryOpenOrderNo:StopOrderNo,isPending,PendingPrice:ExecutedEntryList:TargetOrderNo,TargetPrice:ExecutedTargetList:InitialStopDistance,InitialEntry
	*/
	save(){
		global contextObj
		
		scripAlias	:= this.scrip.alias
		entryOrder	:= this.newEntryOrder.getOrderDetails().nowOrderNo
		stopString	:= this.stopOrder.getOrderDetails().nowOrderNo . ( "," . this.isStopPending . "," . this.stopOrder.getInput().trigger )
		
		executedEntryString := ""
		For index, value in this.executedEntryOrderList{
			executedEntryString := executedEntryString . value.getOrderDetails().nowOrderNo . ","
		}
		
		targetString 		 := this.target.getOpenOrder().getOrderDetails().nowOrderNo	. "," .  this.target.getPrice() . "," . this.target.getGUIQty()
		executedTargetString := this.target.getExecutedOrderList()
		
		InitialStopDistanceString := this.InitialStopDistance . "," . this.InitialEntry
		
		savestring  := scripAlias . ":" . entryOrder . ":" . stopstring . ":" . executedEntryString . ":" . targetString . ":" . executedTargetString . ":" . InitialStopDistanceString
		
		if( this.index == -1 )
			MsgBox, 262144,, Trade index not saved					// assert(), should not happen
		
		saveOrders( this.index, savestring )
	}
	
	/* Format:		Alias:EntryOpenOrderNo:StopOrderNo,isPending,PendingPrice:ExecutedEntryList:TargetOrderNo,TargetPrice:ExecutedTargetList:InitialStopDistance,InitialEntry
	*/
	loadOrders(){
		global orderbookObj, contextObj, SavedOrders1, SavedOrders2, SavedOrders3
		
		index := contextObj.getCurrentIndex()
		
		orderbookObj.read()
		
		fields 					 := StrSplit( SavedOrders%index% , ":") 
		scripAlias				 := fields[1]
		entryOrderID			 := fields[2]
		stopstring   			 := fields[3]
		executedEntryOrderIDList := fields[4]
		targetString 			 := fields[5]
		executedTargetOrderList  := fields[6]
		InitialStopDistanceString := fields[7]
		
		fields 	     := StrSplit( stopstring , ",")
		stopOrderID  := fields[1]
		isPending    := fields[2]
		pendingPrice := fields[3]
		
		if( (entryOrderID == 0 || entryOrderID == "")  &&  (stopOrderID == 0 || stopOrderID == "")  )
			return false
		
		fields		  := StrSplit( targetString , ",")
		targetOrderID := fields[1]
		_targetPrice  := fields[2]
		_targetQty	  := fields[3]
				
		if( this.linkOrders( true, scripAlias, entryOrderID, executedEntryOrderIDList, stopOrderID, isPending, pendingPrice, targetOrderID, _targetPrice, _targetQty, executedTargetOrderList  ) ){
			
			fields := StrSplit( InitialStopDistanceString , ",")
			this.InitialStopDistance  := fields[1]			
			this.InitialEntry 		  := fields[2]
			
			return true
		}
		
		return false
	}

	/*	Link with Input Order
		Linking Stop Order is optional
		Does not call this.save() - should be called by caller. loadOrders()->linkOrders() does not need to save
	*/
	linkOrders( isSilent, scripAlias, entryOrderID, executedEntryOrderIDList, stopOrderID, isPending, pendingPrice, targetOrderID, targetPrice, targetQty, executedTargetOrderList ){
		global contextObj, orderbookObj, STOP_ORDER_TYPE
		
		orderbookObj.read()
		entryOrderDetails   	:= orderbookObj.getOrderDetails( entryOrderID )
		stopOrderDetails    	:= orderbookObj.getOrderDetails( stopOrderID )
		targetOrderDetails  	:= orderbookObj.getOrderDetails( targetOrderID )
		
		newEntryOrderExists 	:= IsObject(entryOrderDetails)
		stopOrderExists			:= IsObject(stopOrderDetails)
		openTargetOrderExists	:= IsObject(targetOrderDetails)
		
		newEntrySize 			:= newEntryOrderExists ? entryOrderDetails.totalQty : 0
		stopSize	 			:= stopOrderDetails.totalQty
		
		if( newEntryOrderExists && stopOrderExists && entryOrderDetails.tradingSymbol != stopOrderDetails.tradingSymbol ){
			UtilClass.conditionalMessage(isSilent, "Trading Symbol does not match for Entry and Stop Order"  ) 					
			return false
		}

		positionSize 	 	 := 0
		entryOrderListObj    := []
		targetOrderListObj   := []
		openTargetSize		 := openTargetOrderExists ? targetOrderDetails.totalQty : 0
		openTargetFilledSize := openTargetOrderExists ? targetOrderDetails.tradedQty : 0

		if( executedEntryOrderIDList != ""){										// Fetch Executed Entry Orders
																					// Stop will always exits if atleast 1 entry order has been filled
			size := this._loadExecutedOrders( isSilent, executedEntryOrderIDList, entryOrderListObj, stopOrderDetails.tradingSymbol  )
			if(  size == -1 )
				return false
			else
				positionSize += size
		}		

		if( executedTargetOrderList != ""){											// Fetch Executed Target Orders		
			size := this._loadExecutedOrders( isSilent, executedTargetOrderList, targetOrderListObj, stopOrderDetails.tradingSymbol  )
			if(  size == -1 )
				return false
			else
				positionSize -= size												// Reduce position size
		}
		
		if( openTargetFilledSize > 0  )												// Partial Target Fill - Reduce Position size
			positionSize -= openTargetFilledSize

	// Validations
		if( isPending && !entryOrderDetails.isOpen() ){								// If Pending stop, then entry order must be open
			UtilClass.conditionalMessage(isSilent, "Entry Order is not Open" )
			return false
		}
		if( openTargetSize > positionSize ){										// Target and Entry Order size mismatch
			UtilClass.conditionalMessage(isSilent, "Target total qty exceeds Entry Position" )
			return false
		}
		if( positionSize > 0 ){														// If some entry/add orders are complete, then stop must be open
			if( !stopOrderDetails.isOpen() ){										// Should never happen with manual linking from link button
				UtilClass.conditionalMessage(isSilent, "Stop Order is not Open"  )
				return false
			}
			expectedStopSize := isPending ? positionSize : positionSize + newEntrySize			
			if( stopSize != expectedStopSize){
				UtilClass.conditionalMessage(isSilent, "Stop Size does not match with Entry position size"  )
				return false	
			}
		}
		if( positionSize == 0 ){													// If no executed orders, then entry must exist. Also stop should be open or pending
			if( !newEntryOrderExists ){												// Cannot have Open Target Order
				UtilClass.conditionalMessage(isSilent, "Order " . entryOrderID " Not found" )
				return false
			}
			if( isPending && stopOrderExists ) {
				UtilClass.conditionalMessage(isSilent, "No Entry position linked against stop order" )
				return false
			}
			if( !isPending &&  !stopOrderDetails.isOpen() ){
				UtilClass.conditionalMessage(isSilent, "No Pending/Open Stop Order Found covering Entry" )
				return false
			}
			if( !isPending &&  newEntrySize != stopSize ){
				UtilClass.conditionalMessage(isSilent, "Stop Size does not match with Entry size"  )
				return false
			}
			if( openTargetOrderExists || executedTargetOrderList != "" ){
				UtilClass.conditionalMessage(isSilent, "Cannot link Target Order without some completed Entry Orders"  )
				return false
			}
		}	

	// Validations over - Load Data

		loadScrip( scripAlias )
		
		this.index := contextObj.getCurrentIndex()
		
		this.newEntryOrder := new OrderClass
		this.newEntryOrder.loadOrderFromOrderbook( entryOrderDetails )
		this.executedEntryOrderList  := entryOrderListObj
		
		this.stopOrder := new OrderClass
		this.stopOrder.loadOrderFromOrderbook( stopOrderDetails )
		
		this.target.loadTarget( targetOrderDetails )
		this.target.executedOrderList := targetOrderListObj

		this._calculateAveragePrice()
		this.positionSize := positionSize

		if( !newEntryOrderExists ){													// No New Order => We may have Executed Entry Orders 
			o := this._getLastExecutedInputOrder()										// Use the latest Executed Order and copy Input to prepare for future Adds
			if( IsObject(o) ){															// Keep qty as 0, it should be set manually and not taken from last entry/add order 
				o.loadOrderFromOrderbook( 0 )										// Load input from Orderbook, passing 0 to avoid resetting orderDetails
				i := o.getInput()
				this.newEntryOrder.setOrderInput( i.orderType, i.direction, 0, i.price, i.trigger, i.prodType, i.scrip )
			}
		}
		if( isPending ){
			this.isStopPending := true
			entryInput		   := this.newEntryOrder.getInput()
			
			if( pendingPrice == 0 && stopOrderExists)								// In manual Linking, use stop order price as pending price
				pendingPrice := this.stopOrder.getInput().trigger
			this._setupStopOrderInput( STOP_ORDER_TYPE,  entryInput.qty, entryInput.prodType, pendingPrice,  UtilClass.reverseDirection(entryInput.direction), entryInput.scrip )
		}

		this.scrip 		 := this.newEntryOrder.getInput().scrip
		this.direction 	 := this.newEntryOrder.getInput().direction

		if( ! openTargetOrderExists  && (targetPrice > 0 || targetQty > 0) ){		// Set up pending Target Order
			this.target.handleTargetOrder( targetPrice, targetQty, this.stopOrder, this.positionSize )
		}

		return true
	}

	/*	Reset All Order pointers
	*/
	unlinkOrders(){
		global contextObj

		this.newEntryOrder	:= -1												// Current Entry/Add order - Not yet executed
		this.stopOrder 		:= -1												// Single stop order covering all executed orders + open entryOrder
		this.target.unlink()
		
		this.isStopPending			:= false									// Is Stop pending for entryOrder to Complete - Applicable for SL/SL M orders
		this.positionSize   		:= 0										// Sum of all successfully executed Orders' qty
		this.averageEntryPrice 		:= 0
		this.executedEntryOrderList := []										// List of successfully executed Orders		
		
		this.save()

		contextObj.resetContext( this.index  )
	}
	
	/* Reload order details from orderbook
		call orderbookObj.read() before reload()
	*/
	reload(){		
		if( this.isNewEntryLinked() )
			this.newEntryOrder.reloadDetails()
		if( this.isStopLinked() )
			this.stopOrder.reloadDetails()
		if( this.isTargetLinked() )
			this.target.getOpenOrder().reloadDetails()
	}


	

	/*	New Entry Order Open ? - Returns true if newEntryOrder is an object and is linked with an order in orderbook
	*/
	isNewEntryLinked(){		
		return IsObject( this.newEntryOrder )  && IsObject(this.newEntryOrder.getOrderDetails()) 
	}

	/*	Returns true if atleast one Entry order has been executed - ie we have open position
	*/
	isEntryOrderExecuted(){
		return  this.positionSize > 0
	}
	
	/*	Returns true if stopOrder is an object and is linked with an order in orderbook
	*/
	isStopLinked(){		
		return IsObject( this.stopOrder ) && IsObject(this.stopOrder.getOrderDetails()) 
	}

	isTargetLinked(){
		return this.target.isLinked()
	}

	/*	Indicates whether Entry Order has status = complete
		Note this wont remain true for too long. trackerCallback will move succesful order to executedEntryOrderList.
		This is meant for use in callback
	*/
	isEntrySuccessful(){		
		return  IsObject( this.newEntryOrder ) && this.newEntryOrder.isComplete()
	}

	/*	Indicates whether Stop Order has status = complete
	*/
	isStopSuccessful(){
		return  IsObject( this.stopOrder ) && this.stopOrder.isComplete()
	}

	/*	Indicates whether Entry Order is in Order Book > Open Orders	
	*/
	isEntryOpen(){
		return  IsObject( this.newEntryOrder ) && this.newEntryOrder.isOpen()
	}
	
	/*	Indicates whether Stop Order  is in Order Book > Open Orders	
	*/
	isStopOpen(){
		return  IsObject( this.stopOrder ) && this.stopOrder.isOpen()
	}

	/*	Indicates whether Entry Order is in Order Book > Completed Orders	
	*/
	isEntryClosed(){
		return  IsObject( this.newEntryOrder ) && this.newEntryOrder.isClosed()
	}
	
	/*	Indicates whether Entry Order is in Order Book > Completed Orders	
	*/
	isStopClosed(){
		return  IsObject( this.stopOrder ) && this.stopOrder.isClosed()
	}

	/* Is Trade Direction = Long?
	*/
	isLong(){
		return this.direction == "B"
	}


// -- Private ---

	_triggerPendingStop(){

		this._mergeStopSize()

		if( this.stopOrder.isCreated ){										// If stop order already exists ( ie Entry Order was an add order )
			this.stopOrder.update()											//	  then take added qty from entry order and add to stop order
		}
		else{			
			this.stopOrder.create()			
		}
		this.isStopPending := false
		this.save()		
	}
	
	/* Take added qty from entry order and add to stop order	 
	 * Stop size = Executed Orders + Current open order
	 * positionSize will be 0 when there is no Existing position
	*/
	_mergeStopSize(){
		openEntrySize := this.newEntryOrder.getOrderDetails().totalQty
		if( openEntrySize == "" )
			openEntrySize := 0 
		this.stopOrder.getInput().qty := this.positionSize + openEntrySize
	}

	/* Update Stop size after change to positionSize
	*/
	_updateStopSize(){
		openEntrySize := this.newEntryOrder.getOrderDetails().totalQty
		if( openEntrySize == "" || this.newEntryOrder.isClosed() )
			openEntrySize := 0 
		
		this.stopOrder.getInput().qty := this.positionSize + (this.isStopPending ? 0 : openEntrySize)
	}

	/*	Set Entry Order Input details based on Order Type
	*/
	_setupEntryOrderInput( entryOrderType, qty, prodType, entryPrice, direction, scrip ){
		global MaxSlippage, ORDER_TYPE_GUI_LIMIT, ORDER_TYPE_GUI_MARKET, ORDER_TYPE_GUI_SL_MARKET, ORDER_TYPE_GUI_SL_LIMIT
		
		if( !IsObject( this.newEntryOrder ) )
			this.newEntryOrder := new OrderClass
				
		if( entryOrderType == ORDER_TYPE_GUI_LIMIT ){
			this.newEntryOrder.setOrderInput( entryOrderType, direction, qty, entryPrice, 0, prodType, scrip )
		}
		else if( entryOrderType == ORDER_TYPE_GUI_MARKET ){
			this.newEntryOrder.setOrderInput( entryOrderType, direction, qty, 0, 0, prodType, scrip  )
		}
		else if( entryOrderType == ORDER_TYPE_GUI_SL_MARKET ){
			this.newEntryOrder.setOrderInput( entryOrderType, direction, qty, 0, entryPrice, prodType, scrip  )
		}
		else if( entryOrderType == ORDER_TYPE_GUI_SL_LIMIT ){
			limitprice := direction == "B" ? entryPrice + MaxSlippage : entryPrice - MaxSlippage		
			this.newEntryOrder.setOrderInput( entryOrderType, direction, qty, limitprice, entryPrice, prodType, scrip )
		}
		else{			// should not happen
			MsgBox, 262144,, Entry Ordertype: %entryOrderType% is invalid
		}
	}
	
	/*	Set Stop Order Input details based on Order Type
	*/
	_setupStopOrderInput( stopOrderType, qty, prodType, stopPrice, direction, scrip ){
		global ORDER_TYPE_GUI_SL_MARKET, ORDER_TYPE_GUI_SL_LIMIT															// ORDER_TYPE_GUI_SL_LIMIT added
		
		if( !IsObject( this.stopOrder ) )
			this.stopOrder := new OrderClass
				
		if( stopOrderType == ORDER_TYPE_GUI_SL_MARKET  || stopOrderType == ORDER_TYPE_GUI_SL_LIMIT){						// set limit order if SL-M not available
			this.stopOrder.setOrderInput( stopOrderType, direction, qty, 0, stopPrice, prodType, scrip )					//Limit Price = 0 means market price
		}	
		else{			// should not happen
			MsgBox, 262144,, Stop Ordertype: %stopOrderType% is invalid
		}
	}
	
	/* Update Stop price - Set price / trigger price based on ordertype		
	*/
	_setStopPrice( price ){
		global ORDER_TYPE_GUI_SL_MARKET, ORDER_TYPE_GUI_SL_LIMIT                    										// ORDER_TYPE_GUI_SL_LIMIT added 
		
		stopOrderType := this.stopOrder.getInput().orderType
		
		if( stopOrderType == ORDER_TYPE_GUI_SL_MARKET || stopOrderType == ORDER_TYPE_GUI_SL_LIMIT){							// set limit order if SL-M not available
			this.stopOrder.setInputPrice( 0, price )
		}	
		else{			// should not happen
			MsgBox, 262144,, Stop Ordertype: %stopOrderType% is invalid
		}
	}
		
	/*  Returns false if stop order should be created immediately
	*/
	_isStopPending( entryOrderType ){
		global
		return ( entryOrderType == ORDER_TYPE_GUI_SL_LIMIT || entryOrderType == ORDER_TYPE_GUI_SL_MARKET )
	}

	/* Go through orders in input csv
	   Check if trading symbol matches against Input
	   Setup OrderClass and push to input List	
	   Returns totalQty of Executed Orders if successful, else returns -1	   
	*/
	_loadExecutedOrders( isSilent, inputOrderCsv, outputOrderList, tradingSymbol  ){
		global orderbookObj

		totalQty := 0

		Loop, parse, inputOrderCsv, `,
		{
			orderID := A_LoopField
			if( orderID == "" )													// Extra Comma at the end
				break
			
			orderDetails := orderbookObj.getOrderDetails( orderID )

			if( !IsObject(orderDetails) ){
				UtilClass.conditionalMessage(isSilent, "Order " . orderID . " Not found"  )
				return -1
			}
			if( tradingSymbol != orderDetails.tradingSymbol ){
				UtilClass.conditionalMessage(isSilent, "Trading Symbol does not match for Order " . orderID  )
				return -1
			}

			order 			:= new OrderClass
			order.isCreated := true
			order.setOrderDetails( orderDetails )

			outputOrderList.Push( order )
			totalQty += orderDetails.totalQty
		}

		return totalQty
	}

	/* Returns latest order with highest order no from list of Executed Entry Orders
	*/
	_getLastExecutedInputOrder(){
		
		highestOrderNo := ""
		lastEntryOrder := -1
		
		For index, value in this.executedEntryOrderList{
			
			orderno := value.getOrderDetails().nowOrderNo		
			if( highestOrderNo == "" || highestOrderNo < orderno ){
				lastEntryOrder := value
				highestOrderNo := orderno
			}		
		}	

		return lastEntryOrder
	}

	/* Update Stop order
		1. Allow update of Stop order for open Entry Order, Stops can be pending
		2. Allow update of Stop order for executed Entry Order but no open Add order. Stops cannot be pending
		3. Allow update of Stop order for open Add Order + Executed Entry/Add orders. Stops can be pending
	*/
	_updateStop( inScrip, stopOrderType, qty, prodType, stopPrice ){
		
		if(  stopPrice == "" )
			return
		
		stopDirection	:= UtilClass.reverseDirection( this.direction )
	
		if( this.isNewEntryLinked() && !this.isEntryOrderExecuted()   ){			// 1. Update Stop Order for Open Entry Order. No Executed Enty/Add orders
																					// Stop size is only relevant if not pending, ie For Limit/Market orders
			this._setupStopOrderInput( stopOrderType, qty, prodType, stopPrice, stopDirection, inScrip )			
			if( !this.isStopPending )												// For Stop Entry Orders, Entry order size is used as stop size on Entry Trigger
				this.stopOrder.update()
		}
		else if( !this.isNewEntryLinked() && this.isEntryOrderExecuted()   ){		// 2. Update Stop Order for Executed Entry orders. No open Add order
			this._setupStopOrderInput( stopOrderType, this.positionSize, prodType, stopPrice, stopDirection, inScrip )
			this.stopOrder.update()
		}
		else if( this.isNewEntryLinked() && this.isEntryOrderExecuted()  ){			// 3. We have stops for both open and executed orders
		
			stopQty	:= this.positionSize + (this.isStopPending ? 0 : qty)			// If add order's stop is pending, Increasing stop size will be handled later on trigger, but update stop price if changed
																					// If No Pending order => Stop size = open + executed position				
			this._setupStopOrderInput( stopOrderType, stopQty, prodType, stopPrice, stopDirection, inScrip )
			this.stopOrder.update()
		}
		else{		// should not happen
			MsgBox, 262144,, Bug in _updateStop(). No stop order to update
		}
	}	
	
	/* Calculate Average Entry Price from executedEntryOrderList
	   Call this before updating this.positionSize
	*/
	_calculateAveragePrice(){
		For index, value in this.executedEntryOrderList{
			this.averageEntryPrice := this._getAveragePrice( this.positionSize, this.averageEntryPrice, value.getOrderDetails() )
		}	
	}
	
	/* Returns Updated Average weighted price - Call this before updating this.positionSize
	*/
	_getAveragePrice( oldQty, oldAverageprice, newOrderDetails ){
		_qty   	  := newOrderDetails.totalQty
		_avgPrice := newOrderDetails.averagePrice

		return ( oldAverageprice*oldQty + _avgPrice*_qty ) / (  oldQty + _qty )
	}

}

