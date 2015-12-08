class UtilClass{
	
	checkNOWOpen(){
		global TITLE_NOW
		IfWinNotExist, %TITLE_NOW%
		{
			MsgBox, NOW not found.
			ExitApp
		}
	}

	isNumber( str ) {
		if str is number
			return true	
		return false
	}

	roundToTickSize( price ){	// Ceil / Floor
		global TickSize	
		return Round(  price / TickSize ) * TickSize
	}
	
	reverseDirection( direction ){
		return direction == "B" ? "S" : "B"
	}
	
	orderIdentifier( direction, price, trigger ){
		identifier := direction . ", Price " . price . ", Trigger " . trigger
		return identifier
	}

}