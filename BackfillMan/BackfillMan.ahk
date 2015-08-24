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


// TODO - DataTable - Search columns for Trading symbol, remove TradingSymbolColIndex 
// TODO - 2 save calls triggered?
// TODO - Put Keepalive for NOW. Touch every 15mins or so. Seperate ahk - SetTimer 


// TODO - VWAP - HS needs extra columns for volume	- Just select correct columns - maybe can select in order?
// TODO - VWAP - loop test
// TODO - settings - Move to RAM drive in both, create files if not found
// NOW on top Errors
	// DT open using MW shift-D fails many times when NOW is in front
	// ** DT Scrip Not found error ** - AHK With HotKEY - Row not selected? - symbol from row is empty
		// Click on TabBar/ Marketwatch and run using Hotkey			
		// Maybe made worse by Shift-D problem above	
// TODO - VWAP - Better logic to check if vwap data has been fetched 
// 			   - Maybe do in ABBackfill - validate option and use exit code 
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
