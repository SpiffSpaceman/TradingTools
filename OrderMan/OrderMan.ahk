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

SendMode Input  															// Recommended for new scripts
SetWorkingDir %A_ScriptDir%  												// Ensures a consistent starting directory
SetTitleMatchMode, 2 														// A window's title can contain the text anywhere
SetControlDelay, -1 														// Without this ControlClick fails sometimes

TITLE_NOW		 			  := "NOW 1.13"									// window titles
TITLE_ORDER_BOOK			  := "Order Book -"
TITLE_BUY					  := "Buy Order Entry"
TITLE_SELL					  := "Sell Order Entry"
TITLE_TRANSACTION_PASSWORD 	  := "Transaction Password"

ORDER_STATUS_COMPLETE 		  := "complete"
ORDER_STATUS_OPEN	  		  := "open"
ORDER_STATUS_TRIGGER_PENDING  := "trigger pending"

loadSettings()
createGUI()
readOrderBook()
linkOrderPrompt()
initializeStatusTracker()
installHotkeys()

return
  


getScrip( segment, instrument, symbol, type, strikePrice, expiryIndex ){
	scrip  := {}
	scrip.segment		:= segment
	scrip.instrument	:= instrument
	scrip.symbol		:= symbol
	scrip.type			:= type
	scrip.strikePrice	:= strikePrice
	scrip.expiryIndex   := expiryIndex
	
	return scrip
}

getOrder( orderType, qty, price, triggerprice, prodType   ){
	order := {}
	order.orderType := orderType
	order.qty 		:= qty
	order.price		:= price
	order.trigger 	:= triggerprice
	order.prodType  := prodType
	
	return order
}

isNumber( str ) {
	if str is number
		return true	
	return false
}

getDirectionFromOrder( order ){
	return order.buySell == "BUY" ? "B" : "S"	
}

reverseDirection( direction ){
	return direction == "B" ? "S" : "B"
}

roundToTickSize( price ){
	global TickSize	
	return Round(  price / TickSize ) * TickSize
}

#include Settings.ahk
#include OrderSubmitter.ahk
#include OrderTracker.ahk
#include OrderManGui.ahk
#include AB.ahk

#CommentFlag ;
#include Lib/__ExternalHeaderLib.ahk										; External Library to read Column Headers
