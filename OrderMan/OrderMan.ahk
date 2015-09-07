#CommentFlag // 
#Include %A_ScriptDir%														// Set Include Directory path
#SingleInstance force														// Reloads if already running
#NoEnv																		// Recommended for new scripts

SendMode Input  															// Recommended for new scripts
SetWorkingDir %A_ScriptDir%  												// Ensures a consistent starting directory
SetTitleMatchMode, 2 														// A window's title can contain the text anywhere
SetControlDelay, -1 														// Without this ControlClick fails sometimes

NowWindowTitle	= NOW 1.13
executeOrders()
return


executeOrders(){
	
	direction	:= "B"
	entryPrice  := 7000
	stopTrigger	:= 6990



	/////////////////////////////////////////////////////////////////////////	
	qty			:= 25
	scrip 		:= getScrip("NFO", "FUTIDX", "NIFTY", "XX","","1" )
	prodType	:= "NRML"
	
	
	entryOrder	:= getOrder("LIMIT", qty, entryPrice, 0,	   	   prodType  )
	stopOrder   := getOrder("SL-M",  qty, 0,  	      stopTrigger, prodType  )	
	
	limitOrder( direction, scrip, entryOrder, stopOrder )
}

 
 



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


#include OrderSubmitter.ahk
#include OrderTracker.ahk

#CommentFlag ;
#include Lib/__ExternalHeaderLib.ahk										; External Library to read Column Headers
