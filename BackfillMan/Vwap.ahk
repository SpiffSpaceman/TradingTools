// NOW - Hourly Stats Backfill

vwapBackFill()
{		
	global

	Loop, %VWAPCount% {
		
		local fields := StrSplit( VWAP%A_Index% , ",")  					// Format - HS parameters 1-6,Alias
			
		openVwap( fields[1], fields[2], fields[3], fields[4], fields[5], fields[6] )	
		writeVwapData( fields[7] )											// Write csv 	
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
	Control, ChooseString , %inParam2%, ComboBox2, %VWAPWindowTitle%		// Series
	Control, ChooseString , %inParam3%, ComboBox3, %VWAPWindowTitle%		// Symbol
	Control, Choose		  , %inParam4%, ComboBox4, %VWAPWindowTitle%		// Expiry Date - Set by Position
	Control, ChooseString , %inParam5%, ComboBox5, %VWAPWindowTitle%		// Opt Type
	Control, ChooseString , %inParam6%, ComboBox6, %VWAPWindowTitle%		// Strike Price	
	
	ControlSetText, Edit1, 1,       %VWAPWindowTitle%						// Set Interval as 1		
	ControlSend,    Edit1, {Enter}, %VWAPWindowTitle%						// Request Data		
}

// Columns Expected Order - Start time, O, H, L, C, V
writeVwapData( alias ){
	global VWAPWindowTitle, VWAPBackfillFileName, VWAPSleepTime, VWAPColumnIndex
	
	// Wait till all data is available
	// Just hope that sleep time is enough to fetch all data
	// When slow, NOW seems to fetch them in batches without necessarily a clear order. sort messes it up more
	// Better option - Can sort and try to verify that each minute from current time till 09:15 has been fetched 		
		
	Sleep, %VWAPSleepTime%
	
	if( VWAPColumnIndex == "" )
		getVWAPColumnIndex()
		
	ControlGet, vwapStats, List, , SysListView321, %VWAPWindowTitle%		// Copy Data into vwapStats
	WinClose, %VWAPWindowTitle%		 										// Close HS		
	
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
		File.WriteLine(  start . " " . open . " " . high . " " . low . " " . close . " " . vol   )
	}	
	
	file.Close()															// Flushes buffer
}
