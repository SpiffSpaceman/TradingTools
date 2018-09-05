import time
import sys
import numpy as np
import pandas as pd
from multiprocessing import Pool

import database
import signals
from settings import s



# ---------------------------------------------
returns          = {key: [] for key in s.DAYS}      
                           # Key = return period. Value = List of all returns for that period for all scrips together    
                           # Initialize with keys from s.DAYS and value = Empty List

baselineSum      = 0       # Sum of return of all Scrips from 1st bar to last bar of each scrip
baselineBarCount = 0       # Total number of bars covering above
scripCount       = 0 
trades           = pd.DataFrame()

tradelogFile     = None

pd.set_option('display.max_rows', None)
pd.set_option('display.max_columns', None)
pd.set_option('display.width', 10000)
pd.options.display.float_format = '{:,.2f}'.format
pd.set_option('display.width', 10000)



def clearData():
    global returns, baselineSum, baselineBarCount, scripCount, trades

    returns = {key: [] for key in s.DAYS}
    baselineSum = 0
    baselineBarCount = 0
    scripCount = 0
    trades = pd.DataFrame()

def init():
    global orig_stdout, _file, start, tradelogFile

    start = time.time()

    orig_stdout = sys.stdout
    _file       = open(s.OUTPUT_FOLDER + 'EventStudy-output.txt', 'w')
    sys.stdout  = _file

    if( s.EXPORT_TRADES ) :
        tradelogFile = open(s.OUTPUT_FOLDER + 'EventStudy-trades.csv', 'w')

def finit():
    global orig_stdout, _file, start, tradelogFile

    print( '\nTime Taken:', time.time() - start )

    sys.stdout = orig_stdout
    _file.close()

    if( s.EXPORT_TRADES ) :
        tradelogFile.close()

def processScrip( scrip ):

    trades = None
    
    try:
        bars = database.loadScripRandomDB( scrip ) if s.DB_RANDOM else database.loadScripDB( scrip )    
    except IOError:   
        print( scrip, " Not Found" )
        return None                                        # Scrip in Scrip List is not in DB. Ignore 

    C      = bars['C']
    signal = signals.signalFilter( s.SIGNAL_FN( scrip, bars ), bars )

    signalReturnsN = {}                                     # Map with key= return period and value = list of signal returns
    IsSignal       = (signal == True)

    if s.SIGNAL_START_DATE != "":                           # Filter out data outside date range
        filter   = C.index >= s.SIGNAL_START_DATE 
        IsSignal = IsSignal[ filter ] 
        C        = C[ filter ] 
    if s.SIGNAL_END_DATE != "":
        filter   = C.index <= s.SIGNAL_END_DATE
        IsSignal = IsSignal[ filter ]
        C        = C[ filter ]
    

    if( len(C) > 0 ) :
        baseline         = C[-1]/C[0] - 1
        baselineBarCount = C.count()
    else:
        baseline = baselineBarCount = 0
        
    for n in s.DAYS:        
        signalReturnsN[n] = []
        
        # n bar returns, Look ahead by n bars. For Signal bars only. Filter out open trades
        signalReturns       = np.where( IsSignal, C.pct_change(periods=n).shift(-n), np.NaN) 
        signalReturns       = signalReturns[ ~np.isnan(signalReturns) ]         
        signalReturnsN[n] += signalReturns.tolist() 
        
        if( s.EXPORT_TRADES and n == s.EXPORT_TRADES_DAY ) :
            trades = pd.concat( [ C[IsSignal], C.shift(-n)[IsSignal] ], axis=1 )
            trades.columns = ['Entry', 'Exit']            
            trades['Result'] = (trades['Exit']/trades['Entry'] - 1 )*100
            trades['Scrip']  = scrip
            trades = trades[trades['Exit'].notnull()]            

    return (signalReturnsN, baseline, baselineBarCount, trades)

# Process result from processScrip()
# Input result = Tuple
def processResult( result ):
    global baselineSum, baselineBarCount, returns, scripCount, trades
    
    if( result == None ):
        return
    
    if( result[2] != 0 ):                       # Baseline 
        baselineSum      += result[1]
        baselineBarCount += result[2]
        scripCount       += 1        

    for n,returnsList in result[0].items() :   # Result[0] = Signal Returns = List of Maps, with key=n and value = List of returns 
        returns[n] += returnsList               # Merge them
        
    if s.EXPORT_TRADES :        
        trades = pd.concat( [trades,result[3]], copy=False )


# ----------------------------------------------------------
        
def doEventStudy():
    global baselineSum, baselineBarCount, returns, scripCount, trades, tradelogFile

    if s.MULTIPROC :
        pool    = Pool( s.PROCESS_COUNT )
        results = pool.map( processScrip, s.SCRIPS )
        
        for result in results :
            processResult( result )
        pool.close()
        pool.join()
    else:
        for scrip in s.SCRIPS:
            processResult( processScrip( scrip ) )
    
    if s.EXPORT_TRADES:
        if( tradelogFile == None ) :                # s.EXPORT_TRADES set after init()
            tradelogFile = open(s.OUTPUT_FOLDER + 'EventStudy-trades.csv', 'w')
    
        #trades.sort_index(inplace=True)        
        trades = trades.sort_values('Scrip', ascending=True ).sort_index(level=0, sort_remaining=False, kind='mergesort')
        trades.to_csv(tradelogFile, index_label='Date', header=['Entry','Exit','Result','Scrip'])

    # ---------------
    
    sigCount = len( returns[next(iter(returns))] )

    print("Scrips #",  scripCount )
    print("Signals #", sigCount, " (", "{0:.2f}".format(sigCount/baselineBarCount*100)  ,"% )" ) 
    print("Total Bars #", baselineBarCount , "\n") 
    
    baselineReturn = baselineSum/baselineBarCount
    outputTable    = []

    for n in s.DAYS:
        retlist = np.array(returns[n])        
        cols    = {}
        
        total    = len(retlist)
        
        if( total == 0  ) :
            up = down = unch = base = mean = median = std = iqr = 0 
        else :
            up      = len(retlist[retlist>0])/total * 100
            down    = len(retlist[retlist<0])/total * 100
            unch    = 100 - up - down
            
            base    = baselineReturn * 100 * n
            mean    = retlist.mean() * 100
            median  = np.median(retlist) * 100
            std     = retlist.std() * 100
            iqr     = np.subtract(*np.percentile(retlist, [75, 25])) * 100

        cols['#']           = total
        cols['%Up']         = up
        cols['%Down']       = down
        cols['%Unch']       = unch
        cols['Bar']         = n
        cols['Mean']        = mean * 100   # bps
        cols['std']         = std  * 100
        cols['IQR']         = iqr  * 100
        cols['Med']         = median * 100
        cols['Base']        = base * 100
        cols['DiffM']       = (mean-base) * 100
        cols['DiffMed']     = (median-base) * 100

        outputTable.append( cols )
    
    cols = ['#','%Up','%Down','%Unch','Base','Mean','std','Med','IQR','DiffM','DiffMed']
    
    print( pd.DataFrame(outputTable).set_index(['Bar'])[cols] )

    clearData()
    



    
    
    
    
    
    


 

