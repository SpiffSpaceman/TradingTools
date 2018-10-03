
import mechTM
import indicators as ind

import database
import signals as sig

# Trade Management Prototype functions using callbacks 

# ---- Compare with Nifty ------------
# Move to signals ?

def loadNifty():
    try:
        niftyBars = database.loadScripDB( 'NIFTY' ) 
    except IOError:   
        print( "NIFTY Not Found" )
        return None       
    
    return niftyBars

def niftyTrendSignal( direction, niftyBars, lookback=50 ):
    scrip = sig.scrip
    bars  = sig.bars
    
    sig.scrip = 'NIFTY'
    sig.bars  = niftyBars
    
    if( direction == "LONG" ):
        output = sig.trendUp( lookback=lookback)
    else:
        output = sig.trendDown( lookback=lookback )

    sig.scrip = scrip
    sig.bars  = bars

    return output

# --------------------------------------















# ---------- TimeStop : Trail by 2 ATR from extreme if below 0X after 20 bars  ---------
    # Trail only as long as trade is below 0X
    # Exits imm if price is behind 2 ATR from extreme
''' 
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeTrailAtr
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.onTradeChangeExtremePrice    
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnTimeStop
'''

def onScripChangeTrailAtr( bars ):
    global trailAtr    
    
    trailAtr = ind.atr( bars, 20 )
    
def onTradeChangeExtremePrice( trade, firstBar ):
    global barCount, extremePrice
    
    barCount = 0
    extremePrice = firstBar['H'] if trade.isLong else firstBar['L']

# Trail as long as price is below MIN_X
def trailOnTimeStop( trade, bar, initStop, stop ):
    global barCount, extremePrice, trailAtr
    
    TRAIL_ATR_MULTIPLIER = 2
    MIN_X                = 0
    BAR_TIME_LIMIT       = 20

    barCount  += 1    
    
    extremePrice  = mechTM.getExtremePrice( trade, bar, extremePrice ) 
    
    if( barCount >= BAR_TIME_LIMIT and mechTM.currentTradeStatus( trade, initStop, bar ) < MIN_X  ):
        # TODO try by ignoring BO Bar, ie once time limit is up, take last bar as extreme
        #extremePrice  = mechTM.getExtremePrice( trade, bar, extremePrice )      #  Not updated until Timestop => Trails behind recent extreme (or BO Bar whichever is further) after timestop is active
        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER
        stop     = mechTM.getTrailPrice( trade, bar, initStop, extremePrice, distance  ) 
    
    return stop
# -------------------







# ------------- Trail behind by x*ATR after price reaches yX     --------------------------
'''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeTrailAtr
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.onTradeChangeExtremePrice  
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnProfit
'''   

def trailOnProfit( trade, bar, initStop, stop ):
    global extremePrice, trailAtr
        
    TRAIL_ATR_MULTIPLIER = 2
    MIN_X                = 1.5
    extremePrice         = mechTM.getExtremePrice( trade, bar, extremePrice )
    
    if(  mechTM.currentTradeStatus( trade, initStop, bar ) >= MIN_X  ):        
        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER        
        stop     =  mechTM.getTrailPrice( trade, bar, initStop, extremePrice, distance  ) 
    
    return stop

# -------------------

'''
  new H/L but pin barish 
    - Look at close vs bar range
    - Look at close vs previous close  
'''
def trailOnProfit2( trade, bar, initStop, stop ):
    global extremePrice, trailAtr
        
    TRAIL_ATR_MULTIPLIER = 2
    MIN_X                = 1.5

    
    isPinBar = ( bar.H == bar.L )        
    if( not isPinBar ) :
        if trade.isLong:
            isPinBar = (bar.H-bar.C) / (bar.H-bar.L) > 0.75
        else:
            isPinBar = (bar.C-bar.L) / (bar.H-bar.L) > 0.75
    
    if( not isPinBar ):
        extremePrice = mechTM.getExtremePrice( trade, bar, extremePrice )

    if(  mechTM.currentTradeStatus( trade, initStop, bar ) >= MIN_X  ):
            distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER        
            return  mechTM.getTrailPrice( trade, bar, initStop, extremePrice, distance  ) 
    
    return stop



    
    
    
    
    

    
    
    
