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

/*
	entryOrderNOW, stopOrderNOW = objects linked with our entry and stop orders in orderbook
	pendingStop = Stop order details for SL Entry waiting to be created on Entry order completion
*/
createOrders( scrip, entryOrderType, stopOrderType, direction, qty, prodType, entryPrice, stopPrice ){
	global entryOrderNOW, stopOrderNOW, pendingStop, TITLE_NOW
	
	if ( !checkOpenOrderEmpty() )
		return
	
// Entry
	entry		  := getEntryForOrderType(entryOrderType, qty, prodType, entryPrice, direction )
	entryOrderNOW := createNewOrder( direction, scrip, entry )
	if( ! IsObject(entryOrderNOW)  )
		return	
	
// Stop
	direction := reverseDirection(direction)
	stop	  := getStopForOrderType( stopOrderType, qty, prodType, stopPrice )	

	if( ! addPendingStop( entryOrderType, scrip, direction, stop ) )
		stopOrderNOW  := createNewOrder( direction, scrip, stop )
	
	updateStatus()
}

modifyOrders( scrip, entryOrderType, stopOrderType, qty, prodType, entryPrice, stopPrice  ){
	
	global entryOrderNOW, stopOrderNOW	
	
	if( IsObject(entryOrderNOW) && entryPrice != "" ){		
		
		direction 	    := getDirectionFromOrder( entryOrderNOW )			// same direction as linked order
		entry		    := getEntryForOrderType(entryOrderType, qty, prodType, entryPrice, direction )	
		entryOrderNOW   := modifyOrder( entryOrderNOW, direction, scrip, entry )
	}
	
	if( IsObject(entryOrderNOW)  && stopPrice != "" ){						// Stop can only exist if Entry Order Exist
																			// Stop can be pending, stopOrderNOW need not exist
		stop			:= getStopForOrderType( stopOrderType, qty, prodType, stopPrice  )		
		direction 	    := reverseDirection( getDirectionFromOrder( entryOrderNOW )	)
		
		if( isOrderOpen( stopOrderNOW ) )									// Order in Open Status - Modify it
			stopOrderNOW    := modifyOrder( stopOrderNOW, direction, scrip, stop )
		else if ( !IsObject( stopOrderNOW ) )								// Pending only applicable if order not created yet
			addPendingStop( entryOrderType, scrip, direction, stop )
	}
	
	updateStatus()
}

/* 
	cancel open orders - Entry/Stop
*/
cancelOrders(){
	global entryOrderNOW, stopOrderNOW, pendingStop
	
	if( isEntrySuccessful() ){	
		MsgBox, % 262144+4,,  Entry Order has already been Executed. Do you still want to cancel Stop order?
			IfMsgBox No
				return -1	
	}	
	
	if( isOrderOpen(entryOrderNOW) && selectOpenOrder( entryOrderNOW.nowOrderNo ) ){
		cancelSelectedOpenOrder()
		entryOrderNOW := -1
	}
	if( isOrderOpen(stopOrderNOW)  && selectOpenOrder( stopOrderNOW.nowOrderNo ) ){
		cancelSelectedOpenOrder()
		stopOrderNOW := -1
	}
	pendingStop := -1
	
	updateStatus()
}

/*
	Called by Tracker Thread - orderStatusTracker()
	Create SL order when entry completes, prompt if entry fails
*/
createSLOrderOnEntryTrigger(){
	global pendingStop, entryOrderNOW, stopOrderNOW
	
	if( pendingStop == -1 || !IsObject(pendingStop) || isOrderOpen( entryOrderNOW) )
		return
	
	if( isOrderClosed(entryOrderNOW) ){										// Entry Finished. Open Stop order if status = complete else Notify
		
		stop		  := pendingStop
		pendingStop   := -1	
		stopOrderNOW  := -1
		
		if( !isEntrySuccessful() ){
			MsgBox, % 262144+4,,  Breakout Entry Order Seems to have failed. Do you still want to create SL?
			IfMsgBox No
				return -1
		}
		
		stopOrderNOW  := createNewOrder( stop.direction, stop.scrip, stop.stop )		
	}	
}


// --  Private -- 
/*
	Return Entry Order details based on Order Type
*/
getEntryForOrderType(entryOrderType, qty, prodType, entryPrice, direction ){
	global MaxSlippage, ORDER_TYPE_LIMIT, ORDER_TYPE_MARKET, ORDER_TYPE_SL_MARKET, ORDER_TYPE_SL_LIMIT
	
	if( entryOrderType == ORDER_TYPE_LIMIT ){
		entry := getOrder(entryOrderType, qty, entryPrice, 0, prodType  )
	}
	else if( entryOrderType == ORDER_TYPE_MARKET ){
		entry := getOrder(entryOrderType, qty, 0, 0, prodType  )
	}
	else if( entryOrderType == ORDER_TYPE_SL_MARKET ){
		entry := getOrder(entryOrderType, qty, 0, entryPrice, prodType  )
	}
	else if( entryOrderType == ORDER_TYPE_SL_LIMIT ){
		limitprice := direction == "B" ? entryPrice + MaxSlippage : entryPrice - MaxSlippage
		entry 	   := getOrder(entryOrderType, qty, limitprice, entryPrice, prodType )
	}
	
	return entry
}

