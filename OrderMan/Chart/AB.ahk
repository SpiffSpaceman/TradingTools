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

installHotkeys(){
	global HKEntryPrice, HKStopPrice, HKTargetPrice, scripControl

	if( HKEntryPrice != "" && HKEntryPrice != "ERROR")		
		installHotKey( HKEntryPrice, "getEntryPriceFromAB" )
	
	if( HKStopPrice != "" && HKStopPrice != "ERROR")
		installHotKey( HKStopPrice, "getStopPriceFromAB" )		
	
	if( HKTargetPrice != "" && HKTargetPrice != "ERROR")
		installHotKey( HKTargetPrice, "getTargetPriceFromAB" )
	
	scripControl := "RichEdit20A3"			// Symbol control with one Analysis window open
}

installHotKey( key, function ){
	Hotkey, IfWinActive, ahk_class AmiBrokerMainFrameClass					// Context sensitive HK - only active if AB/OM is active
	Hotkey, %key%, %function%
			
	Hotkey, IfWinActive, OrderMan
	Hotkey, %key%, %function%
	
	Hotkey, IfWinActive, ahk_class XTPDockingPaneMiniWnd					// Floating Window
	Hotkey, %key%, %function%
}

setScrip(){
	scrip := getScripFromAB()
	if( scrip != "" )
		setSelectedScrip( scrip )
}

getEntryPriceFromAB(){
	global EntryPriceActual, StopPrice, isABPick
	
	setScrip()
	price := getPriceFromAB()

	if( price > 0 ){		
		EntryPriceActual := price
		_guessDirection( price, StopPrice )
		adjustPrices( price, StopPrice )
		isABPick := true
	}
}

getStopPriceFromAB(){
	global EntryPrice, StopPriceActual, isABPick
	
	setScrip()
	price := getPriceFromAB()

	if( price > 0 ){		
		StopPriceActual := price
		_guessDirection( EntryPrice, price )
		adjustPrices( EntryPrice, price )
		isABPick := true
	}
}

getTargetPriceFromAB(){

	setScrip()
	price := getPriceFromAB()
	
	if( price > 0 ){		
		setTargetPrice( UtilClass.roundToTickSize(price) )
	}
}
 
_guessDirection( entry, stop ){
	global contextObj
	
	trade := contextObj.getCurrentTrade()
	
	if( !trade.isEntryOrderExecuted() && !trade.isNewEntryLinked()){			// Guess Direction only at start. Dont change direction once order opened
		setDirection( entry > stop ? "B" : "S")
	}
}

/* Adjust prices to tick size based on direction
 */
adjustPrices( entry, stop ){
	global Direction, EntryPriceActual, StopPriceActual
	
	if( Direction == "B" )
		_longPriceAdjust()
	else
		_shortPriceAdjust()
}

/* Adjust prices to tick size for buy order
   Entry price shift up and stop price shift down       
   NOTE - EntryPriceActual/StopPriceActual should contain the original values taken from AB
 */
_longPriceAdjust(){
	global EntryPriceActual, StopPriceActual
	
	setEntryPrice(  UtilClass.ceilToTickSize( EntryPriceActual),  EntryPriceActual )		
	setStopPrice(   UtilClass.floorToTickSize(StopPriceActual),   StopPriceActual )		
}

/* Adjust prices to tick size for sell order
   Entry price shift down and stop price shift up
 */
_shortPriceAdjust(){
	global EntryPriceActual, StopPriceActual
	
	setEntryPrice(  UtilClass.floorToTickSize(EntryPriceActual),  EntryPriceActual )		
	setStopPrice(   UtilClass.ceilToTickSize( StopPriceActual),   StopPriceActual )
}




