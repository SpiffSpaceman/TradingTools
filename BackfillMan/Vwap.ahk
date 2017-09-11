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

// NOW - Hourly Stats Backfill

vwapBackFill()
{
	global
	
	if( isMarketClosed() ){
		Loop, %VWAPCount% {
			local fields := StrSplit( VWAP%A_Index% , ",")  				// Format - HS parameters 1-6,Alias
			vwapBackFillSingle_( fields )
		}
	}
	else{
		vwapBackfillTDOnly()		
	}
}

vwapBackfillTDOnly(){
	global ABActiveWatchListPath

	try{
		
		RunWait, cscript.exe SaveAB.js,, hide
		
		Loop, Read, %ABActiveWatchListPath%
		{		
			scrip := A_LoopReadLine	

			if( scrip != "NIFTY50" && scrip != "" ){
				vwapBackFillSingle( scrip )
			}
		}
	} catch e {
		handleException(e)
	}	
	
}

vwapBackFillSingle( alias ){
	
	local vindex, fields
	
	vindex := getVWAPScripIndex(alias)										// Index in VWAP
	
	if( vindex > 0  ){
		fields := StrSplit( VWAP%vindex% , ",")	
		vwapBackFillSingle_( fields )
		return true
	}
	return false
}

vwapBackFillSingle_( fields ){
	global
	
	openVwap( fields[1], fields[2], fields[3], fields[4], fields[5], fields[6] )
	if( !IsObject( VWAPColumnIndex ) ){
		getVWAPColumnIndex()											// Check Required columns
	}
	if( waitForDataLoad( fields[7] ) )									// Wait for All data to load
		writeVwapData( fields[7] )										// Write csv if data loaded
}

/* Load Index VWAP data (Nest)
*/
indexVwapBackFillSingle_( fields ){
	global VWAPColumnIndex

	openVwapIndex( fields[1])
	
	if( !IsObject( VWAPColumnIndex ) ){
		getVWAPColumnIndex()											// Check Required columns
	}
	
	if( waitForDataLoad( fields[2] ) )									// Wait for All data to load
		writeVwapData( fields[2] )										// Write csv if data loaded
}

getVWAPScripIndex( alias ){
	global 
	
	Loop, %VWAPCount% {
		local fields := StrSplit( VWAP%A_Index% , ",")  					// Format - HS parameters 1-6,Alias
		if( fields[7] == alias)			
			return %A_Index%
	}
	
	return -1
}

// ------- Private --------

getVWAPColumnIndex(){														// Gets Position of Start time, O, H, L, C, V columns
	global controlObj, VWAPWindowTitle, VWAPColumnIndex

	VWAPHeaders := GetExternalHeaderText( VWAPWindowTitle, controlObj.VWAP_LIST )

	VWAPColumnIndex := {}													// Creates object

	for index, headertext in VWAPHeaders{
		if( headertext == controlObj.VWAP_HEADER_START_TIME )
			VWAPColumnIndex.start := index
		if( headertext == controlObj.VWAP_HEADER_END_TIME )
			VWAPColumnIndex.end := index
		else if( headertext == controlObj.VWAP_HEADER_OPEN  )
			VWAPColumnIndex.open  := index
		else if( headertext == controlObj.VWAP_HEADER_HIGH  )
			VWAPColumnIndex.high  := index
		else if( headertext == controlObj.VWAP_HEADER_LOW )
			VWAPColumnIndex.low   := index
		else if( headertext == controlObj.VWAP_HEADER_CLOSE  )
			VWAPColumnIndex.close := index
		else if( headertext == controlObj.VWAP_HEADER_DIFF_VOL )
			VWAPColumnIndex.vol   := index
	}

	if( controlObj.VWAP_HEADER_START_TIME == "" ){
		VWAPColumnIndex.start := -1 										// Use end time if start time not available
	}
	else
		checkEmpty( VWAPColumnIndex.start, controlObj.VWAP_HEADER_START_TIME )
	
	checkEmpty( VWAPColumnIndex.end,   controlObj.VWAP_HEADER_END_TIME  )
	checkEmpty( VWAPColumnIndex.open,  controlObj.VWAP_HEADER_OPEN   )
	checkEmpty( VWAPColumnIndex.high,  controlObj.VWAP_HEADER_HIGH )
	checkEmpty( VWAPColumnIndex.low,   controlObj.VWAP_HEADER_LOW  )
	checkEmpty( VWAPColumnIndex.close, controlObj.VWAP_HEADER_CLOSE  )
	checkEmpty( VWAPColumnIndex.vol,   controlObj.VWAP_HEADER_DIFF_VOL  )
}

checkEmpty( value, field ){
	global VWAPWindowTitle

	if( value == "" ){
		MsgBox, Column %field% not found in VWAP Window
		WinClose, %VWAPWindowTitle%
		Exit
	}
}

