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
	
	scrip			:= ""
	direction		:= ""													// B/S
	entryOrder		:= -1
	stopOrder  		:= -1
	
	isStopPending	:= false												// Is Stop Waiting for Entry order to trigger?			
	
	
	
	
	/*	open new Trade by creating Entry/Stop/Target orders	
	*/
	create( inScrip, entryOrderType, stopOrderType, direction, qty, prodType, entryPrice, stopPrice ){		
		
		global TITLE_NOW
	
		if ( !this._checkOpenOrderEmpty() )
			return
		
		this.scrip  	:= inScrip
		this.direction	:= direction
		
		this.entryOrder := new OrderClass
		this._setupEntryOrderInput( entryOrderType, qty, prodType, entryPrice, direction, inScrip )
		
		this.stopOrder 	:= new OrderClass
		this._setupStopOrderInput(  stopOrderType,  qty, prodType, stopPrice,  UtilClass.reverseDirection(direction), inScrip )

		this.entryOrder.create()												// Create Entry Order and update Details from Orderbook
		if( ! this.entryOrder.isCreated  )
			return	
					
		if( this._isPendingStop( entryOrderType )){								// Create Stop Order. Keep it pending if entry waiting for trigger
			this.isStopPending := true
		}
		else{
			this.stopOrder.create()
		}
		
		this.save()
		updateStatus()
	}		
	
	/*	Update Trade - Update Entry/Stop/Target orders	
	*/
	update( inScrip, entryOrderType, stopOrderType, qty, prodType, entryPrice, stopPrice  ){
				
		if( this.isEntryLinked() && entryPrice != "" ){		
			
			orderDirection  := this.entryOrder.getGUIDirection()				// same direction as linked order			
			this._setupEntryOrderInput( entryOrderType, qty, prodType, entryPrice, orderDirection, inScrip )		// TODO- no need to  update scrip?
			this.entryOrder.update()
		}
		
		if( this.isEntryLinked()  && stopPrice != "" ){							// Stop can only exist if Entry Order Exist
																				// Stop can be pending, stopOrder need not exist
			stopDirection   := UtilClass.reverseDirection( this.entryOrder.getGUIDirection() )
			this._setupStopOrderInput( stopOrderType, qty, prodType, stopPrice, stopDirection, inScrip )			// TODO- no need to update scrip?
			
			if( this.stopOrder.isOpen() )										// Order in Open Status - Modify it
				this.stopOrder.update()
			else if ( !this.isStopLinked() )									// Pending only applicable if order not created yet
				this.isStopPending := true
		}
				
		this.save()	
		updateStatus()
	}
	
	/*	cancel open orders - Entry/Stop/Pending Stop/Target
	*/
	cancel(){
		
		if( this.isEntrySuccessful() ){	
			MsgBox, % 262144+4,,  Entry Order has already been Executed. Do you still want to cancel Stop order?
				IfMsgBox No
					return -1	
		}	
		
		toggleStatusTracker( "off" )										// Turn off tracker before cancelling orders
		
		if( this.isEntryLinked() ){
			if( ! this.entryOrder.cancel() ){
				toggleStatusTracker( "on" )
				MsgBox, 262144,, Entry cancellation failed
				return
			}
		}
		
		if( this.isStopLinked() ){
			if( ! this.stopOrder.cancel() ){
				toggleStatusTracker( "on" )
				MsgBox, 262144,, Entry cancellation failed
				return
			}
		}		
		
		this.isStopPending := false
		this.entryOrder    := -1
		this.stopOrder 	   := -1
		
		this.save()
		updateStatus()
	}
			
	/*	Save linked order nos to ini
		Used on startup to link to open orders on last exit
	*/
	save(){		
		if( this.isStopPending )
			savestring := this.entryOrder.getOrderDetails().nowOrderNo . "," . "Pending," . this.stopOrder.getInput().trigger
		else
			savestring := this.entryOrder.getOrderDetails().nowOrderNo . "," . this.stopOrder.getOrderDetails().nowOrderNo
			 
		saveOrders( savestring )			
	}
	
	
	loadOrders(){
		global SavedOrders, orderbookObj
				
		orderbookObj.read()
		
		fields 		 := StrSplit( SavedOrders , ",") 
		entryOrderID := fields[1]
		stopOrderID  := fields[2]
				
		if( stopOrderID == "Pending"  ){

			entryOrder := orderbookObj.getOrderDetails( entryOrderID )			// Link if entry order is open, with stop still pending for entry trigger
			
			if( entryOrder.isOpen() ){				
				this.linkOrders( entryOrderID, "", false )
							
				_stop_price 	   := fields[3]									// Setup Pending order Input
				this.isStopPending := true				
				entryInput		   := this.entryOrder.getInput()
				this.stopOrder 	   := new OrderClass				
				this._setupStopOrderInput( "SLM",  entryInput.qty, entryInput.prodType, _stop_price,  UtilClass.reverseDirection(entryInput.direction), entryInput.scrip )

				return true
			}
		}		
		else{
			stopOrder := orderbookObj.getOrderDetails( stopOrderID )			// Link if stop order is open, ie positon is still open
			if( stopOrder.isOpen() ){			
				this.linkOrders( entryOrderID, stopOrderID, true )	
				return true
			}			
		}
		
		return false
	}
	
	/* Reload order details from orderbook
	*/
	reload(){
		global orderbookObj
		
		orderbookObj.read()
		if( this.isEntryLinked() )
			this.entryOrder.reloadDetails()
		if( this.isStopLinked() )
			this.stopOrder.reloadDetails()
	}
	
	/*	Link with Input Order
		Linking Stop Order is optional
		Does not call this.save() - should be called by caller. loadOrders()->linkOrders() does not need to save
	*/
	linkOrders( entryOrderID, stopOrderID, isStopLinked ){
		global orderbookObj
		
		orderbookObj.read()		
		entryOrderDetails := orderbookObj.getOrderDetails( entryOrderID )
		stopOrderDetails  := orderbookObj.getOrderDetails( stopOrderID )
		
		if( entryOrderDetails == -1 ){
			MsgBox, 262144,, Order %entryOrderID% Not found
			return false
		}
		if( stopOrderDetails == -1 && isStopLinked ){		
			MsgBox, 262144,, Order %stopOrderID% Not found
			return false
		}		
		if( isStopLinked && (entryOrderDetails.tradingSymbol != stopOrderDetails.tradingSymbol)  ){
			MsgBox, 262144,, Orders have different Trading Symbols 
			return false	
		}
				
		this.entryOrder  := new OrderClass
		this.entryOrder.updateOrderDetails( entryOrderDetails ) 
		this.entryOrder.isCreated := true
				
		if( isStopLinked  && IsObject(stopOrderDetails)  ){
			this.stopOrder 	:= new OrderClass
			this.stopOrder.updateOrderDetails( stopOrderDetails ) 
			this.stopOrder.isCreated := true
		}

		this._loadOrderInputFromOrderbook()										// OrderClass.InputClass
		this.scrip 		:= this.entryOrder.getInput().scrip
		this.direction  := this.entryOrder.getInput().direction
		
		return true
	}

	/*	Reset All Order pointers
	*/
	unlinkOrders(){
		
		this.entryOrder		:= -1
		this.stopOrder 		:= -1
		this.isStopPending	:= false
		
		this.save()
	}
	
	/*	Called by Tracker Thread - orderStatusTracker()
		Create pending SL order when entry completes
	*/
	trackerCallback(){		

		if( this.isStopPending && this.entryOrder.isClosed() ){					// Entry Finished and we have pending stop order.
																				// Open Stop order if status = complete else Notify
			if( !this.entryOrder.isEntrySuccessful() ){
				MsgBox, % 262144+4,,  Breakout Entry Order Seems to have failed. Do you still want to create SL?
				IfMsgBox No
				{
					this.isStopPending := false
					return -1
				}
			}
			
			this.stopOrder.create()
			this.isStopPending := false
			this.save()
		}
	}
	
	/*	Returns true if entryOrder is an object and is linked with an order in orderbook
	*/
	isEntryLinked(){		
		return IsObject( this.entryOrder )  && IsObject(this.entryOrder.getOrderDetails()) 
	}
	
	/*	Returns true if stopOrder is an object and is linked with an order in orderbook
	*/
	isStopLinked(){		
		return IsObject( this.stopOrder ) && IsObject(this.stopOrder.getOrderDetails()) 
	}

	/*	Indicates whether Entry Order has status = complete
	*/
	isEntrySuccessful(){		
		return  IsObject( this.entryOrder ) && this.entryOrder.isComplete()
	}

	/*	Indicates whether Stop Order has status = complete
	*/
	isStopSuccessful(){
		return  IsObject( this.stopOrder ) && this.stopOrder.isComplete()
	}

	/*	Indicates whether Entry Order is in Order Book > Open Orders	
	*/
	isEntryOpen(){
		return  IsObject( this.entryOrder ) && this.entryOrder.isOpen()
	}
	
	/*	Indicates whether Stop Order  is in Order Book > Open Orders	
	*/
	isStopOpen(){
		return  IsObject( this.stopOrder ) && this.stopOrder.isOpen()
	}

	/*	Indicates whether Entry Order is in Order Book > Completed Orders	
	*/
	isEntryClosed(){
		return  IsObject( this.entryOrder ) && this.entryOrder.isClosed()
	}
	
	/*	Indicates whether Entry Order is in Order Book > Completed Orders	
	*/
	isStopClosed(){
		return  IsObject( this.stopOrder ) && this.stopOrder.isClosed()
	}




