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

/* Button New 
*/
orderBtn(){
	global contextObj, selectedScrip, EntryOrderType, Direction, Qty, ProdType, EntryPrice, StopPrice
		
	Gui, 1:Submit, NoHide										// sets variables from GUI
	
	setEntryPrice( UtilClass.roundToTickSize(EntryPrice) )
	setStopPrice(  UtilClass.roundToTickSize(StopPrice) )
		
	if( !validateInput() )
		return

	trade 	:= contextObj.getCurrentTrade()
	trade.create( selectedScrip, EntryOrderType, "SLM", Direction, Qty, ProdType, EntryPrice, StopPrice )
	
}

/* Button Update
*/
updateOrderBtn(){
	global contextObj, selectedScrip, EntryOrderType, Qty, ProdType, EntryPrice, StopPrice
	trade := contextObj.getCurrentTrade()
	
	Gui, 1:Submit, NoHide
	
	setEntryPrice( UtilClass.roundToTickSize(EntryPrice) )
	setStopPrice(  UtilClass.roundToTickSize(StopPrice) )
	
	if( !validateInput() )
		return
		
	trade.reload()

	entry := ""																// Update if order linked and status is open/trigger pending and price/qty has changed
	stop  := ""	
	if( trade.isEntryOpen() && hasOrderChanged( trade.entryOrder.getOrderDetails(), EntryPrice, Qty)  )
	{	 																	// Entry Order is open and Entry order has changed
		entry := EntryPrice													// If entry is empty, trade.update() will skip changing Entry Order
	}
	
	if( ( !trade.isStopLinked() || trade.isStopOpen() || trade.isStopPending() ) && hasOrderChanged( trade.stopOrder.getOrderDetails(), StopPrice, Qty) )
	{																		// Stop Order is open or has not been created yet and Stop order has changed
		stop := StopPrice													// If stop is empty, trade.update() will skip changing Stop Order	   
	}
		
	if( entry != ""  ||  stop != "" ){
		trade.update( selectedScrip, EntryOrderType, "SLM", Qty, ProdType, entry, stop  )
	}
	else{
		MsgBox, 262144,, Nothing to update or Order status is not open
	}
}

/*	Status Bar Double Click
	Open window to manually link orders
	Entry order can be linked with Open Orders and successfully completed orders
	Stop order can only be linked with open orders
*/
statusBarClick(){	
	if( A_GuiEvent == "DoubleClick" ){
		openStatusGUI()			
	}
}

/* Stop Text Double Click 
*/
stopClick(){	
	if( A_GuiEvent == "DoubleClick"  ){
		setDefaultStop()
	}	
}

/*  Unlink Button
*/
unlinkBtn(){
	global contextObj
	trade := contextObj.getCurrentTrade()
	
	toggleStatusTracker( "off" )
	trade.unlinkOrders()
	updateStatus()
}

/* Cancel Button
*/
cancelOrderBtn(){
	global contextObj
	trade := contextObj.getCurrentTrade()
	
	trade.cancel()
}

/* Direction Switch
*/
onDirectionChange(){
	global Direction
	
	updateCurrentResult()												// Also submits		
	Gui, Color, % Direction == "B" ? "33cc66" : "ff9933"
}

/* Links Context to selected existing orders
*/
linkOrdersSubmit(){
	global contextObj, ORDER_TYPE_LIMIT, ORDER_TYPE_MARKET, listViewOrderIDPosition, listViewOrderTypePosition
		
	entry_OrderId   := ""
	entry_Ordertype := ""
	stopOrderId	    := ""	
	
// Get Selected Orders
	Gui, 2:ListView, SysListView321
	rowno := LV_GetNext()									// Entry Order ListView Selected row
	if( rowno > 0 ){
		LV_GetText( entry_OrderId,   rowno, listViewOrderIDPosition )
		LV_GetText( entry_Ordertype, rowno, listViewOrderTypePosition )
	}
	
	Gui, 2:ListView, SysListView322
	rowno := LV_GetNext()									// Stop Order ListView Selected row
	if( rowno > 0 )
		LV_GetText( stopOrderId, rowno, listViewOrderIDPosition )
	
// Validations
	if( entry_OrderId == "" ){
		MsgBox, 262144,, Select Entry Order
		return
	}
	if( stopOrderId == "" ){
		if( entry_Ordertype == ORDER_TYPE_LIMIT || entry_Ordertype == ORDER_TYPE_MARKET ){
			MsgBox, 262144,, Select Stop Order				// Allow skipping Stop order linking for SL/SLM Orders
			return
		}
		else{
			MsgBox, 262144,, Stop order is not linked, Enter Stop Price and click Update immediately to ready Stop order
		}		
	}
	if( entry_OrderId == stopOrderId ){
		MsgBox, 262144,, Selected Entry And Stop Order are same
		return
	}
	
	trade := contextObj.getCurrentTrade()
	
// Link Orders in Current Context
	if( !trade.linkOrders( entry_OrderId, stopOrderId, stopOrderId == "" ? false : true ))
		return
	
	Gui, 2:Destroy
	Gui  1:Default	
	
	loadTradeInputToGui()									// Load Gui with data from Order->Input	
	
	trade.save()											// Manually Linked orders - save order nos to ini
}


// -- Helpers ---

/*	Check if Order Details in GUI is different than input order 
*/
hasOrderChanged( order, price, qty ){
	global ORDER_TYPE_LIMIT, ORDER_TYPE_MARKET
	
	if( qty != order.totalQty)
		return true
	
	type := order.orderType
	
	if( type == ORDER_TYPE_LIMIT || type == ORDER_TYPE_MARKET)
		oldprice := order.price
	else
		oldprice := order.triggerPrice
	
	return price != oldprice
}

/* Validations before trade orders creation/updation
*/
validateInput(){
	global contextObj, EntryPrice, StopPrice, Direction, CurrentResult, MaxStopSize
	
	trade := contextObj.getCurrentTrade()
	
	if( Direction != "B" && Direction != "S"  ){
		MsgBox, 262144,, Direction not set
		return false
	}
	
	if( !UtilClass.isNumber(EntryPrice) ){
		MsgBox, 262144,, Invalid Entry Price
		return false
	}
	if( !UtilClass.isNumber(StopPrice) ){
		MsgBox, 262144,, Invalid Stop Trigger Price
		return false
	}	
	
	if( ! trade.isEntrySuccessful() ){							// Allow to trail past Entry 
		if( Direction == "B" ){									// If Buying, stop should be below price and vv
			if( StopPrice >= EntryPrice  ){
				MsgBox, 262144,, Stop Trigger should be below Buy price
				return false
			}
		}
		else{
			if( StopPrice <= EntryPrice  ){
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


