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
onNew(){
	global contextObj, selectedScrip, EntryOrderType, Direction, Qty, ProdType, EntryPrice, StopPrice, TargetPrice, TargetQty, STOP_ORDER_TYPE, isButtonTrigger

	isButtonTrigger := true										// Avoid triggering setTradeRisk() by adjustPrices()
	
	Gui, 1:Submit, NoHide										// sets variables from GUI
	
	adjustPrices( EntryPrice, StopPrice)
		
	if( !validateInput() ){
		isButtonTrigger := false
		return
	}
	
	TargetEntryDiff := Direction == "B" ? TargetPrice-EntryPrice : EntryPrice-TargetPrice
	if( TargetEntryDiff <= 0  && TargetPrice != "" && TargetPrice != 0 ){
		MsgBox, 262144,, Target Should be ahead of Entry Price for new order
		isButtonTrigger := false
		return
	}	

	trade 	:= contextObj.getCurrentTrade()
	trade.create( selectedScrip, EntryOrderType, STOP_ORDER_TYPE, Direction, Qty, ProdType, EntryPrice, StopPrice, TargetPrice, TargetQty )
	
	isButtonTrigger := false
}

/* Button Add
*/
onAdd(){
	onNew()
}

/* Button Update
*/
onUpdate(){
	global contextObj, orderbookObj, selectedScrip, EntryOrderType, Qty, ProdType, EntryPrice, StopPrice, TargetPrice, TargetQty, STOP_ORDER_TYPE, isButtonTrigger
	
	isButtonTrigger := true
	
	trade := contextObj.getCurrentTrade()	
	
	Gui, 1:Submit, NoHide
	
	adjustPrices( EntryPrice, StopPrice)
	
	if( !validateInput() ){
		isButtonTrigger := false
		return
	}

	orderbookObj.read()
	trade.reload()

	entry 		 := ""														// Update if order linked and status is open/trigger pending and price/qty has changed
	stop  		 := ""
	target		 := ""
	positionSize := trade.positionSize
	
	if( trade.isEntryOpen() && hasOrderChanged( trade.newEntryOrder, EntryPrice, Qty)  )
	{	 																	// Entry Order is open and Entry order has changed
		entry := EntryPrice													// If entry is empty, trade.update() will skip changing Entry Order
	}																		// Stop Order - check if Entry Order qty has changed, stop qty may be different and is handled later
	if( hasPriceChanged( trade.stopOrder, StopPrice) || hasQtyChanged( trade.newEntryOrder, Qty) )
	{
		stop := StopPrice
	}
																			// If Target order is linked, check if something changed
																			// If Target order is not linked, then always create target order if price is filled
																			// Target Order size is always = completed Entry orders' size
	if( trade.isTargetLinked() )
		target := hasOrderChanged( trade.target.getOpenOrder(), TargetPrice, TargetQty ) ? TargetPrice : -1
	else
		target := TargetPrice

	if( entry != ""  ||  stop != "" || target != -1 ){		
		trade.update( selectedScrip, EntryOrderType, STOP_ORDER_TYPE, Qty, ProdType, entry, stop, target, TargetQty  )
	}
	else{
		MsgBox, 262144,, Nothing to update or Order status is not open
	}
	
	isButtonTrigger := false
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
		setBreakevenStop()
	}
}

/* Target Text 
	Click = Increase by 1X
	Double Click = Reset to 1X
*/
TargetClick(){
	if( A_GuiEvent == "DoubleClick"  ){
		resetTarget1X()
	}	
	else if( A_GuiEvent == "Normal" ){
		increaseTarget1X()
	}
}

/*  Unlink Button
*/
onUnlink(){
	global contextObj
	trade := contextObj.getCurrentTrade()
		
	trade.unlinkOrders()
	updateStatus()
}

/* Cancel Button
*/
onCancel(){
	global contextObj
	trade := contextObj.getCurrentTrade()
	
	trade.cancel()
	clearGUI()
}

/* Scrip combobox change
	Seems to be Only called on manually selecting option and not by changing value through GuiControl
*/
onScripChange(){
	global SelectedScripText
	
	oldScrip := SelectedScripText	
	
	Gui, 1:Submit, NoHide
	
	if( oldScrip != SelectedScripText){ 
		loadScripSettings()
	}
}

loadScripSettings(){
	global SelectedScripText, EntryOrderType
	
	setDefaultFocus()															// Change Focus to Entry price to prevent change by mouse scroll
	loadScrip( SelectedScripText )
		
	setGUIValues( 0, 0, 0, 0, 0, "B", EntryOrderType )							// clear GUI but keep selected order type
	
	priceUpdateCallback()
}

