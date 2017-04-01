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



class OrderClass{
	class InputClass{														// Input taken from GUI / Settings - Used to create/update Order
		orderType	:= ""
		direction	:= ""
		qty			:= ""
		price		:= ""
		trigger		:= ""
		prodType	:= ""
		scrip		:= ""													// Scrip Object
	}
	
	_input			:= new this.InputClass
	_orderDetails	:= -1													// Order Details read from orderbook for this order	
	isCreated		:= false


	setOrderInput( orderType, direction, qty, price, triggerprice, prodType, scrip  ){
		this._input.orderType := orderType
		this._input.direction := direction
		this._input.qty 	  := qty
		this._input.price 	  := price
		this._input.trigger   := triggerprice
		this._input.prodType  := prodType
		this._input.scrip  	  := scrip									// scrip object
	}	

	setInputPrice( price, triggerprice)  {
		this._input.price 	  := price
		this._input.trigger   := triggerprice
	}
	
	setInputQty( qty ){
		this._input.qty := qty
	}
	
	setOrderDetails( newdata ){
		this._orderDetails := newdata
	}
	
	
	
	getInput(){
		return this._input
	}
	
	getOrderDetails(){
		return this._orderDetails
	}
	
	getPrice(){
		global ORDER_TYPE_GUI_LIMIT, ORDER_TYPE_GUI_MARKET, ORDER_TYPE_GUI_SL_MARKET, ORDER_TYPE_GUI_SL_LIMIT
		
		ot := this._input.orderType
		
		if( ot == ORDER_TYPE_GUI_LIMIT  ||  ot == ORDER_TYPE_GUI_MARKET ){
			return this._input.price
		}
		else if( ot == ORDER_TYPE_GUI_SL_MARKET || ot == ORDER_TYPE_GUI_SL_LIMIT ){
			return this._input.trigger
		}
		else
			return 0	// should not happen
	}

	isClosed(){																// Indicates whether order is in Order Book > Completed Orders
		return this._orderDetails.isClosed()
	}
	
	isOpen(){																// Indicates whether order is in Order Book > Open Orders
		return this._orderDetails.isOpen()
	}	
	
	isComplete(){															// Indicates whether order status is "Complete"		
		return this._orderDetails.isComplete()
	}

	getFilledQty(){
		return this._orderDetails.tradedQty
	}
	
	getOpenQty(){
		return this._orderDetails.totalQty - this.getFilledQty()
	}
	getTotalQty(){
		return this._orderDetails.totalQty
	}

	getGUIDirection(){
		global controlObj
		return this._orderDetails.buySell == controlObj.ORDER_DIRECTION_BUY ? "B" : "S"	
	}
	
	getGUIOrderType(){
		global controlObj, ORDER_TYPE_GUI_LIMIT, ORDER_TYPE_GUI_MARKET, ORDER_TYPE_GUI_SL_LIMIT, ORDER_TYPE_GUI_SL_MARKET
		
		nowtype 	  := this._orderDetails.orderType
		triggerPrice  := this._orderDetails.triggerPrice
		price  		  := this._orderDetails.price
		
		if( nowtype == controlObj.ORDER_TYPE_LIMIT){						// LIMIT -  If Trigger price is set, its triggered Stop Order
			if( triggerPrice != "" && triggerPrice != 0 ){
				if( price == "" || price == 0 )
					return ORDER_TYPE_GUI_SL_MARKET
				else
					return ORDER_TYPE_GUI_SL_LIMIT
			}
			else 
				return ORDER_TYPE_GUI_LIMIT
		}
		else if( nowtype == controlObj.ORDER_TYPE_MARKET )
			return ORDER_TYPE_GUI_MARKET
		else if( nowtype == controlObj.ORDER_TYPE_SL_LIMIT )
			return ORDER_TYPE_GUI_SL_LIMIT
		else if( nowtype == controlObj.ORDER_TYPE_SL_MARKET )
			return ORDER_TYPE_GUI_SL_MARKET
	}
	
