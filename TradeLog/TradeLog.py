
import pandas as pd
import numpy as np
import os
import configparser
import matplotlib.pyplot as plt
import sys

os.chdir(sys.path[0])                               # Set working dir


LOG     =  "data/tradelog.csv"
FIELDS  =  str("Setup,isNested,Tags,Date,Time,Market,InitStop,PriceIn,Trail,T1,T2,Qty,T1Qty,T2Qty,ExpenseAmt,Mistakes,Comment,TrailTrigger,PriceInTrigger,StopTime,T1Time,T2Time")

#-----------------------------------------------------------------------------------

InitialCapital  = 0
RiskPerTrade    = 0
Expense         = 0

t               = 0                                 # Input Data + Column calculations
o               = 0                                 # Open Trades
stats           = {}                                # Overall Stats Fields Map

pd.set_option('display.max_columns', None)
pd.set_option('display.width', 10000)
pd.options.display.float_format = '{:.2f}'.format
pd.options.mode.chained_assignment = None           # Hide warning on sliced data update

#-----------------------------------------------------------------------------------



def init():
    global LOG

    loadSettings()

    if( len(sys.argv) > 1 ):                        # Input Args. 1) Input csv
        LOG = sys.argv[1]
    
    if not os.path.isfile(LOG):                     # create initial csv if not found
        file = open(LOG, 'w+')
        file.write(FIELDS + "\n")
        file.close()


def loadSettings():
    global InitialCapital, RiskPerTrade, Expense
    
    config = configparser.ConfigParser()
    config.read('TradeLog.ini')
    
    InitialCapital = config.getfloat('TradeLog', 'InitialCapital')
    RiskPerTrade   = config.getfloat('TradeLog', 'RiskPerTrade')
    Expense        = config.getfloat('TradeLog', 'Expense')



def processLog(T1_QTY, T2_QTY):
    global t, o, Expense, InitialCapital, RiskPerTrade

    file = open(LOG, 'r')
    t = pd.read_csv(file)
    file.close()

    t = t[ t['PriceIn'] > 0 ]                       # Only consider rows with price-in set

    t['Direction'] = np.where( t['PriceIn'] > t['InitStop'], 1, -1 )

    t['T1Hit']     = t['T1'] > 0
    t['T2Hit']     = t['T2'] > 0
                                                    # T1 Hit but T1 qty not entered, set calculated T1 qty for backtesting
                                                    # &/|/~ does element wise conditional.() is necessary
    t['T1Qty']     = np.where( t['T1Hit'] & (t['T1Qty'] == 0) , T1_QTY * t['Qty'], t['T1Qty']  )
    t['T2Qty']     = np.where( t['T2Hit'] & (t['T2Qty'] == 0) , T2_QTY * t['Qty'], t['T2Qty']  )
    
    t['TrailQty']  = t['Qty'] - t['T1Qty'] - t['T2Qty']

    t['PriceOut']  = (t['T1'] * t['T1Qty'] + t['T2']* t['T2Qty'] + t['Trail'] * t['TrailQty']) / t['Qty']

    t['StopDistance'] = t['Direction'] * (t['PriceIn']-t['InitStop'])
    t['InitRiskAmt']  = t['StopDistance'] * t['Qty']
    
    t['BuyAmt']      = np.where( t['Direction'] == 1, t["PriceIn"] , t["PriceOut"] ) * t["Qty"] 
    t['SellAmt']     = np.where( t['Direction'] == 1, t["PriceOut"], t["PriceIn"] )  * t["Qty"] 

    t['GrossAmt']    = t['SellAmt'] - t['BuyAmt']
    t['TurnoverAmt'] = t['GrossAmt'].abs()          # if Expense not entered, use estimate for simulators
    t['ExpenseAmt']  = -1 * np.where( t['ExpenseAmt'] > 0, t['ExpenseAmt'], (t['BuyAmt'] + t['SellAmt'])*Expense )
    t['NetAmt']      = t['GrossAmt'] + t['ExpenseAmt']
    t['Capital']     = t['NetAmt'].cumsum() + InitialCapital

    t['Risk/Ideal']  = t['InitRiskAmt']/( t['Capital'] * RiskPerTrade )    
    
    # Result in terms of risk, if 100 % size was taken out at Trail/T1/T2
    InitRiskAmoutInv = 1/t['InitRiskAmt']    
    temp             = 1/(t['PriceIn']-t['InitStop'])
    
    t['TrailX']      = (t['Trail'] - t['PriceIn']) * temp
    t['T1X']         = (np.where( t['T1Hit'], t['T1'], t['Trail']) - t['PriceIn']) * temp
    t['T2X']         = (np.where( t['T2Hit'], t['T2'], t['Trail']) - t['PriceIn']) * temp

    t['ExpenseX']    = t['ExpenseAmt'] * InitRiskAmoutInv
    t['GrossX']      = t['GrossAmt']   * InitRiskAmoutInv
    t['NetX']        = t['GrossX'] + t['ExpenseX']

    t['SlipEntryX']  =  ( t["PriceIn"] - t["PriceInTrigger"]  ) * temp
    t['SlipExitX']   =  ( t["TrailTrigger"] - t["Trail"]  )     * temp  * (t['TrailQty']/t['Qty'])
    
    o = t[ t['Qty'] <= 0 ]

    if o.size > 0 :
        handleOpenTrades()        
    else:
        calculateOverallStats()

