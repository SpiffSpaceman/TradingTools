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

readOrderBook(){	
	
	openOrderBook()	
	readColumnHeaders()											// Find required columns in orderbook	
	readOpenOrders()
	readCompletedOrders()	
}

initializeStatusTracker(){
	SetTimer, orderStatusTracker, 2500
	SetTimer, orderStatusTracker, off
}

toggleStatusTracker( on_off ){
	
	static isTimerActive := false
	
	if( on_off == "on" ){
		if( !isTimerActive ){
			isTimerActive := true
			SetTimer, orderStatusTracker, on
		}
	}
	else if( on_off == "off"  ){
		if( isTimerActive ){
			isTimerActive := false
			SetTimer, orderStatusTracker, off
		}
	}
	return isTimerActive
}

orderStatusTracker(){
	Critical 													// Mark Timer thread Data fetch as Critical to avoid any possible Mixup with main thread ( esp with linked orders )
																	// Marking it as critical should avoid Main thread from running
	refreshLinkedOrderDetails()										// Otherwise can get problem with entryOrderNOW / stopOrderNOW in unlink()
	Critical , off
	
	updateStatus()
}

doOpenOrdersExist(){
	global OpenOrders
	
	readOpenOrders()
	return OpenOrders.size > 0 
}

/*
   Get Order ID of newly opened orders, searches both open and completed orders
   Assuming only 1 opened/completed since last read
   So readOpenOrders(),readCompletedOrders() should be called before creating new order and
	  getNewOrder() should be immediately called after creating new order
   
   Returns order object if found, -1 if not found
*/
getNewOrder(){											
	global OpenOrders, CompletedOrders
	
	openOrdersOld		:=  OpenOrders
	completedOrdersOld  :=  CompletedOrders
	
	Loop, 5{													// Wait for upto 5 seconds for new order
		readOpenOrders()
		readCompletedOrders()
		
		if( openOrdersOld.size < OpenOrders.size || completedOrdersOld.size < CompletedOrders.size )
			break
		Sleep, 1000
	}
	if( openOrdersOld.size >= OpenOrders.size  && completedOrdersOld.size >= CompletedOrders.size )
		return -1
		
	foundOrder := getNewOrder_( openOrdersOld, OpenOrders )		// Find order that doesnt exist in openOrdersOld / completedOrdersOld
	if( foundOrder ==-1 )
		foundOrder := getNewOrder_( completedOrdersOld, CompletedOrders )	

	return foundOrder
}

linkOrders( entryOrderID, stopOrderID ){
	
	global entryOrderNOW, stopOrderNOW
	
	order := getOrderDetails( entryOrderID )
	if( order == -1 ){
		MsgBox, 262144,, Order %entryOrderID% Not found
		return false
	}
		
	order2 := getOrderDetails( stopOrderID )
	if( order2 == -1 ){
		MsgBox, 262144,, Order %stopOrderID% Not found
		return false
	}
	
	if( order.tradingSymbol != order2.tradingSymbol  ){
		MsgBox, 262144,, Orders have different Trading Symbols 
		return false	
	}
	
	entryOrderNOW := order
	stopOrderNOW  := order2
	return true
}

unlinkOrders(){
	global entryOrderNOW, stopOrderNOW
	
	entryOrderNOW := -1
	stopOrderNOW  := -1
}

/*
	Search input NOW order number in Order Book 
	Returns order details if found else -1
*/
getOrderDetails( inNowOrderNo ){
	
	global OpenOrders, CompletedOrders
	
	readOrderBook()
	
	order := getOrderDetails_(OpenOrders,  inNowOrderNo )
	if( order == -1 ){
		order := getOrderDetails_(CompletedOrders,  inNowOrderNo )
	}
	return order
}

refreshLinkedOrderDetails(){	
	global entryOrderNOW, stopOrderNOW
	
	if( IsObject(entryOrderNOW) )
		entryOrderNOW := getOrderDetails( entryOrderNOW.nowOrderNo )
	
	if( IsObject(stopOrderNOW) )
		stopOrderNOW  := getOrderDetails( stopOrderNOW.nowOrderNo )
}

isEntryComplete(){
	global entryOrderNOW, ORDER_STATUS_COMPLETE
	
	return  IsObject( entryOrderNOW ) && entryOrderNOW.status == ORDER_STATUS_COMPLETE
}