	getNowOrderType(){														// Convert froom GUI ordertype save in _input to what is expected by NOW
		global
		
		local guitype := this._input.orderType
		
		if( guitype == ORDER_TYPE_GUI_LIMIT )
			return controlObj.ORDER_TYPE_LIMIT
		else if( guitype == ORDER_TYPE_GUI_MARKET )
			return controlObj.ORDER_TYPE_MARKET
		else if( guitype == ORDER_TYPE_GUI_SL_LIMIT )
			return controlObj.ORDER_TYPE_SL_LIMIT
		else if( guitype == ORDER_TYPE_GUI_SL_MARKET )
			return controlObj.ORDER_TYPE_SL_MARKET
	}		

	/*	Creates a New Order. Input Details should be set before calling this
	*/
	create(){
		
		global orderbookObj, controlObj
		
		if( this.isCreated ){
			MsgBox, 262144,, Order Already created								// Should not happen
			return
		}
		if( this._input.qty <= 0  )
			return
		
		orderbookObj.read()														// Read current status so that we can identify new order
		winTitle := this._openOrderForm()
		
		toggleStatusTracker("off")												// Turn off Tracker thread during order creation
																				// Otherwise it can also read orderbook in between and we will not be able to 
		this._submitOrder( winTitle )											// detect newly created order.
		this._orderDetails  := orderbookObj.getNewOrder()						// Tracker thread can be on when this create() is for adds

		if( !IsObject(this._orderDetails) ){									// New order found in Orderbook ?
			
			identifier := UtilClass.orderIdentifier( this._input.direction, this._input.price, this._input.trigger) 
			MsgBox, % 262144+4,,  Order( %identifier%  ) Not Found yet in Order Book. Was the Order Created?
			IfMsgBox No
			{
				toggleStatusTracker("on")
				return -1
			}
			this._orderDetails := orderbookObj.getNewOrder()
		}
		
		toggleStatusTracker("on")												// Turn back on after new order has been read

		this._waitforOrderValidation()		
		status := this._orderDetails.status		
																				// if Entry order may have failed, ask
		if( status != controlObj.ORDER_STATUS_OPEN && status != controlObj.ORDER_STATUS_TRIGGER_PENDING && status != controlObj.ORDER_STATUS_COMPLETE  ){
			od := this._orderDetails
			identifier := UtilClass.orderIdentifier( od.buySell, od.price, od.triggerPrice)
			MsgBox, % 262144+4,,  Order( %identifier%  ) has status - %status%. Do you want to continue?
			IfMsgBox No
				return -2
		}
		
		this.isCreated := true		
	}

	/*	Modifies order. Input Details should be set before calling this
	*/
	update(){		
		
		global orderbookObj, controlObj
		
		if( ! this._hasOrderChanged() )
			return
		
		if( this._input.qty <= 0  ){												// If qty is 0, cancel the order
			if( !this.cancel() ){
				orderno := this._orderDetails.nowOrderNo
				MsgBox, 262144,, Order cancellation failed. Order No: %orderno%
			}
			return
		}
		
		winTitle := this._input.direction == "B" ? controlObj.ORDER_ENTRY_TITLE_BUY : controlObj.ORDER_ENTRY_TITLE_SELL	
		
		opened := orderbookObj.openModifyOrderForm( this._orderDetails.nowOrderNo, winTitle )	
		if( !opened )																// Open Order by clicking on Modify in Order Book
			return
		
		this._submitOrderCommon( winTitle )											// Fill up new details and submit 
		
		orderbookObj.read()
		this.reloadDetails()														// Get updated order details from orderbook

		if( !IsObject( this._orderDetails )){
			MsgBox, % 262144,,  Bug? - Updated Order not found in Orderbook after Modification
		}		
	}	

