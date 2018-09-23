# Analyze Tradelog against Database. Can check how different stops/targets might have worked with set filters
# Can also use Mech Entry signals instead of input tradelog

import os
import sys
import time

import signals as sig
import mechTM
from settings import s
import plugins as p

os.chdir(sys.path[0])                               # Set working dir
 

def setStopATR( atrDistance ):
    s.MECHTM_STOP_OVERRIDE       = True
    s.MECHTM_STOP_ATR_LOOKBACK   = 20

    s.MECHTM_STOP_ATR_MULTIPLIER = atrDistance

def setTargetX( distance ):
    s.MECHTM_TARGET_X = distance

def setTimeFilter( start, end ):
    s.MECHTM_START_TIME = start
    s.MECHTM_END_TIME   = end
  
def setTradeDirection( direction ):
    if( direction == 'SHORT' ):    
        s.MECHTM_DIRECTION  = s.DIRECTION.SHORT_ONLY
    else:
        s.MECHTM_DIRECTION  = s.DIRECTION.LONG_ONLY
    
# --------------------------------------------

def signalShort(scrip, bars):
    sig.scrip = scrip
    sig.bars  = bars

    signal = sig.trendDown() & sig.newLOD() #& ~sig.spikeDown(4)

    return signal

def signalLong(scrip, bars):
    sig.scrip = scrip
    sig.bars  = bars

    signal =  sig.trendUp() & sig.newHOD()  & ~sig.spikeUp(4)

    return signal

def setMechEntry( function, direction, startTime, EndTime  ):
    #s.FILTER_NEAR_SIGNALS = False
    #s.PRICE_CUTOFF

    s.setSignalFunction( function )    
    setTradeDirection(direction )
    setTimeFilter( startTime, EndTime  )    

def setDateRange( start, end ):
    s.setDateFilter( start, end, False ) 

def setMonth( yearmonth ):
    s.setDateFilter( yearmonth + '-01', yearmonth + '-31', False )

def setYear( year):
    s.setDateFilter( year + '-01-01', year + '-12-31', False )

    
def filterBySetup( setup ):
    s.MECHTM_QUERY = ( "Setup", s.OPERATOR.EQUALS, setup  )

def filterByTag( tag ):
    s.MECHTM_QUERY = ( "Tags", s.OPERATOR.CONTAINS, tag )
    
# --------------------------------------------



 
# --------------------------------------------

def setConfig(): 
    s.MULTIPROC = True
    
    setStopATR( 5 )
    setTargetX( 10 )
    
    #'''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.trailTimeStopOnScripChange
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.trailTimeStopOnTradeChange  
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnProfit
    #'''
    
    '''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.trailTimeStopOnScripChange
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.trailTimeStopOnTradeChange    
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnTimeStop
    '''

    #setYear('2017')
        
    
    '''
    s.MECHTM_ISTRAIL_ENABLED = True
    s.MECHTM_TRAIL_ATR_MULTIPLIER = 6    
    #s.MECHTM_TRAIL_MOVE_BACK_STOP = False
    '''

    #setTradeDirection('SHORT')
    #setTradeDirection('LONG')

    #setTimeFilter( "10:00", "12:30"  )
    #setTimeFilter( "12:30", "14:30"  )
    #setDateRange( '2014-08-10', '2014-08-15')
    #setMonth( '2014-08')
    #setYear('2017')
    #s.MECHTM_CLOSING_TIME = (15, 14)
    #filterBySetup( 'BOBase' )
    #filterByTag('Test')

    #s.MECHTM_INPUT_LOG = "../TradeLog/data/tradelog.csv" 

    #s.MECHTM_INPUT_LOG = "config/tradelogSim.csv" 
    #s.useStocksDB()

    #s.useNiftyIndexDB()
    #s.useBankNiftyIndexDB()

    #setMechEntry( signalShort, 'SHORT', "10:00", "14:30"  )
    #setMechEntry( signalLong, 'LONG', "10:00", "14:30"  )
  
    #setMechEntry( signalLong, 'LONG', "10:00", "12:30"  )
    #setMechEntry( signalLong, 'LONG', "12:30", "14:30"  )
    
    #setMechEntry( signalShort, 'SHORT', "10:00", "12:30"  )
    #setMechEntry( signalShort, 'SHORT', "12:30", "14:30"  )

    
    
# --------------------------------------------

if __name__ == '__main__':      
    start = time.time()   

s.useStocksCurrentDB()
s.MULTIPROC = False
s.createDBIfNeeded()

setConfig()

def run():
    mech = mechTM.MechTM()     
    #mech.SCRIPS = [ 'HINDALCO' ]
    mech.processLog()
    
    print( '\nTime Taken:', time.time() - start )

if __name__ == '__main__':   
    run()    
    
    '''
    import cProfile
    cProfile.run('run()', filename='profile.txt')    
    import pstats
    p = pstats.Stats('profile.txt')
    p.sort_stats('cumulative').print_stats(10)
    # Run from cmd  'snakeviz  profile.txt'
    '''