clearGUI(){																		// Reset to default state
	global DefaultEntryOrderType, InitialStopDistance, InitialEntry
	
	setGUIValues( 0, 0, 0, 0, 0, "B", DefaultEntryOrderType )
	InitialStopDistance  := 0
    InitialEntry         := 0
}

/* Direction Switch
*/
onDirectionChange(){
	global Direction
	
	updateCurrentResult()												// Also submits		
	Gui, Color, % Direction == "B" ? "33cc66" : "ff9933"
}

onEntryPriceChange(){
	global EntryPrice, EntryPriceActual, isABPick
	
	if( isABPick ){
		isABPick := false							// workaround fix, This fn is called by both manual setting of price and by AB picker
		return											// better way to keep AB picked price?
	}
	
	Gui, 1:Submit, NoHide
	
	EntryPriceActual := EntryPrice	
	updateCurrentResult()
}

onStopPriceChange(){
	global StopPrice, StopPriceActual, isABPick
	
	if( isABPick ){
		isABPick := false
		return
	}
	
	Gui, 1:Submit, NoHide
	
	StopPriceActual := StopPrice
	updateCurrentResult()
}

OnEntryUpDown(){
	global EntryUpDown, TickSize, EntryPrice
	
	EntryPrice := (EntryUpDown == 1) ? EntryPrice + TickSize : EntryPrice - TickSize	
	setEntryPrice( EntryPrice, EntryPrice )
}

OnStopUpDown(){
	global StopUpDown, TickSize, StopPrice
	
	StopPrice := (StopUpDown == 1) ? StopPrice + TickSize : StopPrice - TickSize	
	setStopPrice( StopPrice, StopPrice )
}

OnTargetUpDown(){
	global TargetUpDown, TickSize, TargetPrice
	
	TargetPrice := (TargetUpDown == 1) ? TargetPrice + TickSize : TargetPrice - TickSize	
	setTargetPrice( TargetPrice )
}

OnTargetQtyPercChange(){
	global contextObj, TargetQtyPerc, TargetQty, Qty
	
	Gui, 1:Submit, NoHide
	
	trade			:= contextObj.getCurrentTrade()
	
	positionSize	:= trade.positionSize
	openSize		:= trade.isEntryOpen() ? trade.newEntryOrder.getTotalQty() : 0
	totalSize		:= openSize + positionSize

	if( totalSize == 0 )
		totalSize := Qty														// Initially allow setting based on Qty so that we can set default targets
		
	TargetQty  		:= Ceil( totalSize * TargetQtyPerc/100  )					// Input Target qty is fraction of Total filled and unfilled entry orders
	
	updateCurrentResult()
}

OnEntrySizeChange(){
	global EntryRiskPerc, Qty, EntryPrice, StopPrice
		
	Gui, 1:Submit, NoHide
	riskPerTrade := UtilClass.getRiskPerTrade()
	fullQty		 := riskPerTrade /  Abs(EntryPrice - StopPrice) 
	Qty 		 := Floor(fullQty * EntryRiskPerc/100)
	
	GuiControl, 1:Text, Qty,  %Qty%		// Dont call setQty as that will again try to change EntryRiskPerc
	OnTargetQtyPercChange()
}

