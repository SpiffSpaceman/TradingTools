
import pandas as pd
import numpy as np
import os.path
import configparser


LOG     =  "tradelog.csv"
FIELDS  =  str("Setup,Date,Market,InitStop,PriceIn,Trail,T1,T2,QtyMult,Qty,T1Qty,T2Qty,ExpenseAmt,Comment")

#-----------------------------------------------------------------------------------

InitialCapital  = 0
RiskPerTrade    = 0
Expense         = 0

t               = 0                                 # Input Data + Column calculations
o               = 0                                 # Open Trades
stats           = {}                                # Overall Stats Fields Map

pd.set_option('display.max_columns', None)
pd.options.display.float_format = '{:,.2f}'.format
pd.options.mode.chained_assignment = None           # Hide warning on sliced data update

#-----------------------------------------------------------------------------------


def init():    
    loadSettings()
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
    global t, o, Expense, InitialCapital

    t = pd.read_csv('tradelog.csv')

    t['Direction'] = np.where( t['PriceIn'] > t['InitStop'], 1, -1 )

    t['T1Hit']     = t['T1'] > 0
    t['T2Hit']     = t['T2'] > 0
                                                    # T1 Hit but T1 qty not entered, set calculated T1 qty for backtesting
                                                    # &/| does element wise conditional.() is necessary
    t['T1Qty']     = np.where( t['T1Hit'] & (t['T1Qty'] == 0) , T1_QTY, t['T1Qty']  )
    t['T2Qty']     = np.where( t['T2Hit'] & (t['T2Qty'] == 0) , T2_QTY, t['T2Qty']  )
    
    t['TrailQty']  = 1 - t['T1Qty'] - t['T2Qty']

    t['PriceOut']  = t['T1']    * t['T1Qty']      \
                   + t['T2']    * t['T2Qty']      \
                   + t['Trail'] * t['TrailQty']

    t['InitRiskAmt'] = t['Direction']*(t['PriceIn']-t['InitStop']) * t['Qty']
    t['BuyAmt']      = np.where( t['Direction'] == 1, t["PriceIn"] , t["PriceOut"] ) * t["Qty"] 
    t['SellAmt']     = np.where( t['Direction'] == 1, t["PriceOut"], t["PriceIn"] )  * t["Qty"] 

    t['GrossAmt']    = t['SellAmt'] - t['BuyAmt']
    t['TurnoverAmt'] = t['GrossAmt'].abs()          # if Expense not entered, use estimate for simulators
    t['ExpenseAmt']  = np.where( t['ExpenseAmt'] > 0, t['ExpenseAmt'], (t['BuyAmt'] + t['SellAmt'])*Expense )
    t['NetAmt']      = t['GrossAmt'] - t['ExpenseAmt']
    t['Capital']     = t['NetAmt'].cumsum() + InitialCapital

    # Result in terms of risk, if 100 % size was taken out at Trail/T1/T2
    temp             = t['Direction'] * t['Qty'] / t['InitRiskAmt'] 
    t['TrailX']      = (t['Trail'] - t['PriceIn']) * temp
    t['T1X']         = (np.where( t['T1Hit'], t['T1'], t['Trail']) - t['PriceIn']) * temp
    t['T2X']         = (np.where( t['T2Hit'], t['T2'], t['Trail']) - t['PriceIn']) * temp
    t['ExpenseX']    = t['ExpenseAmt'] / t['InitRiskAmt']
 

    o = t[ t['Trail'] <= 0 ]

    if o.size > 0 :
        handleOpenTrades()
    else:
        calculateOverallStats()
    

def handleOpenTrades():
    global t, o, RiskPerTrade

    currentCapital = t['Capital'][t['Trail'] > 0].iloc[-1]
    stopDistance   = (o['PriceIn']-o['InitStop']).abs()

    o['Qty'] = np.floor( (RiskPerTrade * currentCapital) / stopDistance )   # Position Size
    o['InitRiskAmt'] = o['Direction']* stopDistance * o['Qty']
                                                                
    o['T1'] = o['PriceIn'] + stopDistance * o['Direction']                  # Target Prices - 1X, 2X
    o['T2'] = o['PriceIn'] + stopDistance * o['Direction'] * 2


def calculateOverallStats():
    global itr, t
    
    itr = {}
    itr['BuyValue']  = t['BuyAmt'].sum()
    itr['SellValue'] = t['SellAmt'].sum()
    itr['Expenses']  = t['ExpenseAmt'].sum()    
    itr['Gross']     = itr['SellValue'] - itr['BuyValue']
    itr['Net']       = itr['Gross'] -  itr['Expenses']
    itr['Turnover']  = t['TurnoverAmt'].sum()
    itr['Gross/Turnover%'] = itr['Gross'] / itr['Turnover'] * 100
    
    stats['itr']  = itr

# TODO
# Open Trades view - Qty, Targets
#def calculatePartStats():
    #resultsByParts = {}
    #resultsByParts['']
    # calculate  stats mean/stddev/coeff etc for each part - 2d array


def printStats():
    global t, o, itr

    if o.size == 0 :    
        print( t[[ 'Setup','Date','Market','InitStop','PriceIn','Trail','T1','T2','Qty','InitRiskAmt', \
                   'ExpenseX','TrailX','T1X','T2X','Capital']] )

        print("\nITR :")

        i   = ['BuyValue','SellValue','Expenses','Gross','Net','Turnover','Gross/Turnover%']
        tax = pd.Series(stats['itr'], index=i )
        print( tax  )
    
        print( "\n", "------------------------------------", "\n" )
    
        #print(  pd.DataFrame(itr)  )
    else:
        print( o[['Setup','Date','Market','InitStop','PriceIn','T1','T2','Qty','InitRiskAmt']] )

#-----------------------------------------------------------------------------------

init()

processLog(0.4, 0.3)
printStats()


#if o.size == 0 : 
    #processLog(0.5, 0)
    #printStats()

# TODO - Overall Stats for each part
# TODO - Part chart
# TODO - Later compare constant risk vs percentage risk (calculate qty)


