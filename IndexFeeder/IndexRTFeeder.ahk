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
																			// Includes behave as though the file's contents are present at this exact position
#SingleInstance force														// Reloads if already running
#NoEnv																		// Recommended for new scripts
#Warn, All, StdOut		 

SendMode Input  															// Recommended for new scripts
SetWorkingDir %A_ScriptDir%  												// Ensures a consistent starting directory
SetTitleMatchMode, 2 														// A window's title can contain the text anywhere
SetControlDelay, -1 														// Without this ControlClick fails sometimes. Example - Index Right click fails if mouse is over NOW

#Persistent																	// Keep script running untill manual close or on ExitApp

try{
	IdleCount := 0 
	
	loadSettings()
	SetTimer, readIndices, %RTInterval% 									// Read Index Data
	SetTimer, export, %ABInterval% 											// Export Bars to AB
} catch ex {
	handleException(ex)
}
return



loadSettings(){
	global NowWindowTitle, IndexTableID, RTInterval, ABInterval, START_TIME, END_TIME, QuotesFileName, IndexList, IndexCount, Quotes, TickPath
	
	IniRead, NowWindowTitle,  IndexRTFeeder.ini, IndexRTFeeder, NowWindowTitle		
	IniRead, IndexTableID,    IndexRTFeeder.ini, IndexRTFeeder, IndexTableID	

	IniRead, RTInterval,   	  IndexRTFeeder.ini, IndexRTFeeder, RTInterval
	IniRead, ABInterval,   	  IndexRTFeeder.ini, IndexRTFeeder, ABInterval
	
	IniRead, START_TIME, 	  IndexRTFeeder.ini, IndexRTFeeder, StartTime
	IniRead, END_TIME, 		  IndexRTFeeder.ini, IndexRTFeeder, EndTime
	
	IniRead, QuotesFileName,  IndexRTFeeder.ini, IndexRTFeeder, QuotesFileName
	IniRead, TickPath,  	  IndexRTFeeder.ini, IndexRTFeeder, TickPath

	IndexList  := {}
	IndexCount := 0	
	Quotes	   := {}
	
	Loop{	
		IniRead, value, IndexRTFeeder.ini, IndexRTFeeder, Index%A_Index%
		if value = ERROR 
			break	
		
		split    := StrSplit( value, "," )
		nowAlias := split[1]
		abAlias	 := split[2]
		
		IndexList.Insert( nowAlias )
		IndexCount 	 := A_Index	
		
		scrip   	 := {}
		scrip.symbol := abAlias
		resetQuote( scrip )
	
		Quotes[nowAlias] := scrip											// Key = NOW alias, value = Object with properties O/H/L/C/symbol
	}
	
	createFileDirectory( QuotesFileName )
}

resetQuote( ByRef scrip ){
	scrip.O := 0
	scrip.H := 0
	scrip.L := 0
	scrip.C := 0
}

updateBar( ByRef scrip, price ){

	if( scrip.O == 0 )
		scrip.O := price
	
	if( price > scrip.H )
		scrip.H := price
	
	if( scrip.L == 0  ||  price < scrip.L )
		scrip.L := price

	scrip.C := price
}

/* Index Dialog must be docked
*/
readIndices(){

	global  NowWindowTitle, IndexTableID, Quotes
	
	time := A_Hour . ":" . A_Min
	if( isPreMarketOpen( time ) )
		return
	if( isPostMarketClose( time) )
		ExitApp
	
	IndexSymbol := ""
	IndexValue  := ""
	
	ControlGet, List, List, , %IndexTableID%, %NowWindowTitle%
	Loop, Parse, List, `n  													// Rows are delimited by linefeeds (`n)
	{																		// Fields (columns) in each row are delimited by tabs (A_Tab)
		Loop, Parse, A_LoopField, %A_Tab%  
		{	
			if( A_Index == 1  )
				IndexSymbol :=  A_LoopField
			else if( A_Index == 2  )
				IndexValue  :=  A_LoopField
		}

		IndexValue	:= StrSplit( IndexValue, "(" )[1]
		
		scrip 		:= Quotes[ IndexSymbol ]
		updateBar( scrip, IndexValue )
	}
}

export(){
	global Quotes, IndexCount, IndexList, QuotesFileName, TickPath, IdleCount
	
	time := A_Hour . ":" . A_Min
	if( isPreMarketOpen( time ) || isPostMarketClose( time ) )
		return
	
	data := ""
	
	Loop, %IndexCount%{
		nowAlias := IndexList[A_Index]
		scrip 	 := Quotes[ nowAlias ]
	
		if( scrip.C == 0 )
			continue
	
		// Ticker, Date_YMD, Time, Open, High, Low, Close, Volume, OpenInt
		bar  := scrip.symbol . "," . (A_YYYY . A_MM . A_DD) . "," . (A_Hour . ":" . A_Min . ":" . A_Sec) . "," . scrip.O . "," . scrip.H . "," . scrip.L . "," . scrip.C . "`n"
		data := data . bar
		
		tickFile := TickPath . scrip.symbol . ".csv"
		WriteData( tickFile, "a", bar )
		resetQuote( scrip )
	}
	
	if( data != "" ){
		WriteData( QuotesFileName, "w", data )
		Run, cscript.exe ImportRT.js,, hide
		IdleCount := 0
	}
	else{
		IdleCount++
	
		if( IdleCount >= 2){
			IfWinExist, NEST Trader, Do you want to Reconcile							// TODO NOW
			{
				ControlClick, Button1, NEST Trader, Do you want to Reconcile
			}
			
			IfWinExist, NEST Trader, The parameter is incorrect
			{
				ControlClick, Button1, NEST Trader, The parameter is incorrect
			}
			
			IdleCount := 0
		}
	}
}

WriteData( filename, mode, data ){
	
	file := FileOpen(filename, mode )
	if !IsObject(file){
		MsgBox, Can't open Index RT file for writing. %filename%
		Exit
	}

	file.Write(data)							    						// Add Data	
	file.Close()
}

isPreMarketOpen( time ){
	global START_TIME
	
	return time < START_TIME
}

isPostMarketClose( time  ){
	global END_TIME	

	return time >= END_TIME													// 15:30 = end time. No quotes from 15:30:XX
}

createFileDirectory( file_path ){											// Create File directory path if it does not exist
	
	SplitPath, file_path,, directory
	
	IfNotExist, %directory%
		FileCreateDir, %directory%
}

handleException(e){
	MsgBox % "Error in " . e.What . ", Location " . e.File . ":" . e.Line . " Message:" . e.Message . " Extra:" . e.Extra
}