/* Links Context to selected existing orders
*/
linkOrdersSubmit(){
	global contextObj, controlObj, orderbookObj, listViewOrderIDPosition, listViewOrderTypePosition, listViewOrderStatusPosition, LinkedScripText, LinkInitialStopPrice

	Gui, 2:Submit, NoHide										// sets variables from GUI
	if( LinkedScripText == "" ){
		MsgBox, 262144,, Select Scrip Alias
		return
	}
	
	if( LinkInitialStopPrice == "" || !UtilClass.isNumber( LinkInitialStopPrice) ){
		MsgBox, 262144,, Set Initial Stop Price
		return
	}

	entryId   			 := ""
	entryType 			 := ""
	executedEntryIDList	 := ""
	stopOrderId	    	 := ""
	targetOrderId		 := ""
	executedtargetIDList := ""
	isPending			 := false
	rowno				 := 0
	firstEntryOrderId	 := 0

	Gui, 2:ListView, SysListView321
	Loop % LV_GetCount("Selected")
	{		
		rowno := LV_GetNext( rowno )								// Entry Order ListView Selected row
		if( rowno == 0 )
			break
		
		LV_GetText( orderId,   rowno, listViewOrderIDPosition )
		LV_GetText( ordertype, rowno, listViewOrderTypePosition )
		LV_GetText( status,    rowno, listViewOrderStatusPosition )
		
		if(firstEntryOrderId == 0 || firstEntryOrderId > orderId )	// Assuming Entry Order with lowest id is First Entry Order
			firstEntryOrderId := orderId
																	// Is this Open Order?
		if( status == controlObj.ORDER_STATUS_OPEN || status == controlObj.ORDER_STATUS_TRIGGER_PENDING ){
			if( entryId != ""  ){
				MsgBox, 262144,, Select Only One Open Entry Order
				return
			}
			entryId   := orderId
			entryType := ordertype
		}
		else{
			executedEntryIDList := orderId . "," . executedEntryIDList
		}
	}
	if( entryId == "" && executedEntryIDList == "" ){
		MsgBox, 262144,, Select Atleast One Entry Order
		return
	}
	
	Gui, 2:ListView, SysListView322
	rowno := 0 
	
	Loop % LV_GetCount("Selected")
	{		
		rowno := LV_GetNext( rowno )							// Stop/Target Order ListView Selected rows
		if( rowno == 0 )
			break
		
		LV_GetText( orderId,   rowno, listViewOrderIDPosition )
		LV_GetText( ordertype, rowno, listViewOrderTypePosition )
		LV_GetText( status,    rowno, listViewOrderStatusPosition )
		
		if( ordertype == controlObj.ORDER_TYPE_LIMIT){			// Target - Open / Executed
			if( status == controlObj.ORDER_STATUS_OPEN ){
				if( targetOrderId != ""  ){
					MsgBox, 262144,, Select Only One Open Target Order
					return
				}
				targetOrderId := orderId
			}
			else{
				executedtargetIDList := orderId . "," . executedtargetIDList
			}
		}
		else if( ordertype == controlObj.ORDER_TYPE_SL_MARKET){
			if( stopOrderId == "" )
				stopOrderId := orderId
			else{
				MsgBox, 262144,, Select only One Stop Order
				return	
			}					
		}
	}
		
	
	if( entryType == controlObj.ORDER_TYPE_SL_LIMIT || entryType == controlObj.ORDER_TYPE_SL_MARKET )
		isPending := true
	
	if( stopOrderId == "" ){
		if( entryType == controlObj.ORDER_TYPE_SL_LIMIT || entryType == controlObj.ORDER_TYPE_SL_MARKET ){
			MsgBox, 262144,, Stop order is not linked, Enter Stop Price and click Update immediately to ready Stop order
		}
		else{
			MsgBox, 262144,, Select Stop Order				// Skipping Stop order allowed only for SL/SLM Orders
			return
		}
	}
	if( entryId == stopOrderId ){							// No Need to check against executedEntryIDList as only completed orders are allowed in it
		MsgBox, 262144,, Selected Entry And Stop Order are same
		return
	}
	
	trade := contextObj.getCurrentTrade()					// Link Orders in Current Context	

	if( !trade.linkOrders( false, LinkedScripText, entryId, executedEntryIDList, stopOrderId, isPending, 0, targetOrderId, 0, 0, executedtargetIDList ) )
		return
	
	// Set Initial Entry Price and Stop distance
	entryOrder := new OrderClass
	entryOrder.loadOrderFromOrderbook(  orderbookObj.getOrderDetails(firstEntryOrderId) )
	
	LinkInitialEntryPrice := entryOrder.getPrice()
	risk := abs( LinkInitialEntryPrice -LinkInitialStopPrice )
	trade.saveInitialStopDistance( risk, LinkInitialEntryPrice )
	
	Gui, 2:Destroy
	Gui  1:Default	
	
	toggleStatusTracker("on")								// Turn on Tracker thread once Trade has been loaded successfully
	
	loadTradeInputToGui()									// Load Gui with data from Order->Input	
	
	trade.save()											// Manually Linked orders - save order nos to ini
}

/*Switch between trades
*/
contextSwitch1(){
	global contextObj
	contextObj.switchContext(1)	
}

contextSwitch2(){
	global contextObj
	contextObj.switchContext(2)
}

contextSwitch3(){
	global contextObj
	contextObj.switchContext(3)
}

// -- Helpers ---

/*	Check if Order Details in GUI is different than input order 
	Returns false if input order is empty
*/
hasOrderChanged( order, price, qty ){
	return hasPriceChanged( order, price ) || hasQtyChanged( order, qty )	
}

hasPriceChanged( order, price  ){
	global ORDER_TYPE_GUI_LIMIT, ORDER_TYPE_GUI_MARKET
	
	orderInput := order.getInput()	
	if( !IsObject(orderInput) )
		return false
	
	type := orderInput.orderType
	
	if( type == ORDER_TYPE_GUI_LIMIT || type == ORDER_TYPE_GUI_MARKET)
		oldprice := orderInput.price
	else
		oldprice := orderInput.trigger
	
	return price != oldprice
}

