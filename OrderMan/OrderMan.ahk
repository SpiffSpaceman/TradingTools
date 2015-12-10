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

#CommentFlag // 
#Include %A_ScriptDir%														// Set Include Directory path
#SingleInstance force														// Reloads if already running
#NoEnv																		// Recommended for new scripts
#Warn, All, StdOut

SendMode Input  															// Recommended for new scripts
SetWorkingDir %A_ScriptDir%  												// Ensures a consistent starting directory
SetTitleMatchMode, 2 														// A window's title can contain the text anywhere
SetControlDelay, -1 														// Without this ControlClick fails sometimes

TITLE_NOW		 			  := "NOW 1.13"									// window titles
TITLE_ORDER_BOOK			  := "Order Book -"
TITLE_BUY					  := "Buy Order Entry"
TITLE_SELL					  := "Sell Order Entry"
TITLE_TRANSACTION_PASSWORD 	  := "Transaction Password"

ORDER_STATUS_PUT			  := "put order req received"
ORDER_STATUS_VP				  := "validation pending"
ORDER_STATUS_OPEN	  		  := "open"
ORDER_STATUS_TRIGGER_PENDING  := "trigger pending"
ORDER_STATUS_COMPLETE 		  := "complete"
ORDER_STATUS_REJECTED		  := "rejected"
ORDER_STATUS_CANCELLED		  := "cancelled"

ORDER_TYPE_LIMIT			  := "LIMIT"
ORDER_TYPE_MARKET			  := "MARKET"
ORDER_TYPE_SL_LIMIT			  := "SL"
ORDER_TYPE_SL_MARKET		  := "SL-M"

ORDER_TYPE_GUI_LIMIT		  := "LIM"
ORDER_TYPE_GUI_MARKET		  := "M"
ORDER_TYPE_GUI_SL_LIMIT		  := "SL"
ORDER_TYPE_GUI_SL_MARKET	  := "SLM"

ORDERBOOK_POLL_TIME			  := 2500										// Time between reading of OrderBook status by Tracker. In ms
NEW_ORDER_WAIT_TIME			  := 5											// How many seconds to wait for New Submitted Order to appear in orderbook. 
OPEN_ORDER_WAIT_TIME		  := 5											// How many seconds to wait for Order to be Open ( ie for validation etc to be over)
																				// Warning message shown after wait period

orderbookObj := new OrderbookClass                                          // Keep Class string in class names to avoid conflict - can get overwritten by object of same name
contextObj   := new ContextClass                                            // without new, class members are not initialized

UtilClass.checkNOWOpen()
loadSettings()
initializeStatusTracker()

orderbookObj.read()
createGUI()
linkOrderPrompt()

installHotkeys()

return  

linkOrderPrompt(){
	global orderbookObj, contextObj

    trade := contextObj.getCurrentTrade()    
  
	if( orderbookObj.doOpenOrdersExist() ) {
        if( trade.loadOrders() ){                                           // Load open orders if saved Else Ask to link manually
            loadTradeInputToGui()
            return
        }
      
		MsgBox, % 262144+4,, Open Orders exist, Link with Existing order?
			IfMsgBox Yes
				openLinkOrdersGUI()
	}
}



#include Settings.ahk
#include Scrip.ahk
#include OrderDetails.ahk
#include Order.ahk
#include Trade.ahk
#include Context.ahk
#include Orderbook.ahk
#include OrderTracker.ahk
#include Gui.ahk
#include GuiActions.ahk
#include AB.ahk
#include Util.ahk


#CommentFlag ;
#include Lib/__ExternalHeaderLib.ahk										; External Library to read Column Headers
