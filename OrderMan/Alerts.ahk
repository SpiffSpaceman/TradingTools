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

alertsTimer(){
	global alertsObj
	alertsObj.triggerAlerts()
}
onAlertDismiss(){
	global alertsObj
	alertsObj.onAlertDismiss()
}

/* This allows moving GUI without window controls
   On double click, dismiss alert
*/
uiMove(){
	PostMessage, 0xA1, 2,,, A 
	
	if( A_GuiEvent == "DoubleClick"  ){
		onAlertDismiss()
	}
	Return
}

class AlertsClass{

	class triggersClass{
		longTriggers	:=	""								// sorted based on direction. Lowest price first for long and vv
		shortTriggers	:=	""
		
		nextLong		:=  ""								// Lowest Long Price yet to trigger					
		nextShort		:=  ""
	}
	
	class triggeredAlertClass{
		scrip 		:= ""
		direction	:= ""
		price 		:= ""
		
		setAlert( scrip, direction, price ){
			this.scrip 		:= scrip
			this.direction	:= direction
			this.price		:= price
		}
	}
	
	ALERTS_CONFIG 	 := "config/alerts.ini"
	ALERTS_POLL_TIME := 2000

	_alerts		  	 := {}									// Long and short prices for alerts taken from settings
	_prices 	  	 := {}									// Current Prices read from RTDMan tick csv
	_inputFiles		 := ""									// List of RTDMan Tick Files
	
	_triggeredAlerts := {}									// stack to hold triggered alerts. Will be shown one by one
	_currentAlert	 := ""									// Currently Displayed alert that has not yet been dismissed
	

	init(){
		global AlertsEnabled, TickPath
		
		IniRead, TickPath, % this.ALERTS_CONFIG, OrderMan, TickPath

		if( AlertsEnabled ){
			this.loadTriggers()
			this.showGui()
		}

		SetTimer, alertsTimer, % this.ALERTS_POLL_TIME
	}

	showGui(){
		global AlertText
		
		Gui, 9:New, +AlwaysOnTop -Caption +ToolWindow +0x400000
		gui, 9:font, bold s15
		Gui, 9:Add, Text, w200 h27 Border Center GuiMove vAlertText, Waiting
		Gui, 9:Show, AutoSize NoActivate 		// X0 Y0
	}	
	
	addTriggeredAlert( alert ){
		if( this._currentAlert == "" || alert == ""){		// No alert Visible - show new alert. Else push to stack
			this._currentAlert := alert						// If input alert is empty, reset to Waiting
			this.updateAlert()
		}
		else{
			this._triggeredAlerts.push( alert )
		}
	}
	
	updateAlert(){
		if( this._currentAlert != "" ){
			Gui, 9:Color, red
			GuiControl, 9:Text, AlertText, % this._currentAlert.scrip . " - " . this._currentAlert.direction
		}
		else{
			Gui, 9:Color, Default
			GuiControl, 9:Text, AlertText, Waiting
		}
	}
		
	onAlertDismiss(){
		this._currentAlert := ""
		this.addTriggeredAlert( this._triggeredAlerts.pop()  )											// pop out next alert and set GUI
	}

	/*	Reads alerts.ini for long and short price alerts for each scrip in ScripList
	*/
	loadTriggers(){
		global ScripList, TickPath, test
		
		Loop, Parse, ScripList, |
		{
			scrip := A_LoopField
			IniRead, RTDManAlias, % this.ALERTS_CONFIG, OrderMan, % scrip . ".alias"
			
			this._alerts[scrip]			:= new this.triggersClass
			this._inputFiles 			:= this._inputFiles . " " . TickPath . RTDManAlias . ".csv"

			IniRead, LongTriggers,  % this.ALERTS_CONFIG, OrderMan, % scrip . ".LONG"
			if(	LongTriggers != "ERROR" ){
				Sort LongTriggers, N D,							//  Sort numerically in ascending order, use comma as delimiter
				this._alerts[scrip].longTriggers := LongTriggers
				this._alerts[scrip].nextLong 	 := this._getFirstCsvField( LongTriggers )
			}

			IniRead, ShortTriggers, % this.ALERTS_CONFIG, OrderMan, % scrip . ".SHORT"
			if(	ShortTriggers != "ERROR" ){
				Sort ShortTriggers, N R D,						//  Sort numerically in descending order, use comma as delimiter
				this._alerts[scrip].shortTriggers := ShortTriggers
				this._alerts[scrip].nextShort 	  := this._getFirstCsvField( ShortTriggers )
			}
		}
	}
	
	/*	Fetch latest quotes - then compare trigger with close price
		If price breaks and returns within loop period, there will be no trigger
		
		Once triggered, remove triggered price from config
	*/
	triggerAlerts(){
		global ScripList, AlertsEnabled
		
		this.fetchPrices()
		
		if( !AlertsEnabled ){
			return
		}

		Loop, Parse, ScripList, |
		{
			scrip := A_LoopField
			price := this._prices[scrip]
			
			scripConfig := this._alerts[scrip]
			long  := scripConfig.nextLong 
			short := scripConfig.nextShort
			
			if( price != "" && price != 0 && long != "" && price >= long ){								// Long Triggered - Add to Trigger List and remove from settings
			
				scripConfig.longTriggers := this._removeFromCsv(scripConfig.longTriggers, long )
				scripConfig.nextLong	 := this._getFirstCsvField(scripConfig.longTriggers)
				IniWrite, % scripConfig.longTriggers, % this.ALERTS_CONFIG, OrderMan, % scrip . ".LONG"
			
				triggeredAlert := new this.triggeredAlertClass
				triggeredAlert.setAlert( scrip, "LONG", long )
				this.addTriggeredAlert( triggeredAlert )
			}
				
			if( price != "" && price != 0 && short != "" && price <= short ){							// Short Triggered
			
				scripConfig.shortTriggers := this._removeFromCsv(scripConfig.shortTriggers, short )
				scripConfig.nextShort	  := this._getFirstCsvField(scripConfig.shortTriggers)
				IniWrite, % scripConfig.shortTriggers, % this.ALERTS_CONFIG, OrderMan, % scrip . ".SHORT"
			
				triggeredAlert := new this.triggeredAlertClass
				triggeredAlert.setAlert( scrip, "SHORT", short )
				this.addTriggeredAlert( triggeredAlert )
			}
		}
	}

	/*	Takes latest price from RTDMan exported tick csv for each scrip in ScripList
	*/
	fetchPrices(){
		global ScripList, TickPath

		lastTicksCsv := TickPath . "last_prices.csv"		

		Loop, Read, %lastTicksCsv% 
		{
			if( A_LoopReadLine != "" ){		
				fields 		   		:= StrSplit( A_LoopReadLine , ":")
				scrip				:= fields[1]
				this._prices[scrip] := fields[2]												// close price
			}
		}
	}

	_removeFromCsv( csvString, removeme ){
		output := ""
		Loop, parse, csvString, CSV
		{
			if( A_LoopField != removeme){
				output := (output != "" ) ? output . "," . A_LoopField : A_LoopField
			}
		}
		return output
	}
	
	_getFirstCsvField( csvString ){
		Loop, Parse, csvString, CSV
		{
			return A_LoopField
		}
	}
}
