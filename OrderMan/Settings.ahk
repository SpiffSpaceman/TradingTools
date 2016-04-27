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



loadSettings(){
	
	local value                 												// All variables global by default

    config := "config/OrderMan.ini"

    IniRead, ScripList,         %config%, OrderMan, ScripList
    IniRead, HKEntryPrice,   	%config%, OrderMan, HKEntryPrice
    IniRead, HKStopPrice,   	%config%, OrderMan, HKStopPrice
    IniRead, HKTargetPrice,   	%config%, OrderMan, HKTargetPrice
    IniRead, LastWindowPosition,%config%, OrderMan, LastWindowPosition
    IniRead, SavedOrders,       %config%, OrderMan, SavedOrders
    IniRead, TITLE_NOW,         %config%, OrderMan, WindowTitle
    
    IniRead, value,     %config%, OrderMan, AlertsEnabled
    AlertsEnabled := value=="true"
  
    IniRead, value, %config%, OrderMan, AutoSubmit
    AutoSubmit := value=="true"
    
    IniRead, DefaultEntryOrderType, %config%, OrderMan, EntryOrderType
    EntryOrderType := DefaultEntryOrderType

    IniRead, Server, %config%, OrderMan, Server
    isServerNOW := (Server == "Now")

    ORDERBOOK_POLL_TIME			  := 500										// Time between reading of OrderBook status by Tracker in order to trigger pending orders. In ms
    GUI_POLL_TIME_MULTIPLE        := 4                                          // Time between GUI refresh by tracker - as multiple of ORDERBOOK_POLL_TIME
    NEW_ORDER_WAIT_TIME			  := 5											// How many maximum seconds to wait for New Submitted Order to appear in orderbook. 
    OPEN_ORDER_WAIT_TIME		  := 5											// How many maximum seconds to wait for Order to be Open ( ie for validation etc to be over)
																				// Warning message shown after wait period
}

/*
  Loads Scrip details from ini.
  Input alias = ini file name
*/
loadScrip( alias ){
    
    local value
    
    ini := "config/scrips/" . alias . ".ini"
    
    IniRead, value,	%ini%, OrderMan, Scrip, NotFound
    
    if( value == "NotFound"){
        MsgBox, Config file not found - %ini%
        return
    }
    
    local fields := StrSplit( value , ",")
    selectedScrip := new ScripClass
    selectedScrip.setInput( fields[1], fields[2], fields[3], fields[4], fields[5], fields[6], alias )  
    
    IniRead, DefaultQty, %ini%, OrderMan, Qty
    Qty :=  DefaultQty
    
    IniRead, ProdType, 	        %ini%, OrderMan, ProdType
    IniRead, MaxStopSize,   	%ini%, OrderMan, MaxStopSize
    IniRead, MaxSlippage,       %ini%, OrderMan, MaxSlippage
    IniRead, DefaultStopSize,	%ini%, OrderMan, DefaultStopSize
    IniRead, DefaultTargetSize,	%ini%, OrderMan, DefaultTargetSize
    IniRead, MinTargetStopDiff,	%ini%, OrderMan, MinTargetStopDiff
    IniRead, TickSize,      	%ini%, OrderMan, TickSize
}

/*
  Save Current Position to Settings. Used to restore position on next start
*/
saveLastPosition(){
    global config
    
	WinGetPos, X, Y,,, OrderMan ahk_class AutoHotkeyGUI
    value = X%X% Y%Y%
	IniWrite, %value%, %config%, OrderMan, LastWindowPosition
}

/*
  Save orders. Used to load open trade on startup
*/
saveOrders( savestring ){
    global config
    IniWrite, %savestring%, %config%, OrderMan, SavedOrders
}

