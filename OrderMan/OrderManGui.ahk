/*
  Copyright (C) 2014  SpiffSpaceman

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
	global EntryPrice, StopTrigger, Direction, CurrentResult
		
	Gui, New, +AlwaysOnTop, OrderMan
	
	Gui, Add, ListBox, vDirection h30 w20 Choose1, B|S		// Column 1
	Gui, Add, Edit, vCurrentResult ReadOnly w30
	
	Gui, Add, Text, ym, Entry								// Column 2
	Gui, Add, Text,, Stop
			
	Gui, Add, Edit, vEntryPrice w75 ym						// Column 2
	Gui, Add, Edit, vStopTrigger w75
	Gui, Add, Button, gorder, Enter	
	Gui, Add, Button, gtrail x+m, Trail
	
	Gui, Add, Button, gsetDefaultStop ym, Default Stop		// Column 3 	
	Gui, Add, Button, gupdateCurrentResult, Current Result	

	Gui, Show, AutoSize NoActivate
	
	setDefaultValues()
	
	return	
}


order(){	
	Gui, Submit, NoHide										// sets variables from GUI	
	if( !validateInput() )
		return
	
	entryOrder()
}
trail(){
	Gui, Submit, NoHide
	if( !validateInput() )
		return
	
	trailSLOrder()
}



setDefaultValues(){	
	global EntryPrice, StopTrigger, Direction
		
	GuiControl,, EntryPrice, 0
	GuiControl,, StopTrigger, 0	
}
setDefaultStop(){
	global EntryPrice, StopTrigger, Direction, DefaultStopSize
		
	Gui, Submit, NoHide			
	StopTrigger :=  Direction == "B" ? EntryPrice-DefaultStopSize : EntryPrice+DefaultStopSize		
	GuiControl,, StopTrigger, %StopTrigger%
	
	updateCurrentResult()
}
updateCurrentResult(){
	global EntryPrice, StopTrigger, Direction, CurrentResult
	
	Gui, Submit, NoHide
	CurrentResult := Direction == "B" ? StopTrigger-EntryPrice : EntryPrice-StopTrigger
	GuiControl,, CurrentResult, %CurrentResult%	
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
	ExitApp
	