#  --- trail by 2 ATR behind recent extreme near closing time --- 
# Recent extreme = Extreme since Time cut off is passed
'''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeTrailAtr    
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.onTradeChangeRecentExtreme    
    s.MECHTM_CALLBACK_STOP_FN         = p.trailNearClose
'''

# Is bar Time >= Cutoff time. If isExactTimeOnly is True, then return true only if bar time matches cutoff
def isTimeTriggered( bar, TIME_CUT_OFF, isExactTimeOnly = False  ):
    hr   = bar.Index.hour
    min  = bar.Index.minute
    
    #isTime = bar.Index.hour >= TIME_CUT_OFF[0] and bar.Index.minute >= TIME_CUT_OFF[1]    

    if( isExactTimeOnly ):
        return  hr == TIME_CUT_OFF[0] and min == TIME_CUT_OFF[1]
    else:
        return (hr > TIME_CUT_OFF[0]) or ( hr == TIME_CUT_OFF[0] and min >= TIME_CUT_OFF[1] ) 


def onTradeChangeRecentExtreme( trade, firstBar ):
    global recentExtremePrice
    recentExtremePrice = None


def trailNearClose( trade, bar, initStop, stop ):
    global recentExtremePrice, trailAtr

    TRAIL_ATR_MULTIPLIER = 2                    # trail by x atr
    TIME_CUT_OFF         = ( 14, 54 )           # Trail only after cut off time    
    isTime               = isTimeTriggered( bar, TIME_CUT_OFF )
    
    # Another Wider Trail earlier
    '''
    if( not isTime ):
        TRAIL_ATR_MULTIPLIER = 5
        TIME_CUT_OFF         = ( 14, 29 )
        isTime               = isTimeTriggered( bar, TIME_CUT_OFF )
    '''

    if( isTime ):
        if(  recentExtremePrice is None ):
            recentExtremePrice = bar.H if trade.isLong else bar.L                            # Use first bar after trigger as initial extreme
        else :
            recentExtremePrice = mechTM.getExtremePrice( trade, bar, recentExtremePrice )

        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER
        stop     = mechTM.getTrailPrice( trade, bar, initStop, recentExtremePrice, distance  ) 
        #print(  trade.Market, bar.Index,  stop, "------", recentExtremePrice, trailAtr[bar.Index] )

    return stop

#  --- Trail on profit + Trail near closing time --- 
'''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeTrailAtr
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.onTradeChangeRecentExtreme2  
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnProfit4
'''   

def onTradeChangeRecentExtreme2( trade, firstBar ):
    global recentExtremePrice
    recentExtremePrice = None
    onTradeChangeExtremePrice( trade, firstBar )

def trailOnProfit4( trade, bar, initStop, stop ):
    global recentExtremePrice, extremePrice, trailAtr
        
    TRAIL_ATR_MULTIPLIER = 2
    MIN_X                = 1.5
    TIME_CUT_OFF         = ( 14,54 )             # Trail only after cut off time

    extremePrice         = mechTM.getExtremePrice( trade, bar, extremePrice )
    isTime               = isTimeTriggered( bar, TIME_CUT_OFF )

    if(  mechTM.currentTradeStatus( trade, initStop, bar ) >= MIN_X  ): 
        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER        
        stop     = mechTM.getTrailPrice( trade, bar, initStop, extremePrice, distance  )
    elif( isTime ):
        if(  recentExtremePrice is None ):
            recentExtremePrice = bar.H if trade.isLong else bar.L                            # Use first bar after trigger as initial extreme
        else :
            recentExtremePrice = mechTM.getExtremePrice( trade, bar, recentExtremePrice )

        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER
        stop     = mechTM.getTrailPrice( trade, bar, initStop, recentExtremePrice, distance  )

    return stop








# ----  Donchian Stop near closing time  --------

def isStopValid( trade, initStop, stop ):
    return ( trade.isLong and stop >= initStop ) or ( not trade.isLong and stop <= initStop  )

# Stop at previous X bar Low/High
''' 
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeDonchianStop    
    s.MECHTM_CALLBACK_STOP_FN         = p.donchianTrailNearClose
    p.DONCHIAN_LOOKBACK = 10
'''
DONCHIAN_LOOKBACK = 10

