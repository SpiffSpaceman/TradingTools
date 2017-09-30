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
																			// Includes behave as though the file's contents are present at this exact position
#SingleInstance force														// Reloads if already running
#NoEnv																		// Recommended for new scripts
#Warn, All, StdOut		 

SendMode Input  															// Recommended for new scripts
SetWorkingDir %A_ScriptDir%  												// Ensures a consistent starting directory
SetTitleMatchMode, 2 														// A window's title can contain the text anywhere
SetControlDelay, -1 														// Without this ControlClick fails sometimes. Example - Index Right click fails if mouse is over NOW

try{

	VWAPColumnIndex := ""													// Initialize some variables to avoid harmless warn errors
	scripControl	:= ""

	loadSettings()															// Load settings for Timer before hotkey install

	controlObj := isServerNOW ? new NowControlsClass : new NestControlsClass // Contains  control ids, window titles for Now/Nest 
	
	SetTimer, PingNOW, %PingerPeriod% 										// Install Keep Alive Timer
	installEOD()															// Install Timer for EOD backfill once
	installHotkeys()														// Setup Hotkey for Backfill
	
	// Simulator Hotkeys
	#If WinExist("Bar Replay") && WinActive("ahk_exe Broker.exe")	
	Numpad0::hkSim5()
	Right::hkSimNext()
	Left::hkSimPrev()
	#If

} catch ex {
	handleException(ex)
}
return

installHotKeys(){
	global HKFlattenTL, HKBackfill, HKBackfillAll, HKSetLayer, HKDelStudies
		
	if( HKBackfill == "ERROR" ||  HKBackfill == "" ){
		MsgBox, Set backfill Hotkey
		return
	}
	
	Hotkey, %HKBackfill%,  hkBackfill
	Hotkey, %HKBackfillAll%,  hkBackfillAll	


	// Context sensitive HK - only active if window is active	
	Hotkey, IfWinActive, ahk_exe Broker.exe
	if( HKFlattenTL != "" && HKFlattenTL != "ERROR")
		Hotkey, %HKFlattenTL%, hkFlatTrendLine	
		
	if( HKSetLayer != "" && HKSetLayer != "ERROR")
		Hotkey, %HKSetLayer%, hkSetLayer
	
	if( HKDelStudies != "" && HKDelStudies != "ERROR")
		Hotkey, %HKDelStudies%, hkDelStudies
	
	// Numpad9 to activate Watchlist and Numpad3 for symbols
	Hotkey, Numpad9, hkWatchList
	Hotkey, Numpad3, hkSymbols
	Hotkey, F5, hkRefresh					// Send refresh to AB main window. useful in AA
	Hotkey, Numpad5, hkNum5					// Send Numpad key to AB main window. useful in AA
	Hotkey, Numpad6, hkNum6					// Send Numpad key to AB main window. useful in AA
	Hotkey, NumpadDot, hkSwitchExplore		// Switch between FT and Momentum	
	Hotkey, NumpadDiv, hkUpdateScrips		// Update RTDMan with scrips from TD watchlist. Also setup Nest Marketwatch
}

// --------------------------------

isBarReplay(){
	return WinExist("Bar Replay") && WinActive("ahk_exe Broker.exe")
}

hkRefresh(){
	try{		
		ControlSend, , {F5}, ahk_class XTPDockingPaneMiniWnd ahk_exe Broker.exe
	} catch e {
		handleException(e)
	}
}

// Erase from AA results and rerun AA
hkNum5(){
	try{
		Click 1000,300									// click on center chart
		Send, {Numpad5}
		hkSwitchExplore()
	} catch e {
		handleException(e)
	}
}

// Erase from AA results and rerun AA
hkNum6(){
	try{
		Click 1000,300									// click on center chart
		Send, {Numpad6}
		hkSwitchExplore()
	} catch e {
		handleException(e)
	}
}

// Move forward 1 min	
hkSimNext(){

	try{
		WinActivate, Bar Replay
		ControlClick, Button5, Bar Replay,, LEFT,1,NA
	}
	catch e {
		handleException(e)
	}
}

