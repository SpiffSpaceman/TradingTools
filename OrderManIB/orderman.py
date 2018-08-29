import threading
import queue
from   typing       import Dict, Any

from ibapi.contract import Contract
from ib             import InteractiveBrokers 

import trade
import tradelog
import server
from   settings     import s
import gui

orderman = None

def startAll():
    global orderman
    orderman = OrderMan()
    orderman.start()
    
def sendMessage( command:str, input:Dict[str, Any]  ):              # Called by IB or Server thread
    global orderman
    orderman.messageQ.put(  (command, input)   )
    

'''
Server Thread    - Wait for input and send message to OrderMan Thread on input
IB Thread        - Used for IB callbacks. Sends Message to OrderMan Thread on callbacks
OrderMan Thread  - Wait for message for Input or from IB callback
GUI              - GUI Event loop Thread
'''
class OrderMan():
    def __init__(self):
        self.trades   = {}
        self.messageQ = queue.Queue()

    def start( self ):
        self.loadTradeLog()
        #self.connectToIB()
        self.startInputServer()
        
        thread = threading.Thread(target = self.waitForMessage)     # Waits for messages from Input Server or from ib
        thread.start()
        
        self.startGUI()                                             # Final GUI thread

    def loadTradeLog( self ):
        self.tradelog = tradelog.TradeLog()
        self.capital  = self.tradelog.getCurrentCapital()
        print( 'Current Capital', self.capital )
    
    def connectToIB( self ):
        self.ib = InteractiveBrokers( sendMessage )
        self.ib.connect("127.0.0.1", s.IB_PORT, clientId=s.CLIENT_ID)       
        
        thread = threading.Thread(target = self.ib.run)             # Start IB thread
        thread.start()        
        
        self.ib.EVENT_IS_CONNECTED.wait()                           # Wait for IB to respond with nextValidId
    
    def startInputServer( self ):
        self.inputServer = server.Server( sendMessage )
    
        thread = threading.Thread(target = self.inputServer.waitForInput )
        thread.start()   
        
    def startGUI( self ) : 
        self.gui = gui.GUI()
        self.gui.start()
        
        
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
    # Message = Tuple of 1) command String = key in dictionary that maps to a function in COMMANDS and  2) function inputs sent as dict
    def waitForMessage(self):
        
        # Maps input command strings to functions
        COMMANDS = { "CREATE"     : self.newTrade, 
                     "pickPrices" : self.pickPrices
                   }                     

        while True:
            message = self.messageQ.get()
            
            fn = COMMANDS[ message[0] ]
            fn( ** message[1] )                                     # ** unpacks dictionary and maps directly to function paramters. Names and types must match
            
            self.messageQ.task_done()
    
    def pickPrices( self, contractSymbol:str, entryPrice:float, stopPrice:float, targetPrice:float  ):
        self.gui.pickPrices( contractSymbol, entryPrice, stopPrice, targetPrice )
    
    def newTrade(self, contractSymbol:str, entryPrice:float, stopPrice:float ):
        
        # TEMP
        contractSymbol="EURUSD"
        contract = Contract()
        contract.symbol = "EUR"
        contract.secType = "CASH"
        contract.currency = "GBP"
        contract.exchange = "IDEALPRO"
        contract.tickSize = 0.00005
        contract.lotSize  = 20000
        # TEMP
        
        #if( self.trades[contractSymbol]  )
        
        '''                
        contractDetails = s.getContractDetails( contractSymbol )

        contract = Contract()
        
        contract.exchange = contractDetails.exchange
        contract.secType  = contractDetails.secType
        contract.symbol   = contractSymbol
        contract.lastTradeDateOrContractMonth = contractDetails.expiry
        contract.tickSize = contractDetails.tickSize                # Custom field
        contract.lotSize  = contractDetails.lotSize                 # Custom field
        '''

        diff = abs(entryPrice-stopPrice) 
        qty  = self.capital * s.RiskPerTrade / diff 

        t = trade.Trade( self.ib, contract )
        t.placeNewTrade( qty, entryPrice, stopPrice  )
        
        self.trades[contractSymbol] = t 