def onScripChangeDonchianStop( bars ):
    global donchianLow, donchianHigh    
    

    donchianLow  = bars.L.rolling(DONCHIAN_LOOKBACK, min_periods=DONCHIAN_LOOKBACK).min()
    donchianHigh = bars.H.rolling(DONCHIAN_LOOKBACK, min_periods=DONCHIAN_LOOKBACK).max()


def donchianTrailNearClose( trade, bar, initStop, stop ):
    global donchianLow, donchianHigh

    TIME_CUT_OFF = ( 14, 54 )                                                               # Trail only after cut off time    
    isTime       = isTimeTriggered( bar, TIME_CUT_OFF )

    if( isTime ):        
        newStop = donchianLow[ bar.Index ]  if trade.isLong  else donchianHigh[ bar.Index ]
        if isStopValid( trade, initStop, newStop ):
            stop = newStop
        #print(  trade.Market, bar.Index, stop )

    return stop
    
    
# Donchian trail for entire trade => Trend following + exit when time is up. 
    # Use longer lookbacks vs donchianTrailNearClose
    # can switch to ATR stops once trending
''' 
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeDonchianStop    
    s.MECHTM_CALLBACK_STOP_FN         = p.donchianTrail
    p.DONCHIAN_LOOKBACK = 40
'''  
def donchianTrail( trade, bar, initStop, stop ):

    newStop = donchianLow[ bar.Index ]  if trade.isLong  else donchianHigh[ bar.Index ]    
    
    if isStopValid( trade, initStop, newStop ):
        stop = newStop

    return stop


    
    
    
    
#  --- Trail on profit + Trail near closing time + initial Donchian Trail --- 
'''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeDonchianStop2
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.onTradeChangeRecentExtreme2  
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnProfit5
    p.DONCHIAN_LOOKBACK = 40
'''   
def onScripChangeDonchianStop2( bars ):
    onScripChangeDonchianStop( bars)
    onScripChangeTrailAtr( bars )

def onTradeChangeRecentExtreme2( trade, firstBar ):
    global recentExtremePrice
    recentExtremePrice = None
    onTradeChangeExtremePrice( trade, firstBar )

def trailOnProfit5( trade, bar, initStop, stop ):
    global recentExtremePrice, extremePrice, trailAtr
        
    TRAIL_ATR_MULTIPLIER = 2
    MIN_X                = 1.5
    TIME_CUT_OFF         = ( 14,54 )             # Trail only after cut off time

    extremePrice         = mechTM.getExtremePrice( trade, bar, extremePrice )
    isTime               = isTimeTriggered( bar, TIME_CUT_OFF )
    
    if(  mechTM.currentTradeStatus( trade, initStop, bar ) >= MIN_X  ): 
        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER        
        stop     = mechTM.getTrailPrice( trade, bar, initStop, extremePrice, distance  )
    elif( isTime ):
        if(  recentExtremePrice is None ):
            recentExtremePrice = bar.H if trade.isLong else bar.L                            # Use first bar after trigger as initial extreme
        else :
            recentExtremePrice = mechTM.getExtremePrice( trade, bar, recentExtremePrice )

        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER
        stop     = mechTM.getTrailPrice( trade, bar, initStop, recentExtremePrice, distance  )
    else:
        newStop = donchianLow[ bar.Index ]  if trade.isLong  else donchianHigh[ bar.Index ]        
        if isStopValid( trade, initStop, newStop ):
            stop = newStop

    return stop
   
    
    
    
    
    
    
    
    
    
    
    
    
#  --- TimeStop/Trail near closing time --- 
'''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeTrailAtr
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.onTradeChangeExtremePrice    
    s.MECHTM_CALLBACK_STOP_FN         = p.timeStopTrailNearClose
'''   
def timeStopTrailNearClose( trade, bar, initStop, stop ):
    global extremePrice, trailAtr

    TRAIL_ATR_MULTIPLIER = 2                    # trail by x atr    
    TIME_CUT_OFF         = ( 14,54 )            # Trail only after cut off time
    
    extremePrice         = mechTM.getExtremePrice( trade, bar, extremePrice )
    isTime               = isTimeTriggered( bar, TIME_CUT_OFF )
        
    # Time Stop. Only hold if price within 2 ATR of extreme and trail
    if( isTime  ):
        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER        
        stop     = mechTM.getTrailPrice( trade, bar, initStop, extremePrice, distance  ) 

    return stop
    
    

