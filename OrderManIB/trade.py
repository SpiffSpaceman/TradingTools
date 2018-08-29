from ib             import InteractiveBrokers 
from ibapi.order    import Order 
from ibapi.contract import Contract, ContractDetails

from settings       import s

import util
import math

class Trade():
    def placeNewTrade(self, qty:int, entryPrice:float, stopPrice:float ) :
        
        self.qty        = qty
        self.entryPrice = entryPrice
        self.stopPrice  = stopPrice

        lotSize               = self.contract.lotSize
        self.adjustedQty      = (qty // lotSize) * lotSize                          # adjust to Lot size        

        self.direction        = "BUY" if entryPrice > stopPrice else "SELL"
        self.stopDirection    = "SELL" if self.direction == "BUY" else "BUY"

        self.initialStop      = stopPrice                                           # Save Initial Stop before updates
        self.initialDistance  = abs(entryPrice-stopPrice)
        self.maxSlippage      = self._getMaxSlippage()

        self._placeEntryOrder()
        self._placeStopOrder()
        self._placeTargetOrders( transmit=s.AUTO_TRANSMIT )                         # last child being sent - set transmit to True to activate all its predecessors (if auto-transmit enabled)
    
    
    ##########################################
    
    
    def __init__(self, ib:InteractiveBrokers, contract:Contract):        
        self.ib        = ib
        self.contract  = contract

        # Input        
        self.qty                = 0
        self.entryPrice         = None
        self.stopPrice          = None
        
        self.adjustedQty        = 0                                                 # Qty alighned with Lot size
        self.direction          = None
        self.stopDirection      = None
        self.initialStop        = None
        self.initialDistance    = None
        self.maxSlippage        = None

        # IB objects - saved for modifying orders
        self.entryOrder   = Order()
        self.stopOrder    = Order()
        self.targetOrder  = Order()
        
        self.entryOrder.orderId    =  None
        self.stopOrder.orderId     =  None
        self.targetOrder.orderId   =  None

    def _placeEntryOrder(self, transmit:bool=False  ):

        entry   = self.entryOrder
        trigger = self.entryPrice

        if entry.orderId is None:
            entry.orderId  = self.ib.nextOrderId()                                  # Custom field - not used by ib

        entry.action        = self.direction
        entry.orderType     = "STP LMT"
        entry.totalQuantity = self.adjustedQty
        entry.auxPrice      = trigger 
        entry.lmtPrice      = (trigger + self.maxSlippage) if self.direction == "BUY" else (trigger - self.maxSlippage)
        entry.transmit      = transmit

        self.ib.placeOrder(entry.orderId, self.contract, entry )

    # Call after setting entry order
    def _placeStopOrder(self, transmit:bool=False ):
        
        entry = self.entryOrder
        stop  = self.stopOrder

        if stop.orderId is None:
            stop.orderId  = self.ib.nextOrderId()
        
        stop.parentId       = entry.orderId
        stop.action         = self.stopDirection
        stop.orderType      = "STP"
        stop.totalQuantity  = entry.totalQuantity
        stop.auxPrice       = self.stopPrice
        stop.transmit       = transmit
        
        self.ib.placeOrder(stop.orderId, self.contract, stop)

    # Call after setting Entry and Stop orders
    # For new Trade, set transmit to false in Entry and Stop orders, to true in Trade order which is set up last
    def _placeTargetOrders(self, transmit:bool=False):
    
        entry     = self.entryOrder
        stop      = self.stopOrder
        target    = self.targetOrder

        pricediff = self.initialDistance
        totalSize = entry.totalQuantity
    
        if target.orderId is None:            
            target.orderId = self.ib.nextOrderId()

        target.parentId       = entry.orderId
        target.action         = stop.action
        target.orderType      = "LMT"
        target.totalQuantity  = totalSize
        target.lmtPrice       = (entry.auxPrice + pricediff) if entry.action == "BUY" else (entry.auxPrice - pricediff)        
        target.transmit       = transmit

        lotSize = self.contract.lotSize
        t1Size  = math.ceil( s.TARGET_SIZE_RATIO * totalSize / lotSize )  * lotSize
        t2Size  = t1Size
        
        if( t1Size + t2Size > totalSize  ):
            t2Size = totalSize - t1Size
        
        if( t2Size > 0 ):
            target.scaleInitLevelSize  = t1Size
            target.scaleSubsLevelSize  = t2Size
            target.scalePriceIncrement = pricediff                  # type: float   
        
        self.ib.placeOrder(target.orderId, self.contract, target)
    
    def _getMaxSlippage( self ):
        return util.ceilToTickSize( s.MAX_SLIPPAGE_RISK * self.initialDistance, self.contract.tickSize   ) 

    # TODO
    # IB seems to switch continous contract at start of expiry week and not on expiry day
    def _fetchFutureMonth(self):
        contract = Contract()
        
        '''
        contract.secType = "CONTFUT"
        #contract.lastTradeDateOrContractMonth="201812"     # CONTFUT can be used to get details of contract from which we can get month for order
        contract.symbol="SBIN"
        contract.exchange="NSE"
        '''
        
        contract.secType = "FUT"
        contract.lastTradeDateOrContractMonth="201805"
        contract.symbol="SBIN"
        contract.exchange="NSE"

        ## resolve the contract
        self.ib.reqContractDetails(213, contract)

    
    
    

    
    
    
    