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
	class InputClass{														// Input taken from GUI / Settings		
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

	updateOrderDetails( newdata ){
		this._orderDetails := newdata
	}
	
	
	/*
	getInput(){
		return this._input
	}
	*/
	getOrderDetails(){
		return this._orderDetails
	}
	
	isClosed(){																// Indicates whether order is in Order Book > Completed Orders 	TODO IsObject?
		return this._orderDetails.status2 == "C"
	}
	
	isOpen(){																// Indicates whether order is in Order Book > Open Orders		TODO IsObject?
		return this._orderDetails.status2 == "O"
	}	
	
	isComplete(){															// Indicates whether order status is "Complete"
		global
		return this._orderDetails.status == ORDER_STATUS_COMPLETE
	}

	getGUIDirection(){
		return this._orderDetails.buySell == "BUY" ? "B" : "S"	
	}
	
	getGUIOrderType(){
		global
		
		otype := this._orderDetails.orderType
		
		if( otype == ORDER_TYPE_LIMIT)
			return ORDER_TYPE_GUI_LIMIT
		else if( otype == ORDER_TYPE_MARKET )
			return ORDER_TYPE_GUI_MARKET
		else if( otype == ORDER_TYPE_SL_LIMIT )
			return ORDER_TYPE_GUI_SL_LIMIT
		else if( otype == ORDER_TYPE_SL_MARKET )
			return ORDER_TYPE_GUI_SL_MARKET
	}
	
	getNowOrderType( ordertype ){											// static function
		global
		
		if( ordertype == ORDER_TYPE_GUI_LIMIT )
			return ORDER_TYPE_LIMIT
		else if( ordertype == ORDER_TYPE_GUI_MARKET )
			return ORDER_TYPE_MARKET
		else if( ordertype == ORDER_TYPE_GUI_SL_LIMIT )
			return ORDER_TYPE_SL_LIMIT
		else if( ordertype == ORDER_TYPE_GUI_SL_MARKET )
			return ORDER_TYPE_SL_MARKET
	}		

	/*	Creates a New Order. Input Details should be set before calling this
	*/
	create(){
		
		global orderbookObj, ORDER_STATUS_COMPLETE, ORDER_STATUS_OPEN, ORDER_STATUS_TRIGGER_PENDING
		
		if( this.isCreated ){
			MsgBox, 262144,, Order Already created								// Should not happen
			return
		}
		
		orderbookObj.read()														// Read current status so that we can identify new order
		winTitle			:= this._openOrderForm()
		this._submitOrder( winTitle )		
		this._orderDetails  := orderbookObj.getNewOrder()

		if( this._orderDetails == -1 ){											// New order found in Orderbook ?
			
			identifier := UtilClass.orderIdentifier( this._input.direction, this._input.price, this._input.trigger) 
			MsgBox, % 262144+4,,  Order( %identifier%  ) Not Found yet in Order Book. Do you want to continue?
			IfMsgBox No
				return -1
			this._orderDetails := orderbookObj.getNewOrder()
		}

		this._waitforOrderValidation()		
		status := this._orderDetails.status		
																				// if Entry order may have failed, ask
		if( status != ORDER_STATUS_OPEN && status != ORDER_STATUS_TRIGGER_PENDING && status != ORDER_STATUS_COMPLETE  ){
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
		
		global orderbookObj, TITLE_BUY, TITLE_SELL
		
		winTitle := this._input.direction == "B" ? TITLE_BUY : TITLE_SELL	
		
		opened := orderbookObj.openModifyOrderForm( this._orderDetails.nowOrderNo, winTitle )	
		if( !opened )																// Open Order by clicking on Modify in Order Book
			return
		
		this._submitOrderCommon( winTitle )											// Fill up new details and submit 
		
		orderbookObj.read()
		this.reloadDetails()														// Get updated order details from orderbook

		if( this._orderDetails = -1 ){
			MsgBox, % 262144,,  Bug? - Updated Order not found in Orderbook after Modification
		}		
	}	

	/* Cancel Order through orderbook
	*/
	cancel(){
		global orderbookObj
		
		if( this.isOpen() && orderbookObj.selectOpenOrder( this._orderDetails.nowOrderNo ) ){
			orderbookObj.cancelSelectedOpenOrder()
			// TODO confirm cancelled else retry
			_orderDetails := -1
		}
	}

	/*	Reload _orderDetails from Orderbook. Call orderbookObj.read() first
	*/
	reloadDetails(){		
		global orderbookObj
		this._orderDetails := orderbookObj.getOrderDetails( this._orderDetails.nowOrderNo )	// Get updated order details from orderbook
	}



// -- Private ---



	/*	Open Buy / Sell Window
	*/
	_openOrderForm(){
		global TITLE_NOW, TITLE_BUY, TITLE_SELL
		
		if( this._input.direction == "B" ){
			winTitle := TITLE_BUY
			WinMenuSelectItem, %TITLE_NOW%,, Orders and Trades, Buy Order Entry	// F1 F2 F3 sometimes (rarely) does not work. Menu Does
		}
		else if( this._input.direction == "S" ){
			winTitle := TITLE_SELL
			WinMenuSelectItem, %TITLE_NOW%,, Orders and Trades, Sell Order Entry
		}		
		WinWait, %winTitle%,,5
		
		return winTitle
	}

	/*	Fill up Buy/Sell Window and Submit
	*/
	_submitOrder( winTitle ){												// Fill up opened Buy/Sell window and verify

		scrip := this._input.scrip
		
		Control, ChooseString , % scrip.segment,     ComboBox1,  %winTitle%			// Exchange Segment - NFO/NSE etc
		Control, ChooseString , % scrip.instrument,  ComboBox5,  %winTitle%			// Inst Name - FUTIDX / EQ  etc
		Control, ChooseString , % scrip.symbol, 	 ComboBox6,  %winTitle%			// Scrip Symbol
		Control, ChooseString , % scrip.type,  	 	 ComboBox7,  %winTitle%			// Type - XX/PE/CE
		Control, ChooseString , % scrip.strikePrice, ComboBox8,  %winTitle%			// Strike Price for options
		Control, Choose		  , % scrip.expiryIndex, ComboBox9,  %winTitle%			// Expiry Date - Set by Position Index (1/2 etc)

		Control, ChooseString , % this._input.orderType, ComboBox3,  %winTitle%		// Order Type - LIMIT/MARKET/SL/SL-M
		Control, ChooseString , % this._input.prodType,  ComboBox10, %winTitle%		// Prod Type - MIS/NRML/CNC
		Control, ChooseString , DAY, 	   			 	 ComboBox11, %winTitle%		// Validity - Day/IOC
		
		this._submitOrderCommon( winTitle )
	}

	/*	Fills up stuff that is relevant to both create and update orders
	*/
	_submitOrderCommon( winTitle ){
		global	TITLE_TRANSACTION_PASSWORD, AutoSubmit
		
		ControlSetText, Edit3, 	   % this._input.qty,     %winTitle%				// Qty
		if( this._input.price != 0 )
			ControlSetText, Edit4, % this._input.price,   %winTitle%				// Price
		if( this._input.trigger != 0 )
			ControlSetText, Edit7, % this._input.trigger, %winTitle%				// Trigger
		
		if( AutoSubmit ){		
			ControlClick, Button4, %winTitle%,,,, NA								// Submit Order
			WinWaitClose, %winTitle%, 2												// Wait for order window to close. If password needed, notify
			IfWinExist, %TITLE_TRANSACTION_PASSWORD%
				MsgBox, 262144,, Enter Transaction password in NOW and then click ok
		}
		
		WinWaitClose, %winTitle%
	}

	/*	Wait for order to be validated - wait if status is validation pending or put order req recieved
	*/
	_waitforOrderValidation(){
		global orderbookObj, OPEN_ORDER_WAIT_TIME, ORDER_STATUS_PUT, ORDER_STATUS_VP
		
		Loop, % OPEN_ORDER_WAIT_TIME*4 {
			
			status := this._orderDetails.status

			if( status == ORDER_STATUS_PUT || status == ORDER_STATUS_VP ){
				Sleep, 250
				orderbookObj.read()
				this.reloadDetails()
			}
			else
				break
		}
	}	

}