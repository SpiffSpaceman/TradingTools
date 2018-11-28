import os
import sys
import datetime

from   multiprocessing import Pool
from   itertools import chain
import pandas as pd

import database
import indicators
import signals
from settings import s

# Helper functions 

def markTargetHit( trade, targetPrice ):
        
    output = trade._asdict()
    
    output['T1']            = targetPrice
    output['Trail']         = targetPrice                                           # For only 1 part test - Set all to same price        
    output['TrailTrigger']  = targetPrice        
    output['T1Qty']         = output['Qty']
    
    output['T2']    = 0
    output['T2Qty'] = 0
    
    return output

def markClosedAtCurrentPrice( trade, bar ):                                         # manually close trade at current bar
    output = trade._asdict()
    
    closePrice              = bar.C
    output['Trail']         = closePrice        
    output['TrailTrigger']  = closePrice
    
    output['T1']    = 0
    output['T1Qty'] = 0
    output['T2']    = 0
    output['T2Qty'] = 0
    
    return output

def markStopHit( trade, bar, stopPrice   ):

    output = trade._asdict()
                                                                                    # Stop outside bar range => stop slipped, take open price    
    if( (trade.isLong and bar.O < stopPrice)  or ( not trade.isLong and bar.O > stopPrice ) ) :
        stopPrice = bar.O

    output['Trail']         = stopPrice        
    output['TrailTrigger']  = stopPrice
    
    output['T1']    = 0
    output['T1Qty'] = 0
    output['T2']    = 0
    output['T2Qty'] = 0
    
    return output

   
def getExtremePrice( trade, bar, currentExtreme ):                                  # If new H/L(from entry) made in this bar, return it
    
    if trade.isLong :
        barExtreme = bar.H
        if(  barExtreme > currentExtreme  ):
            return barExtreme
    else : 
        barExtreme = bar.L
        if(  barExtreme < currentExtreme  ):
            return barExtreme
    
    return currentExtreme    

def getTrailPrice( trade, bar, maxStop, extremePrice, distance ):

    if( trade.isLong ):
        stop = extremePrice - distance
        if( stop < maxStop ):                                                     # Dont set trailing stop beyond maxStop
            stop = maxStop
        if( stop >= bar.C ):                                                      # If Stop is beyond current price, close position at current price  
            stop = bar.C
    else:
        stop = extremePrice + distance
        if( stop > maxStop ):
            stop = maxStop
        if( stop <= bar.C ):
            stop = bar.C

    return stop    

def currentTradeStatus( trade, initStop, bar ):

    entryPrice       = trade.PriceInTrigger    
    initStopDistance = entryPrice - initStop
    
    return (bar.C - entryPrice)/ initStopDistance   
    


    
