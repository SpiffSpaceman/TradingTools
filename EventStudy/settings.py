import os
import multiprocessing

from enum import Enum

import util

'''
NOTE - All folder paths should end with '/'
       Date Strings should be correct dates, Ex 20170930 is correct but 20170931 will give error

SIGNAL_FN  - signal function A(scrip, bars) to be tested

DBPATH     - If folder empty, new DB will be created using input CSV. Else assume DB is up to date
INPUT_CSV  - Input csv file or folder 
             All quotes of a scrip must be within a single file
             Using multiple csvs for import is done in parallel and is faster
CSV_FIELDS - Array of Field names or position indices to pick columns in  csv. Order must match with DB_FIELDS
             If Position indices are used, csv will be assumed to have no header row
DB_FIELDS  - Map CSV fields to dataframe fields.  S=Symbol, D=Date, T=Time + O/H/L/C/V      
             If Symbol(S) is not present, filename will be used as Symbol
             If Time(T) is present, data is assumed to be 1m intraday 
DB_FROM_DATE - Filter out old data. Applied during DB creation
DB_RESAMPLE_TF    - Change DB Timeframe. http://pandas.pydata.org/pandas-docs/stable/timeseries.html#offset-aliases
                    Right Extreme is included in bar and is used as label
DB_RESAMPLE_BASE  - Minute to choose as Right extreme. For 5min resample, value can be 0-4.  4 => 09:19, 09:24 etc
DB_RANDOM         - Test against ramdomized database


SIGNAL_START_DATE - Filter out signals before start date
SIGNAL_END_DATE   - Filter out signals after end date 
SCRIPS_LIST       - Filter out signals in scrips that are not in this list. Leave empty to process all
                      This is used both during initial DB creation and in later queries
                      So DB can have a subset of source and query can have a subset of DB scrips

SIGNAL_START_TIME,SIGNAL_END_TIME - Filter out intraday signals outside this range

DAYS                - Array of Event Study Periods. Open Trades are filtered out
SKIP_INITIAL_BARS   - Skip signals for some bars from DB/Stock start date
                      Allows indicators (esp EMA) to set  
                      Extending DB_FROM_DATE wont help as some stocks can start midway
PRICE_CUTOFF        - Ignore signals if price is below cutoff
FILTER_NEAR_SIGNALS - Ignore signal within 10 bars of previous signal

MULTIPROC           - Enable Multi Processing
PROCESS_COUNT       - Number of processes to use. Uses all cores by default

EXPORT_TRADES       - Export Trades to trades.csv
EXPORT_TRADES_DAY   - How many days to hold in exported trades. Must be from DAYS[]
'''