	/* Cancel Order through orderbook
	   Returns true if order is Closed else false
	*/
	cancel(){
		global orderbookObj

		if( !this.isOpen() ) 												// Only cancel open orders
			return true

		Loop, 5 {															// Try upto 5 times 
			selected := orderbookObj.selectOpenOrder( this._orderDetails.nowOrderNo )
			if( selected ){
				orderbookObj.cancelSelectedOpenOrder()
			}
																			// Wait for some time for Orderbook to update
			Sleep, 250														// orderbookObj.read() and orderbookObj.selectOpenOrder() should happen together
																			// else selectOpenOrder() will be on old data
			orderbookObj.read()
			this.reloadDetails()
			
			if( this.isClosed() ){											// verify cancelled
				_orderDetails == -1
				return true
			}
		}		
		
		if( !selected  ){
			orderno := this._orderDetails.nowOrderNo
			MsgBox, Order %orderno% Not Found in OrderBook > Open Orders
		}

		return false														// cancel failed
	}

	/*	Reload _orderDetails from Orderbook. Call orderbookObj.read() first
	*/
	reloadDetails(){		
		global orderbookObj
		this._orderDetails := orderbookObj.getOrderDetails( this._orderDetails.nowOrderNo )	// Get updated order details from orderbook
	}

	/*  Reads Data from input orderDetails (ie Orderbook) and sets up OrderClass._orderDetails and OrderClass._input (GUI input)
		Used to link to existing orders
		Call orderbookObj.read() before calling this
		Input orderDetails is optional - If passed, we set it as _orderDetails
	*/
	loadOrderFromOrderbook( orderBookDetails  ){
		
		global selectedScrip, ProdType
		
		if( IsObject(orderBookDetails) )
			this._orderDetails := orderBookDetails

		od := this._orderDetails

		if( IsObject( od ) ){
			this.setOrderInput( this.getGUIOrderType(), this.getGUIDirection(), od.totalQty, od.price, od.triggerPrice, ProdType, selectedScrip )				
			this.isCreated := true
		}
	}

	/* Returns true if _orderDetails is set. ie Order is linked to order in orderbook
	*/
	isLinked(){
		return  IsObject( this._orderDetails )
	}

	getOrderString(){
		return UtilClass.orderIdentifier( this._input.direction, this._input.price, this._input.trigger )
	}


// -- Private ---

	/* Compares input with orderDetails to check if order has changed
		compares  ordertype, qty, price, trigger price
	*/
	_hasOrderChanged(){
		if( this._input.orderType != this.getGUIOrderType() )
			return true
		if( this._input.qty 	  != this._orderDetails.totalQty )
			return true
		if( this._input.price     != this._orderDetails.price )
			return true
		if( this._input.trigger   != this._orderDetails.triggerPrice )
			return true
		
		return false
	}

	/*	Open Buy / Sell Window
	*/
	_openOrderForm(){
		global TITLE_NOW, controlObj
		
		Loop, 5{															// Try upto 5 times
			if( this._input.direction == "B" ){								// F1 F2 F3 sometimes (rarely) does not work. Menu Does
				
				winTitle := % controlObj.ORDER_ENTRY_TITLE_BUY
				menus 	 := StrSplit( controlObj.ORDER_ENTRY_MENU_BUY , ",")
			}
			else if( this._input.direction == "S" ){
				winTitle := % controlObj.ORDER_ENTRY_TITLE_SELL
				menus 	 := StrSplit( controlObj.ORDER_ENTRY_MENU_SELL , ",")
			}
			
			if( menus.MaxIndex() == 3 )
				WinMenuSelectItem, %TITLE_NOW%,, % menus[1], % menus[2], % menus[3]
			else
				WinMenuSelectItem, %TITLE_NOW%,, % menus[1], % menus[2]
				
			WinWait, %winTitle%,,2
			if !ErrorLevel
				break
		}
		if ErrorLevel
			MsgBox, Could not open Buy/Sell Window
		
		return winTitle
	}

