import os
import sys
import time

os.chdir(sys.path[0])                               # Set working dir

import pandas as pd

import database
from settings import s

# Log Fields -  Setup,isNested,Tags,Date,Time,Market,InitStop,PriceIn,Trail,T1,T2,Qty,T1Qty,T2Qty,ExpenseAmt,Mistakes,Comment,TrailTrigger,PriceInTrigger,StopTime,T1Time,T2Time
class MechTM:
    def __init__(self):
        file        = open( "config/tradelog.csv", 'r')
        self.trades = pd.read_csv(file)        
        file.close()
        
        self.SCRIPS = pd.unique( self.trades['Market'] )                                # All unique markets traded
    
    
    def markTargetHit( self, tradeIndex, targetPrice ):
        
        self.trades.loc[tradeIndex, 'T1']           = targetPrice
        self.trades.loc[tradeIndex, 'T1Qty']        = self.trades.loc[tradeIndex, 'Qty']
        
        self.trades.loc[tradeIndex, 'Trail']        = targetPrice                       # For only 1 part test - Set all to same price
        self.trades.loc[tradeIndex, 'TrailTrigger'] = targetPrice
                
        self.trades.loc[tradeIndex, 'T2']           = 0
        self.trades.loc[tradeIndex, 'T2Qty']        = 0
    
    # For MultiProc - modify copied slice - df.copy() and return + pd.concat([df1, df2, df3])
    # or some other data type
    def markStopHit( self, tradeIndex, stopPrice   ):
        
        self.trades.loc[tradeIndex, 'Trail']        = stopPrice
        self.trades.loc[tradeIndex, 'TrailTrigger'] = stopPrice
        
        self.trades.loc[tradeIndex, 'T1']       = 0
        self.trades.loc[tradeIndex, 'T1Qty']    = 0
        self.trades.loc[tradeIndex, 'T2']       = 0
        self.trades.loc[tradeIndex, 'T2Qty']    = 0

    def processScrip( self, scrip ):
        #pd.options.mode.chained_assignment = None                                       # Hide warning on sliced data update    
        
        try:
            bars = database.loadScripDB( scrip ) 
        except IOError:   
            print( scrip, " Not Found" )
            return None             
        
        t = self.trades
        scripTrades = t[ t['Market'] == scrip ]                                         # Trades taken in this scrip
        
        for trade in scripTrades.itertuples():

            entry   = trade.PriceIn 
            stop    = trade.InitStop
            isLong  = trade.PriceIn > trade.InitStop
            
            diff    = trade.PriceInTrigger - stop                                       # Projecting target from triggered price similar to Live.Else can use PriceIn to project from filled price (adjust to tick size)            
            target  = trade.PriceInTrigger + 1 * diff                                   
            
            barsAfterEntry = bars[trade.Date ].between_time( trade.Time, '1530' )       # Select Day's data After Entry bar using datetimeindex
                                                                                        # 5m bar is labeled on right. So 14:19 is 14:15-14:20 which should be good enough

            for bar in barsAfterEntry.itertuples():                                           # Iterate bar by bar after entry and look for exit            

                if ( isLong and bar.L <= stop) or ( not isLong and bar.H >= stop ):           # Stop hit ? 
                    self.markStopHit( trade.Index, stop )                    
                    break                
                elif  (isLong and bar.H > target) or ( not isLong and bar.L < target ):       # Target hit ? 
                    self.markTargetHit( trade.Index, target  )                    
                    break                
                elif bar.Index.hour == 15 and bar.Index.minute > 18 :                         # Exit before 15:20  
                    self.markStopHit( trade.Index, bar.C  )                    
                    break

    def processLog( self ):
        for scrip in self.SCRIPS:            
            self.processScrip( scrip )
        
        self.trades.to_csv( 'output/tradelogMech.csv' )                                        # Generate newlog
        
        filePath = sys.path[0] + "\output\\tradelogMech.csv"                                   # Run Tradelog.py over generated log
        os.system('python ../TradeLog/Tradelog.py ' + filePath   )

        
# Target distance setting
# TODO - atr based stops
# TODO - try mech - afternoon shorts
        

   
start = time.time()   

s.useStocksCurrentDB()
s.MULTIPROC = False
s.createDBIfNeeded()

if __name__ == '__main__':   
    mech = MechTM()
    mech.processLog()


print( '\nTime Taken:', time.time() - start )


    
    