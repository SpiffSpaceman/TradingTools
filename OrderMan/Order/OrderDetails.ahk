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


/* 
	Order Details read from orderbook
*/
class OrderDetailsClass{
	orderType	 	:= ""
	buySell 	 	:= ""
	tradingSymbol   := ""
	totalQty 	    := ""
	tradedQty 	 	:= ""
	price 		 	:= ""
	triggerPrice   	:= ""
	averagePrice   	:= ""
	status 		 	:= ""
	nowOrderNo 	 	:= ""
	nowUpdateTime 	:= ""
	rejectionReason := ""
	status2			:= ""
	
	isClosed(){																// Indicates whether order is in Order Book > Completed Orders
		return this.status2 == "C"
	}
	
	isOpen(){																// Indicates whether order is in Order Book > Open Orders
		return this.status2 == "O"
	}
	
	isComplete(){															// Indicates whether order status is "Complete"
		global
		return this.status == controlObj.ORDER_STATUS_COMPLETE
	}
}
