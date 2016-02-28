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

class OrderbookClass{

	OpenOrders					:= ""
	CompletedOrders				:= ""
	
	_openOrdersColumnIndex		:= {}
	_completedOrdersColumnIndex	:= {}
	
	

	/*	Opens Order book and fetches all order details
	*/
	read(){	
		
		this.open()	
		this._readColumnHeaders()											// Find required columns in orderbook	
		this.readOpenOrders()
		this.readCompletedOrders()	
	}

	open(){
		global
		
		IfWinExist,  %TITLE_ORDER_BOOK%
			return
		
		WinMenuSelectItem, %TITLE_NOW%,, Orders and Trades, Order Book		// open orderbook

		WinWait, %TITLE_ORDER_BOOK%
		WinMinimize, %TITLE_ORDER_BOOK%	
	}

	/*	Parse Through Order book > open orders
	*/
	readOpenOrders(){
		global TITLE_ORDER_BOOK
		
		this.open()													// Open order book if not already opened
		
		this.OpenOrders	     := {}
		this.OpenOrders.size := 0
		index				 := this._openOrdersColumnIndex
		
		ControlGet, openOrdersRaw, List, , SysListView321, %TITLE_ORDER_BOOK%
		
		Loop, Parse, openOrdersRaw, `n  							// Extract our columns from table
		{															// Rows are delimited by linefeeds (`n)
			order := new OrderDetailsClass							// Fields (columns) in each row are delimited by tabs (A_Tab)
			Loop, Parse, A_LoopField, %A_Tab%  									
			{				
				if( A_Index ==  index.orderType )
					order.orderType 	 := A_LoopField	
				else if( A_Index ==  index.buySell ) 
					order.buySell 	  	 := A_LoopField
				else if( A_Index ==  index.tradingSymbol ) 
					order.tradingSymbol := A_LoopField
				else if( A_Index ==  index.totalQty ) 
					order.totalQty 	 := A_LoopField
				else if( A_Index ==  index.pendingQty ) 
					order.pendingQty 	 := A_LoopField
				else if( A_Index ==  index.price ) 
					order.price 		 := A_LoopField
				else if( A_Index ==  index.triggerPrice ) 
					order.triggerPrice  := A_LoopField
				else if( A_Index ==  index.averagePrice ) 
					order.averagePrice  := A_LoopField
				else if( A_Index ==  index.status ) 
					order.status 		 := A_LoopField
				else if( A_Index ==  index.nowOrderNo ) 
					order.nowOrderNo 	 := A_LoopField
				else if( A_Index ==  index.nowUpdateTime ) 
					order.nowUpdateTime := A_LoopField
			}
			order.status2		:= "O"								// Is Order Open or Completed
			
