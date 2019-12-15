/*
  Copyright (C) 2018  SpiffSpaceman

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


class TradebookClass{

	TradeOrders				     := ""	
	_tradeBookColumnHearderIndex := {}	
	
	
	init(){	
		this.open()
		this.readColumnHeaders()
	}
	
	/* Calculate average price from amount and qty. 
		Avg Price in column is rounded to 2 decimal places
		Orderbook does not have actual totalConsideration. Instead take from tradebook
	*/
	getAvgPrice( order ){
		return UtilClass.floatPriceToStr( this.getOrderAmount( order.nowOrderNo ) / order.tradedQty )
	}

	getOrderAmount( nowOrderNo ) {
		this.readTradeBookOrders()
		
		amount := 0
		list   := this.TradeOrders
		
		Loop, % list.size {
			i := A_Index
			if( list[i].nowOrderNo == nowOrderNo ){
				amount += list[i].totalConsideration
			}
		}
		
		return amount
	}
	
	open(){
		global controlObj, TITLE_NOW

		IfWinExist,  % controlObj.TRADE_BOOK_TITLE
			return
		
		// Using Menu sometimes shows empty table
		/*
		menus := StrSplit( controlObj.TRADE_BOOK_MENU , ",")		// open tradebook
		WinMenuSelectItem, %TITLE_NOW%,, % menus[1], % menus[2]					
		*/
		
		ControlSend, % controlObj.MARKET_WATCH_LIST, % controlObj.TRADE_BOOK_OPEN_HK, %TITLE_NOW%

		WinWait, % controlObj.TRADE_BOOK_TITLE,,5
		if ErrorLevel
		{
			MsgBox, Unable to open TradeBook. Override Menu to fix it.
			ExitApp
		}
		WinMinimize, % controlObj.TRADE_BOOK_TITLE
	}
	
	readTradeBookOrders(){
		global controlObj
		
		this.open()													// Open order book if not already opened
		
		this.TradeOrders	  := {}
		this.TradeOrders.size := 0
		index				  := this._tradeBookColumnHearderIndex
		
		ControlGet, tradeOrdersRaw, List, , % controlObj.TRADE_BOOK_LIST, % controlObj.TRADE_BOOK_TITLE
		
		Loop, Parse, tradeOrdersRaw, `n  							// Extract our columns from table
		{															// Rows are delimited by linefeeds (`n)
			order := {}												// Fields (columns) in each row are delimited by tabs (A_Tab)
			fieldCount := 0
			Loop, Parse, A_LoopField, %A_Tab%  									
			{	
				if( A_Index == index.totalConsideration ){
					order.totalConsideration  := A_LoopField	
					fieldCount++
				}
				else if( A_Index ==  index.nowOrderNo ){
					order.nowOrderNo 	 	  := A_LoopField
					fieldCount++
				}
				if( fieldCount >= 2 )								// Move to next row once all fields found for this row
					break
			}			
			
			this.TradeOrders[A_Index] := order
			this.TradeOrders.size++	
		}
	}

	readColumnHeaders(){
		global	controlObj, orderbookObj
		
		static columnsRead := false											// Read once per load. ?VirtualAllocEx error from lib once? Had to restart NOW
		if( columnsRead )
			return
																			// Read column header texts and extract position for columns that we need
		allHeaders  := GetExternalHeaderText( controlObj.TRADE_BOOK_TITLE, controlObj.TRADE_BOOK_LIST_HEADER)	
		headers		:= % controlObj.TRADE_BOOK_HEADERS_TEXT
		keys		:= ["totalConsideration", "nowOrderNo" ]
		
		orderbookObj.extractColumnIndices( "Trade Book",  allHeaders, headers, this._tradeBookColumnHearderIndex, keys )
	
		columnsRead := true
	}
	
}



