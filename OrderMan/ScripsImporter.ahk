/*
  Copyright (C) 2017  SpiffSpaceman

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


SCRIPS_FILE := "config\quotes.csv"

try{
	
	scripList := ""
	
	Loop, Read, %SCRIPS_FILE%
	{	
		scrip 	  := StrSplit(A_LoopReadLine, "," ) 
		scripList := scripList . scrip[1] . "|"
		
		writeConfig( scrip[1], scrip[2] )
	}	
	
	StringTrimRight, scripList, scripList, 1								// Remove last '|'
	IniWrite, %scripList%, config\OrderMan.ini, OrderMan, ScripList

} catch exc {
    UtilClass.handleException( exc )
}

return

writeConfig( scrip, price ){
	global slippage, targetStopDiff
	
	ini 	   := "config\scrips\" . scrip . ".ini"
	scripValue := "NSE,EQ," . scrip . ",,,1"
	
	setSlippage( price )
	
	IniWrite, %scripValue%, %ini%, OrderMan, Scrip
	IniWrite, MIS,  %ini%, OrderMan, ProdType
	IniWrite, 0.05, %ini%, OrderMan, TickSize
		
	IniWrite, %slippage%, %ini%, OrderMan, MaxSlippage
	IniWrite, %targetStopDiff%, %ini%, OrderMan, MinTargetStopDiff
}

/* Set some rough price based limits. TODO update
*/
setSlippage( price ){
	global slippage, targetStopDiff
	
	slippage := 0
	targetStopDiff := 0
	
	if( price < 75 ){
		slippage := 0.05
		targetStopDiff := 0.5
	}
	else if( price >= 75 && price < 200){
		slippage := 0.1
		targetStopDiff := 0.75
	}
	else if( price >= 200 && price < 400){
		slippage := 0.15
		targetStopDiff := 1
	}
	else if( price >= 400 && price < 600){
		slippage := 0.2
		targetStopDiff := 1.5
	}
	else if( price >= 600 && price < 800){
		slippage := 0.25
		targetStopDiff := 2
	}
	else if( price >= 800 && price < 1000){
		slippage := 0.3
		targetStopDiff := 2.5
	}
	else if( price >= 1000 && price < 1500){
		slippage := 0.4
		targetStopDiff := 3
	}
	else if( price >= 1500 && price < 2000){
		slippage := 0.5
		targetStopDiff := 4
	}
	else if( price >= 2000 && price < 3000){
		slippage := 0.7
		targetStopDiff := 5
	}
	else if( price >= 3000 && price < 5000){
		slippage := 1
		targetStopDiff := 7
	}
	else if( price >= 5000 && price < 10000){
		slippage := 2
		targetStopDiff := 10
	}
	else if( price >= 10000 && price < 15000){
		slippage := 3
		targetStopDiff := 15
	}
	else if( price >= 15000 && price < 20000){
		slippage := 4
		targetStopDiff := 20
	}
	else if( price >= 20000 && price < 30000){
		slippage := 7
		targetStopDiff := 30
	}
	else if( price >= 30000 && price < 50000){
		slippage := 10
		targetStopDiff := 40
	}
	else if( price >= 50000 ){
		slippage := 15
		targetStopDiff := 50
	}

	if( slippage == 0 ){
		MsgBox, 262144,,  Slippage 0
	}
	if( targetStopDiff == 0 ){
		MsgBox, 262144,,  targetStopDiff 0
	}
}


#include Util.ahk