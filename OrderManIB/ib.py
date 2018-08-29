import threading
import queue
from typing    import Callable, Any, Dict

from ibapi          import wrapper
from ibapi.client   import EClient
from ibapi.utils    import iswrapper
from ibapi.common   import *

from ibapi.contract             import Contract, ContractDetails
from ibapi.order                import Order
from ibapi.order_state          import OrderState
from ibapi.execution            import Execution
from ibapi.commission_report    import CommissionReport

# client.reqOpenOrders();

class InteractiveBrokers(wrapper.EWrapper, EClient):
    def __init__(self, callback:Callable[[str, Dict], Any]  ):
        wrapper.EWrapper.__init__(self)
        EClient.__init__(self, wrapper=self)
        
        self.sendMessage = callback
        self.EVENT_IS_CONNECTED = threading.Event()                  # Events for main thread    

    @iswrapper
    def error(self, reqId:TickerId, errorCode:int, errorString:str):
        print("Error. Id: " , reqId, " Code: " , errorCode , " Msg: " , errorString)

    @iswrapper
    def nextValidId(self, orderId:int):
        super().nextValidId(orderId)        
        self.nextValidOrderId = orderId

        print('IB connected')
        self.EVENT_IS_CONNECTED.set()

    def nextOrderId(self):
        id = self.nextValidOrderId
        self.nextValidOrderId += 1
        return id
    
    # self.reqOpenOrders()
    # self.reqAutoOpenOrders(True)  -  only those applications connecting with client Id 0 will be able to take over manually submitted orders
    @iswrapper
    def openOrder(self, orderId: OrderId, contract: Contract, order: Order, orderState: OrderState):
         super().openOrder(orderId, contract, order, orderState)
         print("OpenOrder. ID:", orderId, contract.symbol, contract.secType, "@", contract.exchange, ":", order.action, order.orderType, order.totalQuantity, orderState.status )
         #print( "orderid", order.orderId )
    
    def openOrderEnd(self):
        super().openOrderEnd()
        print("OpenOrderEnd")
    
    # TODO
    @iswrapper
    def contractDetails(self, reqId:int, contractDetails:ContractDetails):
        super().contractDetails(reqId, contractDetails)        
        print(contractDetails.contractMonth)
        print(contractDetails.minTick)        
        print(contractDetails.summary)    
    
    # TODO
    @iswrapper
    def contractDetailsEnd(self, reqId:int):
        super().contractDetailsEnd(reqId)
        print("ContractDetailsEnd. ", reqId, "\n")    
        
        
    # ApiPending PendingSubmit PendingCancel    PreSubmitted Submitted   ApiCancelled Cancelled   Filled    Inactive 
    # Typically there are duplicate orderStatus messages with the same information that will be received by a client
    # There are not guaranteed to be orderStatus callbacks for every change in order status
        # For example with market orders when the order is accepted and executes immediately, there commonly will not be any corresponding orderStatus callbacks
        # For that reason it is recommended to monitor the IBApi.EWrapper.execDetails function in addition to IBApi.EWrapper.orderStatus    
    @iswrapper
    def orderStatus(self, orderId: OrderId, status: str, filled: float, 
                    remaining: float, avgFillPrice: float, permId: int, 
                    parentId: int, lastFillPrice: float, clientId: int,
                    whyHeld: str, mktCapPrice: float):
             
        super().orderStatus(orderId, status, filled, remaining, avgFillPrice, permId, parentId, lastFillPrice, clientId, whyHeld, mktCapPrice)

        print("OrderStatus. Id: ", orderId, ", Status: ", status, ", Filled: ", filled,
              ", Remaining: ", remaining, ", AvgFillPrice: ", avgFillPrice,
              ", PermId: ", permId, ", ParentId: ", parentId, ", LastFillPrice: ",
              lastFillPrice, ", ClientId: ", clientId, ", WhyHeld: ",
              whyHeld, ", MktCapPrice: ", mktCapPrice)
    
    # IBApi.Execution and IBApi.CommissionReport can be requested on demand via the IBApi.EClient.reqExecutions method 
        # which receives a IBApi.ExecutionFilter object as parameter to obtain only those executions matching the given criteria
        # An empty IBApi.ExecutionFilter object can be passed to obtain all previous executions
        # self.reqExecutions(10001, ExecutionFilter())
    @iswrapper
    def execDetails(self, reqId: int, contract: Contract, execution: Execution):
        super().execDetails(reqId, contract, execution)
        print("ExecDetails. ", reqId, contract.symbol, contract.secType, contract.currency,
                execution.execId, execution.orderId, execution.shares, execution.lastLiquidity)
    def execDetailsEnd(self, reqId: int):
        super().execDetailsEnd(reqId)
        print("ExecDetailsEnd. ", reqId)

    @iswrapper
    def commissionReport(self, commissionReport: CommissionReport):
        super().commissionReport(commissionReport)
        print("CommissionReport. ", commissionReport.execId, commissionReport.commission,
                commissionReport.currency, commissionReport.realizedPNL)
        
        
        
        
    