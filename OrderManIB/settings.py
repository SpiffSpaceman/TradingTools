import configparser

class ContractDetails(object):
    def __init__(self, **kwargs):
        for key in kwargs:
            setattr(self, key, kwargs[key])

class Settings:    
    def __init__(self):
        self.loadSettings()
        
    def getContractDetails( self, contractSymbol ):
        return self.contracts[contractSymbol]

    def loadSettings( self ):
        config = configparser.ConfigParser()
        config.read('config/OrderManIB.ini')
        
        self.STOCKS_EXPIRY_MONTH = config.get('OrderManIB', 'STOCKS_EXPIRY_MONTH')
        self.MAX_SLIPPAGE_RISK   = config.getfloat('OrderManIB', 'MAX_SLIPPAGE_RISK')
        self.TARGET_SIZE_RATIO   = config.getfloat('OrderManIB', 'TARGET_SIZE_RATIO')
        self.AUTO_TRANSMIT       = config.getboolean('OrderManIB', 'AUTO_TRANSMIT')
        self.IB_PORT             = config.getint('OrderManIB', 'IB_PORT')
        self.CLIENT_ID           = config.getint('OrderManIB', 'CLIENT_ID')
        self.IO_PATH             = config.get('OrderManIB', 'IO_PATH')
        self.TIMER_PERIOD        = config.getfloat('OrderManIB', 'TIMER_PERIOD')

        self.InitialCapital     = config.getfloat('OrderManIB', 'InitialCapital')
        self.RiskPerTrade       = config.getfloat('OrderManIB', 'RiskPerTrade')
        self.EstimatedTax       = config.getfloat('OrderManIB', 'EstimatedTax')
        self.TRADE_LOG          =  "data/tradelog.csv"
        
        self.STOCK_TICK_SIZE   = 0.05               # TODO contract specific tick sizes https://interactivebrokers.github.io/tws-api/minimum_increment.html 

        self.contracts         = {}
        self._addStockFutures()
        
    def _addStockFutures( self ):
        with open('config/futures.txt', 'rU') as f:
            for line in f:                
                line = line.strip()
                if( line ):                         # Line not empty
                    fields     = line.split(",")
                    symbolName = fields[0]
                    minQty     = int(fields[1]) if len(fields)>=2 else 1
                    
                    self.contracts[symbolName] = ContractDetails( tickSize=self.STOCK_TICK_SIZE, lotSize=minQty, secType="FUT", exchange="NSE", expiry=self.STOCKS_EXPIRY_MONTH   )
        '''
        for key in self.contracts : 
            print( key, vars(self.contracts[key]) )
        '''
        
s = Settings()