	/*	Fill up Buy/Sell Window and Submit
	*/
	_submitOrder( winTitle ){												// Fill up opened Buy/Sell window and verify
		
		global controlObj

		scrip     := this._input.scrip
		ordertype := this.getNowOrderType()
		
		Control, ChooseString , % scrip.segment,     	% controlObj.ORDER_ENTRY_EXCHANGE_SEGMENT,  %winTitle%			// Exchange Segment - NFO/NSE etc
		Control, ChooseString , % scrip.instrument,  	% controlObj.ORDER_ENTRY_INST_NAME,  		%winTitle%			// Inst Name - FUTIDX / EQ  etc
		Control, ChooseString , % scrip.symbol, 	 	% controlObj.ORDER_ENTRY_SYMBOL,  		 	%winTitle%			// Scrip Symbol

		if( scrip.type != "" )
			Control, ChooseString , % scrip.type,  	 	% controlObj.ORDER_ENTRY_TYPE,  			%winTitle%			// Type - XX/PE/CE
		if( scrip.strikePrice != "" )
			Control, ChooseString , % scrip.strikePrice, 	% controlObj.ORDER_ENTRY_STRIKE_PRICE, 	%winTitle%			// Strike Price for options
		if( scrip.expiryIndex != "" )
			Control, Choose		  , % scrip.expiryIndex, 	% controlObj.ORDER_ENTRY_EXPIRY_DATE,  	%winTitle%			// Expiry Date - Set by Position Index (1/2 etc)
		
		Control, ChooseString , % ordertype, 		 	% controlObj.ORDER_ENTRY_ORDER_TYPE,  		%winTitle%			// Order Type - LIMIT/MARKET/SL/SL-M
		Control, ChooseString , % this._input.prodType, % controlObj.ORDER_ENTRY_PROD_TYPE,    		%winTitle%			// Prod Type - MIS/NRML/CNC
		Control, ChooseString , DAY, 	   			 	% controlObj.ORDER_ENTRY_VALIDITY, 			%winTitle%			// Validity - Day/IOC

		this._submitOrderCommon( winTitle )
	}

	/*	Fills up stuff that is relevant to both create and update orders
	*/
	_submitOrderCommon( winTitle ){
		global	controlObj, AutoSubmit
		
		ControlSetText, % controlObj.ORDER_ENTRY_QTY, 				% this._input.qty, 		%winTitle%		// Qty
		if( this._input.price != 0 )
			ControlSetText, % controlObj.ORDER_ENTRY_PRICE, 		% this._input.price, 	%winTitle%		// Price
		if( this._input.trigger != 0 )
			ControlSetText, % controlObj.ORDER_ENTRY_TRIGGER_PRICE, % this._input.trigger, 	%winTitle%		// Trigger
		
		if( AutoSubmit ){		
			ControlClick, % controlObj.ORDER_ENTRY_SUBMIT, %winTitle%,,,, NA								// Submit Order
			
			Sleep, 100
			IfWinExist, % controlObj.ORDER_ENTRY_CONFIRMATION_TITLE											// Zt - confirm and close order
			{
				ControlClick, % controlObj.ORDER_ENTRY_SUBMIT, % controlObj.ORDER_ENTRY_CONFIRMATION_TITLE,,,, NA	 
				WinWait,  % controlObj.ORDER_ENTRY_SUBMITTED_TITLE,,2
				WinClose, % controlObj.ORDER_ENTRY_SUBMITTED_TITLE
				WinWaitClose, % controlObj.ORDER_ENTRY_SUBMITTED_TITLE, 2	
			}
			
			WinWaitClose, %winTitle%, 2																		// Wait for order window to close. If password needed, notify
			IfWinExist, % controlObj.ORDER_ENTRY_TITLE_TRANSACTION_PASSWORD
				MsgBox, 262144,, Enter Transaction password in NOW and then click ok
		}
		
		WinWaitClose, %winTitle%
	}

	/*	Wait for order to be validated - wait if status is 'validation pending', 'open pending' or 'put order req recieved'
	*/
	_waitforOrderValidation(){
		global orderbookObj, OPEN_ORDER_WAIT_TIME, controlObj
		
		Loop, % OPEN_ORDER_WAIT_TIME*4 {
			
			status := this._orderDetails.status

			if( status == controlObj.ORDER_STATUS_PUT || status == controlObj.ORDER_STATUS_VP ||  status == controlObj.ORDER_STATUS_OPEN_PENDING ){
				Sleep, 250
				orderbookObj.read()
				this.reloadDetails()
			}
			else
				break
		}
	}
}