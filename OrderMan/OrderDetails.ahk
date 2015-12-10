
/* 
	Order Details read from orderbook
*/
class OrderDetailsClass{
	orderType	 	:= ""
	buySell 	 	:= ""
	tradingSymbol   := ""
	totalQty 	    := ""
	pendingQty 	 	:= ""
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
		return this.status == ORDER_STATUS_COMPLETE
	}
}