// Move back 1 min
hkSimPrev(){

	try{		
		WinActivate, Bar Replay
		ControlClick, Button2, Bar Replay,, LEFT,1,NA
	} 
	catch e {
		handleException(e)
	}
}


explore(){	
		// refesh exploration
		CoordMode, Mouse, Screen

		Click 1000,300									// click on center chart
		Sleep, 100
		Click 225, 115									// Click Explore
		Sleep, 250
		Click 175,185									// Click first result

		CoordMode, Mouse, Window 
}

// Move forward 5mins and refesh exploration
hkSim5(){
	try{		
		WinActivate, Bar Replay		

		ControlClick, Button5, Bar Replay,, LEFT,5,NA	// Forward 5 mins
		Sleep 2500										// Give time to read current chart
		
		explore()
		
	} catch e {
		handleException(e)
	}
}

hkSwitchExplore(){
	static state = 0									// Current Tab 
	
	try{		
		if( state == 0 ){								// FT to Momentum
			CoordMode, Mouse, Screen
			Click 300,85								// Select Momentum Tab
			CoordMode, Mouse, Window
			
			explore()
			state = 1
		}
		else{											// Momentum to FT			
			CoordMode, Mouse, Screen
			Click 175,85								// Select FT Tab
			CoordMode, Mouse, Window
			
			explore()
			state = 0
		}
	} catch e {
		handleException(e)
	}
}

eraseMW(){
	global NowWindowTitle
	
	ControlGet,  RowCount, List, Count, SysListView323, %NowWindowTitle%
	
	if( RowCount > 0 ){
		ControlSend, SysListView323, {Control Down}a{Control Up}, %NowWindowTitle%
		ControlSend, SysListView323, {Delete}, %NowWindowTitle%
	}
}

addScriptoMW( scrip ){
	global NowWindowTitle
	
	Control, ChooseString, NSE, ComboBox1, %NowWindowTitle%
	Control, ChooseString, %scrip%, ComboBox3, %NowWindowTitle%
	ControlSend, Edit3, {Enter}, %NowWindowTitle%
}

hkUpdateScrips(){	
	global ABActiveWatchListPath, RTDManPath
	
	try{
		ini      := RTDManPath . "\RTDMan.ini"
		rtdman   := RTDManPath . "\RTDManStartHighPriority.bat"

		RunWait, cscript.exe SaveAB.js,, hide

		eraseMW()		
		
		i := 0
		Loop, Read, %ABActiveWatchListPath%
		{		
			scrip := A_LoopReadLine	

			if( scrip != "NIFTY50" && scrip != "" ){
				i++
				rtdString := "nse_cm|" . scrip . "-EQ;" . scrip . ";LTP;LTT;Volume Traded Today;;"
				IniWrite, %rtdString%, %ini%, RTDMan, Scrip%i%
				
				addScriptoMW( scrip )
			}
		}
		// Erase rest from ini if they exist
		if( i > 0 ){
			Loop, 20
			{
				i++	
				IniDelete, %ini%, RTDMan, Scrip%i%
			}
		}

		RunWait, %rtdman%, %RTDManPath%

	} catch e {
		handleException(e)
	}
}

// --------------------------------

hkBackfill(){
	try{
		loadSettings()
		installEOD()
		DoSingleBackfill()
	} catch e {
		handleException(e)
	}
}

hkBackfillAll(){
	try{
		loadSettings()														// Reload settings
		installEOD()														// Update EOD Timer
		DoBackfill()	
	} catch e {
		handleException(e)
	}
}

// Control Ids change on layout selection, So instead click on hardcoded coordinates
// ControlClick, SysTreeView321, ahk_class AmiBrokerMainFrameClass,, LEFT,,NA		
hkWatchList(){
	try{		
		WinActivate, ahk_class AmiBrokerMainFrameClass		
		
		Click 1000,500														// click on chart to make sure floating window is in focus
		Click 75,395

	} catch e {
		handleException(e)
	}
}
hkSymbols(){
	try{
		WinActivate, ahk_class AmiBrokerMainFrameClass
		
		Click 1000,500														// click on chart to make sure floating window is in focus
		Click 75,605														// Select symbol		

		alias  := getScripFromAB()											// Select AB scrip in watchlist
		Send %alias%
	} catch e {
		handleException(e)
	}
}