def handleOpenTrades():
    global t, o, RiskPerTrade, InitialCapital

    capitalClosedTrades = t['Capital'][t['Qty'] > 0]
    
    if( len(capitalClosedTrades) > 0 ):
        currentCapital = t['Capital'][t['Qty'] > 0].iloc[-1]
    else:
        currentCapital = InitialCapital
    
    stopDistance   = (o['PriceIn']-o['InitStop']).abs()
    
    o['Qty'] = np.floor( (RiskPerTrade * currentCapital) / stopDistance )   # Position Size
    o['InitRiskAmt'] = o['Direction']* stopDistance * o['Qty']
                                                                
    o['T1'] = o['PriceIn'] + stopDistance * o['Direction']                  # Target Prices - 1X, 2X
    o['T2'] = o['PriceIn'] + stopDistance * o['Direction'] * 2


def calculateOverallStats():
    global t, stats
    
    itr = {}
    itr['BuyValue']  = t['BuyAmt'].sum()
    itr['SellValue'] = t['SellAmt'].sum()
    itr['Expenses']  = t['ExpenseAmt'].sum()    
    itr['Gross']     = itr['SellValue'] - itr['BuyValue']
    itr['Net']       = itr['Gross'] +  itr['Expenses']
    itr['Turnover']  = t['TurnoverAmt'].sum()
    itr['Gross/Turnover%'] = itr['Gross'] / itr['Turnover'] * 100
    
    stats['itr']  = itr
    calculatePartStats()


def calculatePartStats():
    global t, stats

    result = {}

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
    trail['HitRate']     = ''
    t1['HitRate']        = len(t['T1Hit'][t['T1Hit']>0]) / len(t['T1Hit']) * 100
    t2['HitRate']        = len(t['T2Hit'][t['T2Hit']>0]) / len(t['T2Hit']) * 100
    

    result["combined"]  = combined
    result["trail"]     = trail
    result["t1"]        = t1
    result["t2"]        = t2
    
    stats["result"]    = result
         
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
    stats["WinLoss"] = winloss

# TODO - if max DD includes 1st trade, 1st trade result is not counted - Add '0' row in returns at top
# TODO DD period + recovery period
def maxDrawdownX( returnsX ):
    r   = returnsX.cumsum()         # cumulative X
    dd  = r.sub(r.cummax())         # Drawdown =  current level of the return - maximum return for all periods prior
    mdd = dd.min()                  # max drawndown = minimum of all the calculated drawdowns
    
    #print( pd.concat( [ returnsX, r, r.cummax(), dd ], axis=1 ) ) 
    return mdd  

