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
#Warn, All, StdOut

SendMode Input  															// Recommended for new scripts
SetWorkingDir %A_ScriptDir%  												// Ensures a consistent starting directory
SetTitleMatchMode, 2 														// A window's title can contain the text anywhere
SetControlDelay, -1 														// Without this ControlClick fails sometimes

try{

  loadSettings()

  contextObj   := new ContextClass                                          // Keep Class string in class names to avoid conflict - can get overwritten by object of same name
  contextObj.init()                                                         // without new, class members are not initialized
  orderbookObj := new OrderbookClass
  controlObj   := isServerNOW  ? new NowControlsClass : new NestControlsClass // Contains All control ids, window titles for Now/Nest
  alertsObj    := new AlertsClass


  UtilClass.checkNOWOpen()
  initializeStatusTracker()
  orderbookObj.read()
  createGUI()
  checkForOpenOrders()
  installHotkeys()
  alertsObj.init()

} catch exc {
    UtilClass.handleException( exc )
}

return


checkForOpenOrders(){
	global orderbookObj, contextObj
  
	if( orderbookObj.doOpenOrdersExist() ) {        // Try to load from saved orders
        
        isLoaded3 := loadTradeAt(3)
        isLoaded2 := loadTradeAt(2)
        isLoaded1 := loadTradeAt(1)
        
        if( isLoaded1 ){                            // switch to 1st active trade and update GUI            
            loadTradeInputToGui()
        }
        else if ( isLoaded2 ){
            contextObj.switchContext(2)
        }
        else if( isLoaded3 ){
            contextObj.switchContext(3)
        }
        
        if( isLoaded1 || isLoaded2 || isLoaded3 )
            toggleStatusTracker("on")
	}
}

/* Load Trade data, without updating GUI
*/
loadTradeAt( i ){
    global  contextObj
    
    contextObj.switchContextIndex(i)
    trade := contextObj.getCurrentTrade()
    
    if( trade.loadOrders() ){
        contextObj.loadTradeToContext()
        return true
    }
    return false
}


#include Settings.ahk
#include Alerts.ahk
#include Scrip.ahk
#include Order/OrderDetails.ahk
#include Order/Order.ahk
#include Order/Orderbook.ahk
#include Order/OrderTracker.ahk
#include Trade/Trade.ahk
#include Trade/Target.ahk
#include Context.ahk
#include Gui.ahk
#include GuiActions.ahk
#include Util.ahk
#include Chart/AB.ahk
#include GUIControls/Now.ahk
#include GUIControls/Nest.ahk


#CommentFlag ;
#include Lib/__ExternalHeaderLib.ahk										; External Library to read Column Headers
