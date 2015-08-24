// NOW - Hourly Stats Backfill

vwapBackFill()
{		
	global

	Loop, %VWAPCount% {
		
		local fields := StrSplit( VWAP%A_Index% , ",")  						// Format - HS parameters 1-6,Alias
			
		openVwap( fields[1], fields[2], fields[3], fields[4], fields[5], fields[6] )	
		writeVwapData( fields[7] )												// Write csv 	
	}
}



// ------- Private --------

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
	global VWAPWindowTitle, VWAPBackfillFileName, VWAPSleepTime
	
	// Wait till all data is available
	// Just hope that sleep time is enough to fetch all data
	// When slow, NOW seems to fetch them in batches without necessarily a clear order. sort messes it up more
	// Better option - Can sort and try to verify that each minute from current time till 09:15 has been fetched 		
		
	Sleep, %VWAPSleepTime%
	
	ControlGet, vwapStats, List, , SysListView321, %VWAPWindowTitle%		// Copy Data into vwapStats
	WinClose, %VWAPWindowTitle%		 										// Close HS	
	
	IfExist, %VWAPBackfillFileName%
	{				
		file := FileOpen(VWAPBackfillFileName, "w" )	  				    // := does not need %% for var
		if !IsObject(file){
			MsgBox, Can't open VWAP file for writing.
			Exit
		}
		
		AliasText := "name=" . alias . "`n"
		file.Write(AliasText)												// Append AB Scrip Name		
		file.Write(vwapStats)												// Add Data
		file.Write("`n")							    					// Add newline
		file.Close()		
	}
	else{
		MsgBox, VWAP backfill file Not Found. 
		Exit
	}
}
