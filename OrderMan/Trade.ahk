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
		
		if( this.isEntryLinked() ){
			this.entryOrder.cancel()			
		}
		
		if( this.isStopLinked() ){
			this.stopOrder.cancel()
		}		
		
		this.isStopPending := false
		this.entryOrder    := -1
		this.stopOrder 	   := -1
		
		updateStatus()
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
	*/
	linkOrders( entryOrderID, stopOrderID, isStopLinked ){
		global orderbookObj, selectedScrip
		
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
		
		this.direction	:= this.entryOrder.getGUIDirection()
		
		if( isStopLinked  && IsObject(stopOrderDetails)  ){
			this.stopOrder 	:= new OrderClass
			this.stopOrder.updateOrderDetails( stopOrderDetails ) 
		}

		// TradeClass.scrip and OrderClass.InputClass gets set through GUI

		return true
	}

	/*	Reset All Order pointers
	*/
	unlinkOrders(){
		
		this.entryOrder		:= -1
		this.stopOrder 		:= -1
		this.isStopPending	:= false
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
		global MaxSlippage, ORDER_TYPE_LIMIT, ORDER_TYPE_MARKET, ORDER_TYPE_SL_MARKET, ORDER_TYPE_SL_LIMIT
		
		if( !IsObject( this.entryOrder ) )
			this.entryOrder := new OrderClass
				
		if( entryOrderType == ORDER_TYPE_LIMIT ){
			this.entryOrder.setOrderInput( entryOrderType, direction, qty, entryPrice, 0, prodType, scrip )
		}
		else if( entryOrderType == ORDER_TYPE_MARKET ){
			this.entryOrder.setOrderInput( entryOrderType, direction, qty, 0, 0, prodType, scrip  )
		}
		else if( entryOrderType == ORDER_TYPE_SL_MARKET ){
			this.entryOrder.setOrderInput( entryOrderType, direction, qty, 0, entryPrice, prodType, scrip  )
		}
		else if( entryOrderType == ORDER_TYPE_SL_LIMIT ){
			limitprice := direction == "B" ? entryPrice + MaxSlippage : entryPrice - MaxSlippage		
			this.entryOrder.setOrderInput( entryOrderType, direction, qty, limitprice, entryPrice, prodType, scrip )
		}		
	}
	
	/*	Set Stop Order Input details based on Order Type
	*/
	_setupStopOrderInput( stopOrderType, qty, prodType, stopPrice, direction, scrip ){
		global ORDER_TYPE_SL_MARKET
		
		if( !IsObject( this.stopOrder ) )
			this.stopOrder := new OrderClass
				
		if( stopOrderType == ORDER_TYPE_SL_MARKET ){
			this.stopOrder.setOrderInput( stopOrderType, direction, qty, 0, stopPrice, prodType, scrip )
		}		
	}
		
	/*  Returns false if stop order should be created immediately
	*/
	_isPendingStop( entryOrderType ){
		global ORDER_TYPE_SL_LIMIT, ORDER_TYPE_SL_MARKET		
		return ( entryOrderType == ORDER_TYPE_SL_MARKET || entryOrderType == ORDER_TYPE_SL_LIMIT )
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
}