/*
	Return Stop Order details based on Order Type
*/
getStopForOrderType( stopOrderType, qty, prodType, stopPrice ){
	global ORDER_TYPE_SL_MARKET
	
	if( stopOrderType == ORDER_TYPE_SL_MARKET ){
		stop  := getOrder(stopOrderType, qty, 0, stopPrice, prodType  )
	}	
	
	return stop
}

/* Adds/Modifies Pending stop for Stop Entry Orders 
   Returns false if stop order should be created immediately
*/
addPendingStop( entryOrderType, scrip, direction, stop ){
	global stopOrderNOW, pendingStop, ORDER_TYPE_SL_LIMIT, ORDER_TYPE_SL_MARKET
	
	if( entryOrderType == ORDER_TYPE_SL_MARKET || entryOrderType == ORDER_TYPE_SL_LIMIT ){
		stopOrderNOW		  := -1
		pendingStop			  := {}
		
		pendingStop.direction := direction
		pendingStop.scrip	  := scrip
		pendingStop.stop	  := stop
		
		return true
	}		
	
	return false
}

/*
Check if a pending stop is waiting for entry to trigger
*/
isPendingStopActive(){
	global pendingStop
	return IsObject( pendingStop )
}

/*
	Modifies a single New Order
*/
modifyOrder( orderNOW,  direction, scrip, orderDetails ){
	
	global TITLE_BUY, TITLE_SELL	
	
	winTitle := direction == "B" ? TITLE_BUY : TITLE_SELL	
	
	opened := openModifyOrderForm( orderNOW, winTitle )						// Open Order by clicking on Modify in Order Book	
	if( !opened )
		return
	
	SubmitOrderCommon( winTitle, scrip, orderDetails )						// Fill up new details and submit	
	
	readOrderBook()
	orderNOW := getOrderDetails( orderNOW.nowOrderNo )						// Get updated order details

	if( orderNOW = -1 ){
		MsgBox, % 262144,,  Bug? - Updated Order not found in Orderbook after Modification
	}
	return orderNOW
}

/*
	Creates a single New Order
*/
createNewOrder( direction, scrip, order ){
	
	global ORDER_STATUS_COMPLETE, ORDER_STATUS_OPEN, ORDER_STATUS_TRIGGER_PENDING
	
	readOrderBook()															// Read current status so that we can identify new order
	
	winTitle := openOrderForm( direction )
	SubmitOrder( winTitle, scrip, order )
	
	orderNOW := getNewOrder()
	
	if( orderNOW == -1 ){													// New order found in Orderbook ?
		
		identifier := orderIdentifier( direction, order.price, order.trigger) 				
		MsgBox, % 262144+4,,  Order( %identifier%  ) Not Found yet in Order Book. Do you want to continue?
		IfMsgBox No
			return -1
		orderNOW := getNewOrder()
	}
	
	orderNOW := waitforOrderValidation( orderNOW )
	status   := orderNOW.status
																			// if Entry order may have failed, ask
	if( status != ORDER_STATUS_OPEN && status != ORDER_STATUS_TRIGGER_PENDING && status != ORDER_STATUS_COMPLETE  ){

		identifier := orderIdentifier( orderNOW.buySell, orderNOW.price, orderNOW.triggerPrice)
		MsgBox, % 262144+4,,  Order( %identifier%  ) has status - %status%. Do you want to continue?
		IfMsgBox No
			return -2
	}
	
	return orderNOW
}

/*
	Wait for order to be validated - wait if status is validation pending or put order req recieved
*/
waitforOrderValidation( order ){
	global OPEN_ORDER_WAIT_TIME, ORDER_STATUS_PUT, ORDER_STATUS_VP
	
	Loop, % OPEN_ORDER_WAIT_TIME*4 {
		
		status := order.status

		if( status == ORDER_STATUS_PUT || status == ORDER_STATUS_VP ){
			Sleep, 250
			readOrderBook()
			order := getOrderDetails( order.nowOrderNo  )
		}
		else
			break
	}

	return order
}

/*
	Open Buy / Sell Window
*/
openOrderForm( direction ){
	global TITLE_NOW, TITLE_BUY, TITLE_SELL
	
	if( direction == "B" ){
		winTitle := TITLE_BUY
		WinMenuSelectItem, %TITLE_NOW%,, Orders and Trades, Buy Order Entry	// F1 F2 F3 sometimes (rarely) does not work. Menu Does
	}
	else if( direction == "S" ){
		winTitle := TITLE_SELL
		WinMenuSelectItem, %TITLE_NOW%,, Orders and Trades, Sell Order Entry
	}		
	WinWait, %winTitle%,,5
	
	return winTitle
}

