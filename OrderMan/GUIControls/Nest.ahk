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

/* 
  Overides control ids and Windows Title specific to Nest
*/
class NestControlsClass extends NowControlsClass{

// Titles, Menus - Unique substrings will do
	static ORDER_BOOK_MENU			  				:= "View Order,Order Book"							// Menu to open Order Book
	static ORDER_BOOK_CANCEL_CONFIRMATION_TITLE		:= "NEST Trader"									// Title of Confirmation window on cancel order

	static ORDER_ENTRY_MENU_BUY						:= "Orders and Trades,Order Entry,Buy Order Entry"	// Menu to open Buy/Sell Window
	static ORDER_ENTRY_MENU_SELL					:= "Orders and Trades,Order Entry,Sell Order Entry"

// Controls
	static ORDER_ENTRY_PROD_TYPE 					:= "ComboBox11"
	static ORDER_ENTRY_VALIDITY 					:= "ComboBox12"
	
	static ORDER_ENTRY_QTY 							:= "Edit5"
	static ORDER_ENTRY_PRICE						:= "Edit6"
	static ORDER_ENTRY_TRIGGER_PRICE				:= "Edit8"
	static ORDER_ENTRY_SUBMIT						:= "Button1"

	static ORDER_BOOK_CANCEL			  			:= "Button2"
	static ORDER_BOOK_DISPLAY			  			:= "Button5"										// "Display all Orders" Checkbox in Orderbook
	
	// NestOrderNo and Nest UpdateTime
	static ORDER_BOOK_OPEN_HEADERS_TEXT				:= ["Order Type", "Buy/Sell", "Trading Symbol", "Total Qty", "Traded Qty", "Price", "TriggerPrice", "Average Price", "Status", "NestOrderNo", "Nest UpdateTime"]
	static ORDER_BOOK_COMPLETED_HEADERS_TEXT		:= ["Order Type", "Buy/Sell", "Trading Symbol", "Total Qty", "Traded Qty", "Price", "TriggerPrice", "Average Price", "Status", "NestOrderNo", "Nest UpdateTime", "Rejection Reason"]
	
	// ZT - gives confirmation screen after submit, does not close after confirmation
	static ORDER_ENTRY_CONFIRMATION_TITLE			:= "Press 'Enter' to confirm Order placement"
	static ORDER_ENTRY_SUBMITTED_TITLE				:= "Order Submitted -"
	
}