openDrawProperties(){	
	Click 2																// Double click at mouse position
	Loop, 20{															// Try to hide window as soon as possible. WinWait seems to take too long
		Sleep 25
		try{															// Ignore Error and keep trying until it opens
			WinSet,Transparent, 1, Properties, Start Y:					// Line Properties
			WinSet,Transparent, 1, Text box properties, Start Y:		// text properties
		}
		catch e{
		}
		IfWinExist, Properties, Start Y:
			break
		IfWinExist, Text box properties, Start Y:
			break
	}	
		
	IfWinExist, Properties, Start Y:									// Line Properties window opened?
	{
		WinWait, Properties, Start Y:, 1
		WinSet,Transparent, 1, Properties, Start Y:
		return true
	}
	IfWinExist, Text box properties, Start Y:
	{
		WinWait, Text box properties, Start Y:, 1
		WinSet,Transparent, 1, Text box properties, Start Y:
		return true
	}

	return false
}

closeDrawProperties(){
	IfWinExist, Properties, Start Y:
		ControlSend, Edit2, {Enter}, Properties, Start Y:
	IfWinExist, Text box properties, Start Y:
		ControlSend, Edit2, {Enter}, Text box properties, Start Y:
	Click 1															// Select chart again for floating windows
}

/* Find Interval control, Id is dynamic - RichEdit20A*
   Map Interval value to Layer Name
*/
getIntervalLayerName(){
	
	Loop, 20{															// check if control exists, if found map value
		try{
			controlName := "RichEdit20A" . A_Index
			ControlGetText, interval, %controlName%, ahk_class AmiBrokerMainFrameClass

			if( interval == "3m" || interval == "15m" || interval == "75m" || interval == "78m" || interval == "D" || interval == "W" )
				return interval
			else if( interval == "5m" || interval == "1m" )
				return "3m"
			else
				continue		// Found Control can be Symbol dropdown or dropdowns from AA etc
		} catch e{				// Control does not exist
			continue
		}
	}
	return ""
}

/* AB - Set Layer Name = Interval
*/
hkSetLayer(){
	try{
		if( !openDrawProperties() )
			return
		
		interval := getIntervalLayerName()
		if( interval == "" )
			return
		
		IfWinExist, Properties, Start Y:
			Control, ChooseString, %interval%, ComboBox3, Properties, Start Y:
		IfWinExist, Text box properties, Start Y:
			Control, ChooseString, %interval%, ComboBox1, Text box properties, Start Y:
		closeDrawProperties()
	} catch e {
		handleException(e)
	}
}

hkDelStudies(){
	try{
		Click right
		//Send l		// When disabled, l select lock
		Send {Down 14}
		Send {Enter}
		Send {Space}
		Send {Esc}
	} catch e {
		handleException(e)
	}
}

hkFlatTrendLine(){															// Sets End price = Start price for trend line at current mouse position
	try{
		if( openDrawProperties() ){
			ControlGet, price, Line, 1, Edit1, Properties, Start Y:			// Copy Start Price into End Price and press enter
			ControlSetText, Edit2, %price%, Properties, Start Y:
			closeDrawProperties()
		}		
	}catch e {
		handleException(e)
	}
}


DoBackfill(){
	
	global NowWindowTitle, Mode, DoIndex
	
	IfWinExist, %NowWindowTitle%
	{			
		IfWinExist, Session Expired, E&xitNOW
		{
			MsgBox, NOW Locked.
			Exit
		}
		
		clearFiles()
		
		if( Mode == "DT" ){
			dtBackFill()		
		}
		else if( Mode == "VWAP" )  {			
			vwapBackFill()
		}	
		if( DoIndex == "VWAP" || DoIndex == "DT" ){
			indexBackFill()
		}		
		
		save()
	}
	else{
		MsgBox, NOW not found.
	}
}

