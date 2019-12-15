import configparser

class Settings:
    def __init__(self):
        self.loadSettings()

    def loadSettings( self ):
        config = configparser.ConfigParser()
        config.read('TradeLog.ini')

        self.InitialCapital     = config.getfloat('TradeLog', 'InitialCapital')
        self.RiskPerTrade       = config.getfloat('TradeLog', 'RiskPerTrade')
        self.EstimatedTax       = config.getfloat('TradeLog', 'EstimatedTax')
        self.TRADE_LOG          = "data/tradelog.csv"

        self.CN_SOURCE_PATH     = str(config.get('TradeLog', 'CN_SOURCE_PATH')).strip( "\"'" )
        self.CN_DEST_PATH       = config.get('TradeLog', 'CN_DEST_PATH').strip( '"\'' )

    def setTradeLog( self, filepath ):
        self.TRADE_LOG  =  filepath

s = Settings()
