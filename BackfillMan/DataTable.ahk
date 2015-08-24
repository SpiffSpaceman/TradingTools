// NOW - NestPlus DataTable Backfill

#include Lib/__ExternalHeaderLib.ahk										// External Library to read Column Headers

dtBackFill(){
	global																	// This Declares function global - all variables global except local ones	
																			// Need to use DT1, DT2 etc
	
	TradingSymbolColIndex := getColumnIndex( "Trading Symbol" )				// Get Position of Trading Symbol Column in Market Watch
	if( TradingSymbolColIndex == -1) { 
		MsgBox, Trading Symbol not found in Market Watch
		Exit
	}
	
	Loop, %DTCount% {
				
		local fields := StrSplit( DT%A_Index% , ",")  						// Format - TradingSymbol,Alias
				
		openDataTable( fields[1], 0 )		
		writeDTData( fields[2] )			
	}	
}

indexBackFill(){															// NOTE - This wont work if Index has scroll bars
	global

	Loop, %IndexCount% {
		
		local fields := StrSplit( Index%A_Index% , ",")  					// Format - IndexSymbol,Alias
			
		openIndexDataTable( fields[1] )			
		writeDTData( fields[2] )		
	}	
	
	closeNestPlusChart()													// Close Nest Plus chart when All done
}




// ------- Private --------

getColumnIndex( inColumnHeaderText ){										// Gets ListView Column Number for input Header text
	global NowWindowTitle
	
	MWHeaders := GetExternalHeaderText( NowWindowTitle, "SysHeader323")	

	for index, headertext in MWHeaders{
		if( headertext == inColumnHeaderText )
			return index
	}	
	
	return -1
}

openDataTable( inTradingSymbol, retryCount ){
	
	global NowWindowTitle, DTWindowTitle, TradingSymbolColIndex
	
	WinClose, %DTWindowTitle%	 											// Close DT If already Opened	
	ControlGet, RowCount, List, Count, SysListView323, %NowWindowTitle%		// No of rows in MarketWatch	
	ControlSend, SysListView323, {Home}, %NowWindowTitle%					// Start from top and search for scrip
				
	Loop, %RowCount%{														// Select row with our scrip		
		ControlGet, RowSymbol, List, Selected Col%TradingSymbolColIndex%, SysListView323, %NowWindowTitle%							
																			// Take Trading Symbol from column Number in %TradingSymbolColIndex%		
		if( RowSymbol = inTradingSymbol ){									// and compare it with input 
			 break
		}
		ControlSend, SysListView323, {Down}, %NowWindowTitle%				// Move Down to next row if not found yet
	}		
	if ( RowSymbol != inTradingSymbol ) {
		MsgBox, %inTradingSymbol% Not Found.
		Exit
	}	
		
	ControlSend, SysListView323, {Shift}D, %NowWindowTitle%				// At this point row should be selected. Open Data Table with shift-d	
		
	if( !waitforDTOpen( inTradingSymbol, retryCount, 20, 1 ) ) {		// Wait for DataTable to open and load
		openDataTable( inTradingSymbol, retryCount+1  )
	}
	waitForDTData( inTradingSymbol )	
	
	WinMinimize, %DTWindowTitle%											// Minimize after data is loaded ? check
}

waitforDTOpen( symbol, i, maxI, waitTime  ){								// returns true if Datatable is open
	global DTWindowTitle
	
	SetTitleMatchMode, RegEx
	WinWait, %DTWindowTitle%.*%symbol%,, %waitTime%							// Wait 1 second for Data Table to open - Look for DTWindowTitle and Scrip name
	SetTitleMatchMode, 2													// If not opened, we will call openDataTable again
		
	if ErrorLevel {															// Sometimes shortcut does not work with NOW focussed , try again
		checkPlusLoginPrompt()
		if( i >= maxI ){
			MsgBox, DataTable for %symbol% did not open.	
			Exit
		}		
		return false
	}	
	return true
}

