/*
  Copyright (C) 2016  SpiffSpaceman

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

class UtilClass{
	
	checkNOWOpen(){
		global TITLE_NOW
		IfWinNotExist, %TITLE_NOW%
		{
			MsgBox, NOW not found.
			ExitApp
		}
	}
	
	roundToTickSize( price ){
		global TickSize	
		return Round(  price / TickSize ) * TickSize
	}
	
	ceilToTickSize( price ){
		global TickSize	
		return Ceil(  price / TickSize ) * TickSize
	}
	
	floorToTickSize( price ){
		global TickSize
		
		return Floor( Round( price/TickSize, 2) ) * TickSize				// Round to 2 decimal places before Floor to avoid inaccurate floor due to FP accuracy loss
	}																			// Without Rounding, FloorToTick( 209.45 ) with tick 0.05 returns 209.4

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
	
	timer( mode ){
		static start := 0

		if( mode == "start" ) {
			start := A_TickCount
		}
		if( mode == "end" ) {
			return (A_TickCount - start )
		}
	}
	
	handleException( e ){
		MsgBox % "Error in " . e.What . ", Location " . e.File . ":" . e.Line . " Message:" . e.Message . " Extra:" . e.Extra
	}
	
	getRiskPerTrade(){
		 global Capital, TradeRisk
		 return  Capital * TradeRisk/100	
	}
}