/*
 Backfill currently selected scrip in AB
*/
DoSingleBackfill(){	
	global NowWindowTitle, Mode, DoIndex
	
	IfWinExist, %NowWindowTitle%
	{			
		IfWinExist, Session Expired, E&xitNOW
		{
			MsgBox, NOW Locked.
			Exit
		}
		
		clearFiles()
	
		alias  := getScripFromAB()					// AB scrip				
	
		if( Mode == "VWAP" && vwapBackFillSingle(alias)  ) {
			save()	
			return
		}
		else if( Mode == "DT" && dtBackFillSingle(alias)  ) {
			save()	
			return
		}
		else if( (DoIndex == "VWAP" || DoIndex == "DT") && indexBackFillSingle(alias) ){
			save()	
			return
		}
	}
	else{
		MsgBox, NOW not found.
	}
}

/* Is alias present in Backfill scrip list
*/ 
isValidScrip( alias ){
	return getVWAPScripIndex(alias) > 0 || getIndexScripIndex(alias) > 0
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
		catch exc {				// Control does not exist
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
			} catch exc{				// Control does not exist
				continue
			}
		}	
	}
	
	MsgBox, AB scrip not found in settings
	
	return ""
}

getExpectedDataRowCount(){
	global START_HOUR, START_MIN, END_HOUR, END_MIN

	hour 		  := A_Hour>END_HOUR ? END_HOUR : A_Hour
	min  		  := (A_Hour>END_HOUR || (A_Hour==END_HOUR && A_Min>END_MIN) ) ? END_MIN : A_Min
	ExpectedCount := (hour - START_HOUR)*60 + (min - START_MIN)								

	if( !isMarketClosed() && ExpectedCount > 1 )
		ExpectedCount := ExpectedCount-1									// Allow 1 less minute for border case - 
																			// Minute changes between data fetch and call to getExpectedDataRowCount() 
	return ExpectedCount
}

createFileDirectory( file_path ){											// Create File directory path if it does not exist
	
	SplitPath, file_path,, directory
	
	IfNotExist, %directory%
		FileCreateDir, %directory%
}

clearFiles(){
	global VWAPBackfillFileName, DTBackfillFileName
	
	IfExist, %DTBackfillFileName%											// Clear Out DT data
	{
		file := FileOpen(DTBackfillFileName, "w" )	  
		if IsObject(file){
			file.Write("")
			file.Close()
		}
	}	
	IfExist, %VWAPBackfillFileName%											// Clear Out VWAP data
	{
		file := FileOpen(VWAPBackfillFileName, "w" )	  
		if IsObject(file){
			file.Write("")
			file.Close()
		}
	}
}

save(){
	global BackfillExe, BackfillExePath
	RunWait, %BackfillExe%, %BackfillExePath%,hide 							// Do backfill by calling exe	
	if ErrorLevel
		MsgBox, Backfill failed, check logs.
}

PingNOW(){	
	global NowWindowTitle		
	
	IfWinExist, %NowWindowTitle%
	{		
		ControlClick, Button9, %NowWindowTitle%,, LEFT,,NA					// Just click on Button9  (  INT/Boardcast status Button ) 
	}																		// Button9 is common to both Now and Nest
}

installEOD(){
	global EODBackfillTriggerTime	
	
	targetTime  := StrSplit( EODBackfillTriggerTime, ":")
	timeLeft	:= (targetTime[1] - A_Hour)*60 + ( targetTime[2] - A_Min )	// Time left to Trigger EOD Backfill in mins

	if( timeLeft >= 0 ){
		SetTimer, EODBackfill, % (timeLeft * 60 * -1000 )					// -ve Period => Run only once
	}
	else{
		SetTimer, EODBackfill, Delete
	}
}