isStatusOpen( status ){
	global ORDER_STATUS_OPEN, ORDER_STATUS_TRIGGER_PENDING
	return status==ORDER_STATUS_OPEN || status==ORDER_STATUS_TRIGGER_PENDING
}

// ----------

getOrderDetails_( list, orderno){
	Loop, % list.size {
		i := A_Index
		if( list[i].nowOrderNo ==  orderno ){					// Found
			return list[i]
		}	
	}
	return -1
}

getNewOrder_( oldList, newList ){
	
	Loop, % newList.size {
		i 	  := A_Index	
		found := false
		
		Loop, % oldList.size {
			j := A_Index
			
			if( newList[i].nowOrderNo == oldList[j].nowOrderNo ){	
				found := true									// Found In old Order list
				break
			}
		}
		if( !found ){
			return newList[i]
		}
	}
	return -1
}

openOrderBook(){
	global TITLE_NOW, TITLE_ORDER_BOOK
	
	IfWinExist,  %TITLE_ORDER_BOOK%
		return
	
	WinGetTitle, currentWindow, A 								// ControlSend F3 is activating NOW. Workaround save and active current window			
	ControlSend, SysListView323 , {F3}, %TITLE_NOW%				// open orderbook		
	WinActivate, %currentWindow%	
	
	WinWait, %TITLE_ORDER_BOOK%
	WinMinimize, %TITLE_ORDER_BOOK%	
}

readOpenOrders(){
	global TITLE_ORDER_BOOK, OpenOrdersColumnIndex, OpenOrders
	
	openOrderBook()												// Open order book if not already opened	
	
	OpenOrders	    := {}
	OpenOrders.size := 0
	
	ControlGet, openOrdersRaw, List, , SysListView321, %TITLE_ORDER_BOOK%
		
	Loop, Parse, openOrdersRaw, `n  							// Extract our columns from table
	{															// Rows are delimited by linefeeds (`n)
		order := {} 											// Fields (columns) in each row are delimited by tabs (A_Tab)
		Loop, Parse, A_LoopField, %A_Tab%  									
		{				
			if( A_Index ==  OpenOrdersColumnIndex.orderType )
				order.orderType 	 := A_LoopField	
			else if( A_Index ==  OpenOrdersColumnIndex.buySell ) 
				order.buySell 	  	 := A_LoopField
			else if( A_Index ==  OpenOrdersColumnIndex.tradingSymbol ) 
				order.tradingSymbol := A_LoopField
			else if( A_Index ==  OpenOrdersColumnIndex.totalQty ) 
				order.totalQty 	 := A_LoopField
			else if( A_Index ==  OpenOrdersColumnIndex.pendingQty ) 
				order.pendingQty 	 := A_LoopField
			else if( A_Index ==  OpenOrdersColumnIndex.price ) 
				order.price 		 := A_LoopField
			else if( A_Index ==  OpenOrdersColumnIndex.triggerPrice ) 
				order.triggerPrice  := A_LoopField
			else if( A_Index ==  OpenOrdersColumnIndex.status ) 
				order.status 		 := A_LoopField
			else if( A_Index ==  OpenOrdersColumnIndex.nowOrderNo ) 
				order.nowOrderNo 	 := A_LoopField
			else if( A_Index ==  OpenOrdersColumnIndex.nowUpdateTime ) 
				order.nowUpdateTime := A_LoopField
		}
		OpenOrders[A_Index] := order
		OpenOrders.size++	
	}
}

