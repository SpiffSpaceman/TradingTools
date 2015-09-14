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
	global Qty, EntryPrice, StopTrigger, Direction, CurrentResult, BtnOrder, BtnUpdate, BtnLink, BtnUnlink, EntryStatus, StopStatus, LastWindowPosition
	
	SetFormat, FloatFast, 0.2
		
	Gui, 1:New, +AlwaysOnTop +Resize, OrderMan
																		// Column 1
	Gui, 1:Add, Edit, vQty w30
	Gui, 1:Add, ListBox, vDirection gonDirectionChange h30 w20 Choose1, B|S	
		
	Gui, 1:Add, Text, ym, Entry											// Column 2	
	Gui, 1:Add, Text, gstopClick, Stop
			
	Gui, 1:Add, Edit, vEntryPrice w55 ym gupdateCurrentResult 			// Column 3
	Gui, 1:Add, Edit, vStopTrigger w55 gupdateCurrentResult
	
	Gui, 1:Add, Button, gupdateOrderBtn vBtnUpdate hide, Update			// Link or Update
	Gui, 1:Add, Button, gopenLinkOrdersGUI vBtnLink xp+0 yp+0, Link
	
	Gui, 1:Add, Button, gorderBtn vBtnOrder xp-50, New					// New or Unlink
	Gui, 1:Add, Button, gunlinkBtn vBtnUnlink hide xp+0 yp+0, Unlink
	
	Gui, 1:Add, Text, ym vEntryStatus
	Gui, 1:Add, Text, vStopStatus
	Gui, 1:Add, Text, vCurrentResult  w30
	
	Gui, 1:Add, StatusBar, gstatusBarClick, 							// Status Bar - Shows link order Numbers. Double click to link manually
	
	Gui, 1:Show, AutoSize NoActivate %LastWindowPosition% 
		
	setGUIValues(Qty, 0, 0, "B")
	
	initalizeListViewVars()
	
	return	
}

/*
	Update status bar, GUI controls state and Timer state based on order status
*/
updateStatus(){
	global entryOrderNOW, stopOrderNOW, ORDER_STATUS_OPEN, EntryStatus, StopStatus	
	
	entryLinked := IsObject( entryOrderNOW )
	stopLinked	:= IsObject( stopOrderNOW )
	anyLinked	:= entryLinked || stopLinked 

	entryOpen	:= entryLinked && isStatusOpen( entryOrderNOW.status )
	stopOpen	:= stopLinked  && isStatusOpen( stopOrderNOW.status  )
	
	GuiControl, % anyLinked ? "1:Disable" : "1:Enable", Direction					// Disable Direction if orders Linked
	GuiControl, % anyLinked ? "1:Show"    : "1:Hide",   BtnUnlink					// Show Order if unlinked. If orders links show Unlink button instead
	GuiControl, % anyLinked ? "1:Hide"    : "1:Show",   BtnOrder	
	
	GuiControl, % entryOpen    || stopOpen  ? "1:Show"  : "1:Hide", BtnUpdate		// Show Update only if atleast one linked order is open
	GuiControl, % entryOpen    || stopOpen  ? "1:Hide"  : "1:Show", BtnLink			// Else show Link
	
	GuiControl, % !entryLinked || entryOpen ? "1:Enable"  : "1:Disable", EntryPrice	// Enable Price entry for new orders or for linked open orders
	GuiControl, % !stopLinked  || stopOpen  ? "1:Enable"  : "1:Disable", StopTrigger
	
	if( entryLinked ){																// Set Status if Linked
		shortStatus	:= getOrderShortStatus( entryOrderNOW.status )
		GuiControl, 1:Text, EntryStatus, % shortStatus
		GuiControl, 1:Move, EntryStatus, % shortStatus == entryOrderNOW.status ? "w125" : "w30"
	}
	else{
		GuiControl, 1:Text, EntryStatus, 
		GuiControl, 1:Move, EntryStatus, w1
	}
	if( stopLinked ){
		shortStatus	:= getOrderShortStatus( stopOrderNOW.status )
		GuiControl, 1:Text, StopStatus, % shortStatus
		GuiControl, 1:Move, StopStatus, % shortStatus == stopOrderNOW.status ? "w125" : "w30"
	}
	else{
		GuiControl, 1:Text, StopStatus,
		GuiControl, 1:Move, StopStatus, w1
	}
	
	isEntryClosed := entryLinked && isStatusClosed( entryOrderNOW.status )		// If order linked, start tracking orderbook
	isStopClosed  := stopLinked	 && isStatusClosed( stopOrderNOW.status )		// But stop if both closed
	isTimerActive := (entryLinked || stopLinked) && ! (isEntryClosed && isStopClosed)

	isTimerActive := isTimerActive ?  toggleStatusTracker( "on" ) : toggleStatusTracker( "off" )	
	timeStatus    := isTimerActive ? "A" : "I"
			
	SB_SetText( timeStatus . "  Open: " . getOpenOrderCount() . "  Complete: " . getCompletedOrderCount() )
	
	Gui, 1:Show, AutoSize NA
}