#  --- Trail on profit + Time stop/Trail near closing time --- 
'''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChangeTrailAtr
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.onTradeChangeExtremePrice  
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnProfit3
'''   

def trailOnProfit3( trade, bar, initStop, stop ):
    global extremePrice, trailAtr
        
    TRAIL_ATR_MULTIPLIER = 2
    MIN_X                = 1.5
    TIME_CUT_OFF         = ( 14,54 )             # Trail only after cut off time

    extremePrice         = mechTM.getExtremePrice( trade, bar, extremePrice )
    isTime               = isTimeTriggered( bar, TIME_CUT_OFF )
    
    #isTime = False
    
    if(  isTime or mechTM.currentTradeStatus( trade, initStop, bar ) >= MIN_X  ):        
        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER        
        stop     = mechTM.getTrailPrice( trade, bar, initStop, extremePrice, distance  ) 
    
    return stop

# -------------------












        
        
        

        
        
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------        





# ---------- TimeStop Exit below xX ---------
'''
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.timeStopOnTradeChange
    s.MECHTM_CALLBACK_EXIT_FN         = p.timeStop
'''

def timeStopOnTradeChange( trade, firstBar ):
    global barCount
    barCount = 0
    
def timeStop( trade, bar, initStop ):
    global barCount
    
    barCount += 1
    
    if( barCount >=20 and mechTM.currentTradeStatus( trade, initStop, bar ) < 0.1 ):
        return mechTM.markClosedAtCurrentPrice( trade, bar )
    else:
        return False

# -------------------




# --------- Spike UP ----------

'''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChange_exitOnSpikeUp
    s.MECHTM_CALLBACK_EXIT_FN         = p.exitNextBarOnSpikeUp
    
    s.MECHTM_CALLBACK_EXIT_FN         = p.exitOnSpikeUp
'''

def onScripChange_exitOnSpikeUp( bars ):
    global ss
    ss = ind.sigmaSpike(bars['C'], 20 )

def exitOnSpikeUp( trade, bar, initStop ):
    global ss    
    
    if( trade.isLong and ss[bar.Index] >= 5):
        #print( trade.Market, bar.Index, bar.C  )
        return mechTM.markTargetHit( trade, bar.C )

    return False

# exempt spikes close to BO time
def exitNextBarOnSpikeUp( trade, bar, initStop ):
    global ss    

    if( exitNextBarOnSpikeUp.exitNextBar == trade.Index):
        exitNextBarOnSpikeUp.exitNextBar = None
        #print( "Next Bar", trade.Market, bar.Index, bar.C  )
        return mechTM.markTargetHit( trade, bar.C )
    
    barTime   = str(bar.Index.hour) + str(bar.Index.minute)
    #tradeTime = 
    
    if( trade.isLong and ss[bar.Index] >= 5 and barTime < "1445") :
        exitNextBarOnSpikeUp.exitNextBar = trade.Index

    return False

exitNextBarOnSpikeUp.exitNextBar = None

#  --- Trail on Spike --- 
'''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.onScripChange_trailOnSpikeUp
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.onTradeChangeExtremePrice    
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnSpike
'''

def onScripChange_trailOnSpikeUp( bars ):
    global ss, trailAtr
    
    ss = ind.sigmaSpike(bars['C'], 20 )    
    trailAtr = ind.atr( bars, 20 )
   
def trailOnSpike( trade, bar, initStop, stop ):
    global extremePrice, trailAtr, ss
        
    TRAIL_ATR_MULTIPLIER = 2    
    extremePrice         = mechTM.getExtremePrice( trade, bar, extremePrice )
    spike                = ss[bar.Index]
    
    if( (trade.isLong and spike >= 5)  or ( not trade.isLong and spike <= -5) ):
        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER        
        stop     = mechTM.getTrailPrice( trade, bar, initStop, extremePrice, distance  ) 
    
    return stop



 

