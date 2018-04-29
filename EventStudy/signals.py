import numpy as np

import indicators as ind
from settings import s

scrip = None
bars = None


# Example
def signal(_s, b):
    global scrip, bars
    scrip = _s
    bars = b

    signal = trendUp() & KBTopClose()

    return signal


# -------------------------------------------------------------------------

def signalFilter(signal, bars, removeAdjacentCount=10):
        
    if( s.PRICE_CUTOFF > 0 ):                           # Price cutoff
        signal &= (bars['C'] > s.PRICE_CUTOFF)
    
    if( s.SKIP_INITIAL_BARS > 0  ):
        signal.iloc[0:s.SKIP_INITIAL_BARS] = False      # Remove initial signals for few bars to give time to indicators

    if (s.SIGNAL_START_TIME != ""):                      # Filter out signals outside time range
        signal.iloc[signal.index.indexer_between_time(s.SIGNAL_END_TIME, s.SIGNAL_START_TIME, include_start=False,
                                                      include_end=False)] = False

    if (not s.FILTER_NEAR_SIGNALS):
        return signal

    oldSignalCount = signal.sum()  # Remove signals too close to another signal
    while True:
        freeSignal   = signal & ~ind.recent(removeAdjacentCount, signal)      # Signal with no signal behind it within range
        closeSignals = signal &  ind.recent(removeAdjacentCount, freeSignal)  # signals within range of a free signal - Remove them
        signal[closeSignals] = False

        newSignalCount = signal.sum()
        if (newSignalCount == oldSignalCount):
            break
        else:
            oldSignalCount = newSignalCount

    return signal

# -------------------------------------------------------------------------

def KBBottomClose():
    x, ema, KBot = ind.keltnerBands(bars, top=False)

    signal = (bars['C'] < KBot)

    # signal = (bars['C'] < KBot) & (bars['C'].shift(1) > KBot.shift(1) )
    # signal = (bars['C'].shift(1) < KBot.shift(1)) & (bars['C'] > KBot

    return signal

def KBTopClose():
    KTop, ema, x = ind.keltnerBands(bars, bottom=False)

    signal = (bars['C'] > KTop)

    # signal = (bars['C'] > KTop) & (bars['C'].shift(1) < KTop.shift(1) )    # Prev bar closed below and this bar closed above
    # signal = (bars['C'].shift(1) > KTop.shift(1)) & (bars['C'] < KTop)     # Prev bar closed above and this bar closed below

    return signal


def emaCloseAbove():
    return bars['C'] >= ind.ema(bars['C'], 20)

def emaCloseBelow():
    return bars['C'] <= ind.ema(bars['C'], 20)


def spikeUp(threshold=2):
    signal = ind.sigmaSpike(bars['C'], s.KB_PERIOD) >= threshold
    return signal

def spikeDown(threshold=2):
    signal = ind.sigmaSpike(bars['C'], s.KB_PERIOD) <= -threshold
    return signal


'''    
Price above KB Top over lookback no of bars for atleast ktopCutoff  ( ktopCutoff between 0 and 1 ) 
      above EMA for atleast ktopCutoff and 
      above KB Bottom for atleast kbottomCutoff
'''
def trendUp(lookback=50, ktopCutoff=0.15, emaCutoff=0.8, kbottomCutoff=0.95):
    KTop, ema, KBot = ind.keltnerBands(bars)
    C = bars['C']

    aboveKBTop = (C > KTop).rolling(lookback, min_periods=lookback).sum()
    aboveMA    = (C > ema).rolling(lookback, min_periods=lookback).sum()
    aboveKBBot = (C > KBot).rolling(lookback, min_periods=lookback).sum()

    signal = (aboveKBTop > lookback * ktopCutoff) & (aboveMA > lookback * emaCutoff) & ( aboveKBBot > lookback * kbottomCutoff)

    return signal

def trendDown(lookback=50, ktopCutoff=0.95, emaCutoff=0.8, kbottomCutoff=0.15):
    KTop, ema, KBot = ind.keltnerBands(bars)
    C = bars['C']

    belowKBTop = (C < KTop).rolling(lookback, min_periods=lookback).sum()
    belowKBBot = (C < KBot).rolling(lookback, min_periods=lookback).sum()
    belowMA    = (C < ema).rolling(lookback, min_periods=lookback).sum()

    signal = (belowKBTop > lookback * ktopCutoff) & (belowMA > lookback * emaCutoff) & ( belowKBBot > lookback * kbottomCutoff)

    return signal


# H > Prev H and C >= Prev C  for n bars in a row
def nBarRunUp(n):
    H = bars['H']
    C = bars['C']

    signal = True

    for i in range(n):
        signal &= (H.shift(i) > H.shift(i + 1)) & (C.shift(i) >= C.shift(i + 1))

    return signal