getOrderShortStatus( status ){
	global ORDER_STATUS_OPEN, ORDER_STATUS_TRIGGER_PENDING, ORDER_STATUS_COMPLETE, ORDER_STATUS_REJECTED, ORDER_STATUS_CANCELLED
	
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

onDirectionChange(){
	global Direction
	
	updateCurrentResult()												// Also submits		
	Gui, Color, % Direction == "B" ? "33cc66" : "ff9933"
}

/*
	Open window to manually link orders
	Entry order can be linked with Open Orders and successfully completed orders
	Stop order can only be linked with open orders
*/
statusBarClick(){	
	if( A_GuiEvent == "DoubleClick" ){
		openStatusGUI()			
	}
}

stopClick(){	
	if( A_GuiEvent == "DoubleClick"  ){
		setDefaultStop()
	}	
}

openLinkOrdersGUI(){
	global OpenOrders, CompletedOrders, listViewFields, listViewOrderIDPosition
	static selectedEntry, selectedStop
	
	readOrderBook()

	Gui, 2:New, +AlwaysOnTop, Link Orders		
	
	Gui, 2:font, bold
	Gui, 2:Add, Text,, Select Entry Order
	Gui, 2:font
	
	Gui, 2:Add, ListView, w600 -Multi SortDesc, % listViewFields
	Loop, % OpenOrders.size {
		addOrderRow( OpenOrders[A_Index] )
	}
	Loop, % CompletedOrders.size {
		o := CompletedOrders[A_Index]
		if( o.status = "complete" )
			addOrderRow(o)
	}
	LV_ModifyCol()										// Show All text
	
	Gui, 2:font, bold
	Gui, 2:Add, Text, ym, Select Stop Order				// Column 2
	Gui, 2:font
	
	Gui, 2:Add, ListView, w600 -Multi SortDesc,  % listViewFields
	Loop, % OpenOrders.size {
		addOrderRow( OpenOrders[A_Index] )
	}
	LV_ModifyCol()
	
	Gui, 2:Add, Button, Default glinkOrdersSubmit, Link Orders
	Gui, 2:Show, AutoSize	
}

openStatusGUI(){
	global entryOrderNOW, stopOrderNOW, listViewFields
	
	readOrderBook()
	
	Gui, 3:New, +AlwaysOnTop, Linked Orders
	Gui, 3:font, bold
	Gui, 3:Add, Text,, Linked Order Details
	Gui, 3:font
	
	Gui, 3:Add, ListView, w600 -Multi SortDesc,  % listViewFields
	
	addOrderRow( entryOrderNOW )
	addOrderRow( stopOrderNOW )
	
	LV_ModifyCol()									// Show All text
	
	Gui, 3:Show, AutoSize
}

initalizeListViewVars(){
	global listViewFields, listViewOrderIDPosition
	
	listViewFields 	   	    := "Scrip|Status|OrderType|Buy/Sell|Qty|Price|Trigger|Order No|Time"
	listViewOrderIDPosition := 8
}

addOrderRow( o ) {		
	LV_Add("", o.tradingSymbol, o.status, o.orderType, o.buySell, o.totalQty, o.price, o.triggerPrice, o.nowOrderNo, o.nowUpdateTime )
}

unlinkBtn(){
	toggleStatusTracker( "off" )		
	unlinkOrders()
	updateStatus()
}

setDefaultStop(){
	global EntryPrice, StopTrigger, Direction, DefaultStopSize
		
	Gui, 1:Submit, NoHide			
	StopTrigger :=  Direction == "B" ? EntryPrice-DefaultStopSize : EntryPrice+DefaultStopSize		
	GuiControl, 1:Text, StopTrigger, %StopTrigger%
	
	updateCurrentResult()
}

updateCurrentResult(){
	global EntryPrice, StopTrigger, Direction, CurrentResult
	
	Gui, 1:Submit, NoHide
	CurrentResult := Direction == "B" ? StopTrigger-EntryPrice : EntryPrice-StopTrigger
	GuiControl, 1:Text, CurrentResult, %CurrentResult%	
}

orderBtn(){	
	global EntryPrice, StopTrigger, Direction, Qty, ProdType, Scrip
		
	Gui, 1:Submit, NoHide										// sets variables from GUI
	
	setEntryPrice( roundToTickSize(EntryPrice) )
	setStopPrice(  roundToTickSize(StopTrigger) )
		
	if( !validateInput() )
		return
		
	entryOrder	:= getOrder("", Qty, EntryPrice, 0,	 	      ProdType  )
	stopOrder   := getOrder("", Qty, 0,  	     StopTrigger, ProdType  )
	
	limitOrder( Direction, Scrip, entryOrder, stopOrder )
}

updateOrderBtn(){
	global EntryPrice, StopTrigger, Qty, ProdType, Scrip, entryOrderNOW, stopOrderNOW
	
	Gui, 1:Submit, NoHide
	if( !validateInput() )
		return

	refreshLinkedOrderDetails()
	
	// Update if order linked and status is open/trigger pending and price has changed
	
	isEntryParamsChanged := (entryOrderNOW.price != EntryPrice)  	   || ( entryOrderNOW.totalQty != Qty )
	isStopParamsChanged  := (stopOrderNOW.triggerPrice != StopTrigger) || ( stopOrderNOW.totalQty  != Qty )
	
	if( IsObject(entryOrderNOW) && isStatusOpen(entryOrderNOW.status) && isEntryParamsChanged )
		entryOrder	:= getOrder("", Qty, EntryPrice, 0,	 ProdType  )	
	
	if( IsObject(stopOrderNOW)  && isStatusOpen(stopOrderNOW.status)  && isStopParamsChanged )
		stopOrder   := getOrder("", Qty, 0, StopTrigger, ProdType  )
	
	if( entryOrder != ""  ||  stopOrder != "" )	
		modifyLimitOrder( Scrip, entryOrder, stopOrder )
	else{
		MsgBox, 262144,, Nothing to update or Order status is not open
	}
}

linkOrderPrompt(){
	if( doOpenOrdersExist() ) {		
		MsgBox, % 262144+4,, Open Orders exist, Link with Existing order?
			IfMsgBox Yes
				openLinkOrdersGUI()
	}	
}

linkOrdersSubmit(){
	global entryOrderNOW, stopOrderNOW, listViewOrderIDPosition
	
	Gui, 2:ListView, SysListView321							// Get Selected Orders
	rowno := LV_GetNext()
	if( rowno > 0 )
		LV_GetText( entryOrderId, rowno, %listViewOrderIDPosition% )
	
	Gui, 2:ListView, SysListView322
	rowno := LV_GetNext()
	if( rowno > 0 )
		LV_GetText( stopOrderId, rowno, %listViewOrderIDPosition% )
	
	if( entryOrderId == "" ){
		MsgBox, 262144,, Select Entry Order
		return
	}
	if( stopOrderId == "" ){
		MsgBox, 262144,, Select Stop Order
		return
	}
	if( entryOrderId == stopOrderId ){
		MsgBox, 262144,, Selected Entry And Stop Order are same
		return
	}
	
	if( !linkOrders( entryOrderId, stopOrderId ))			// set Entry and Stop order objects
		return
	
	Gui, 2:Destroy
	Gui  1:Default
		
	setGUIValues( entryOrderNOW.totalQty, entryOrderNOW.price, stopOrderNOW.triggerPrice, getDirectionFromOrder( entryOrderNOW ) )
	updateCurrentResult()
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
	global StopTrigger
	StopTrigger := inStop
	GuiControl, 1:Text, StopTrigger, %StopTrigger%
}

setDirection( inDirection ){
	global Direction
	Direction := inDirection
	GuiControl, 1:ChooseString, Direction,  %Direction%
	onDirectionChange()
}

setGUIValues( inQty, inEntry, inStop, inDirection ){
	
	setQty( inQty )
	setEntryPrice( inEntry )
	setStopPrice( inStop )
	setDirection( inDirection )	
	
	updateStatus()	
}

validateInput(){
	global EntryPrice, StopTrigger, Direction, CurrentResult, MaxStopSize
	
	if( Direction != "B" && Direction != "S"  ){
		MsgBox, 262144,, Direction not set
		return false
	}
	
	if( !isNumber(EntryPrice) ){
		MsgBox, 262144,, Invalid Entry Price
		return false
	}
	if( !isNumber(StopTrigger) ){
		MsgBox, 262144,, Invalid Stop Trigger Price
		return false
	}	
	
	if( !isEntryComplete() ){									// Allow to trail past Entry 
		if( Direction == "B" ){									// If Buying, stop should be below price and vv
			if( StopTrigger >= EntryPrice  ){
				MsgBox, 262144,, Stop Trigger should be below Buy price
				return false
			}
		}
		else{
			if( StopTrigger <= EntryPrice  ){
				MsgBox, 262144,, Stop Trigger should be above Sell price
				return false
			}
		}	
	}

	updateCurrentResult()
	if( CurrentResult < -MaxStopSize  ){
		MsgBox, % 262144+4,, Stop size more than Maximum Allowed. Continue?
		IfMsgBox No
			return false
	}
	
	return true
}

GuiClose:
	saveLastPosition()
	ExitApp