hasQtyChanged( order, qty ){
	
	orderInput := order.getInput()	
	if( !IsObject(orderInput) )
		return false
	
	if( qty != orderInput.qty)
		return true
}

/* Validations before trade orders creation/updation
*/
validateInput(){
	global contextObj, EntryPrice, Qty, StopPrice, TargetPrice, TargetQty, Direction, CurrentResult, MinTargetStopDiff, EntryOrderType, ORDER_TYPE_GUI_LIMIT, ORDER_TYPE_GUI_SL_LIMIT, ORDER_TYPE_GUI_SL_MARKET
	
	trade 		:= contextObj.getCurrentTrade()
	checkEntry  := trade.positionSize==0  ||  trade.isNewEntryLinked()		// Skip Entry Price Validations if Entry is Complete and No Add Orders created yet
	
	if( Direction != "B" && Direction != "S"  ){
		MsgBox, 262144,, Direction not set
		return false
	}
		
	if( checkEntry && (!UtilClass.isNumber(EntryPrice) || EntryPrice<=0  ) ){
		MsgBox, 262144,, Invalid Entry Price
		return false
	}
	if( !UtilClass.isNumber(StopPrice) || StopPrice<=0 ){
		MsgBox, 262144,, Invalid Stop Trigger Price
		return false
	}
	if( TargetPrice!= ""  && (!UtilClass.isNumber(TargetPrice) || TargetPrice<0) ){		// target price can be 0 => No Target
		MsgBox, 262144,, Invalid Target Price
		return false
	}	
	
	if( TargetPrice != "" && TargetPrice != 0 && TargetQty != "" && TargetQty != 0 ){
		StopDiff := Direction == "B" ? TargetPrice-StopPrice : StopPrice-TargetPrice
		if( StopDiff < 0  ){
			MsgBox, 262144,, Target should be ahead of Stop
			return false
		}		
		if( StopDiff < MinTargetStopDiff ){									// Warn if Target-Stop diff is less than threshold. As Both orders may get executed if diff too small
			MsgBox, % 262144+4,, Target and Stop orders are too close, Do you want to continue?
			IfMsgBox No
				return false
		}
	}
		
	
	if( checkEntry ){														// If Buying, stop should be below price and vv
		if( Direction == "B" ){												// checkEntry - Allow to trail past Entry once Entry/Add order is closed
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
	
	// Current Price based checks
	currentPrice := getCurrentScripPrice()
	
	if( currentPrice != "" && currentPrice != 0  && Qty > 0 ){
		
		if( EntryOrderType == ORDER_TYPE_GUI_LIMIT ){
			if(  Direction == "B"  && EntryPrice >= currentPrice ){
				MsgBox, % 262144+4,, LIMIT Buy order is above current price and will be immediately filled - Continue ?
				IfMsgBox No
					return false
			}
			if(  Direction == "S"  && EntryPrice <= currentPrice ){
				MsgBox, % 262144+4,, LIMIT Sell order is below current price and will be immediately filled - Continue ?
				IfMsgBox No
					return false
			}
		}		
		else if( EntryOrderType == ORDER_TYPE_GUI_SL_LIMIT   ||   EntryOrderType == ORDER_TYPE_GUI_SL_MARKET ){
			if(  Direction == "B"  && EntryPrice <= currentPrice ){
				MsgBox, % 262144+4,, Stop Buy order is below current price and will be immediately filled - Continue ?
				IfMsgBox No
					return false
			}
			if(  Direction == "S"  && EntryPrice >= currentPrice ){
				MsgBox, % 262144+4,, Stop Sell order is above current price and will be immediately filled - Continue ?
				IfMsgBox No
					return false
			}
		}
	}	
	

	updateCurrentResult()	
	
	return true
}

/* Returns price of currently selected Scrip
*/
getCurrentScripPrice(){
	global alertsObj, SelectedScripText
	
	return alertsObj.getScripCurrentPrice( SelectedScripText )
}

/* Called by Alerts Timer to trigger price update
*/
priceUpdateCallback(){
	global contextObj, InitialStopDistance
	
	scripPrice    	  := getCurrentScripPrice()
	averageTradePrice := contextObj.getCurrentTrade().averageEntryPrice
	
	if( averageTradePrice == 0 )
		averageTradePrice := ""
	
	result := ""
	if( averageTradePrice != "" ){
		result := contextObj.getCurrentTrade().isLong() ? scripPrice - averageTradePrice : averageTradePrice - scripPrice
		result := result / InitialStopDistance
		result := % Format( "{1:0.1f}X", result )
	}	

	setPriceStatus( scripPrice . "  " . averageTradePrice . "  " . result )
}

