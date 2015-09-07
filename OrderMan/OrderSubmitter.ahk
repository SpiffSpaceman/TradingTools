
limitOrder( direction, scrip, entry, stop ){
	global NowWindowTitle
		
	winTitle := openOrderForm( direction )									// Entry	
	SubmitOrder( winTitle, scrip, entry )	
		
	stopDirection :=  direction == "B" ? "S" : "B"							// Submit Stop Immediately Once order is open
	winTitle := openOrderForm( stopDirection  )
	SubmitOrder( winTitle, scrip, stop )
}


// --  Private -- 


openOrderForm( direction ){
	global NowWindowTitle
	
	if( direction == "B" ){
		winTitle := "Buy Order Entry"		
		ControlSend, SysListView323, {F1}, %NowWindowTitle%
	}
	else if( direction == "S" ){
		winTitle := "Sell Order Entry"
		ControlSend, SysListView323, {F2}, %NowWindowTitle%	
	}		
	WinWait, %winTitle%,,5
	
	return winTitle
}

SubmitOrder( winTitle, scrip, order ){										// Fill up opened Buy/Sell window and verify

	Control, ChooseString , % scrip.segment,     ComboBox1,  %winTitle%		// Exchange Segment - NFO/NSE etc
	Control, ChooseString , % scrip.instrument,  ComboBox5,  %winTitle%		// Inst Name - FUTIDX / EQ  etc
	Control, ChooseString , % scrip.symbol, 	 ComboBox6,  %winTitle%		// Scrip Symbol
	Control, ChooseString , % scrip.type,  	   	 ComboBox7,  %winTitle%		// Type - XX/PE/CE
	Control, ChooseString , % scrip.strikePrice, ComboBox8,  %winTitle%		// Strike Price for options
	Control, Choose		  , % scrip.expiryIndex, ComboBox9,  %winTitle%		// Expiry Date - Set by Position Index (1/2 etc)

	Control, ChooseString , % order.orderType,   ComboBox3,  %winTitle%		// Order Type - LIMIT/MARKET/SL/SL-M
	Control, ChooseString , % order.prodType,    ComboBox10, %winTitle%		// Prod Type - MIS/NRML/CNC
	Control, ChooseString , DAY, 			   	 ComboBox11, %winTitle%		// Validity - Day/IOC
	
	ControlSetText, Edit3, % order.qty,     %winTitle%						// Qty
	ControlSetText, Edit4, % order.price,   %winTitle%						// Price
	ControlSetText, Edit7, % order.trigger, %winTitle%						// Trigger	
	
	//ControlSend,, {Enter}, %winTitle%										// Submit Order
	
	WinWaitClose, %winTitle%, 1												// Wait for order window to close. If password needed, notify
	IfWinExist, Transaction Password	
		MsgBox, Enter Transaction password in NOW and then click ok
}