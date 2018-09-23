
import mechTM
import indicators as ind

# Trade Management Prototype functions using callbacks 


# ---------- TimeStop : Trail by 2 ATR from extreme if below 0X after 20 bars  ---------
    # Trail only as long as trade is below 0X
    # Exits imm if price is behind 2 ATR from extreme
''' 
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.trailTimeStopOnScripChange
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.trailTimeStopOnTradeChange    
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnTimeStop
'''

def trailTimeStopOnScripChange( bars ):
    global trailAtr    
    
    trailAtr = ind.atr( bars, 20 )
    
def trailTimeStopOnTradeChange( trade, firstBar ):
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
        #extremePrice  = mechTM.getExtremePrice( trade, bar, extremePrice )      #  Not updated until Timestop => Trails behind recent extreme (or BO Bar whichever is further) after timestop is active
        distance      = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER
        return  mechTM.getTrailPrice( trade, bar, initStop, extremePrice, distance  ) 
    else:
        return stop
# -------------------







# ------------- Trail behind by x*ATR after price reaches yX     --------------------------
'''
    s.MECHTM_CALLBACK_SCRIP_CHANGE_FN = p.trailTimeStopOnScripChange
    s.MECHTM_CALLBACK_TRADE_CHANGE_FN = p.trailTimeStopOnTradeChange  
    s.MECHTM_CALLBACK_STOP_FN         = p.trailOnProfit
'''   

def trailOnProfit( trade, bar, initStop, stop ):
    global extremePrice, trailAtr
        
    TRAIL_ATR_MULTIPLIER = 2
    MIN_X                = 1.5
    extremePrice         = mechTM.getExtremePrice( trade, bar, extremePrice )
    
    if(  mechTM.currentTradeStatus( trade, initStop, bar ) >= MIN_X  ):        
        distance = trailAtr[bar.Index] * TRAIL_ATR_MULTIPLIER        
        return  mechTM.getTrailPrice( trade, bar, initStop, extremePrice, distance  ) 
    
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

# -------------------