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

createGUI(){
	global Qty, EntryPrice, StopPrice, Direction, CurrentResult, BtnOrder, BtnUpdate, BtnLink, BtnUnlink, BtnCancel, EntryStatus, StopStatus, LastWindowPosition, EntryOrderType
	
	SetFormat, FloatFast, 0.2
		
	Gui, 1:New, +AlwaysOnTop +Resize, OrderMan

	Gui, 1:Add, ListBox, vDirection gonDirectionChange h30 w20 Choose1, B|S	
	Gui, 1:Add, Edit, vQty w30											// Column 1
		
	Gui, 1:Add, Text, ym, Entry											// Column 2	
	Gui, 1:Add, Text, gstopClick, Stop
			
	Gui, 1:Add, Edit, vEntryPrice w55 ym gupdateCurrentResult 			// Column 3
	Gui, 1:Add, Edit, vStopPrice w55 gupdateCurrentResult
		
	Gui, 1:Add, Button, gorderBtn vBtnOrder xp-35 y+m, New				// New or Update
	Gui, 1:Add, Button, gupdateOrderBtn vBtnUpdate  xp+0 yp+0, Update	

	Gui, 1:Add, Button, gopenLinkOrdersGUI vBtnLink x+5, Link			// Link or Unlink
	Gui, 1:Add, Button, gunlinkBtn vBtnUnlink xp+0 yp+0, Unlink		

	Gui, 1:Add, DropDownList, vEntryOrderType w45 Choose1 ym, LIM|SL|SLM|M // Entry Type
	//Gui, 1:Add, DropDownList, w45 Choose1, SLM|SL
	Gui, 1:Add, Text, vCurrentResult  w30
	Gui, 1:Add, Button, gcancelOrderBtn vBtnCancel y+14, Cancel		 	// Cancel button
	
	Gui, 1:Add, Text, ym vEntryStatus
	Gui, 1:Add, Text, vStopStatus	
	
	Gui, 1:Add, StatusBar, gstatusBarClick, 							// Status Bar - Shows link order Numbers. Double click to link manually
	
	Gui, 1:Show, AutoSize NoActivate %LastWindowPosition% 
		
	setGUIValues(Qty, 0, 0, "B", EntryOrderType)
	
	initalizeListViewVars()
	
	return	
}

/* Link Button GUI
*/
openLinkOrdersGUI(){
	global orderbookObj, listViewFields, listViewOrderIDPosition
	static selectedEntry, selectedStop
	
	orderbookObj.read()

	Gui, 2:New, +AlwaysOnTop, Link Orders		
	
	Gui, 2:font, bold
	Gui, 2:Add, Text,, Select Entry Order
	Gui, 2:font
	
	Gui, 2:Add, ListView, w600 -Multi SortDesc, % listViewFields
	Loop, % orderbookObj.OpenOrders.size {
		addOrderRow( orderbookObj.OpenOrders[A_Index] )
	}
	Loop, % orderbookObj.CompletedOrders.size {
		o := orderbookObj.CompletedOrders[A_Index]
		if( o.status = "complete" )
			addOrderRow(o)
	}
	LV_ModifyCol()										// Show All text
	
	Gui, 2:font, bold
	Gui, 2:Add, Text, ym, Select Stop Order				// Column 2
	Gui, 2:font
	
	Gui, 2:Add, ListView, w600 -Multi SortDesc,  % listViewFields
	Loop, % orderbookObj.OpenOrders.size {
		addOrderRow( orderbookObj.OpenOrders[A_Index] )
	}
	LV_ModifyCol()
	
	Gui, 2:Add, Button, Default glinkOrdersSubmit, Link Orders
	Gui, 2:Show, AutoSize	
}