def nBarRunDown(n):
    L = bars['L']
    C = bars['C']

    signal = True

    for i in range(n):
        signal &= (L.shift(i) < L.shift(i + 1)) & (C.shift(i) <= C.shift(i + 1))

    return signal

    
# Entry on close beyond channel
def donchianLong(lookback=50):

    C       = bars['C']
    channel = bars['H'].rolling(lookback, min_periods=lookback).max().shift(1)
    signal  = C > channel
    
    return signal

def donchianShort(lookback=50):

    C       = bars['C']
    channel = bars['L'].rolling(lookback, min_periods=lookback).min().shift(1)
    signal  = C < channel

    return signal
    

# Check if HOD/LOD has held for 5 bars
def __minBarsHeld( extreme, minBars ):
    holdRolling = extreme.rolling( minBars, min_periods=minBars )
    minBarsHeld = holdRolling.max() == holdRolling.min()                    # HOD has held for 5 bars
    
    # indexDate    = extreme.index.date
    # minBarsHeld &= (indexDate == np.roll( indexDate, minBars ) )           # Ignore yesterday Extreme which can be same as open bar extreme in *rare* cases
                                                                             # very slow, instead run tests from 09:45/09:44 
    return minBarsHeld
 
def newHOD( holdMinBars = 5 ):    
    hod    = ind.hod(bars).shift(1)
    signal = ( bars['H'] > hod ) & __minBarsHeld( hod, holdMinBars ) 
    return signal
    
def newLOD( holdMinBars = 5 ):
    lod    = ind.lod(bars).shift(1)
    signal = ( bars['L'] < lod ) & __minBarsHeld( lod, holdMinBars ) 
    return signal

''' BO of HOD with condition that HOD was beyond KB
holdMinBars - Only consder BOs of HOD that held for atleast 5 bars
Set s.FILTER_NEAR_SIGNALS = False to remove filtering of signals within 10 bars
'''
def newExtendedHOD( holdMinBars = 5 ):

    hod    = ind.hodExtended(bars).shift(1)
    signal = ( bars['H'] > hod ) &  __minBarsHeld( hod, holdMinBars ) 

    return signal

def newExtendedLOD( holdMinBars = 5 ):

    lod    = ind.lodExtended(bars).shift(1)
    signal = ( bars['L'] < lod ) &  __minBarsHeld( lod, holdMinBars ) 

    return signal

'''
This does not use HOD/LOD from yesterday (for all bars except 1st one - Can Set Start Time after 1st bar to avoid it )    
In trading, will prob want to use previous day extreme if part of same swing structure in trend    
Set s.FILTER_NEAR_SIGNALS = False to remove filtering of signals within 10 bars
'''
def FTShort( minRejectAtr = 0.3, hodHoldMinBars = 5 ):
    hod = ind.hodExtended(bars).shift(1)                                # use hod 1 bar behind BO bar
    bo  = ( bars['H'] > hod ) &  __minBarsHeld( hod, hodHoldMinBars ) 
    
    atrDiff   = ind.atr( bars).shift(1) * minRejectAtr                  # Min rejection distance
    ftSameBar = bo          & ( (hod-bars['C']) > atrDiff )
    ftnextBar = bo.shift(1) & ( (hod.shift(1)-bars['C']) > atrDiff )

    signal = ftSameBar | ( ftnextBar & (~ftSameBar).shift(1) )          # FT in BO bar  Or  FT in Next bar without FT in previous bar
    
    return signal

def FTLong( minRejectAtr = 0.3, lodHoldMinBars = 5 ):
    lod = ind.lodExtended(bars).shift(1)
    bo  = ( bars['L'] < lod ) &  __minBarsHeld( lod, lodHoldMinBars ) 
    
    atrDiff   = ind.atr( bars).shift(1) * minRejectAtr
    ftSameBar = bo          & ( (bars['C']-lod) > atrDiff )
    ftnextBar = bo.shift(1) & ( (bars['C']-lod.shift(1)) > atrDiff )

    signal = ftSameBar | ( ftnextBar & (~ftSameBar).shift(1) )
    
    return signal


# -------------------------------------------------------------------------


# TODO  PB
# 1) No strong momentum in PB leg 2) low ST vol vs longer term 3) VC bars
# 2) Try Momentum based PB
def pbLongKB():
    C = bars['C']

    impulse = KBTopClose()
    emaClose = emaCloseBelow()
    # emaClose   = bars['L'] <= ind.ema( C, 20 )

    isFirstClose = (ind.barsSince(emaClose).shift(1) + 1) > ind.barsSince(impulse)  # Only pick 1st close behind ema

    signal = ind.recent(30, impulse) & emaClose & isFirstClose

    return signal


s.setSignalFunction(signal)

