#CommentFlag // 
#Include %A_ScriptDir%														// Set Include Directory path 
																			// Includes behave as though the file's contents are present at this exact position
#SingleInstance force														// Reloads if already running
#NoEnv																		// Recommended for new scripts

SendMode Input  															// Recommended for new scripts
SetWorkingDir %A_ScriptDir%  												// Ensures a consistent starting directory.
SetTitleMatchMode, 2 														// A window's title can contain the text anywhere
SetControlDelay, -1 														// Without this ControlClick fails sometimes. Example - Index Right click fails if mouse is over NOW

loadSettings()																// Load settings for Timer before hotkey install
SetTimer, PingNOW, %PingerPeriod% 											// Install Keep Alive Timer 
installEOD()																// Install Timer for EOD backfill once
#B:: 							 							 				// Press Win-B to execute

// TODO
// DT - Shift-D also causes separate d keystroke. So if Marketwatch has a scrip starting with D, it gets selected
	// check how to avoid it.  Datatable opens correctly though, so no bug.
// Index - x,y click may fail if index list has  multiple indices and big empty space 


loadSettings()																// Reload settings
installEOD()																// Update EOD Timer
DoBackfill( Mode, DoIndex )
return

DoBackfill( inMode, inDoIndex	){
	
	global NowWindowTitle
	
	IfWinExist, %NowWindowTitle%
	{			
		IfWinExist, Session Expired, E&xitNOW
		{
			MsgBox, NOW Locked.
			Exit
		}
		
		clearFiles()
		
		if( inMode = "DT" ){
			dtBackFill()		
		}
		else if( inMode = "VWAP" )  {	
			vwapBackFill()
		}	
		if( inDoIndex = "Y"){
			indexBackFill()
		}
		
		save()
	}
	else{
		MsgBox, NOW not found.
	}
}

getExpectedDataRowCount(){
	hour 		  := A_Hour>15 ? 15 : A_Hour
	min  		  := (A_Hour>15 || (A_Hour==15 && A_Min>30) ) ? 30 : A_Min
	ExpectedCount := (hour - 9)*60 + (min - 15) -1							// Allow 1 less minute for border case - 
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
		ControlClick, Button10, %NowWindowTitle%,, LEFT,,NA					// Just click on Button10  ( First INT status Button ) 
	}
}
installEOD(){
	global EODBackfillTriggerTime	
	
	targetTime  := StrSplit( EODBackfillTriggerTime, ":") 	
	timeLeft	:= (targetTime[1] - A_Hour)*60 + ( targetTime[2] - A_Min )	// Time left to Trigger EOD Backfill in mins
	
	if( timeLeft > 0 ){
		SetTimer, EODBackfill, % (timeLeft * 60 * -1000 )					// -ve Period => Run only once
	}
	else{
		SetTimer, EODBackfill, Delete
	}
}
EODBackfill(){
	MsgBox, 4,, Do EOD Backfill ?
	IfMsgBox Yes
	{
		eodMode :=  Mode == "DT" ? "DT" : "VWAP"
		DoBackfill( eodMode, "Y" )
	}		
}

#Include Settings.ahk
#Include DataTable.ahk
#Include Vwap.ahk

#CommentFlag ;
#include Lib/__ExternalHeaderLib.ahk										; External Library to read Column Headers
