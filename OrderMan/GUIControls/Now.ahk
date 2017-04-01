/*
  Copyright (C) 2016  SpiffSpaceman

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

class NowControlsClass{

// Buy/Sell Order Entry
	static ORDER_ENTRY_TITLE_BUY					:= "Buy Order Entry"
	static ORDER_ENTRY_TITLE_SELL					:= "Sell Order Entry"
	static ORDER_ENTRY_TITLE_TRANSACTION_PASSWORD	:= "Transaction Password"

	static ORDER_ENTRY_MENU_BUY						:= "Orders and Trades,Buy Order Entry"			// Menu options to open Buy/Sell Window
	static ORDER_ENTRY_MENU_SELL					:= "Orders and Trades,Sell Order Entry"			// Takes either 2 or 3 comma separated values
	
	static ORDER_ENTRY_EXCHANGE_SEGMENT				:= "ComboBox1"
	static ORDER_ENTRY_INST_NAME 					:= "ComboBox5"
	static ORDER_ENTRY_SYMBOL 						:= "ComboBox6"
	static ORDER_ENTRY_TYPE 						:= "ComboBox7"
	static ORDER_ENTRY_STRIKE_PRICE 				:= "ComboBox8"
	static ORDER_ENTRY_EXPIRY_DATE 					:= "ComboBox9"
	static ORDER_ENTRY_ORDER_TYPE 					:= "ComboBox3"
	static ORDER_ENTRY_PROD_TYPE 					:= "ComboBox10"
	static ORDER_ENTRY_VALIDITY 					:= "ComboBox11"

	static ORDER_ENTRY_QTY 							:= "Edit3"
	static ORDER_ENTRY_PRICE						:= "Edit4"
	static ORDER_ENTRY_TRIGGER_PRICE				:= "Edit7"
	static ORDER_ENTRY_SUBMIT						:= "Button4"

// Buy/Sell - Order Type Options
	static ORDER_TYPE_LIMIT			  				:= "LIMIT"
	static ORDER_TYPE_MARKET			  			:= "MARKET"
	static ORDER_TYPE_SL_LIMIT			  			:= "SL"
	static ORDER_TYPE_SL_MARKET		  				:= "SL-M"
	
// OrderBook
	static ORDER_BOOK_TITLE			  				:= "Order Book -"
	static ORDER_BOOK_CANCEL_CONFIRMATION_TITLE		:= "NOW"										// To detect Confirmation window after cancel 
	static ORDER_BOOK_CANCEL_CONFIRMATION_TEXT		:= "Cancel These Order"							// Text within Confirmation window

	static ORDER_BOOK_OPEN_LIST			  			:= "SysListView321"
	static ORDER_BOOK_OPEN_LIST_HEADER	  			:= "SysHeader321"
	static ORDER_BOOK_COMPLETE_LIST			  		:= "SysListView322"
	static ORDER_BOOK_COMPLETE_LIST_HEADER 			:= "SysHeader322"
	
	static ORDER_BOOK_MODIFY			  			:= "Button1"
	static ORDER_BOOK_CANCEL			  			:= "Button3"
	static ORDER_BOOK_CANCEL_OK			  			:= "Button1"									// OK button after cancel prompt
	static ORDER_BOOK_DISPLAY			  			:= "Button6"									// "Display all Orders" Checkbox in Orderbook
	static ORDER_BOOK_MENU			  				:= "Orders and Trades,Order Book"				// Takes 2 comma separated values
																									// Column Header Text - Array order must match with OrderbookClass::_readColumnHeaders()
	static ORDER_BOOK_OPEN_HEADERS_TEXT				:= ["Order Type", "Buy/Sell", "Trading Symbol", "Total Qty", "Traded Qty", "Price", "TriggerPrice", "Average Price", "Status", "NOWOrderNo", "NOW UpdateTime"]
	static ORDER_BOOK_COMPLETED_HEADERS_TEXT		:= ["Order Type", "Buy/Sell", "Trading Symbol", "Total Qty", "Traded Qty", "Price", "TriggerPrice", "Average Price", "Status", "NOWOrderNo", "NOW UpdateTime", "Rejection Reason"]
	
// OrderBook -> Order status column
	static ORDER_STATUS_PUT			  				:= "put order req received"
	static ORDER_STATUS_VP				  			:= "validation pending"
	static ORDER_STATUS_OPEN	  		  			:= "open"
	static ORDER_STATUS_TRIGGER_PENDING  			:= "trigger pending"
	static ORDER_STATUS_OPEN_PENDING				:= "open pending"
	static ORDER_STATUS_COMPLETE 		  			:= "complete"
	static ORDER_STATUS_REJECTED		  			:= "rejected"
	static ORDER_STATUS_CANCELLED		  			:= "cancelled"

// OrderBook -> Buy/Sell Column
	static ORDER_DIRECTION_BUY    					:= "BUY"
	static ORDER_DIRECTION_SELL  					:= "SELL"
	
// ZT specific
	static ORDER_ENTRY_CONFIRMATION_TITLE			:= "NA 99999"
	static ORDER_ENTRY_SUBMITTED_TITLE				:= "NA 99999"

}