/* Get scrip name from Ticker ToolBar
*/
getScripFromAB(){
	global scripControl
	
	IfWinExist, ahk_class AmiBrokerMainFrameClass
	{	
		try{
			if( scripControl != "" ){			
				ControlGetText, scrip, %scripControl%, ahk_class AmiBrokerMainFrameClass
				if( isValidScrip(scrip) ){
					return scrip
				}
			}
		}
		catch ex{				// Control does not exist
			scripControl := ""
		}
		
		Loop, 20{															// Find Symbol Control
			try{
				controlName := "RichEdit20A" . A_Index
				ControlGetText, scrip, %controlName%, ahk_class AmiBrokerMainFrameClass

				if( isValidScrip(scrip) ){
					scripControl := controlName
					return scrip
				}
				else
					continue		// Found Control can be Symbol dropdown or dropdowns from AA etc
			} catch ex{				// Control does not exist
				continue
			}
		}	
	}
	
	MsgBox, Could not select Scrip from AB
	
	return ""
}

/*
	Get price from line under cursor if found, else get from tooltip text
*/
getPriceFromAB(){

	IfWinExist, ahk_class AmiBrokerMainFrameClass
	{	
		BlockInput, MouseMove
		price := getPriceAtCursor()
		if( price <= 0 )
			price := getPriceFromLine()
		if( price <= 0 )
			price := getPriceAtCursorTooltip()
		BlockInput, MouseMoveOff

		return price
	}
	else
		return -1
}

/*
	If Price/Y Axis Tooltip is enabled - pick price from it
	This is fastest way to pick price
*/
getPriceAtCursor(){
	
	WinGet, id, LIST, ahk_class tooltips_class32						// Goes through all tooltips
	Loop, %id%	{
		tt_id := id%A_Index%											// id is pseudo array.  id = NO of tooltips. id1,id2 = Windows ids of tooltips
		ControlGetText, tt_text,, ahk_id %tt_id%
		
		if( UtilClass.isNumber( tt_text ) )								// If tooltip is number - Assume its our price
			return tt_text
	}
	return ""
}

/*
	Selects line and opens properties. Price copied from start price
*/
getPriceFromLine(){
	
	Click 1																// Open trendline / HL properties. Click to Select + Alt-Enter
	Send {Alt down}{Enter}{Alt up}	
	
	Loop, 8{															// Try to hide window as soon as possible. WinWait seems to take too long
		Sleep 25
		WinSet,Transparent, 1, Properties, Start Y:
		IfWinExist, Properties, Start Y:
			break
	}	
	
	WinWait, Properties, Start Y:, 1
	WinSet,Transparent, 1, Properties, Start Y:
	
	IfWinExist, Properties, Start Y:
	{
		ControlGet, price, Line, 1, Edit1, Properties, Start Y:			// Get Start Price
		WinClose, Properties, Start Y:	
		return price
	}
	
	return -1
}

/*
	If View > X-Y Labels set to Off - Pick price from tooltip at cursor
	Tries to trigger tooltip in Amibroker and copies price using Value property
	Tooltip is Triggered by moving right slowly. This takes little extra time.
	Tooltip text row format is assumed to be either "Value = 7747.650"(cursor over empty space) or "Begin:     09-09-2015 09:44:59, Value: 7785.28" ( cursor over line)
*/
getPriceAtCursorTooltip(){

	//IfWinActive, OrderMan
	//	WinActivate, ahk_class AmiBrokerMainFrameClass

	SendMode Event														// Input mode moves cursor immediately - Tooltip open is unreliable
	Loop, 5 {
		
		MouseMove, 15, 0, 25, R											// Move a bit to trigger tooltip
		WinWait, ahk_class tooltips_class32,, 1
		ControlGetText, tt_text,, ahk_class tooltips_class32			
		MouseMove, -15, 0,, R
		
		if( tt_text != ""){			
			break
		}
	}
	SendMode Input	

	if( tt_text == "" )
		return ""	

	Loop, Parse, tt_text, `n
	{
		split := StrSplit( A_LoopField, "=", A_Space )			// Empty Area Tooltip
		if( split[1] == "Value" ){
			return  split[2]
		}
		
		split := StrSplit( A_LoopField, ",", A_Space )			// Line Tooltip
		split := StrSplit( split[2], ":", " `r`n" )				// Remove space and CR LF before/after number
		if( split[1] == "Value" ){
			return  split[2]
		}
	}

	return ""
}