			this.OpenOrders[A_Index] := order
			this.OpenOrders.size++	
		}
	}
	
	/*	Parse Through Order book > completed orders
	*/
	readCompletedOrders(){
		global TITLE_ORDER_BOOK
		
		this.open()
			
		this.CompletedOrders	  := {}
		this.CompletedOrders.size := 0
		index				 	  := this._completedOrdersColumnIndex
		
		ControlGet, completedOrdersRaw, List, , SysListView322, %TITLE_ORDER_BOOK%
			
		Loop, Parse, completedOrdersRaw, `n
		{
			order := new OrderDetailsClass
			Loop, Parse, A_LoopField, %A_Tab%
			{
				if( A_Index ==  index.orderType )
					order.orderType 	 := A_LoopField	
				else if( A_Index ==  index.buySell ) 
					order.buySell 	  	 := A_LoopField
				else if( A_Index ==  index.tradingSymbol ) 
					order.tradingSymbol  := A_LoopField
				else if( A_Index ==  index.totalQty ) 
					order.totalQty 	     := A_LoopField
				else if( A_Index ==  index.pendingQty ) 
					order.pendingQty 	 := A_LoopField
				else if( A_Index ==  index.price ) 
					order.price 		 := A_LoopField
				else if( A_Index ==  index.triggerPrice ) 
					order.triggerPrice   := A_LoopField
				else if( A_Index ==  index.averagePrice ) 
					order.averagePrice   := A_LoopField
				else if( A_Index ==  index.status ) 
					order.status 		 := A_LoopField
				else if( A_Index ==  index.nowOrderNo ) 
					order.nowOrderNo 	 := A_LoopField
				else if( A_Index ==  index.nowUpdateTime ) 
					order.nowUpdateTime := A_LoopField
				else if( A_Index ==  index.rejectionReason ) 
					order.rejectionReason := A_LoopField			
			}
			order.status2			 := "C"	
			
			this.CompletedOrders[A_Index] := order
			this.CompletedOrders.size++
		}	
	}

	/*	Search input NOW order number in Order Book 
		Returns OrderDetails object if found else -1
		Run read() before calling getOrderDetails() to get latest data
	*/
	getOrderDetails( inNowOrderNo ){
		
		if( inNowOrderNo == "" )
			return -1
		
		order := this._getOrderDetails( this.OpenOrders,  inNowOrderNo )
		if( !IsObject(order)  ){
			order := this._getOrderDetails( this.CompletedOrders,  inNowOrderNo )
		}
		return order
	}
	
	doOpenOrdersExist(){
		
		this.readOpenOrders()
		return this.OpenOrders.size > 0 
	}

	getOpenOrderCount(){		
		return this.OpenOrders.size
	}

	getCompletedOrderCount(){		
		return this.CompletedOrders.size
	}

	/* Get Order ID of newly opened orders, searches both open and completed orders
	   Assuming only 1 opened/completed since last read
	   So readOpenOrders(),readCompletedOrders() should be called before creating new order and
		  getNewOrder() should be immediately called after creating new order
	   
	   Returns OrderDetails object if found, -1 if not found
	*/
	getNewOrder(){											
		global NEW_ORDER_WAIT_TIME
		
		openOrdersOld		:=  this.OpenOrders
		completedOrdersOld  :=  this.CompletedOrders
		
		Loop, % NEW_ORDER_WAIT_TIME {											// Wait for new order to show up in OrderBook
			this.readOpenOrders()
			this.readCompletedOrders()
			
			if( openOrdersOld.size < this.OpenOrders.size || completedOrdersOld.size < this.CompletedOrders.size )
				break
			Sleep, 1000
		}
		if( openOrdersOld.size >= this.OpenOrders.size  && completedOrdersOld.size >= this.CompletedOrders.size )
			return -1
			
		foundOrder := this._getNewOrder( openOrdersOld, this.OpenOrders )		// Find order that doesnt exist in openOrdersOld / completedOrdersOld
		if( !IsObject(foundOrder) )
			foundOrder := this._getNewOrder( completedOrdersOld, this.CompletedOrders )	

		return foundOrder
	}

	/*	Open Buy / Sell Window for existing order from Orderbook
	*/
	openModifyOrderForm( nowOrderNo, winTitle ){
		global TITLE_ORDER_BOOK
			
		if( this.selectOpenOrder( nowOrderNo ) ){
			Loop, 5{
				ControlClick, Button1, %TITLE_ORDER_BOOK%,,,, NA				
				WinWait, %winTitle%,,2
				if !ErrorLevel
					return true
			}			
			MsgBox, Could not open Buy/Sell Window
			return false
		}
		else{
			MsgBox, Order %nowOrderNo% Not Found in OrderBook > Open Orders
			return false
		}
	}	

	/*	Selects input order in OrderBook > Open Orders
		Returns true if found and selected else returns false
	*/
	selectOpenOrder( searchMeOrderNo ){
		global TITLE_ORDER_BOOK
		
		this.open()
		orderNoColIndex := this._openOrdersColumnIndex.nowOrderNo					// column number containing NOW Order no in Order Book > open orders
		
		Loop, 3{																	// Select order in Order Book. Search 3 times as a precaution
			ControlGet, RowCount, List, Count, SysListView321, %TITLE_ORDER_BOOK%	// No of rows in open orders
			ControlSend, SysListView321, {Home 2}, %TITLE_ORDER_BOOK%				// Start from top and search for order

			Loop, %RowCount%{														// Get order number of selected row and compare
				ControlGet, RowOrderNo, List, Selected Col%orderNoColIndex%, SysListView321, %TITLE_ORDER_BOOK%
			
				if( RowOrderNo == searchMeOrderNo ){								// Found and Selected
					return true
				}
				ControlSend, SysListView321, {Down}, %TITLE_ORDER_BOOK%				// Move Down to next row if not found yet
			}				
		}		

		return false
	}

	/*	Clicks on cancel button in orderbook, assuming order is already selected
	*/
	cancelSelectedOpenOrder(){
		global TITLE_ORDER_BOOK
		
		window 		:= "NOW"
		windowText	:= "Cancel These Order"
		
		ControlClick, Button3, %TITLE_ORDER_BOOK%,,,, NA				// Click Cancel
		
		WinWait, %window%, %windowText%, 1
		WinSet, Transparent, 1, %window%, %windowText%
		
		ControlClick, Button1, %window%, %windowText%,,, NA				// Click ok
	}



// -- Private ---



	/*	Reads Column Header text of Open and Completed Orders in orderbook to look for position of required fields 
	*/
	_readColumnHeaders(){
		global	TITLE_ORDER_BOOK
		
		static columnsRead := false											// Read once per load. ?VirtualAllocEx error from lib once? Had to restart NOW
		if( columnsRead )
			return
	
	// Open Orders
		// Read column header texts and extract position for columns that we need
		allHeaders  := GetExternalHeaderText( TITLE_ORDER_BOOK, "SysHeader321")	
		headers		:= ["Order Type", "Buy/Sell", "Trading Symbol", "Total Qty", "Pending Qty", "Price", "TriggerPrice", "Average Price", "Status", "NOWOrderNo", "NOW UpdateTime"]
		keys		:= ["orderType",  "buySell",  "tradingSymbol",  "totalQty",  "pendingQty",  "price", "triggerPrice", "averagePrice" , "status", "nowOrderNo", "nowUpdateTime"]			
		
		this._extractColumnIndices( "Order Book > Open Orders",  allHeaders, headers, this._openOrdersColumnIndex, keys )
		
	// Completed Orders
		allHeaders  := GetExternalHeaderText( TITLE_ORDER_BOOK, "SysHeader322")
		headers		:= ["Order Type", "Buy/Sell", "Trading Symbol", "Total Qty", "Pending Qty", "Price", "TriggerPrice", "Average Price", "Status", "NOWOrderNo", "NOW UpdateTime", "Rejection Reason"]
		keys		:= ["orderType",  "buySell",  "tradingSymbol",  "totalQty",  "pendingQty",  "price", "triggerPrice", "averagePrice" , "status", "nowOrderNo", "nowUpdateTime", "rejectionReason"]
		
		this._extractColumnIndices( "Order Book > Completed Orders",  allHeaders, headers, this._completedOrdersColumnIndex, keys )	
		
		columnsRead := true
	}

	/*	listIdentifier= Identifier text for the List, used in error message
		allHeaders    = headers extracted from GetExternalHeaderText
		targetHeaders = Array of headers that we want to search in allHeaders
		targetObject  = Object to save positions with key taken from targetKeys and value = Column position
		Gives Error if Column is not found
	*/
	_extractColumnIndices( listIdentifier, allHeaders, targetHeaders, targetObject, targetKeys  ){
		
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
		
			this._checkEmpty( targetObject[key], columnText, listIdentifier )
		}
	}

	/*	If Column that we want is not found in header, show message and exit
	*/
	_checkEmpty( value, field, listName ){
		global TITLE_ORDER_BOOK
		
		if( value == "" ){
			MsgBox, 262144,, Column %field% not found in %listName%
			WinClose, %TITLE_ORDER_BOOK%	
			Exit
		}
	}

	/*	Search order with input numbet in order array
	*/
	_getOrderDetails( list, orderno){
		Loop, % list.size {
			i := A_Index
			if( list[i].nowOrderNo ==  orderno ){					// Found
				return list[i]
			}	
		}
		return -1
	}

	/*	Compare old and new order list and return First new order found 
	*/
	_getNewOrder( oldList, newList ){
		
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
	
}