# Analyze Tradelog against Database. Can check how different stops/targets might have worked with set filters
# Can also use Mech Entry signals instead of input tradelog

import os
import sys
import time
import datetime

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


def signalLongWithNifty( scrip, bars ):
    signal = signalLong( scrip, bars ) & p.niftyTrendSignal( "LONG", p.loadNifty()  )

    return signal
    
def signalShortWithNifty( scrip, bars ):
    signal = signalShort( scrip, bars ) & p.niftyTrendSignal( "SHORT", p.loadNifty(),30  )

    return signal

 
# --------------------------------------------

def longsToday( date = datetime.datetime.today().strftime('%Y-%m-%d') ):
    setDateRange( date, date)    
    setMechEntry( signalLong, 'LONG', "10:00", "14:30"  )

def shortsToday( date = datetime.datetime.today().strftime('%Y-%m-%d')  ):
    setDateRange( date, date)
    setMechEntry( signalShort, 'SHORT', "10:00", "14:30"  )
    

    
    
    
# --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

def setConfig():
    s.MULTIPROC = True
    #s.PROCESS_COUNT = 3

    setStopATR( 5 )
    setTargetX( 10 )

    #s.MECHTM_STOP_MAX_ATR_LOOKBACK = 5
    
    '''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeDonchianStop    
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.onTradeChangeExtremePrice    
    s.MECHTM_CALLBACK_STOP_FN         = p.donchianTrailTimeStop
    p.DONCHIAN_LOOKBACK = 40
    '''
    
    #'''    
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeTrailAtr
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.onTradeChangeRecentExtreme2  
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnProfit4
    #'''
    
    #longsToday()
    shortsToday()    
    
    
    #setTradeDirection('SHORT')
    #setTradeDirection('LONG')
    #setTimeFilter( "10:00", "12:30"  )
    #setTimeFilter( "12:30", "14:30"  )
    #setDateRange( '2018-10-15', '2018-12-31')    
    #setMonth( '2013-07')
    #setYear('2017')
    #s.MECHTM_CLOSING_TIME = (15, 14)
    #filterBySetup( 'BOBase' )
    #filterByTag('NiftyAgainstEntry')

    s.MECHTM_INPUT_LOG = "config/tradelogLive.csv" 
    #s.MECHTM_INPUT_LOG = "config/tradelogSim.csv" 

    #s.useStocksDB()
    #s.enableRandomDB()

    #s.useNiftyIndexDB()
    #s.useBankNiftyIndexDB()

    #setMechEntry( signalShort, 'SHORT', "10:00", "14:30"  )
    #setMechEntry( signalLong, 'LONG', "10:00", "14:30"  )
  
    #setMechEntry( signalLong, 'LONG', "10:00", "12:30"  )
    #setMechEntry( signalLong, 'LONG', "12:30", "14:30"  )
    
    #setMechEntry( signalShort, 'SHORT', "10:00", "12:30"  )
    #setMechEntry( signalShort, 'SHORT', "12:30", "14:30"  )
    
    #setMechEntry( signalLongWithNifty,  'LONG',  "10:00", "14:30"  )
    #setMechEntry( signalShortWithNifty, 'SHORT', "10:00", "14:30"  )    
    
    s.MECHTM_IGNORE_SCRIPS = {'NIFTY', 'Nifty50', 'NiftyAuto', 'NiftyBank', 'NiftyEnergy', 'NiftyFMCG', 'NiftyIT', 'NiftyMetal', 'NiftyPharma' }
    
    
# --------------------------------------------

if __name__ == '__main__':      
    start = time.time()   

s.useStocksCurrentDB()
setConfig()

#s.MULTIPROC = False
if __name__ == '__main__':    
    s.createDBIfNeeded()


def run():
    mech = mechTM.MechTM()     
    #mech.SCRIPS = [ 'SBIN' ]
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