openVwap( inParam1,inParam2,inParam3,inParam4,inParam5,inParam6 ){
	global controlObj, NowWindowTitle, VWAPWindowTitle
	
	menus := StrSplit( controlObj.VWAP_MENU , ",")	
	WinMenuSelectItem, %NowWindowTitle%,, % menus[1], % menus[2]			// Open HS using NOW Menu
	
	WinWait, %VWAPWindowTitle%,,10											// Wait for HS to open
	
	if ErrorLevel
	{
		MsgBox, Failed to open VWAP stats
		return
	}
	
	WinMinimize, %VWAPWindowTitle%

	Control, ChooseString , %inParam1%, ComboBox1, %VWAPWindowTitle%		// Set Params - Exchg-Seg	
	
	Loop {																	// Error Prone, Try few times
		try{
			Control, ChooseString , %inParam2%, ComboBox2, %VWAPWindowTitle%
		}
		catch exc {
			Sleep, 250
		}
		
		if( !ErrorLevel  ){
			break
		}
		if(  A_Index >=10 ){
			Control, ChooseString , %inParam2%, ComboBox2, %VWAPWindowTitle%		// Last attempt without catch
		}
	}
	
	
	Control, ChooseString , %inParam3%, ComboBox3, %VWAPWindowTitle%		// Symbol
	

	if( inParam4 != "" )
		Control, Choose		  , %inParam4%, ComboBox4, %VWAPWindowTitle%	// Expiry Date - Set by Position
	if( inParam5 != "" )
		Control, ChooseString , %inParam5%, ComboBox5, %VWAPWindowTitle%	// Opt Type
	if( inParam6 != "" )
		Control, ChooseString , %inParam6%, ComboBox6, %VWAPWindowTitle%	// Strike Price

	ControlSetText, Edit1, 1,       %VWAPWindowTitle%						// Set Interval as 1
	ControlSend,    Edit1, {Enter}, %VWAPWindowTitle%						// Request Data
}

/* Index Dialog must be docked, Headers should not be visible and height should be adjusted to best fit data
*/
openVwapIndex( inIndexSymbol ){
	global  controlObj, NowWindowTitle, VWAPWindowTitle
	RowSymbol := ""

	WinClose, %VWAPWindowTitle%	 											// Close VWAP If already Opened
	ControlGet,  RowCount, List, Count, SysListView324, %NowWindowTitle%	// No of rows in Index Dialog
	ControlSend, SysListView324, {HOME}, %NowWindowTitle%					// Start from top and search for Index

	Loop, %RowCount%{
		ControlGet, RowSymbol, List, Selected Col1, SysListView324, %NowWindowTitle%
		if( RowSymbol = inIndexSymbol ){									// Assuming 1st column has Index names, compare with input
			RowNumber = %A_Index%
			break
		}
		ControlSend, SysListView324, {Down}, %NowWindowTitle%				// Move Down to next row if not found yet
	}

	if ( RowSymbol != inIndexSymbol ) {
		MsgBox, %inIndexSymbol% Not Found.
		Exit
	}

	ControlGetPos, IndexX, IndexY, IndexWidth, IndexHeight, SysListView324, %NowWindowTitle%
	RowSize := IndexHeight/RowCount											// Get Position of Index Row
	ClickX  := IndexX + IndexWidth/2										// Middle of Index box
	ClickY  := IndexY + RowNumber*RowSize - RowSize/2						// Somewhere within the Row

	ControlClick, X%ClickX% Y%ClickY%, %NowWindowTitle%,, RIGHT,,NA			// Right Click on Index Row
	ControlSend,  SysListView324, {v}, %NowWindowTitle%		 				// Open VWAP stats	
		
	WinWait, %VWAPWindowTitle%,,10											// Wait for HS to open
	
	WinMinimize, %VWAPWindowTitle%
	Sleep 3000																// Allow default load of 5min. Precaution to avoid possible mixing of data

	if ErrorLevel
	{
		MsgBox, Failed to open VWAP stats for index %inIndexSymbol%
		return
	}

	ControlSetText, Edit1, 1,       %VWAPWindowTitle%						// Set Interval as 1
	ControlSend,    Edit1, {Enter}, %VWAPWindowTitle%						// Request Data
}