def sma( bars_field, n=20 ):
    return bars_field.rolling( n, min_periods=n ).mean()
    
def printStats():
    global t, o, itr

    orig_stdout = sys.stdout
    fn = os.path.splitext(LOG)[0] 
    f = open(fn + "-stats.txt", 'w')
    sys.stdout = f
    
    if o.size == 0 :
        i = [ 'Gross', 'HitRate', 'Mean', 'Median', 'std', 'CoeffVar', 'Largest', 'Smallest', 'Expense', 'Net' ]         
        print( "Results:\n")
        print( pd.DataFrame( stats['result'], index = i  ))


        i = [ '%', 'Gross', 'Mean', 'Median', 'std' ] 
        print( "\n", "------------------------------------", "\n")
        print( "Winners/Loosers:\n" )
        print(  pd.DataFrame( stats["WinLoss"], index = i  ))

        print( "\n", "------------------------------------", "\n")
        print( "Max Net Drawdown: ", round(maxDrawdownX( t['NetX'] ), 2), " -- Slippage Entry: ", round(t['SlipEntryX'].sum(),2), " -- Slippage Exit: ", round(t['SlipExitX'].sum(),2) )
        
        print( "\n", "------------------------------------", "\n" )
        print("Trades :")
        #print( t )
        print( t[[ 'Setup','Date','Market','InitStop','PriceIn','Trail','T1','T2','Qty','InitRiskAmt', 'Risk/Ideal', \
                   'TrailX','T1X','T2X','GrossX','ExpenseX','NetX','Capital','SlipEntryX','SlipExitX']] )
        print( "\nNote : PriceIn Includes Entry Slippage. InitRiskAmt can be more than ideal Risk due to 1) Entry Slippage 2) Multiple open positions. All 'X' items are wrt PriceIn" )
        

        print( "\n", "------------------------------------", "\n" )
        i   = ['BuyValue','SellValue','Expenses','Gross','Net','Turnover','Gross/Turnover%']        
        print( "ITR:" )
        print( pd.Series(stats['itr'], index=i )  )        


        plt.plot( t['GrossX'].cumsum(), label="Combined" )
        plt.plot( t['TrailX'].cumsum(), label="Trail" )
        plt.plot( t['T1X'].cumsum(), label="T1"  )
        plt.plot( t['T2X'].cumsum(), label="T2"  )

        plt.legend()
        plt.savefig( fn + '-curve.png', bbox_inches='tight')
        #plt.show()     # open chart instead of saving to file
        
        plt.clf()        
        plt.close()

        
        t.plot.bar( y='NetX' )              # Histogram        
        plt.plot( sma( t['NetX'], 10 ) )    # sma
        plt.savefig( fn + '-hist.png', bbox_inches='tight')

    else:
        print( o[['Setup','Date','Market','InitStop','PriceIn','T1','T2','Qty','InitRiskAmt']] )

    sys.stdout = orig_stdout
    f.close()

def updateCapital():
    global t
    capital = int( t['Capital'].iloc[-1] ) 
    
    if( capital > 0  ):
        from configobj import ConfigObj        
        config = ConfigObj('..\OrderMan\config\OrderMan.ini')
        config['OrderMan']['Capital'] = capital
        config.write()
    
#-----------------------------------------------------------------------------------



init()
processLog(0.4, 0.4)
printStats()
updateCapital()



# Histogram of wins/losses - option for trailing 100 only


# Import multiple csv
# More stats
    # Grimes - TRADING STRATEGIES:Monitoring Tools, STATISTICAL ANALYSIS OF TRADING RESULTS
    # Max drawdawns, control charts etc, Highest  win/loss streaks
    # Average drawdown size, hit rate, Sharpe ratio, average daily P/L volatility, etc
# Monte Carlo models - Pick Ramdom x trades y times and plot equity curve/drawdowns etc. Shows possible variations
# Later compare constant risk vs percentage risk (calculate qty)


