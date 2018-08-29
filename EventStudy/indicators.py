import numpy as np
import pandas as pd

from settings import s

''' bars since last signal
    b = BarIndex ( For Event = True index is same as previous row, but is irrelevant )
    c = b - x
    x = Take only index(b) of Event bars and then copy it forward on all subsequent non event bars
'''
def barsSince(event):
    b = (~event).cumsum()
    c = b - b.where(event).ffill().fillna(1).astype(int)
    return c

# signal within lookback
def recent(lookback, signal):
    return (signal.rolling(lookback, min_periods=lookback).sum().shift(1) > 0)
    
# -----------------------------------     


def ema( bars_field, n=20 ):
    return bars_field.ewm( span=n, adjust=False).mean()
    
def sma( bars_field, n=20 ):
    return bars_field.rolling( n, min_periods=n ).mean()
    
'''
Wilders Smoothing(n) = EMA(2n-1)
    ATR(x) = a*TrueRange + (1-a)*Ref(ATR,-1)
    EMA : a = 2/(n+1)
    WS  : a = 1/n.          
        WS has separate logic for initial n bars. Not using it here
        This difference can cause slightly different EMA & atr for initial period
    AB :  _ATR = EMA( ATR(1), 2*Periods-1 )
'''
def atr( bars, n=20  ):
    prevc = bars['C'].shift(1)
    with np.errstate(invalid='ignore'):                 # suppress nan warning due to shift
        tr =  np.maximum( bars['H']-bars['L'],
                           np.maximum( np.absolute( prevc-bars['H'] ),
                                       np.absolute( prevc-bars['L'] )
                         )
                     )
        tr[0] =  bars['H'][0]-bars['L'][0]
        
        return ema(tr, n*2-1)

'''
SigmaSpike = today's return / yesterday's stdev

std() by default uses ddof=1 (Sample SD)
  Sample SD estimates SD of entire population using input sample
  ddof=0 => Population SD. Input is entire population. Also used by AB by default
  https://math.stackexchange.com/questions/15098/sample-standard-deviation-vs-population-standard-deviation
'''
def sigmaSpike( C, n=20 ):
    returns     = C / C.shift(1) - 1
    returnsStd  = returns.rolling(n, min_periods=n).std(ddof=0)    
    SigmaSpike  = returns  / returnsStd.shift(1)  

    SigmaSpike[0:n+2] = False

    return SigmaSpike

    
def keltnerBands( bars, top=True, bottom=True ):
    _ema   = ema( bars['C'], s.KB_PERIOD )
    _atr   = atr( bars,      s.KB_PERIOD )
    width  = s.KB_BAND_WIDTH * _atr    
    
    KTop   = _ema + width if top     else None
    KBot   = _ema - width if bottom  else None

    return ( KTop, _ema, KBot  )

def KBTop( bars ):
    KTop, x, y = keltnerBands(bars, bottom=False)
    return KTop

def KBBottom( bars ):
    x, y, KBot = keltnerBands(bars, top=False)
    return KBot
    
#def kpos( bars ) :
    # KTop, ema, x = keltnerBands(bars, bottom=False  )    
    # KPos = (bars['C']-ema) / ( KTop - ema )*100;	    


# Slow = MA( Fast, 16 );	
def macdFast(C):
    return  sma(C, 3) - sma(C, 10) 

    
# Rolling max/min using Interval lookback for intraday HOD/LOD
def hod( bars, lookback = '12H' ):    
    return bars['H'].rolling(lookback).max()

def lod( bars, lookback = '12H' ):    
    return bars['L'].rolling(lookback).min()

# hod extended beyond KB
def hodExtended( bars ):

    hodAll       = hod( bars )                                     # HOD that may or may not be beyond bands        
    ktop         = KBTop( bars )
    H            = bars['H']
    highExtended = H.where( H > ktop, 0 )                         # HOD that is extended beyond bands
    hodExtended  = highExtended.rolling('12H').max()              # But may have been broken later with a new HOD that didnt close beyond band
    hodExtended.where( hodExtended == hodAll, inplace=True  )     # Return extended hod only if not broken ( and so high is same as real hod )

    return hodExtended
   
def lodExtended( bars ):
    INFINITY     = 9999999
    lodAll       = lod( bars )
    kbot         = KBBottom( bars )
    L            = bars['L']
    lowExtended  = L.where( L < kbot, INFINITY )
    lodExtended  = lowExtended.rolling('12H').min()
    lodExtended.where( lodExtended == lodAll, inplace=True  )

    return lodExtended
   