class Settings:    
    
    class DIRECTION(Enum):                              # For MECHTM_DIRECTION
        BOTH        = 0
        LONG_ONLY   = 1
        SHORT_ONLY  = 2
        
    class OPERATOR(Enum):                               # For MECHTM_QUERY
        EQUALS      = 0
        CONTAINS    = 1

    def __init__(self):
        self.SIGNAL_FN           = None        
        self.DBPATH              = ''    
        self.INPUT_CSV           = ''
        self.CSV_FIELDS          = []
        self.DB_FIELDS           = [] 
        self.DB_FROM_DATE        = '' 
        self.DB_RESAMPLE_TF      = ''
        self.DB_RESAMPLE_BASE    = 0

        self.SIGNAL_START_DATE   = '' 
        self.SIGNAL_END_DATE     = ''
        self.SIGNAL_START_TIME   = ''
        self.SIGNAL_END_TIME     = ''
        self.DB_RANDOM           = False
        
        self.SCRIPS              = {}    
        self.SCRIPS_LIST         = "config/scrips.txt"
        self.OUTPUT_FOLDER       = 'output/' 
        
        self.DAYS                = [1,2,3,4,5,10,15,20]
        self.SKIP_INITIAL_BARS   = 100   
        self.PRICE_CUTOFF        = 0
        self.FILTER_NEAR_SIGNALS = True

        self.MULTIPROC           = True
        self.PROCESS_COUNT       = multiprocessing.cpu_count()
        self.EXPORT_TRADES       = False
        self.EXPORT_TRADES_DAY   = 5
        
        self.KB_PERIOD           = 20
        self.KB_BAND_WIDTH       = 2.25
        
        self.RANDOM_DBPATH       = '' 
        
        # ------------ MechTM ------------
        
        self.MECHTM_INPUT_LOG           = "config/tradelog.csv"
        
        # Entry can be overrided to use Mech entry signals instead of input tradelog. Call settings.setSignalFunction(). Look at signals.py 
            # This reuses SIGNAL_FN, SIGNAL_START_DATE, SIGNAL_END_DATE, SCRIPS/SCRIPS_LIST, PRICE_CUTOFF/FILTER_NEAR_SIGNALS/SKIP_INITIAL_BARS from above
            # List of scrips can be set in config/scrips.txt. If not set, we will use all scrips in database
            # Note - set MECHTM_DIRECTION as either LONG_ONLY or SHORT_ONLY. This will be taken as trade direction after mech signal
            #        Stop will then be set using MECHTM_STOP_ATR_MULTIPLIER/MECHTM_STOP_ATR_LOOKBACK
        
        self.MECHTM_STOP_OVERRIDE       = False                         # Override InitStop, replacing tradelog data with atr based stops 
        self.MECHTM_STOP_ATR_MULTIPLIER = 5
        self.MECHTM_STOP_ATR_LOOKBACK   = 20
        
        self.MECHTM_TARGET_X            = 1                             # Target multiplier
        
        self.MECHTM_ISTRAIL_ENABLED      = False                        # Trail by x ATR after very bar. Will not exceed InitStop
        self.MECHTM_TRAIL_MOVE_BACK_STOP = True                         # Allow moving stop back on volatility expansion ( But never more than initStop )
        self.MECHTM_TRAIL_ATR_MULTIPLIER = 6
        self.MECHTM_TRAIL_ATR_LOOKBACK   = 20

        self.MECHTM_DIRECTION           = self.DIRECTION.BOTH           # Option to retrict to only long/short trades. For mech entry signals, this indicates whether we are testing Longs or Shorts
        
        self.MECHTM_START_TIME          = "09:20:00"                    # Filter out trades not within range
        self.MECHTM_END_TIME            = "15:30:00"
        
        self.MECHTM_CLOSING_TIME        = ( 15, 19 )                    # when to close open position
        
        self.MECHTM_QUERY               = None                          # Allows selecting rows from input csv. Ex check if 'Setup' = 'Flag' or if tags contains 'Results'
                                                                        # Tuple with 3 fields. [0] = csv field name.  [1] = operator ( use OPERATOR enum )   [2] = value to compare against
        
        #----
        self.MECHTM_CALLBACK_SCRIP_CHANGE_FN = None                     # Callback function called once per scrip. Can be used to setup data for bar-by-bar callback functions. Input = Scrip bars 
        self.MECHTM_CALLBACK_TRADE_CHANGE_FN = None                     # Callback function called once per trade. Input = Trade details, firstBar

                                                                        # Callback functions for custom TM - called every bar
        self.MECHTM_CALLBACK_EXIT_FN    = None                          # Trade Exit rules ( trade, bar, initStop  )
        self.MECHTM_CALLBACK_STOP_FN    = None                          # Move Stop.  ( trade, bar, initStop, currentStop )
        
        #self.MECHTM_CALLBACK_TARGET_FN  = None
        

        # ------------ MechTM End ------------




    def useStocksCurrentDB( self ):
        if os.name == 'nt':
            self.DBPATH              = 'E:/Data/Stats/DB/StocksCurrent5m/'
            self.INPUT_CSV           = 'E:/Data/Stats/source/IntraDay/ABCurrent/Stocks/'
        else:
            self.DBPATH              = '/media/Temp/Data/Stats/DB/StocksCurrent5m/'
            self.INPUT_CSV           = '/media/Temp/Data/Stats/source/IntraDay/ABCurrent/Stocks/'

        self.CSV_FIELDS          = ['Ticker','Date','Time','Open','High','Low','Close']
        self.DB_FIELDS           = ['S','D','T', 'O', 'H', 'L', 'C']         
        self.DB_RESAMPLE_TF      = '5min'
        self.DB_RESAMPLE_BASE    = 4
        
        self.__setDB()
    
    def useStocksDB( self ):
        if os.name == 'nt':
            self.DBPATH              = 'E:/Data/Stats/DB/StocksFull5m/'
            self.INPUT_CSV           = 'E:/Data/Stats/source/IntraDay/Nifty50/Stocks/'
        else:
            self.DBPATH              = '/media/Temp/Data/Stats/DB/StocksFull5m/'
            self.INPUT_CSV           = '/media/Temp/Data/Stats/source/IntraDay/Nifty50/Stocks/'

        self.CSV_FIELDS          = ['Ticker','Date','Time','Open','High','Low','Close']
        self.DB_FIELDS           = ['S','D','T', 'O', 'H', 'L', 'C']         
        self.DB_RESAMPLE_TF      = '5min'
        self.DB_RESAMPLE_BASE    = 4
        
        self.__setDB()

    def useStocksDB1m(self):
        if os.name == 'nt':
            self.DBPATH = 'E:/Data/Stats/DB/StocksFull1m/'
            self.INPUT_CSV = 'E:/Data/Stats/source/IntraDay/Nifty50/Stocks/'
        else:
            self.DBPATH = '/media/Temp/Data/Stats/DB/StocksFull1m/'
            self.INPUT_CSV = '/media/Temp/Data/Stats/source/IntraDay/Nifty50/Stocks/'

        self.CSV_FIELDS = ['Ticker', 'Date', 'Time', 'Open', 'High', 'Low', 'Close']
        self.DB_FIELDS = ['S', 'D', 'T', 'O', 'H', 'L', 'C']

        self.__setDB()
        
    def useNiftyIndexDB( self ):
        if os.name == 'nt':
            self.DBPATH              = 'E:/Data/Stats/DB/Nifty505m/'
            self.INPUT_CSV           = 'E:/Data/Stats/source/IntraDay/Nifty50/Index/NIFTY.txt'
        else:
            self.DBPATH              = '/media/Temp/Data/Stats/DB/Nifty505m/'
            self.INPUT_CSV           = '/media/Temp/Data/Stats/source/IntraDay/Nifty50/Index/NIFTY.txt'
        self.CSV_FIELDS          = [0,1,2,3,4,5,6]
        self.DB_FIELDS           = ['S','D','T', 'O', 'H', 'L', 'C']
        self.DB_RESAMPLE_TF      = '5min'
        self.DB_RESAMPLE_BASE    = 4
        
        self.__setDB()

    def useBankNiftyIndexDB(self):
        if os.name == 'nt':
            self.DBPATH = 'E:/Data/Stats/DB/BankNifty5m/'
            self.INPUT_CSV = 'E:/Data/Stats/source/IntraDay/Nifty50/Index/BANKNIFTY.txt'        
        else:
            self.DBPATH = '/media/Temp/Data/Stats/DB/BankNifty5m/'
            self.INPUT_CSV = '/media/Temp/Data/Stats/source/IntraDay/Nifty50/Index/BANKNIFTY.txt'
        self.CSV_FIELDS = [0, 1, 2, 3, 4, 5, 6]
        self.DB_FIELDS = ['S', 'D', 'T', 'O', 'H', 'L', 'C']
        self.DB_RESAMPLE_TF = '5min'
        self.DB_RESAMPLE_BASE = 4

        self.__setDB()

    def setTimeFilter( self, startTime, endTime ):
    
        self.SIGNAL_START_TIME = startTime
        self.SIGNAL_END_TIME   = endTime
        
        st = startTime != ""                                                # Setup Start Time / End time missing values
        et = endTime   != ""

        if st and not et:
            self.SIGNAL_END_TIME   = "23:59:59"
        if et and not st:
            self.SIGNAL_START_TIME = "00:00:00"         
    
    def setDateFilter( self, startDate, endDate, isAddTime=True ):
    
        self.SIGNAL_START_DATE = startDate
        self.SIGNAL_END_DATE   = endDate
        
        if self.IS_INTRADAY and isAddTime:
            if( self.SIGNAL_START_DATE != "" ):                            # Convert Date to DateTime
                self.SIGNAL_START_DATE += " 00:00:00"
            if( self.SIGNAL_END_DATE != "" ):
                self.SIGNAL_END_DATE += " 23:59:59"
             
    def setSignalFunction( self, func ):
        self.SIGNAL_FN = func

    # Should be called after selecting DB
    def enableRandomDB( self, toggle=True ):
        self.DB_RANDOM = toggle        
        if( toggle ):
            self.__setDB()
    
    def createDBIfNeeded( self ):
        from database import createDB, createRandomDB

        if( not self.DB_SCRIPS ):        
            createDB()
            self.__updateScrips()
                
        if( self.DB_RANDOM and not util.filesInDir(self.RANDOM_DBPATH) ):
            createRandomDB()
            
    def __updateScrips( self ):
        self.DB_SCRIPS  = util.filesInDir(self.DBPATH)                          # Set ScripList to query = Input config list if set Else take all scrips in Database
                                                                                 # Random DB will have same scrips as real DB, so no need to scan it
        if os.path.isfile(self.SCRIPS_LIST): 
            self.SCRIPS = set(line.strip() for line in open(self.SCRIPS_LIST))
        if not self.SCRIPS and self.DB_SCRIPS:
            self.SCRIPS = set(self.DB_SCRIPS)

    def __setDB( self ):
    
        self.RANDOM_DBPATH          = self.DBPATH + 'RANDOM/'            
        self.IS_CSV_HEADERLESS      = isinstance( self.CSV_FIELDS[0], int ) # Assume no header in csv if fields are integer indices
        self.USE_FILENAME_AS_TICKER = 'S' not in self.DB_FIELDS             # If no Symbol field, pick up Symbol from file name
        self.IS_INTRADAY            = 'T' in self.DB_FIELDS                 # Intraday Mode if 'T' in fields list

        self.CSV_HEADER_DATE = self.CSV_FIELDS[ self.DB_FIELDS.index('D')]  # Index of Date in CSV_FIELDS   
        self.CSV_HEADER_TIME = self.CSV_FIELDS[ self.DB_FIELDS.index('T')] if self.IS_INTRADAY else ""
        
        if self.IS_INTRADAY:                                                 # Panda readcsv() ParseDates option combines Date and Time into 1 column at the 1st index
            self.DB_FIELDS.remove('D')
            self.DB_FIELDS.remove('T')
            self.DB_FIELDS.insert(0,'D')
            
            
        # Create DB if not created
        if not os.path.exists( self.DBPATH ):
            os.makedirs( self.DBPATH )
        if not os.path.exists( self.RANDOM_DBPATH ):
            os.makedirs( self.RANDOM_DBPATH )
        
        self.DB_SCRIPS  = util.filesInDir(self.DBPATH)                      # Files in Database (if created)        
        
        #createDBIfNeeded()     # Windows MP - Needs to be called by main
        self.__updateScrips()
    
        
s = Settings()



# -----------------------------------------------------------------------------------------
  
 