readCompletedOrders(){
	global TITLE_ORDER_BOOK, CompletedOrdersColumnIndex, CompletedOrders
	
	openOrderBook()
		
	CompletedOrders	  	 := {}
	CompletedOrders.size := 0
	
	ControlGet, completedOrdersRaw, List, , SysListView322, %TITLE_ORDER_BOOK%
		
	Loop, Parse, completedOrdersRaw, `n
	{
		order := {}
		Loop, Parse, A_LoopField, %A_Tab%
		{
			if( A_Index ==  CompletedOrdersColumnIndex.orderType )
				order.orderType 	 := A_LoopField	
			else if( A_Index ==  CompletedOrdersColumnIndex.buySell ) 
				order.buySell 	  	 := A_LoopField
			else if( A_Index ==  CompletedOrdersColumnIndex.tradingSymbol ) 
				order.tradingSymbol  := A_LoopField
			else if( A_Index ==  CompletedOrdersColumnIndex.totalQty ) 
				order.totalQty 	     := A_LoopField
			else if( A_Index ==  CompletedOrdersColumnIndex.pendingQty ) 
				order.pendingQty 	 := A_LoopField
			else if( A_Index ==  CompletedOrdersColumnIndex.price ) 
				order.price 		 := A_LoopField
			else if( A_Index ==  CompletedOrdersColumnIndex.triggerPrice ) 
				order.triggerPrice   := A_LoopField
			else if( A_Index ==  CompletedOrdersColumnIndex.status ) 
				order.status 		 := A_LoopField
			else if( A_Index ==  CompletedOrdersColumnIndex.nowOrderNo ) 
				order.nowOrderNo 	 := A_LoopField
			else if( A_Index ==  CompletedOrdersColumnIndex.nowUpdateTime ) 
				order.nowUpdateTime := A_LoopField
			else if( A_Index ==  CompletedOrdersColumnIndex.rejectionReason ) 
				order.rejectionReason := A_LoopField			
		}
		CompletedOrders[A_Index] := order
		CompletedOrders.size++
	}	
}

readColumnHeaders(){
	global	TITLE_ORDER_BOOK, OpenOrdersColumnIndex, CompletedOrdersColumnIndex
	
	openOrderBook()
	
	if( !IsObject(OpenOrdersColumnIndex) )
		OpenOrdersColumnIndex := {}	
	if( !IsObject(CompletedOrdersColumnIndex) )
		CompletedOrdersColumnIndex := {}	
	
// Open Orders
	// Read column header texts and extract position for columns that we need
	allHeaders  := GetExternalHeaderText( TITLE_ORDER_BOOK, "SysHeader321")		
	headers		:= ["Order Type", "Buy/Sell", "Trading Symbol", "Total Qty", "Pending Qty", "Price", "TriggerPrice", "Status", "NOWOrderNo", "NOW UpdateTime"]
	keys		:= ["orderType",  "buySell",  "tradingSymbol",  "totalQty",  "pendingQty",  "price", "triggerPrice", "status", "nowOrderNo", "nowUpdateTime"]			
	
	extractColumnIndices( "Order Book > Open Orders",  allHeaders, headers, OpenOrdersColumnIndex, keys )
	
// Completed Orders
	allHeaders  := GetExternalHeaderText( TITLE_ORDER_BOOK, "SysHeader322")
	headers		:= ["Order Type", "Buy/Sell", "Trading Symbol", "Total Qty", "Pending Qty", "Price", "TriggerPrice", "Status", "NOWOrderNo", "NOW UpdateTime", "Rejection Reason"]
	keys		:= ["orderType",  "buySell",  "tradingSymbol",  "totalQty",  "pendingQty",  "price", "triggerPrice", "status", "nowOrderNo", "nowUpdateTime", "rejectionReason"]
	
	extractColumnIndices( "Order Book > Completed Orders",  allHeaders, headers, CompletedOrdersColumnIndex, keys )	
}
/*
	listIdentifier= Identifier text for the List, used in error message
	allHeaders    = headers extracted from GetExternalHeaderText
	targetHeaders = Array of headers that we want to search in allHeaders
	targetObject  = Object to save positions with key taken from targetKeys and value = Column position
	Gives Error if Column is not found
*/
extractColumnIndices( listIdentifier, allHeaders, targetHeaders, targetObject, targetKeys  ){
	
	for index, headertext in allHeaders{
		Loop % targetHeaders.MaxIndex(){							// Loop through all needed columns and check if headertext is one of them 
			columnText	:= targetHeaders[A_Index]					// column we want
			key         := targetKeys[A_Index]						// key for OpenOrdersColumnIndex. Value = column position
			
			if( headertext ==  columnText ){						// column found, save index
				targetObject[key] := index
				break
			}
		}		
	}
	Loop % targetHeaders.MaxIndex(){								// Verify that all columns were found
		columnText	:= targetHeaders[A_Index]
		key         := targetKeys[A_Index]
	
		checkEmpty( targetObject[key], columnText, listIdentifier )
	}
}

checkEmpty( value, field, listName ){
	global TITLE_ORDER_BOOK
	
	if( value == "" ){
		MsgBox, 262144,, Column %field% not found in %listName%
		WinClose, %TITLE_ORDER_BOOK%	
		Exit
	}
}

