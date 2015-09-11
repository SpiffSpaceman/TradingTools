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
	global EntryPrice, StopTrigger, Direction, CurrentResult, BtnOrder, BtnUpdate, BtnUnlink
	
	SetFormat, FloatFast, 0.2
		
	Gui, 1:New, +AlwaysOnTop, OrderMan
	
	Gui, 1:Add, ListBox, vDirection h30 w15 Choose1, B|S		// Column 1	
		
	Gui, 1:Add, Text, ym, Entry									// Column 2	
	Gui, 1:Add, Text,, Stop	
			
	Gui, 1:Add, Edit, vEntryPrice w55 ym section				// Column 3
	Gui, 1:Add, Edit, vStopTrigger w55
	
	Gui, 1:Add, Button, gorderBtn vBtnOrder, Enter	
	Gui, 1:Add, Button, gunlinkBtn vBtnUnlink hide xp+0 yp+0, Unlink
	
	Gui, 1:Add, Button, gupdateOrderBtn vBtnUpdate x+1, Update
	Gui, 1:Add, Edit, vCurrentResult ReadOnly w30 x+10
	
	Gui, 1:Add, Button, gsetDefaultStopBtn ys xs+60, Default Stop // Column 4  - coord wrt Entry Price text box using section
	Gui, 1:Add, Button, gupdateCurrentResultBtn, Current Result  	
			
	Gui, 1:Add, StatusBar, gstatusBarClick, 					// Status Bar - Shows link order Numbers. Double click to link manually
	
	Gui, 1:Show, AutoSize NoActivate
	
	setGUIValues(0, 0, "B")
	
	return	
}
 
updateStatusBar(){
	global entryOrderNOW, stopOrderNOW
	
	entryLinked := IsObject( entryOrderNOW )
	stopLinked	:= IsObject( stopOrderNOW )
	
	entry := entryLinked ? entryOrderNOW.nowOrderNo : "No order linked" 
	stop  := stopLinked  ? stopOrderNOW.nowOrderNo  : "No order linked" 
	
	GuiControl, % entryLinked ? "1:Disable" : "1:Enable", Direction		// Disable Direction if orders Linked
	GuiControl, % entryLinked ? "1:Show"    : "1:Hide",   BtnUnlink		// Show Order if unlinked. If orders links show Unlink button instead
	GuiControl, % entryLinked ? "1:Hide"    : "1:Show",   BtnOrder	
	GuiControl, % stopLinked  ? "1:Enable"  : "1:Disable",BtnUpdate		// Enable Update only if linked		
	
	SB_SetText( "E: " . entry . ". S: " . stop )
}

/*
	Open window to manually link orders
	Entry order can be linked with Open Orders and successfully completed orders
	Stop order can only be linked with open orders
*/
statusBarClick(){	
	if( A_GuiEvent == "DoubleClick" ){
		openLinkOrdersGUI()			
	}
}

openLinkOrdersGUI(){
	global OpenOrders, CompletedOrders
	static selectedEntry, selectedStop
	
	readOrderBook()

	Gui, 2:New, +AlwaysOnTop, Link Orders		
	
	Gui, 2:font, bold
	Gui, 2:Add, Text,, Select Entry Order
	Gui, 2:font
	
	Gui, 2:Add, ListView, w600 -Multi SortDesc,  Order No|Time|Scrip|Status|OrderType|Buy/Sell|Qty|Price|Trigger
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
	
	Gui, 2:Add, ListView, w600 -Multi SortDesc,    Order No|Time|Scrip|Status|OrderType|Buy/Sell|Qty|Price|Trigger		
	Loop, % OpenOrders.size {
		addOrderRow( OpenOrders[A_Index] )
	}
	LV_ModifyCol()
	
	Gui, 2:Add, Button, Default glinkOrdersSubmit, Link Orders
	Gui, 2:Show, AutoSize	
}

unlinkBtn(){
	unlinkOrders()
	updateStatusBar()
}

setDefaultStopBtn(){
	global EntryPrice, StopTrigger, Direction, DefaultStopSize
		
	Gui, 1:Submit, NoHide			
	StopTrigger :=  Direction == "B" ? EntryPrice-DefaultStopSize : EntryPrice+DefaultStopSize		
	GuiControl, 1:Text, StopTrigger, %StopTrigger%
	
	updateCurrentResultBtn()
}

updateCurrentResultBtn(){
	global EntryPrice, StopTrigger, Direction, CurrentResult
	
	Gui, 1:Submit, NoHide
	CurrentResult := Direction == "B" ? StopTrigger-EntryPrice : EntryPrice-StopTrigger
	GuiControl, 1:Text, CurrentResult, %CurrentResult%	
}

orderBtn(){	
	global EntryPrice, StopTrigger, Direction, Qty, ProdType, Scrip
	
	Gui, 1:Submit, NoHide										// sets variables from GUI	
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
	
	if( IsObject(entryOrderNOW) && isStatusOpen(entryOrderNOW.status) && entryOrderNOW.price != EntryPrice )
		entryOrder	:= getOrder("", Qty, EntryPrice, 0,	 ProdType  )
	
	if( IsObject(stopOrderNOW)  && isStatusOpen(stopOrderNOW.status)  && stopOrderNOW.triggerPrice != StopTrigger )
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
	global entryOrderNOW, stopOrderNOW
	
	Gui, 2:ListView, SysListView321							// Get Selected Orders
	rowno := LV_GetNext()
	if( rowno > 0 )
		LV_GetText( entryOrderId, rowno, 1 )
	
	Gui, 2:ListView, SysListView322
	rowno := LV_GetNext()
	if( rowno > 0 )
		LV_GetText( stopOrderId, rowno, 1 )
	
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
		
	setGUIValues( entryOrderNOW.price, stopOrderNOW.triggerPrice, getDirectionFromOrder( entryOrderNOW ) )
	updateCurrentResultBtn()
}

addOrderRow( o ) {
	LV_Add("", o.nowOrderNo, o.nowUpdateTime, o.tradingSymbol, o.status, o.orderType, o.buySell, o.totalQty, o.price, o.triggerPrice )
}

setGUIValues( inEntry, inStop, inDirection ){	
	global EntryPrice, StopTrigger, Direction
		
	GuiControl, 1:Text, EntryPrice,  %inEntry%
	GuiControl, 1:Text, StopTrigger, %inStop%
	GuiControl, 1:ChooseString, Direction,  %inDirection%
	
	updateStatusBar()	
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

	updateCurrentResultBtn()
	if( CurrentResult < -MaxStopSize  ){
		MsgBox, % 262144+4,, Stop size more than Maximum Allowed. Continue?
		IfMsgBox No
			return false
	}
	
	return true
}

GuiClose:
	ExitApp
	