/* Linked Order Status GUI
*/
openStatusGUI(){
	global orderbookObj, contextObj, listViewFields
	
	orderbookObj.read()	
	
	Gui, 3:New, +AlwaysOnTop, Linked Orders
	Gui, 3:font, bold
	Gui, 3:Add, Text,, Linked Order Details
	Gui, 3:font
	
	Gui, 3:Add, ListView, w600 -Multi SortDesc,  % listViewFields
	
	trade := contextObj.getCurrentTrade()
	addOrderRow( trade.entryOrder.getOrderDetails() )
	addOrderRow( trade.stopOrder.getOrderDetails() )
	
	LV_ModifyCol()									// Show All text
	
	Gui, 3:Show, AutoSize
}

/* Sets Current Position status if Stop hits
*/
updateCurrentResult(){
	global
	
	Gui, 1:Submit, NoHide
	CurrentResult := Direction == "B" ? StopPrice-EntryPrice : EntryPrice-StopPrice
	GuiControl, 1:Text, CurrentResult, %CurrentResult%	
}

/* Sets Stop price using default Stop size 
*/
setDefaultStop(){
	global
		
	Gui, 1:Submit, NoHide			
	StopPrice :=  Direction == "B" ? EntryPrice-DefaultStopSize : EntryPrice+DefaultStopSize		
	GuiControl, 1:Text, StopPrice, %StopPrice%
	
	updateCurrentResult()
}




//   -- GUI Updates --- 

/*	Update status bar, GUI controls state and Timer state based on order status
*/
updateStatus(){
	global contextObj, orderbookObj, ORDER_STATUS_OPEN, EntryStatus, StopStatus, EntryPrice, StopPrice
	
	trade 			  := contextObj.getCurrentTrade()
	trade.reload()
	
	entryOrderDetails := trade.entryOrder.getOrderDetails()
	stopOrderDetails  := trade.stopOrder.getOrderDetails()
	
	entryLinked 	  := trade.isEntryLinked()
	stopLinked		  := trade.isStopLinked()
	anyLinked		  := entryLinked || stopLinked 
	entryOpen		  := trade.isEntryOpen()
	isStopPending 	  := trade.isStopPending										// Is Stop waiting for Entry to trigger
	stopOpen		  := trade.isStopOpen()	 || isStopPending
	isEntryClosed	  := trade.isEntryClosed()
	isStopClosed	  := trade.isStopClosed()		
	
	GuiControl, % anyLinked ? "1:Disable" : "1:Enable", Direction					// Disable Direction if orders Linked
	GuiControl, % anyLinked ? "1:Show"    : "1:Hide",   BtnUnlink					// Show Order if unlinked. If orders links show Unlink button instead
	GuiControl, % anyLinked	? "1:Hide"    : "1:Show",   BtnLink						// Show Link if not linked
	GuiControl, % anyLinked ? "1:Hide"    : "1:Show",   BtnOrder	
	
	GuiControl, % entryOpen    || stopOpen  ? "1:Show"  : "1:Hide", BtnUpdate		// Show Update only if atleast one linked order is open
	GuiControl, % entryOpen    || stopOpen  ? "1:Show"  : "1:Hide", BtnCancel		// Show Cancel Button if order linked	
	
	GuiControl, % !entryLinked || entryOpen ? "1:Enable"  : "1:Disable", EntryPrice	// Enable Price entry for new orders or for linked open orders
	GuiControl, % !stopLinked  || stopOpen  ? "1:Enable"  : "1:Disable", StopPrice		

	entryAverage 	  := entryOrderDetails.averagePrice
	stopAverage  	  := stopOrderDetails.averagePrice
	
	if( entryAverage != "" && entryAverage != EntryPrice && trade.isEntrySuccessful()   ){
		setEntryPrice( entryAverage )												// Update Entry Price with Average Price after entry complete
	}
	if( stopAverage != "" && stopAverage != StopPrice && trade.isStopSuccessful() ){
		setStopPrice( stopAverage )													// Update Entry Price with Average Price after entry complete
	}

	if( entryLinked ){																// Set Status if Linked
		shortStatus	:= getOrderShortStatus( entryOrderDetails.status )
		GuiControl, 1:Text, EntryStatus, % shortStatus
		GuiControl, 1:Move, EntryStatus, % shortStatus == entryOrderDetails.status ? "w125" : "w30"
	}
	else{
		GuiControl, 1:Text, EntryStatus, 
		GuiControl, 1:Move, EntryStatus, w1
	}

	if( stopLinked || isStopPending ){
		shortStatus	:= getOrderShortStatus( stopOrderDetails.status )
		if(  shortStatus == "" && isStopPending )
			shortStatus := "P"
			
		GuiControl, 1:Text, StopStatus, % shortStatus
		GuiControl, 1:Move, StopStatus, % shortStatus == stopOrderDetails.status ? "w125" : "w30"
	}
	else{
		GuiControl, 1:Text, StopStatus,
		GuiControl, 1:Move, StopStatus, w1
	}	
	
	isTimerActive := (entryLinked || stopLinked) && ! (isEntryClosed && isStopClosed) 		// If order linked, start tracking orderbook. But stop if both closed
	isTimerActive := isTimerActive ?  toggleStatusTracker( "on" ) : toggleStatusTracker( "off" )	
	timeStatus    := isTimerActive ? "ON" : "OFF"
			
	SB_SetText( "Timer: " . timeStatus . "  Open: " . orderbookObj.getOpenOrderCount() . "  Complete: " . orderbookObj.getCompletedOrderCount() )
	
	Gui, 1:Show, AutoSize NA
}

