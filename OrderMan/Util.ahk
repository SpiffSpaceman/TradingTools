class UtilClass{
	
	checkNOWOpen(){
		global TITLE_NOW
		IfWinNotExist, %TITLE_NOW%
		{
			MsgBox, NOW not found.
			ExitApp
		}
	}
	
	/*
	roundToTickSize( price ){
		global TickSize	
		return Round(  price / TickSize ) * TickSize
	}
	*/
	
	ceilToTickSize( price ){
		global TickSize	
		return Ceil(  price / TickSize ) * TickSize
	}
	
	floorToTickSize( price ){
		global TickSize	
		return Floor(  price / TickSize ) * TickSize
	}

	isNumber( str ) {
		if str is number
			return true	
		return false
	}

	reverseDirection( direction ){
		return direction == "B" ? "S" : "B"
	}
	
	orderIdentifier( direction, price, trigger ){
		identifier := direction . ", Price " . price . ", Trigger " . trigger
		return identifier
	}
	
	/* Show Message only if isSilent = false
	*/
	conditionalMessage( isSilent, message ){
		if( !isSilent ) 
			MsgBox, 262144,, %message%
	}
	
	sendMsgToConsole( msg ){
		FileAppend  %msg%`n, *	
	}

}