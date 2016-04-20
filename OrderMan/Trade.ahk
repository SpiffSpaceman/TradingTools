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
	newEntryOrder	 := -1
	stopOrder  		 := -1	
	targetOrder		 := -1
	
	isStopPending 	 := false												// Is Stop Waiting for Entry/Add order to trigger?
	positionSize	 := 0													// Open Position Size

	executedEntryOrderList := []											// List of executed entry/add orders
																			// entryOrder contains details of current unexecuted order shown in GUI and _entryOrderList has all of executed orders
	
	
	/*	open new Trade by creating Entry/Stop/Target orders	
	*/
	create( inScrip, entryOrderType, stopOrderType, direction, qty, prodType, entryPrice, stopPrice, targetPrice ){
	
		if ( this.positionSize == 0 && !this._checkOpenOrderEmpty() )
			return
		
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
		
		this._handleTargetOrder( targetPrice )

		this.save()
		updateStatus()
	}
	
	/*	Update Trade - Update Entry/Stop/Target orders			
	*/
	update( inScrip, entryOrderType, stopOrderType, qty, prodType, entryPrice, stopPrice, targetPrice  ){
				
		if( this.isNewEntryLinked() && entryPrice != "" ){		
			
			orderDirection  := this.newEntryOrder.getGUIDirection()				// same direction as linked order			
			this._setupEntryOrderInput( entryOrderType, qty, prodType, entryPrice, orderDirection, inScrip )
			this.newEntryOrder.update()
		}
		
		this._updateStop( inScrip, stopOrderType, qty, prodType, stopPrice )
		if( targetPrice !=-1 )													// -1 indicates no change. Else create/delete target order
			this._handleTargetOrder( targetPrice )

		this.save()	
		updateStatus()
	}
		
	/*	Called by Tracker Thread - orderStatusTracker()
		Create pending SL order when entry completes
	*/
	trackerCallback(){

		if( this.newEntryOrder.isClosed() ){									// Entry Finished

			if( this.isEntrySuccessful()  ){									// Entry Successful - Add Entry Order to Position by inserting in executedEntryOrderList

				if( this.isStopPending )										// We have pending stop order - Create/Update Stop order if Entry was successful
					this._triggerPendingStop()

				this.positionSize += this.newEntryOrder.getOrderDetails().totalQty
				this.executedEntryOrderList.Push( this.newEntryOrder )

				this._handleTargetOrder( this.targetOrder.getPrice() )			// If Entry successful, update target order - Increase target order size
			}
			else{																// Entry Order Failed
				if( this.isStopPending  ){
					this.isStopPending := false
					MsgBox, 262144,,  Breakout Entry Order has failed. Pending stop cancelled
				}
				else{
					if( this.isEntryOrderExecuted() ){							// LIMIT/Market Order Failed - Reduce Stop Qty
						this.stopOrder.getInput().qty := this.positionSize		// Reset stop size to current position size, without entryOrder
						this.stopOrder.update()
					}
					else														// Position empty, cancel stop order
						this.stopOrder.cancel()
					MsgBox, 262144,, Entry/Add Order Failed. Stop order has been reverted / cancelled
				}
			}

			this.newEntryOrder := -1 											// Unlink Entry Order to allow adds	
			this.save()
		}	

		if( this.stopOrder.isComplete() || this.targetOrder.isComplete()  ){	// If position closed, then cancel Add order if open
			this.newEntryOrder.cancel()
		}

		if( this.stopOrder.isComplete() && this.targetOrder.isOpen() ){			// OCO Stop, Target Order
			this.targetOrder.cancel()
		}
		else if( this.targetOrder.isComplete() && this.stopOrder.isOpen() ){
			this.stopOrder.cancel()
		}
		
		
		if( this.stopOrder.isClosed() ){										// Unlink After close
			MsgBox, 262144,, Trade Closed - Verify
			this.unlinkOrders()
		}
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
	}
			
	/*	Save linked order nos to ini
		Used on startup to link to open orders on last exit
		EntryOpenOrderNo:StopOrderNo,isPending,PendingPrice:ExecutedEntryList:TargetOrderNo,TargetPrice
	*/
	save(){		
		
		scripAlias		:= this.newEntryOrder.getInput().scrip.alias
		openEntryString := this.newEntryOrder.getOrderDetails().nowOrderNo
		stopString 		:= this.stopOrder.getOrderDetails().nowOrderNo . ( "," . this.isStopPending . "," . this.stopOrder.getInput().trigger ) 		
		
		executedEntryString := ""
		For index, value in this.executedEntryOrderList{
			executedEntryString := executedEntryString . value.getOrderDetails().nowOrderNo . ","
		}
		
		targetString := this.targetOrder.getOrderDetails().nowOrderNo	. "," .  this.targetOrder.getPrice()
		
		savestring  := scripAlias . ":" . openEntryString . ":" . stopstring . ":" executedEntryString . ":" . targetString
			 
		saveOrders( savestring )			
	}
	
	loadOrders(){
		global SavedOrders, orderbookObj
				
		orderbookObj.read()
		
		fields 					 := StrSplit( SavedOrders , ":") 
		scripAlias				 := fields[1]
		entryOrderID			 := fields[2]
		stopstring   			 := fields[3]
		executedEntryOrderIDList := fields[4]
		targetString 			 := fields[5]
		
		fields 	     := StrSplit( stopstring , ",")
		stopOrderID  := fields[1]
		isPending    := fields[2]
		pendingPrice := fields[3]
		
		fields		  := StrSplit( targetString , ",")
		targetOrderID := fields[1]
		_targetPrice  := fields[2]
				
		return this.linkOrders( true, scripAlias, entryOrderID, executedEntryOrderIDList, stopOrderID, isPending, pendingPrice, targetOrderID, _targetPrice  )		
	}
	
	/*	Link with Input Order
		Linking Stop Order is optional
		Does not call this.save() - should be called by caller. loadOrders()->linkOrders() does not need to save
	*/
	linkOrders( isSilent, scripAlias, entryOrderID, executedEntryOrderIDList, stopOrderID, isPending, pendingPrice, targetOrderID, targetPrice ){
		global orderbookObj
		
		orderbookObj.read()
		entryOrderDetails   := orderbookObj.getOrderDetails( entryOrderID )
		stopOrderDetails    := orderbookObj.getOrderDetails( stopOrderID )
		targetOrderDetails  := orderbookObj.getOrderDetails( targetOrderID )
		
		newEntryOrderExists := IsObject(entryOrderDetails)
		stopOrderExists		:= IsObject(stopOrderDetails)
		targetOrderExists	:= IsObject(targetOrderDetails)
		
		if( newEntryOrderExists && stopOrderExists && entryOrderDetails.tradingSymbol != stopOrderDetails.tradingSymbol ){
			UtilClass.conditionalMessage(isSilent, "Trading Symbol does not match for Entry and Stop Order"  ) 					
			return false
		}		
		
		entryOrderListObj := []
		positionSize  	  := 0
		
		if( executedEntryOrderIDList != ""){										// Fetch Executed Orders			
			
			ts := newEntryOrderExists ? entryOrderDetails.tradingSymbol : stopOrderDetails.tradingSymbol
			
			Loop, parse, executedEntryOrderIDList, `,
			{				
				orderID    	 := A_LoopField
				orderDetails := orderbookObj.getOrderDetails( orderID )
				
				if( orderID == "" )													// Extra Comma at the end
					break
				
				if( !IsObject(orderDetails) ){
					UtilClass.conditionalMessage(isSilent, "Add Order " . orderID . " Not found"  ) 					
					return false
				}
				if( ts != orderDetails.tradingSymbol ){
					UtilClass.conditionalMessage(isSilent, "Add Order Trading Symbol does not match"  ) 					
					return false
				}
				
				order 			:= new OrderClass
				order.isCreated := true
				order.setOrderDetails( orderDetails )				
				
				entryOrderListObj.Push( order )
				positionSize += orderDetails.totalQty
			}
		}
		
		
		newEntrySize := newEntryOrderExists ? entryOrderDetails.totalQty : 0
		stopSize	 := stopOrderDetails.totalQty
																					// Validations
		if( isPending && !entryOrderDetails.isOpen() ){								// If Pending stop, then entry order must be open
			UtilClass.conditionalMessage(isSilent, "Entry Order is not Open" )
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
			
			if( targetOrderExists ){
				targetSize := targetOrderDetails.totalQty
				if( targetSize != positionSize  ){
					UtilClass.conditionalMessage(isSilent, "Target Order Size does not match with size of completed Entry Orders"  )
					return false	
				}
			}
		}
		else{																		// If no executed orders, then entry must exist. Also stop should be open or pending
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
			if( targetOrderExists  ){
				UtilClass.conditionalMessage(isSilent, "Cannot link Target Order without some completed Entry Orders"  )
				return false
			}
		}		

	// Validations over - Load Data
		
		loadScrip( scripAlias )
		
		this.newEntryOrder  := new OrderClass
		this.stopOrder 		:= new OrderClass
		this.targetOrder 	:= new OrderClass
		
		if( newEntryOrderExists ){
			this.newEntryOrder.setOrderDetails( entryOrderDetails ) 
			this.newEntryOrder.isCreated := true
			this._loadOrderInputFromOrderbook( this.newEntryOrder )					// OrderClass.InputClass
		} 		
		if( stopOrderExists ){
			this.stopOrder.setOrderDetails( stopOrderDetails ) 
			this.stopOrder.isCreated := true
			this._loadOrderInputFromOrderbook( this.stopOrder )
		}
		if( targetOrderExists ){
			this.targetOrder.setOrderDetails( targetOrderDetails ) 
			this.targetOrder.isCreated := true
			this._loadOrderInputFromOrderbook( this.targetOrder )
		}

		this.executedEntryOrderList  := entryOrderListObj
		this.positionSize			 := positionSize
		
		if( !newEntryOrderExists ){													// No New Order => We may have Executed Entry Orders. Use the latest Executed Order and copy Input
			o := this._getLastExecutedInputOrder()
			if( IsObject(o) )
				this._loadOrderInputFromOrderbook( o )
				i := o.getInput()
				this.newEntryOrder.setOrderInput( i.orderType, i.direction, i.qty, i.price, i.trigger, i.prodType, i.scrip )
		} 
		if( isPending ){
			this.isStopPending := true
			entryInput		   := this.newEntryOrder.getInput()
			
			if( pendingPrice == 0 && stopOrderExists)								// In manual Linking, use stop order price as pending price
				pendingPrice := this.stopOrder.getInput().trigger
			this._setupStopOrderInput( "SLM",  entryInput.qty, entryInput.prodType, pendingPrice,  UtilClass.reverseDirection(entryInput.direction), entryInput.scrip )
		}

		this.scrip 		 := this.newEntryOrder.getInput().scrip
		this.direction 	 := this.newEntryOrder.getInput().direction

		if( ! targetOrderExists  && targetPrice > 0 ){
			this._handleTargetOrder( targetPrice )
		}

		return true
	}

	/*	Reset All Order pointers
	*/
	unlinkOrders(){
		
		this.newEntryOrder	:= -1												// Current Entry/Add order - Not yet executed
		this.stopOrder 		:= -1												// Single stop order covering all executed orders + open entryOrder
		this.targetOrder 	:= -1 
		
		this.isStopPending	:= false											// Is Stop pending for entryOrder to Complete - Applicable for SL/SL M orders
		this.positionSize   := 0												// Sum of all successfully executed Orders' qty
		this.executedEntryOrderList := []										// List of successfully executed Orders		
		
		this.save()
		
		setDefaultQty()															// Reset Qty in GUI to Default Size
		setDefaultEntryOrderType()												// Reset to default order type
	}
	
	/* Reload order details from orderbook
	*/
	reload(){
		global orderbookObj
		
		orderbookObj.read()
		if( this.isNewEntryLinked() )
			this.newEntryOrder.reloadDetails()
		if( this.isStopLinked() )
			this.stopOrder.reloadDetails()
		if( this.isTargetLinked() )
			this.targetOrder.reloadDetails()
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
		return IsObject( this.targetOrder ) && IsObject(this.targetOrder.getOrderDetails()) 			
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
		this.stopOrder.getInput().qty := this.positionSize + this.newEntryOrder.getOrderDetails().totalQty		
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
		global ORDER_TYPE_GUI_SL_MARKET
		
		if( !IsObject( this.stopOrder ) )
			this.stopOrder := new OrderClass
				
		if( stopOrderType == ORDER_TYPE_GUI_SL_MARKET ){
			this.stopOrder.setOrderInput( stopOrderType, direction, qty, 0, stopPrice, prodType, scrip )
		}	
		else{			// should not happen
			MsgBox, 262144,, Stop Ordertype: %stopOrderType% is invalid
		}
	}
	
	/* Update Stop price - Set price / trigger price based on ordertype		
	*/
	_setStopPrice( price ){
		global ORDER_TYPE_GUI_SL_MARKET
		
		stopOrderType := this.stopOrder.getInput().orderType
		
		if( stopOrderType == ORDER_TYPE_GUI_SL_MARKET ){
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

	/*	If Open orders exist, Notify User. Used to warn before creating orders
	*/
	_checkOpenOrderEmpty(){
		global orderbookObj
		
		if( orderbookObj.doOpenOrdersExist() ){									// Entry
			MsgBox, % 262144+4,, Some Open Orders already exist . Continue?
			IfMsgBox No
				return false
		}
		return true
	}

	/*  Reads Data from OrderClass._orderDetails ( ie Orderbook) and sets up OrderClass._input used by GUI
		Used to link to existing orders
		Call orderbookObj.read() before calling this
	*/
	_loadOrderInputFromOrderbook(  order ){
		
		global selectedScrip, ProdType
		
		od := order.getOrderDetails()		
		
		if( IsObject( od ) )
			order.setOrderInput( order.getGUIOrderType(), order.getGUIDirection(), od.totalQty, od.price, od.triggerPrice, ProdType, selectedScrip )		
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

	/* Creates/updates/deletes Target Limit order based on input target price
	   Entry and stop order must be ready before calling this
	*/
	_handleTargetOrder( targetPrice ){
		global ORDER_TYPE_GUI_LIMIT	
		
		if( (targetPrice == 0  ||  targetPrice = "" ) ){
			this.targetOrder.cancel()											// Cancel if open. Can happen for adds, If target cleared, cancel it
			this.targetOrder := -1
			return
		}

		_entryDirection := this.direction
		_stopDirection  := UtilClass.reverseDirection(_entryDirection)
		_prodType	    := this.stopOrder.getInput().prodType
		_stopPrice	    := this.stopOrder.getPrice()

		if( !IsObject( this.targetOrder ) ){
			this.targetOrder := new OrderClass
		}
																				// Create/Update Target Limit Order - Target always covers only current Executed position 			
		if( !this._validateTargetPrice(_entryDirection, _stopPrice, targetPrice) ){
			UtilClass.conditionalMessage( false, "Bug - _handleTargetOrder() validation failure" )
			return
		}
	
		this.targetOrder.setOrderInput( ORDER_TYPE_GUI_LIMIT, _stopDirection, this.positionSize, targetPrice, 0, _prodType, this.scrip )
																				// Setup input params. Also used to update GUI
		if( this.positionSize == 0 ) 											// Keep Target order pending until we have Entered a position
			return
		
		if( this.targetOrder.isCreated )
			this.targetOrder.update()
		else
			this.targetOrder.create()
	}

	/* For Buy order - Target Price should be more than open stop order
	*/
	_validateTargetPrice( direction, stopPrice, targetPrice  ){
		return direction == "B" ? targetPrice > stopPrice : targetPrice < stopPrice	
	}
}

