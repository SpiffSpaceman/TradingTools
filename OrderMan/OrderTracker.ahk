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


/* Register Order Tracking Timer Function
*/
initializeStatusTracker(){
	global ORDERBOOK_POLL_TIME
	SetTimer, orderStatusTracker, % ORDERBOOK_POLL_TIME	
	toggleStatusTracker( "off" )
}

/* Turn order book tracking on/off
*/
toggleStatusTracker( on_off ){
	
	static isTimerActive := false
	
	if( on_off == "on" ){		
		isTimerActive := true
		SetTimer, orderStatusTracker, on
		
	}
	else if( on_off == "off"  ){
		isTimerActive := false
		SetTimer, orderStatusTracker, off
	}
	return isTimerActive
}

/*  Tracker thread that reads orders in orderbook using Timer and updates stuff on change
	Also creates pending order if Stop Entry order was triggered
*/
orderStatusTracker(){
	global contextObj
	
	trade := contextObj.getCurrentTrade()	
	
	Critical 														// Mark Timer thread Data fetch as Critical to avoid any possible Mixup with main thread 
																	// Marking it as critical should avoid Main thread from running
	trade.reload()													// Otherwise can get problem with entryOrder / stopOrder in unlink()
	trade.trackerCallback()
	Critical , off
	
	updateStatus()
}


 






 




