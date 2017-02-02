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
	
	isQuickMode := false
	Loop, %VWAPCount% {														// check for QuickMode, In QuickMode, only "NOW" scrips will be updated
		local fields := StrSplit( VWAP%A_Index% , ",")
		if( fields[8] == "NOW" && !isMarketClosed() ){						// if atleast one scrip found then enable Quick Mode - intraday only
			isQuickMode := True
			break
		}
	}

	Loop, %VWAPCount% {

		local fields := StrSplit( VWAP%A_Index% , ",")  					// Format - HS parameters 1-6,Alias

		if( isQuickMode && fields[8] != "NOW")
			continue
		else if( fields[8] == "EOD" && !isMarketClosed() )					// Skip EOD Scrips during the day
			continue

		openVwap( fields[1], fields[2], fields[3], fields[4], fields[5], fields[6] )
		if( !IsObject( VWAPColumnIndex ) ){
			getVWAPColumnIndex()											// Check Required columns
		}
		if( waitForDataLoad( fields[7] ) )									// Wait for All data to load
			writeVwapData( fields[7] )										// Write csv if data loaded
	}
}


// ------- Private --------

getVWAPColumnIndex(){														// Gets Position of Start time, O, H, L, C, V columns
	global VWAPWindowTitle, VWAPColumnIndex

	VWAPHeaders := GetExternalHeaderText( VWAPWindowTitle, "SysHeader321")

	VWAPColumnIndex := {}													// Creates object

	for index, headertext in VWAPHeaders{
		if( headertext == "Start Time" )
			VWAPColumnIndex.start := index
		if( headertext == "End Time" )
			VWAPColumnIndex.end := index
		else if( headertext == "Open Rate" )
			VWAPColumnIndex.open  := index
		else if( headertext == "High Rate" )
			VWAPColumnIndex.high  := index
		else if( headertext == "Low Rate" )
			VWAPColumnIndex.low   := index
		else if( headertext == "Close Rate" )
			VWAPColumnIndex.close := index
		else if( headertext == "Differential Vol" )
			VWAPColumnIndex.vol   := index
	}

	checkEmpty( VWAPColumnIndex.start, "Start Time"  )
	checkEmpty( VWAPColumnIndex.start, "End Time"  )
	checkEmpty( VWAPColumnIndex.open,  "Open Rate"  )
	checkEmpty( VWAPColumnIndex.high,  "High Rate"  )
	checkEmpty( VWAPColumnIndex.low,   "Low Rate"  )
	checkEmpty( VWAPColumnIndex.close, "Close Rate"  )
	checkEmpty( VWAPColumnIndex.vol,   "Differential Vol"  )
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
	global NowWindowTitle, VWAPWindowTitle

	WinMenuSelectItem, %NowWindowTitle%,, Market, Hourly Statistics			// Open HS using NOW Menu
	WinWait, %VWAPWindowTitle%,,10											// Wait for HS to open
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
		ControlGet, vwapTime, List, % "Col" . VWAPColumnIndex.start, SysListView321, %VWAPWindowTitle%				// Start Time Column only
		Sort, vwapTime, U 																							// Sort, Remove duplicates
		Loop, Parse, vwapTime, `n  																					// Get Number of rows
		{
			time := convert24HHMM( A_LoopField )
			if( isVWAPStartTimeFixNeeded( time ) )
				time := fixStartTime( time )

			if( isTimeInMarketHours( time ) )
				rowCount++
		}

		if( rowCount >= ExpectedCount ){									// All data loaded
			return true
		}

		if( Mod(A_Index, 15 )==0  ){										// Ask Every 15 seconds if all data has not yet been received and no change in missing count
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

		time := convert24HHMM( start )

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