// -- Private ---


	/*	Set Entry Order Input details based on Order Type
	*/
	_setupEntryOrderInput( entryOrderType, qty, prodType, entryPrice, direction, scrip ){
		global MaxSlippage, ORDER_TYPE_GUI_LIMIT, ORDER_TYPE_GUI_MARKET, ORDER_TYPE_GUI_SL_MARKET, ORDER_TYPE_GUI_SL_LIMIT
		
		if( !IsObject( this.entryOrder ) )
			this.entryOrder := new OrderClass
				
		if( entryOrderType == ORDER_TYPE_GUI_LIMIT ){
			this.entryOrder.setOrderInput( entryOrderType, direction, qty, entryPrice, 0, prodType, scrip )
		}
		else if( entryOrderType == ORDER_TYPE_GUI_MARKET ){
			this.entryOrder.setOrderInput( entryOrderType, direction, qty, 0, 0, prodType, scrip  )
		}
		else if( entryOrderType == ORDER_TYPE_GUI_SL_MARKET ){
			this.entryOrder.setOrderInput( entryOrderType, direction, qty, 0, entryPrice, prodType, scrip  )
		}
		else if( entryOrderType == ORDER_TYPE_GUI_SL_LIMIT ){
			limitprice := direction == "B" ? entryPrice + MaxSlippage : entryPrice - MaxSlippage		
			this.entryOrder.setOrderInput( entryOrderType, direction, qty, limitprice, entryPrice, prodType, scrip )
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
		
	/*  Returns false if stop order should be created immediately
	*/
	_isPendingStop( entryOrderType ){
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
	_loadOrderInputFromOrderbook(){
		
		global selectedScrip, ProdType
		
		e   := this.entryOrder
		s   := this.stopOrder		
		eod := e.getOrderDetails()
		sod := s.getOrderDetails()				
		
		e.setOrderInput( e.getGUIOrderType(), e.getGUIDirection(), eod.totalQty, eod.price, eod.triggerPrice, ProdType, selectedScrip )
		s.setOrderInput( s.getGUIOrderType(), s.getGUIDirection(), sod.totalQty, sod.price, sod.triggerPrice, ProdType, selectedScrip )
	}
}