/*
	Open Buy / Sell Window for existing order
*/
openModifyOrderForm( orderNOW, winTitle ){
	global TITLE_ORDER_BOOK
		
	if( selectOpenOrder( orderNOW.nowOrderNo ) ){
		ControlClick, Button1, %TITLE_ORDER_BOOK%,,,, NA				
		WinWait, %winTitle%,,5
		
		return true
	}
	
	return false
}

/*
	Selects input order in OrderBook > Open Orders
	Returns true if found and selected else returns false
*/
selectOpenOrder( searchMeOrderNo ){
	global TITLE_ORDER_BOOK, OpenOrdersColumnIndex
	
	openOrderBook()	
	orderNoColIndex := OpenOrdersColumnIndex.nowOrderNo							// column number containing NOW Order no in Order Book > open orders
	
	Loop, 3{																	// Select order in Order Book. Search 3 times as a precaution
		ControlGet, RowCount, List, Count, SysListView321, %TITLE_ORDER_BOOK%	// No of rows in open orders
		ControlSend, SysListView321, {Home 2}, %TITLE_ORDER_BOOK%				// Start from top and search for order

		Loop, %RowCount%{														// Get order number of selected row and compare
			ControlGet, RowOrderNo, List, Selected Col%orderNoColIndex%, SysListView321, %TITLE_ORDER_BOOK%
		
			if( RowOrderNo = searchMeOrderNo ){									// Found and Selected
				return true
			}
			ControlSend, SysListView321, {Down}, %TITLE_ORDER_BOOK%				// Move Down to next row if not found yet
		}				
	}
	
	MsgBox, Order %searchMeOrderNo% Not Found in OrderBook > Open Orders
	return false
}

/*
	Clicks on cancel button in orderbook, assuming order is already selected
*/
cancelSelectedOpenOrder(){
	global TITLE_ORDER_BOOK
	
	window 		:= "NOW"
	windowText	:= "Cancel These Order"
	
	ControlClick, Button3, %TITLE_ORDER_BOOK%,,,, NA				// Click Cancel
	
	WinWait, %window%, %windowText%, 5		
	WinSet, Transparent, 1, %window%, %windowText%
	
	ControlClick, Button1, %window%, %windowText%,,, NA				// Click ok
}

/*
	Fill up Buy/Sell Window and Submit
*/
SubmitOrder( winTitle, scrip, order ){										// Fill up opened Buy/Sell window and verify
	
	Control, ChooseString , % scrip.segment,     ComboBox1,  %winTitle%		// Exchange Segment - NFO/NSE etc
	Control, ChooseString , % scrip.instrument,  ComboBox5,  %winTitle%		// Inst Name - FUTIDX / EQ  etc
	Control, ChooseString , % scrip.symbol, 	 ComboBox6,  %winTitle%		// Scrip Symbol
	Control, ChooseString , % scrip.type,  	   	 ComboBox7,  %winTitle%		// Type - XX/PE/CE
	Control, ChooseString , % scrip.strikePrice, ComboBox8,  %winTitle%		// Strike Price for options
	Control, Choose		  , % scrip.expiryIndex, ComboBox9,  %winTitle%		// Expiry Date - Set by Position Index (1/2 etc)

	Control, ChooseString , % order.orderType,   ComboBox3,  %winTitle%		// Order Type - LIMIT/MARKET/SL/SL-M
	Control, ChooseString , % order.prodType,    ComboBox10, %winTitle%		// Prod Type - MIS/NRML/CNC
	Control, ChooseString , DAY, 			   	 ComboBox11, %winTitle%		// Validity - Day/IOC
	
	SubmitOrderCommon( winTitle, scrip, order  )
}

/*
	Fills up stuff that is relevant to both create and update orders
*/
SubmitOrderCommon( winTitle, scrip, order ){
	global	TITLE_TRANSACTION_PASSWORD, AutoSubmit

	ControlSetText, Edit3, % order.qty,     %winTitle%						// Qty
	if( order.price != 0 )
		ControlSetText, Edit4, % order.price,   %winTitle%					// Price
	if( order.trigger != 0 )
		ControlSetText, Edit7, % order.trigger, %winTitle%					// Trigger
	
	if( AutoSubmit ){		
		ControlClick, Button4, %winTitle%,,,, NA							// Submit Order		
		WinWaitClose, %winTitle%, 2											// Wait for order window to close. If password needed, notify	
		IfWinExist, %TITLE_TRANSACTION_PASSWORD%
			MsgBox, 262144,, Enter Transaction password in NOW and then click ok
	}
	
	WinWaitClose, %winTitle%
}

/*
	If Open orders exist, Notify User. Used on startup to warn
*/
checkOpenOrderEmpty(){
	if( doOpenOrdersExist() ){												// Entry
		MsgBox, % 262144+4,, Some Open Orders already exist . Continue?
		IfMsgBox No
			return false
	}
	return true
}

orderIdentifier( direction, price, trigger ){
	identifier := direction . ", Price " . price . ", Trigger " . trigger
	return identifier
}