waitForDataLoad( alias ){													// Wait for all data to load. Verifies that all data from now till 09:15 has been loaded
																			// NOTE - If VWAP window is closed before all data is loaded, sometimes remaining data
	global VWAPWindowTitle, VWAPColumnIndex									//     gets spilled	to Next Scrip's VWAP data in NOW

	ExpectedCount := getExpectedDataRowCount()

	Loop, 10 {																// Initial Simple Wait without checking for contents. Wait Max 5 seconds
		ControlGet, rowCount, List, Count, SysListView321, %VWAPWindowTitle%
		if( rowCount >= ExpectedCount )
			break
		Sleep 500
	}

	oldMissingCount := ExpectedCount

	Loop {																	// Count matched, but there can be duplicates in VWAP stats
		rowCount := 0														// So confirm after removing duplicates. And Count Only quotes within market hours
		
		if( VWAPColumnIndex.start != -1 )
			ControlGet, vwapTime, List, % "Col" . VWAPColumnIndex.start, SysListView321, %VWAPWindowTitle%			// Start Time Column only
		else
			ControlGet, vwapTime, List, % "Col" . VWAPColumnIndex.end, SysListView321, %VWAPWindowTitle%			// Use end time if no start time column
		
		Sort, vwapTime, U 																							// Sort, Remove duplicates
		Loop, Parse, vwapTime, `n  																					// Get Number of rows
		{	
			time := convert24HHMM( A_LoopField	 )
			
			if( VWAPColumnIndex.start == -1 ){								// Convert end time to start time
				timeSplit := StrSplit( time, ":") 
				time 	  := subMinute(  timeSplit[1], timeSplit[2] )
			}
			
			if( isVWAPStartTimeFixNeeded( time ) )
				time := fixStartTime( time )

			if( isTimeInMarketHours( time ) )
				rowCount++
		}

		if( rowCount >= ExpectedCount ){									// All data loaded
			return true
		}

		if( Mod(A_Index, 30 )==0  ){										// Ask Every 30 seconds if all data has not yet been received and no change in missing count
			missingCount := ExpectedCount - rowCount

			if( oldMissingCount == missingCount ){
				MsgBox, 4, %alias% - Waiting, VWAP data for %alias% has %missingCount% minutes missing. Is Data still loading?
				IfMsgBox No
				{
					MsgBox, 4,  %alias% - Waiting, Do you still want to Backfill %alias% with this data ?
					IfMsgBox yes
						return true
					Else
						return false
				}
			}
			else
				oldMissingCount := missingCount
		}
		Sleep 1000
	}

	return false
}

// Columns Expected Order - Start time, O, H, L, C, V
writeVwapData( alias ){
	global VWAPWindowTitle, VWAPBackfillFileName, VWAPSleepTime, VWAPColumnIndex, START_TIME, START_HOUR

	ControlGet, vwapStats, List, , SysListView321, %VWAPWindowTitle%		// Copy Data into vwapStats
	WinClose, %VWAPWindowTitle%		 										// Close HS

	createFileDirectory( VWAPBackfillFileName )

	file := FileOpen(VWAPBackfillFileName, "a" )
	if( !IsObject(file) ){
		MsgBox, Can't open VWAP file for writing.
		Exit
	}

	AliasText := "name=" . alias
	file.WriteLine(AliasText)												// Append AB Scrip Name

	Loop, Parse, vwapStats, `n  											// Extract our columns from table
	{																		// Rows are delimited by linefeeds (`n)
		Loop, Parse, A_LoopField, %A_Tab%  									// Fields (columns) in each row are delimited by tabs (A_Tab)
		{
			if( A_Index ==  VWAPColumnIndex.start )
				start = %A_LoopField%
			if( A_Index ==  VWAPColumnIndex.end )
				end	  = %A_LoopField%
			if( A_Index ==  VWAPColumnIndex.open )
				open  = %A_LoopField%
			if( A_Index ==  VWAPColumnIndex.high )
				high  = %A_LoopField%
			if( A_Index ==  VWAPColumnIndex.low )
				low   = %A_LoopField%
			if( A_Index ==  VWAPColumnIndex.close )
				close = %A_LoopField%
			if( A_Index ==  VWAPColumnIndex.vol )
				vol   = %A_LoopField%
		}
		
		if( VWAPColumnIndex.start == -1  ){									// Convert end time to start time
			
			time 	  := convert24HHMMSS( end )								// Should work for both 24H and 12H inputs
			timeSplit := StrSplit( time, ":") 
			time 	  := subMinute(  timeSplit[1], timeSplit[2] )
			
			start	  := time . ":" . timeSplit[3] 			
			start 	  := convert12HHMMSS( start )
		}
		else{
			time := convert24HHMM( start )
		}
		

		if( isVWAPStartTimeFixNeeded( time ) ){		 						// Workaround fix - 1st Bar for Stocks is from 09:14:XX to 09:15:XX
																			// Set this bar's time as 09:15:00
			timeSplit := StrSplit( start, ":")
			if(  START_HOUR >= 12  )
				start := timeSplit[1] . ":" . ( timeSplit[2] + 1 )  . ":00 PM"
			else
				start := timeSplit[1] . ":" . ( timeSplit[2] + 1 )  . ":00 AM"
		}

		File.WriteLine(  start . " " . open . " " . high . " " . low . " " . close . " " . vol   )
	}

	file.Close()															// Flushes buffer
}

