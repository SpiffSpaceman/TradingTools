import pandas as pd
import numpy as np
import os
import matplotlib.pyplot as plt
import math
import sys
os.chdir(sys.path[0])                                                           # Set working dir

from settings  import s

class TradeLog():
    def __init__(self, INPUT_FILE=""):
        self.trades      = 0                                                    # Input csv + caluclated columns
        self.stats       = {}                                                   # Stats derived from t
        
        self.openTrades   = 0
        self.isOpenTrades = False

        self.CSV_HEADER  = str("Setup,isNested,Tags,Date,Time,Market,InitStop,PriceIn,Trail,T1,T2,Qty,T1Qty,T2Qty,ExpenseAmt,Mistakes,Comment,TrailTrigger,PriceInTrigger,StopTime,T1Time,T2Time")
        
        if( INPUT_FILE ):
            s.setTradeLog( INPUT_FILE )        

        if not os.path.isfile(s.TRADE_LOG):                                     # create initial csv if not found
            file = open(s.TRADE_LOG, 'w+')
            file.write(self.CSV_HEADER + "\n")
            file.close()

    def getCurrentCapital(self, T1_QTY=0, T2_QTY=0) -> float:    
        file        = open(s.TRADE_LOG, 'r')
        self.trades = pd.read_csv(file)
        file.close()
        
        self.trades      = self.trades[ self.trades['PriceIn'] > 0 ]            # Only consider rows with price-in set
        t                = self.trades
        
        t['Direction']   = np.where( t['PriceIn'] > t['InitStop'], 1, -1 )

        if( T1_QTY or T2_QTY ):                                                 # Override Qty to check result with different Target sizes
            t['T1Qty']   = T1_QTY * t['Qty']
            t['T2Qty']   = T2_QTY * t['Qty']
        
        t['TrailQty']    = t['Qty'] - t['T1Qty'] - t['T2Qty']

        t['PriceOut']    = (t['T1'] * t['T1Qty'] + t['T2']* t['T2Qty'] + t['Trail'] * t['TrailQty']) / t['Qty']
        
        t['BuyAmt']      = np.where( t['Direction'] == 1, t["PriceIn"] , t["PriceOut"] ) * t["Qty"] 
        t['SellAmt']     = np.where( t['Direction'] == 1, t["PriceOut"], t["PriceIn"] )  * t["Qty"] 

        t['GrossAmt']    = t['SellAmt'] - t['BuyAmt']        
        
        t['ExpenseAmt']  = -1 * np.where( t['ExpenseAmt'] > 0, t['ExpenseAmt'], (t['BuyAmt'] + t['SellAmt'])*s.EstimatedTax )
                                                                                # if Expense not entered, use estimate
        t['NetAmt']      = t['GrossAmt'] + t['ExpenseAmt']        
        t['Capital']     = t['NetAmt'].cumsum() + s.InitialCapital
        
        capital = t['Capital'].iloc[-1] 
        if( math.isnan( capital ) ) :                                           # Open Trade.  Can look for last complete trade for latest capital - but wont be used in live trading anyway
            return 0
        else:
            return int( capital )

    def processLog(self, T1_QTY=0, T2_QTY=0):
        
        self.getCurrentCapital()
        
        t = self.trades
        
        t['T1Hit']       = t['T1'] > 0
        t['T2Hit']       = t['T2'] > 0

        t['StopDistance']= t['Direction'] * (t['PriceIn']-t['InitStop'])
        t['InitRiskAmt'] = t['StopDistance'] * t['Qty']
        t['Risk/Ideal']  = t['InitRiskAmt']/( t['Capital'] * s.RiskPerTrade )    
        
        t['TurnoverAmt'] = t['GrossAmt'].abs()        
        
        # Result in terms of risk, if 100 % size was taken out at Trail/T1/T2
        
        InitRiskAmoutInv = 1/t['InitRiskAmt']    
        temp             = 1/(t['PriceIn']-t['InitStop'])
        
        t['TrailX']      = (t['Trail'] - t['PriceIn']) * temp
        t['T1X']         = (np.where( t['T1Hit'], t['T1'], t['Trail']) - t['PriceIn']) * temp
        t['T2X']         = (np.where( t['T2Hit'], t['T2'], t['Trail']) - t['PriceIn']) * temp

        t['ExpenseX']    = t['ExpenseAmt'] * InitRiskAmoutInv
        t['GrossX']      = t['GrossAmt']   * InitRiskAmoutInv
        t['NetX']        = t['GrossX'] + t['ExpenseX']

        t['SlipEntryX']  = ( t["PriceIn"] - t["PriceInTrigger"]  ) * temp
        t['SlipExitX']   = ( t["TrailTrigger"] - t["Trail"]  )     * temp  * (t['TrailQty']/t['Qty'])
        
        t['StopHit']     = t['TrailX'] <= -0.95             # Mark as stop hit if exit price is within 5 % of Initial Stop, also allowing some positive slippage at exit
        
        # For simulator
        self.openTrades = t[ t['Qty'] <= 0 ]

        if self.openTrades.size > 0 :
            self.isOpenTrades = True
            self._handleOpenTrades()
            self._printOpenStats()
        else:
            self._calculateITRStats()
            self._calculatePartStats()
            self._printStats()
    
    # Orderman
    def updateCapital(self):
        
        t       = self.trades
        capital = int( t['Capital'].iloc[-1] ) 
        
        if( capital > 0  ):
            from configobj import ConfigObj        
            config = ConfigObj('..\OrderMan\config\OrderMan.ini')
            config['OrderMan']['Capital'] = capital
            config.write()

            
    #################################

    
    def _calculateITRStats( self ):
        t   = self.trades        
        itr = {}
        itr['BuyValue']  = t['BuyAmt'].sum()
        itr['SellValue'] = t['SellAmt'].sum()
        itr['Expenses']  = t['ExpenseAmt'].sum()    
        itr['Gross']     = itr['SellValue'] - itr['BuyValue']
        itr['Net']       = itr['Gross'] +  itr['Expenses']
        itr['Turnover']  = t['TurnoverAmt'].sum()
        itr['Gross/Turnover%'] = itr['Gross'] / itr['Turnover'] * 100
        
        self.stats['itr']  = itr
        
    def _calculatePartStats(self):
        
        t        = self.trades
        
        result   = {}

        combined = {}
        trail    = {}
        t1       = {}
        t2       = {}    

        combined['Gross']   = t['GrossX'].sum()
        trail['Gross']      = t['TrailX'].sum()
        t1['Gross']         = t['T1X'].sum()    
        t2['Gross']         = t['T2X'].sum()

        expense             = t['ExpenseX'].sum()
        combined['Expense'] = expense
        trail['Expense']    = expense
        t1['Expense']       = expense
        t2['Expense']       = expense

        combined['Net']     = combined['Gross'] + expense
        trail['Net']        = trail['Gross'] + expense   
        t1['Net']           = t1['Gross']  + expense
        t2['Net']           = t2['Gross']  + expense
        

        combined['Mean']    = t['GrossX'].mean()
        trail['Mean']       = t['TrailX'].mean()
        t1['Mean']          = t['T1X'].mean()    
        t2['Mean']          = t['T2X'].mean()

        combined['Median']  = t['GrossX'].median()
        trail['Median']     = t['TrailX'].median()
        t1['Median']        = t['T1X'].median()    
        t2['Median']        = t['T2X'].median()

        combined['std']     = t['GrossX'].std()
        trail['std']        = t['TrailX'].std()
        t1['std']           = t['T1X'].std()    
        t2['std']           = t['T2X'].std()

        combined['CoeffVar'] = combined['std'] / combined['Mean']
        trail['CoeffVar']    = trail['std'] / trail['Mean']
        t1['CoeffVar']       = t1['std'] / t1['Mean']
        t2['CoeffVar']       = t2['std'] / t2['Mean']

        combined['Largest']  = t['GrossX'].max() 
        trail['Largest']     = t['TrailX'].max()
        t1['Largest']        = t['T1X'].max()    
        t2['Largest']        = t['T2X'].max()

        combined['Smallest'] = t['GrossX'].min() 
        trail['Smallest']    = t['TrailX'].min()
        t1['Smallest']       = t['T1X'].min()    
        t2['Smallest']       = t['T2X'].min()

        combined['HitRate']  = ''
        trail['HitRate']     = len(t['StopHit'][t['StopHit']>0]) / len(t['StopHit']) * 100          # Stop Hit Rate
        t1['HitRate']        = len(t['T1Hit'][t['T1Hit']>0]) / len(t['T1Hit']) * 100
        t2['HitRate']        = len(t['T2Hit'][t['T2Hit']>0]) / len(t['T2Hit']) * 100
        

        result["combined"]  = combined
        result["trail"]     = trail
        result["t1"]        = t1
        result["t2"]        = t2
        
        self.stats["result"]    = result
             
        # Winners/Losers stats 
        winloss  = {}
        win      = {}
        loss     = {} 

        twin     = t['GrossX'][t['GrossX'] > 0]
        tloss    = t['GrossX'][t['GrossX'] < 0]

        win["Gross"]   = twin.sum()
        loss["Gross"]  = tloss.sum()                # Rest BE

        win["Mean"]    = twin.mean()
        loss["Mean"]   = tloss.mean()

        win["Median"]  = twin.median()
        loss["Median"] = tloss.median()

        temp           = 100/len(t)    
        win["%"]       = len(twin)  * temp
        loss["%"]      = len(tloss) * temp

        win["std"]     = twin.std()
        loss["std"]    = tloss.std()
        
        winloss["Win"]  = win
        winloss["Loss"] = loss
        
        self.stats["WinLoss"] = winloss

    def _maxDrawdownX( self, returnsX ):

        returnsX =  pd.concat( [pd.Series( 0.0 ), returnsX], ignore_index=True )            # if max DD includes 1st trade, 1st trade result is not counted below 
                                                                                            # Workaround - Add '0' row in returns at top
        r   = returnsX.cumsum()         # cumulative X
        dd  = r.sub(r.cummax())         # Drawdown =  current level of the return - maximum return for all periods prior
        mdd = dd.min()                  # max drawndown = biggest(minimum value) of all the calculated drawdowns 

        #print( pd.concat( [ returnsX, r, r.cummax(), dd ], axis=1 ) ) 
        return mdd  
    
    # Find max number of trades until a new High is made in Total Net returns
    # Input should have NetX and Date columns
    def  _maxTradesToRecover( self, returnsX  ):

        netReturnsSum = returnsX['NetX'].cumsum()                                   # Overall returns upto this row
        netReturnsMax = netReturnsSum.cummax()                                      # Maximum of overall returns till this row
        
        totalReturnsNewHigh        = netReturnsMax != netReturnsMax.shift(1)        # True if Max Net returns till now is not same for previous row. ie if a new Max was made
        totalReturnsGroupByMaxHigh = totalReturnsNewHigh.cumsum()                   # Consecutive rows that have same 'Maximum Returns so far' get grouped together. This is the key
                                                                                    #   The first row of each group has made a new High in Total Returns. Rest of the group are in drawdown              
        #print( pd.concat( [ netReturnsMax, totalReturnsNewHigh, totalReturnsGroupByMaxHigh], axis=1 ) )

        ddGroups    = returnsX.groupby(  totalReturnsGroupByMaxHigh ).Date          # group by totalReturnsGroupByMaxHigh
        agg         = ddGroups.agg( ['count','max'] )                               # Aggregate by group count, also show drawdown end date
                                                                                    
                                                                                    # Combine TradeCount and End date with Start Date
                                                                                    # StartDate = 2nd row in Max Drawdown group ( 1st row made new High)
                                                                                    # Keep only the Top 5 Drawdowns 
        output           = pd.concat( [ agg[ agg['count']>2 ], ddGroups.nth(2) ],  axis=1  ).nlargest( 5, 'count' )
        output.columns   = ['Trades','EndDate', 'StartDate']
        output           = output[ ['Trades', 'StartDate', 'EndDate' ] ]
        output['Trades'] = output['Trades'] - 1                                     # Subtract 1 to ignore the first trade of the group, which made a new High in overall returns    
        output.index.name= None                                                     # Removes blank row from print output

        return output

    def _sma( self, bars_field, n=20 ):
        return bars_field.rolling( n, min_periods=n ).mean().dropna()

    def _printStats( self ):       

        pd.set_option('display.max_columns', None)
        pd.set_option('display.max_rows', None)
        pd.set_option('display.width', 10000)
        pd.options.display.float_format = '{:.2f}'.format
        pd.options.mode.chained_assignment = None           # Hide warning on sliced data update

        fn = os.path.splitext(s.TRADE_LOG)[0] + "-stats.txt"
        t  = self.trades
    
        with open(fn, 'w') as f:
            
            i = [ 'Gross', 'HitRate', 'Mean', 'Median', 'std', 'CoeffVar', 'Largest', 'Smallest', 'Expense', 'Net' ] 
            print( "Results:\n",  file=f )
            print( pd.DataFrame( self.stats['result'], index = i ),  file=f )
            
            
            print( "\n", "------------------------------------ \n",  file=f)
            
            
            i = [ '%', 'Gross', 'Mean', 'Median', 'std' ]             
            print( "Winners/Loosers:\n", file=f )
            print( pd.DataFrame( self.stats["WinLoss"], index = i), file=f )


            print( "\n", "------------------------------------", "\n", file=f )
            
            maxNetDrawdown = round(self._maxDrawdownX( t['NetX'] ), 2)
            entrySlippageX = round(t['SlipEntryX'].sum(),2)
            exitSlippageX  = round(t['SlipExitX'].sum(),2)            
            maxRecovery    = self._maxTradesToRecover( t[['NetX','Date']] )
            
            printMe = "Slippage Entry: " +  str(entrySlippageX) + " -- Slippage Exit: " + str(exitSlippageX)
            if 'BarsHeld' in t.columns:
                barsHeldAvg = round(  t['BarsHeld'].mean(), 1 )  
                printMe += " -- Average Bars Held: " + str(barsHeldAvg) 
            print( printMe , file=f )

            print( "\nBiggest Drawdown: " + str(maxNetDrawdown) + "X" , file=f )
            print( 'Longest 5 Drawdowns' , file=f  )
            print( maxRecovery.to_string(index=False), file=f  )
            
            
            
            print( "\n", "------------------------------------", "\n", file=f )
            
            t['NetCumulative'] = t['NetX'].cumsum()
            
            i = [ 'Setup','Date','Time','Market','InitStop','PriceIn','Trail','T1','T2','Qty','InitRiskAmt', 'Risk/Ideal', 'TrailX','T1X','T2X','GrossX','ExpenseX','NetX','Capital','SlipEntryX','SlipExitX','NetCumulative']
            print("Trades :", file=f )
            print( t[ i ], file=f )
            print( "\nNote : PriceIn Includes Entry Slippage. InitRiskAmt can be more than ideal Risk due to 1) Entry Slippage 2) Multiple open positions. All 'X' items are wrt PriceIn" , file=f )
            
            #print( t , file=f )

            print( "\n", "------------------------------------", "\n", file=f )
            
            i   = ['BuyValue','SellValue','Expenses','Gross','Net','Turnover','Gross/Turnover%']        
            print( "ITR:", file=f )
            print( pd.Series(self.stats['itr'], index=i ), file=f )
            
            
        plt.plot( t['GrossX'].cumsum(), label="Combined" )
        plt.plot( t['TrailX'].cumsum(), label="Trail" )
        plt.plot( t['T1X'].cumsum(), label="T1"  )
        plt.plot( t['T2X'].cumsum(), label="T2"  )

        plt.legend()
        plt.savefig( fn + '-curve.png', bbox_inches='tight')        
        #plt.show()     # open chart instead of saving to file
        
        plt.clf()        
        plt.close()

        
        
        trailingNetX  = t['NetX'].tail(120)                   # Histogram + SMA
        sma           = self._sma( trailingNetX, 20 )
        isProfit      = trailingNetX  > 0 

        plt.bar( trailingNetX.index, trailingNetX, color=isProfit.map({True: 'b', False: 'r'}) )
        plt.plot( sma )

        plt.savefig( fn + '-hist.png')
        
        
    def _handleOpenTrades( self ):
        pd.options.mode.chained_assignment = None                                   # Hide warning on sliced data update
        
        t = self.trades
        o = self.openTrades
        
        capitalClosedTrades = t['Capital'][t['Qty'] > 0]
        
        if( len(capitalClosedTrades) > 0 ):
            currentCapital = t['Capital'][t['Qty'] > 0].iloc[-1]
        else:
            currentCapital = s.InitialCapital
        
        stopDistance   = (o['PriceIn']-o['InitStop']).abs()
        
        o['Qty'] = np.floor( (s.RiskPerTrade * currentCapital) / stopDistance )     # Position Size
        o['InitRiskAmt'] = o['Direction']* stopDistance * o['Qty']
                                                                    
        o['T1'] = o['PriceIn'] + stopDistance * o['Direction']                      # Target Prices - 1X, 2X
        o['T2'] = o['PriceIn'] + stopDistance * o['Direction'] * 2

    def _printOpenStats( self ):
        
        pd.set_option('display.max_columns', None)
        pd.set_option('display.width', 10000)
        pd.options.display.float_format = '{:.2f}'.format
        pd.options.mode.chained_assignment = None           # Hide warning on sliced data update

        fn = os.path.splitext(s.TRADE_LOG)[0] + "-stats.txt"
        o  = self.openTrades
    
        with open(fn, 'w') as f:  
            print( o[['Setup','Date','Market','InitStop','PriceIn','T1','T2','Qty','InitRiskAmt']], file=f )
        
        
        
        
if __name__ == '__main__': 

    args = sys.argv
    
    if(  len(args) > 1 ):
        log = TradeLog( sys.argv[1] )             # Pass input tradelog file
    else:
        log = TradeLog()
        
        
    log.processLog()
    #log.processLog(0.33, 0.33)
    
    if( not log.isOpenTrades ):
        log.updateCapital()







# More stats
    # Grimes - TRADING STRATEGIES:Monitoring Tools, STATISTICAL ANALYSIS OF TRADING RESULTS
    # Max drawdawns, control charts etc, Highest  win/loss streaks
    # Average drawdown size, hit rate, Sharpe ratio, average daily P/L volatility, etc
# Monte Carlo models - Pick Ramdom x trades y times and plot equity curve/drawdowns etc. Shows possible variations
# Later compare constant risk vs percentage risk (calculate qty)