setGUIValues( inQty, inEntry, inStop, inDirection, inEntryOrderType ){
	
	setQty( inQty )
	setEntryPrice( inEntry )
	setStopPrice( inStop )
	setDirection( inDirection )	
	selectEntryOrderType( inEntryOrderType )
	
	updateStatus()	
}

setQty( inQty ){
	global Qty
	Qty := inQty
	GuiControl, 1:Text, Qty,  %Qty%
}

setEntryPrice( inEntry ){
	global EntryPrice
	EntryPrice := inEntry
	GuiControl, 1:Text, EntryPrice,  %EntryPrice%
}

setStopPrice( inStop ){
	global StopPrice
	StopPrice := inStop
	GuiControl, 1:Text, StopPrice, %StopPrice%
}

setDirection( inDirection ){
	global Direction
	Direction := inDirection
	GuiControl, 1:ChooseString, Direction,  %Direction%
	onDirectionChange()
}

selectEntryOrderType( inEntryOrderType ){
	global EntryOrderType	
	EntryOrderType := inEntryOrderType
	GuiControl, 1:ChooseString, EntryOrderType,  %EntryOrderType%
}


// -- GUI Helpers --- 

/* Map order status to short code for GUI
*/
getOrderShortStatus( status ){
	global
	
	if( status == ORDER_STATUS_OPEN )
		return "O"
	else if( status == ORDER_STATUS_TRIGGER_PENDING )
		return "O-TP"
	else if( status == ORDER_STATUS_COMPLETE )
		return "C"
	else if( status == ORDER_STATUS_REJECTED )
		return "R"
	else if( status == ORDER_STATUS_CANCELLED )
		return "CAN"
	else
		return status
}

/* Headers for Order Listviews
*/
initalizeListViewVars(){
	global
	
	listViewFields 	   	      := "Scrip|Status|OrderType|Buy/Sell|Qty|Price|Trigger|Average|Order No|Time"
	listViewOrderIDPosition   := 9
	listViewOrderTypePosition := 3
}

/* Adds row to list View
*/
addOrderRow( o ) {
	if( IsObject(o) )
		LV_Add("", o.tradingSymbol, o.status, o.orderType, o.buySell, o.totalQty, o.price, o.triggerPrice, o.averagePrice, o.nowOrderNo, o.nowUpdateTime )
}


GuiClose:
	saveLastPosition()
	ExitApp