# Log Fields -  Setup,isNested,Tags,Date,Time,Market,InitStop,PriceIn,Trail,T1,T2,Qty,T1Qty,T2Qty,ExpenseAmt,Mistakes,Comment,TrailTrigger,PriceInTrigger,StopTime,T1Time,T2Time
class MechTM:    
    def __init__(self):

        self.isMechEntry = s.SIGNAL_FN is not None
    
        if( self.isMechEntry ):
            self.SCRIPS = s.SCRIPS                                                      # Use scrips in database. Can be filtered using config/scrips.txt
        else :
            file        = open( s.MECHTM_INPUT_LOG, 'r')
            self.trades = pd.read_csv(file)        
            file.close()
            
            self.SCRIPS = pd.unique( self.trades['Market'] )                            # All unique markets traded
    
     

    # Set ATR Based stops
    def _getInitStopATR( self, trade, bars, tradeBarIndex ):        
        
        atr              = indicators.atr( bars, s.MECHTM_STOP_ATR_LOOKBACK )
        previousBarIndex = tradeBarIndex - datetime.timedelta(minutes=5)                 # Use previous bar's ATR
        
        if( s.MECHTM_STOP_MAX_ATR_LOOKBACK > 1 ):                                        # Use Highest atr within lookback
            atr = atr.rolling( s.MECHTM_STOP_MAX_ATR_LOOKBACK, min_periods=s.MECHTM_STOP_MAX_ATR_LOOKBACK ).max()

        stopATR          = atr[previousBarIndex]
        entry            = trade.PriceIn

        if( trade.isLong ):
            stop = entry - stopATR * s.MECHTM_STOP_ATR_MULTIPLIER
        else:
            stop = entry + stopATR * s.MECHTM_STOP_ATR_MULTIPLIER

        return stop

 


    def _stopHit( self, trade, bar, stop  ):
        
        isLong = trade.isLong 
        
        if( isLong and bar.L <= stop) or ( not isLong and bar.H >= stop ):                 # Stop hit ? 
            return markStopHit( trade, bar, stop )   

        return False
        
    def _targetHit( self, trade, bar, target  ):        
        
        isLong = trade.isLong 
        
        if( isLong and bar.H > target) or ( not isLong and bar.L < target ):               # Target hit ? 
            return markTargetHit( trade, target  )

        return False

    def _timeIsUp( self, trade, bar ):
        
        hr  = bar.Index.hour
        min = bar.Index.minute
                                                                                           # Exit before 15:20 
        if( (hr > s.MECHTM_CLOSING_TIME[0]) or (hr == s.MECHTM_CLOSING_TIME[0] and min >= s.MECHTM_CLOSING_TIME[1]) ):
            return markClosedAtCurrentPrice( trade, bar )

        return False









    # Generate Tradelog from Mechanical Entry signal ( entry generated by s.SIGNAL_FN )
    def _generateMechEntrySignals( self, scrip, bars ):

        if( s.MECHTM_DIRECTION != s.DIRECTION.LONG_ONLY and s.MECHTM_DIRECTION != s.DIRECTION.SHORT_ONLY ) : 
            print( 'Set Mech signal direction to either long or short' )                
            sys.exit()
        
        s.MECHTM_STOP_OVERRIDE = True                                                   # Stops will always be generated for mech entries

        s.setTimeFilter( s.MECHTM_START_TIME, s.MECHTM_END_TIME )
        signal = signals.signalFilter( s.SIGNAL_FN( scrip, bars ), bars )               # Get mech signals and filter out some based on config
        signal = signal[ signal == True ]                                               # Filter out False

        if( len(signal) == 0 ):                                                         # No entry signal for scrip, return Empty dataframe
            return pd.DataFrame(columns=['PriceIn','PriceInTrigger','Date','Time','Market','isLong','Qty','ExpenseAmt','Setup' ])
                    
        scripTrades = bars[ bars.index.isin(signal.index) ]                             # Generate Input Trade log from signal
        scripTrades['PriceIn']          = scripTrades['C']
        scripTrades['PriceInTrigger']   = scripTrades['PriceIn']
        scripTrades['Date']             = scripTrades.index.strftime('%Y-%m-%d')
        scripTrades['Time']             = scripTrades.index.time            
        scripTrades['Market']           = scrip
        scripTrades['isLong']           = s.MECHTM_DIRECTION == s.DIRECTION.LONG_ONLY
        
        scripTrades['Qty']              = 100                                           # Dummy Qty
        scripTrades['ExpenseAmt']       = 0
        scripTrades['Setup']            = "Mech"

        return scripTrades

    def _locateTrade( self, bars, trade  ):
        # -- Locate Data -- 
        if( self.isMechEntry ):
            barsAfterEntry = bars[trade.Date].between_time( trade.Time, '1535' )        # Select Day's data from Entry bar using datetimeindex
            tradeBarIndex  = barsAfterEntry.index[0]
        else:
            # Workaround code - take datetimeindex and refer to previous bar
                #   Panda DB   - 5m resampled bar is labeled on right. So 14:19 is 14:14-14:19. 15:29:XX goes to 15:34:00
                #   AB Live DB - has random second boundaries, different on different days. Panda DB aligns to 00 second boundary => some accuracy is lost in boundary minutes
                #   So, ** trade.Time may resolve to entry bar or to the bar after entry bar **.  This wont be issue when all bars are marked at 00 seconds in source DB
                #   Workaround - Subtract 5m. This will resolve to entry bar or to the bar before, both should be ok

            barsOnDay      = bars[trade.Date]                                                  # All bars on day of trade
            barsAfterEntry = barsOnDay.between_time( trade.Time, '1535' )                      # Day's data from Entry bar to EOD
            
            tradeBarIndex  = barsAfterEntry.index[0] - datetime.timedelta(minutes=5)           # Shift to previous bar
            barsAfterEntry = barsOnDay.between_time( tradeBarIndex.time(), '1535' )
            # Workaround End    
        
        return ( barsAfterEntry, tradeBarIndex )
    
    def _getQueryFilter( self, trades ):
    
        field, operator, value = s.MECHTM_QUERY
            
        if( operator == s.OPERATOR.EQUALS ):
            filter = trades[ field  ] == value
        elif( operator == s.OPERATOR.CONTAINS ):
            filter = trades[ field  ].str.contains( value, na=False ) 

        return filter
        
    def _filterTrades( self, scrip, scripTrades  ):
        
        if( not self.isMechEntry ):                                                         # Mech signals have already been filtered for Time Range and are always either Long only or Short only
            t = scripTrades                                                                 # Trades taken in this scrip within allowed time range
            scripTrades = t[ (t['Market'] == scrip) & (t['Time'] >= s.MECHTM_START_TIME) & (t['Time'] <= s.MECHTM_END_TIME) ]

            if( s.MECHTM_DIRECTION == s.DIRECTION.LONG_ONLY ) :                             # Filter out shorts
                scripTrades = scripTrades[  scripTrades['isLong']   ]
            if( s.MECHTM_DIRECTION == s.DIRECTION.SHORT_ONLY ) :                            # Filter out Longs
                scripTrades = scripTrades[  ~scripTrades['isLong']   ]

        if s.SIGNAL_START_DATE != "" :                                                      # Filter out data outside date range
            filter      = scripTrades['Date'] >= s.SIGNAL_START_DATE                        # Date field does not have Time. Pass false to s.setDateFilter(). Otherwise the filter wont include boundary dates
            scripTrades = scripTrades[ filter ]

        if s.SIGNAL_END_DATE != "" :
            filter      = scripTrades['Date'] <= s.SIGNAL_END_DATE 
            scripTrades = scripTrades[ filter ]
                
        if s.MECHTM_QUERY is not None:                                                      # Custom query on csv fields
            filter      = self._getQueryFilter( scripTrades )
            scripTrades = scripTrades[ filter ]
        
        return scripTrades

    def _loadTradesForScrip( self, scrip, bars ):

        if( self.isMechEntry ):                                                             # generate input trade log using Mechanical signals
            scripTrades = self._generateMechEntrySignals( scrip, bars  )
        else:
            scripTrades = self.trades                                                       # Load trades from input tradelog
            scripTrades['isLong'] = scripTrades['PriceIn'] > scripTrades['InitStop']

        scripTrades = self._filterTrades( scrip, scripTrades )                              # Filter out trades as per settings

        return scripTrades




    def _processScrip( self, scrip ):
        pd.options.mode.chained_assignment = None                                          # Hide warning on sliced data update. We dont need to update it back to source

        if(  scrip in s.MECHTM_IGNORE_SCRIPS ):                                            # Ignore trades in some scrips
            return []
        
        # -- Load Trade Database -- 
        try:
            bars = database.loadScripRandomDB( scrip ) if s.DB_RANDOM else database.loadScripDB( scrip )
        except IOError:   
            print( scrip, " Not Found" )
            return None             
        
        
        # -- Load Trade Log or generate tradelog from Mech signal -- 
        scripTrades = self._loadTradesForScrip( scrip, bars )

        if( s.MECHTM_ISTRAIL_ENABLED ):                                                     # Calculate atr array once per scrip - used for atr trail
            trailAtr = indicators.atr( bars, s.MECHTM_TRAIL_ATR_LOOKBACK )
                
        if( s.MECHTM_CALLBACK_SCRIP_CHANGE_FN is not None ):                                # Callback to allow setting up per scrip datastuctures that can be used for bar-by-bar callbacks
            s.MECHTM_CALLBACK_SCRIP_CHANGE_FN( bars )
        
        # -- For each trade, go bar by bar and look for exit rule

        outputTrades = []                                                                   # Make list of dictionary. These trades will be used to write output csv
                                                                                           
        for trade in scripTrades.itertuples():

            barsAfterEntry, tradeBarIndex  = self._locateTrade( bars, trade )               # Locate Trade bar in database

            # -- Start Mech TM -- 

            entry = trade.PriceIn

            if( s.MECHTM_STOP_OVERRIDE ):
                initStop  = self._getInitStopATR( trade, bars, tradeBarIndex )
            else :
                initStop  = trade.InitStop

            diff    = trade.PriceInTrigger - initStop                                         # Projecting target from triggered price similar to Live
            target  = trade.PriceInTrigger + s.MECHTM_TARGET_X * diff
            stop    = initStop

            firstBar     = barsAfterEntry.iloc[0]
            closePrice   = firstBar['C']
            extremePrice = firstBar['H'] if trade.isLong else firstBar['L']

            
            if(  abs(closePrice-entry) / entry  > 0.01  ):                                    # Split/Bonus etc issues. Detect difference > 1%  
                print( scrip, "Large Price difference. Database Price:", closePrice, "Trade Entry Price:", entry )

                
            barsHeld = 0                                                                      # Trade Holding Time, might show 1 extra bar due to workaround above

            if( s.MECHTM_CALLBACK_TRADE_CHANGE_FN is not None ):                              # Callback to allow setting up per trade datastuctures that can be used for bar-by-bar callbacks
                s.MECHTM_CALLBACK_TRADE_CHANGE_FN( trade, firstBar )
            
            for bar in barsAfterEntry.itertuples():                                           # Iterate bar by bar after entry and look for exit            
                
                barsHeld += 1
                
                if( self.isMechEntry and barsHeld == 1):                                      # Mech Trades are on close, ignore 1st bar  
                    continue

                closedTrade = self._stopHit( trade, bar, stop  )
                if( closedTrade ):                                                            # Stop hit ?
                    break
                    
                closedTrade = self._targetHit( trade, bar, target  )                          # Target hit ?   
                if(closedTrade):                
                    break       

                closedTrade = self._timeIsUp( trade, bar )                                    # Exit before 15:20
                if(closedTrade):
                    break

                if( s.MECHTM_CALLBACK_EXIT_FN is not None ):                                  # Custom rule to exit trade
                    closedTrade = s.MECHTM_CALLBACK_EXIT_FN( trade, bar, initStop  )
                    if(closedTrade):
                        break
                        
                if( s.MECHTM_CALLBACK_STOP_FN is not None ):                                  # Custom rule to update Stop
                    stop = s.MECHTM_CALLBACK_STOP_FN( trade, bar, initStop, stop   )

                if( s.MECHTM_ISTRAIL_ENABLED ):                                               # Trail stop. But never more than InitStop
                    
                    extremePrice  = getExtremePrice( trade, bar, extremePrice )
                    distance      = trailAtr[bar.Index] * s.MECHTM_TRAIL_ATR_MULTIPLIER       # Use current bar's atr. Stop applies to next bar    
                    
                    if( s.MECHTM_TRAIL_MOVE_BACK_STOP ):
                        stop = getTrailPrice( trade, bar, initStop, extremePrice, distance  )      # Dont allow moving behind initStop
                    else:
                        stop = getTrailPrice( trade, bar, stop, extremePrice, distance  )          # Dont allow moving behind current stop

                if( stop == bar.C ):                                                          # Trailing Stop went ahead of current price
                    closedTrade = markClosedAtCurrentPrice( trade, bar )
                    break

                if( (trade.isLong and stop < initStop )  or (not trade.isLong and stop > initStop )  ) : 
                        raise Exception( 'Stop moved behind initStop' )

                if( (trade.isLong and stop > bar.C)  or (not trade.isLong and stop < bar.C )  ) : 
                    raise Exception( 'Stop moved ahead of price' )


            if( closedTrade ):
                closedTrade['InitStop'] = initStop                                            # Add Closed trade to output list
                closedTrade['BarsHeld'] = barsHeld
                outputTrades.append( closedTrade )
            else:
                print( "Trade not closed : ",  trade )

            
        return outputTrades
                
    
    def processLog( self ):
        results = []                                                                           # List of output DFs. Each DF has trades of one scrip
    
        if s.MULTIPROC :                                                                       # Tradelog later is single threaded 
            pool    = Pool( s.PROCESS_COUNT )
            results = pool.map( self._processScrip, self.SCRIPS )
            
            results = list( chain.from_iterable( results ) )                                   # Flatten List of List  
            
            pool.close()
            pool.join()
        else:        
            for scrip in self.SCRIPS:            
                results.extend( self._processScrip( scrip )  )                                 # Output is a list of OrderedDict
        
        
        outputTrades = pd.DataFrame( results )
        
        if( self.isMechEntry ):                                                                # Sort Trades by Date-Time
            outputTrades.set_index( 'Index', inplace=True)
            outputTrades.sort_index( inplace=True )
        else :
            outputTrades.sort_values( ['Date', 'Time'], ascending=[True,True], inplace=True )

        outputTrades.to_csv( s.OUTPUT_FOLDER + '/tradelogMech.csv' )                           # Generate newlog
                
        print( 'Running Tradelog')
        
        filePath = os.path.abspath(s.OUTPUT_FOLDER) + "/tradelogMech.csv"                      # Run Tradelog.py over generated log
        os.system('python ../TradeLog/Tradelog.py ' + filePath   )
