#CommentFlag // 
#Include %A_ScriptDir%			// Set Include Directory path 
								// Includes behave as though the file's contents are present at this exact position
#SingleInstance force			// Reloads if already running
#NoEnv							// Recommended for new scripts

SendMode Input  				// Recommended for new scripts
SetWorkingDir %A_ScriptDir%  	// Ensures a consistent starting directory.
SetTitleMatchMode, 2 			// A window's title can contain the text anywhere
SetControlDelay, -1 			// Without this ControlClick fails sometimes. Example - Index Right click fails if mouse is over NOW

//!F1:: 							// Press Alt F1 to execute

// NOW on top Errors + HK problem
	// DT open using MW shift-D fails many times when NOW is in front - try menu - pd
	// ** DT Scrip Not found error ** - AHK With HotKEY - Row not selected? - symbol from row is empty
		// Click on TabBar/ Marketwatch and run using Hotkey			
		// Maybe made worse by Shift-D problem above
// Index - x,y may fail if index list has empty space


#Include Settings.ahk														// Load settings first

IfWinExist, %NowWindowTitle%
{	
	global Mode, DoIndex	
	
	IfWinExist, Session Expired, E&xitNOW
	{
		MsgBox, NOW Locked.
		Exit
	}
	
	clearFiles()
	
	if( Mode = "DT" ){
		dtBackFill()		
	}
	else if( Mode = "VWAP" )  {	
		vwapBackFill()
	}	
	if( DoIndex = "Y"){
		indexBackFill()
	}
	
	save()
}
else{
	MsgBox, NOW not found.
}
return


getExpectedDataRowCount(){
	hour 		  := A_Hour>15 ? 15 : A_Hour
	min  		  := A_Hour>15 ? 30 : A_Min
	ExpectedCount := (hour - 9)*60 + (min - 15) - 1 						// Allow 1 less minute than the expected count for border cases

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

#Include DataTable.ahk
#Include Vwap.ahk
#include Lib/__ExternalHeaderLib.ahk										// External Library to read Column Headers