EODBackfill(){	
	
	MsgBox, 4,, Do EOD Backfill ?, 10										// 10 second Timeout
	IfMsgBox, No
		Return	
	
	loadSettings()
	DoBackfill( )
}

isMarketClosed(){	
	
	time := A_Hour . ":" . A_Min
	return 	! isTimeInMarketHours(time)
}

/*
	Checks if Time is within Market Hours
*/
isTimeInMarketHours( time ){
	global START_TIME, END_TIME	

	return time >= START_TIME &&  time <= END_TIME
}

// 05-11-2015
isDateToday( date ) {
	return (  date == (A_DD . "-" . A_MM . "-" . A_YYYY )   )
}

/*
	Converts from 12h hh:mm:ss to 24h HH:MM. Example "03:03:15 PM" to "15:03"	
*/
convert24HHMM( time ){

	timeSplit := StrSplit( time, ":") 
	secSplit  := StrSplit( timeSplit[3], " ") 
	
	if( secSplit[2] == "PM" && timeSplit[1] < 12 ){							// Add 12 to Hours if PM. But not for 12
		timeSplit[1] := timeSplit[1] + 12
	}
	
	return timeSplit[1] . ":" . timeSplit[2]
}

convert24HHMMSS( time ){

	timeSplit := StrSplit( time, ":") 
	secSplit  := StrSplit( timeSplit[3], " ") 
	
	if( secSplit[2] == "PM" && timeSplit[1] < 12 ){							// Add 12 to Hours if PM. But not for 12
		timeSplit[1] := timeSplit[1] + 12
	}
	
	return timeSplit[1] . ":" . timeSplit[2] . ":" . secSplit[1] 
}

convert12HHMMSS( time ){

	timeSplit := StrSplit( time, ":") 	
	
	if( timeSplit[1] >= 12 ){
		timeSplit[3] := timeSplit[3] . " PM"
	}
	else{
		timeSplit[3] := timeSplit[3] . " AM"
	}
	
	if( timeSplit[1] > 12 ){											   // Sub 12 from Hours if PM
		timeSplit[1] := timeSplit[1] - 12
		if(timeSplit[1] < 10)
			timeSplit[1] := "0" . timeSplit[1]
	}	
	
	return timeSplit[1] . ":" . timeSplit[2] . ":" . timeSplit[3]
}

/*
  VWAP for stocks in NOW has 09:14:XX as first row. Change it to 09:15
*/ 
isVWAPStartTimeFixNeeded( time ){
	global START_TIME_VWAP
	
	return (time == START_TIME_VWAP)
}

/*
	Input - HH:MM  (24hr)
*/
fixStartTime( time ){	
	if( isVWAPStartTimeFixNeeded( time ) ){
		timeSplit := StrSplit( time, ":") 
		time 	  := addMinute( timeSplit[1], timeSplit[2] )			
	}
	return time
}

/*
	Adds 1 to minute - used in VWAP to move first minute
	Returns time in HH:MM
*/
addMinute( HH, MM ){
	if( MM == 59 )
		return % (HH+1) . ":00"
	else
		return % HH . ":" . (MM+1)
}

subMinute( HH, MM ){
	if( MM == 00 ){
		HH := HH -1
		if( HH < 10 )
			HH := "0" . HH
		
		return % HH . ":59"
	}
	else{
		MM := MM -1
		if( MM < 10 )
			MM := "0" . MM
		
		return % HH . ":" . MM
	}
}
 

timer( mode ){
	static start := 0
	
	if( mode == "start" ) {
		start := A_TickCount
	}
	if( mode == "end" ) {
		return (A_TickCount - start )
	}
}

handleException(e){
	MsgBox % "Error in " . e.What . ", Location " . e.File . ":" . e.Line . " Message:" . e.Message . " Extra:" . e.Extra
}


#Include Settings.ahk
#Include DataTable.ahk
#Include Vwap.ahk
#include GUIControls/Now.ahk
#include GUIControls/Nest.ahk

#CommentFlag ;
#include Lib/__ExternalHeaderLib.ahk										; External Library to read Column Headers
