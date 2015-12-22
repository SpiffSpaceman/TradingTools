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
	
	local value												// All variables global by default
	
	IniRead, Qty, 	  		    OrderMan.ini, OrderMan, Qty
	IniRead, ProdType, 		    OrderMan.ini, OrderMan, ProdType
    IniRead, DefaultStopSize,	OrderMan.ini, OrderMan, DefaultStopSize
    IniRead, DefaultTargetSize,	OrderMan.ini, OrderMan, DefaultTargetSize
    IniRead, MinTargetStopDiff,	OrderMan.ini, OrderMan, MinTargetStopDiff    
    IniRead, MaxStopSize,   	OrderMan.ini, OrderMan, MaxStopSize
    IniRead, HKEntryPrice,   	OrderMan.ini, OrderMan, HKEntryPrice
    IniRead, HKStopPrice,   	OrderMan.ini, OrderMan, HKStopPrice
    IniRead, HKTargetPrice,   	OrderMan.ini, OrderMan, HKTargetPrice
    IniRead, TickSize,      	OrderMan.ini, OrderMan, TickSize
    IniRead, LastWindowPosition,OrderMan.ini, OrderMan, LastWindowPosition
    IniRead, EntryOrderType,    OrderMan.ini, OrderMan, EntryOrderType
    IniRead, MaxSlippage,       OrderMan.ini, OrderMan, MaxSlippage
    IniRead, SavedOrders,       OrderMan.ini, OrderMan, SavedOrders    
    
    IniRead, value, OrderMan.ini, OrderMan, AutoSubmit
    AutoSubmit   := value=="true"
        
    IniRead, value,	OrderMan.ini, OrderMan, Scrip    
	local fields := StrSplit( value , ",")
    
    selectedScrip := new ScripClass
    selectedScrip.setInput( fields[1], fields[2], fields[3], fields[4], fields[5], fields[6] )  
}

/*
  Save Current Position to Settings. Used to restore position on next start
*/
saveLastPosition(){
	WinGetPos, X, Y,,, OrderMan ahk_class AutoHotkeyGUI
    value = X%X% Y%Y%
	IniWrite, %value%, OrderMan.ini, OrderMan, LastWindowPosition
}

/*
  Save orders. Used to load open trade on startup
*/
saveOrders( savestring ){    
    IniWrite, %savestring%, OrderMan.ini, OrderMan, SavedOrders
}