waitForDTData( symbol  ){
	global DTWindowTitle
	
	Loop{																	// If No Data in DataTable, wait for it. 
		ControlSend, SysListView321, {Down 10}, %DTWindowTitle%				// Highlight a row and pick first column. Match against Trading symbol
		ControlSend, SysListView321, {HOME},    %DTWindowTitle%
		ControlGet,  data, List, Selected Col1, SysListView321, %DTWindowTitle%	
		
		if( data == symbol ){
			break															// Found
		}
		if( A_Index == 120  ){												// Wait upto a minute for data to load
			MsgBox, %symbol% DataTable is empty, Continuing ... 
			break			
		}
		if( A_Index > 10 ){
			WinRestore, %DTWindowTitle%										// sometimes data doesnt load if window is minimized ?
		}
		Sleep, 500
	}
}

openIndexDataTable( inIndexSymbol ){
	
	global  NowWindowTitle, DTWindowTitle		
	
	WinClose, %DTWindowTitle%	 											// Close DT If already Opened	
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
	ControlSend,  SysListView324, {P}, %NowWindowTitle%		 				// Open Chart	
		
	WinWait, %NowWindowTitle%, IntraDay Chart, 30							// Wait for Chart Control to load - Waiting for Text 'IntraDay Chart'	
	
	if( ErrorLevel ){ 														// Chart open timeout		
		MsgBox, Nest Plus Chart Open Timed Out.
		Exit	
	}			
	
	Loop{																	// Wait for DataTable to open and load
		WinClose, %DTWindowTitle%
		ControlClick, Static7, 		%NowWindowTitle%,, RIGHT,,NA			// Open Datatable 
		ControlSend,  Static7, {D}, %NowWindowTitle%	
	}
	Until waitforDTOpen( inIndexSymbol, A_Index, 4, 5 )						// Check every 5 seconds upto 4 times

	waitForDTData( inIndexSymbol )
	WinMinimize, %DTWindowTitle%
}

/* Click Works on NestChart close button But ControlClick does not work
	Also, No Control detected name for close button
	So just get XY coordinates, activate window, click and go back to original state
	There may be a better workaround using PostMessage
*/
closeNestPlusChart(){
	global NowWindowTitle, DTWindowTitle	
	
	ControlGetPos, X, Y, Width, Height, AfxControlBar1006, %NowWindowTitle%		
	ClickX  := X + 5
	ClickY  := Y + 15				
	
	CoordMode, Mouse, Screen												// Save Mouse position
	BlockInput, MouseMove	
    MouseGetPos, oldx, oldy
	
	SetTitleMatchMode, RegEx
	IfWinNotActive, .*%NowWindowTitle%.*|.*%DTWindowTitle%.*
	{
		WinGetTitle, currentWindow, A 										// Save active window	
		WinActivate, %NowWindowTitle%	
	}
	SetTitleMatchMode, 2
	
	CoordMode, Mouse, Relative												// click button	
	Click %ClickX%, %ClickY% 		
	Sleep, 50																// Wait for click to work.

	if( currentWindow != "" )
		WinActivate, %currentWindow%										// restore active window		
	
	CoordMode, Mouse, Screen												// restore mouse position
	MouseMove, %oldx%, %oldy%, 0	
	BlockInput, MouseMoveOff
	CoordMode, Mouse, Relative		
}

writeDTData( inAlias )														// columns expected order - TradingSymbol Time O H L C V
{
	global DTWindowTitle, DTBackfillFileName	
	
	ControlGet, data, List, , SysListView321, %DTWindowTitle%				// Copy Data
	WinClose, %DTWindowTitle%	 											// Close DT and Chart	
		
	IfExist, %DTBackfillFileName%
	{				
		file := FileOpen(DTBackfillFileName, "a" )	   			    		// := does not need %% for var
		if !IsObject(file){
			MsgBox, Can't open DT backfill file for writing.
			Exit
		}
		
		AliasText := "name=" . inAlias . "`n"
		file.Write(AliasText)												// Append AB Scrip Name		
		file.Write(data)							    					// Add Data
		file.Write("`n")							    					// Add newline		
		file.Close()		
	}
	else{
		MsgBox, DT backfill file Not Found.
		Exit
	}
}

checkPlusLoginPrompt(){
	IfWinExist, ,If you do not have a PLUS ID
	{ 
		MsgBox, NestPlus Login.
		Exit
	}	
}
