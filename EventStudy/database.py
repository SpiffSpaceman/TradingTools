import pandas as pd
import os
import pickle
from multiprocessing import Pool

from settings import s



def createDB():
    
    if( os.path.isdir(s.INPUT_CSV) ):                   # If Input path is folder, parse all files
    
        csvs = (os.path.join(s.INPUT_CSV, file) for file in os.listdir(s.INPUT_CSV) 
                                                 if os.path.isfile(os.path.join(s.INPUT_CSV, file)))
        if s.MULTIPROC :            
            pool    = Pool(s.PROCESS_COUNT)
            pool.map( __createDBForScrip, csvs )
            pool.close()
            pool.join()
        else:
            for csv in csvs:
                __createDBForScrip( os.path.join(s.INPUT_CSV, csv)  )
    else:                                               # Single File, serial read
        __createDBForScrip(s.INPUT_CSV)

def createRandomDB():
        
    if s.MULTIPROC :            
        pool    = Pool(s.PROCESS_COUNT)
        pool.map( __createRandomDBForScrip, s.DB_SCRIPS )
        pool.close()
        pool.join()
    else:
        for scrip in s.DB_SCRIPS:
            __createRandomDBForScrip( scrip )
            
def loadScripDB( scrip ):    
    path = str(s.DBPATH + scrip)

    with open( path, "rb" ) as f:        
        data = pickle.load( f )

    return data
    
def loadScripRandomDB( scrip ):        
    path = str(s.RANDOM_DBPATH + scrip)

    with open( path, "rb" ) as f:        
        data = pickle.load( f )

    return data

def deleteDB():
    import shutil
        
    shutil.rmtree( s.DBPATH )     
    from time import sleep          # mkdir fails if run immediately after rmtree
    sleep(0.1)
    os.mkdir(s.DBPATH)
    

    
# ------------------------------------------------------------------------------------

    

# Create Data files for input csv
def __createDBForScrip( csv ):
    if( s.USE_FILENAME_AS_TICKER ) :                        # Scrip not in list
        scrip = os.path.splitext( os.path.basename(csv) )[0]        
        if( len(s.SCRIPS) > 0 and scrip not in s.SCRIPS ):
            return

    # Load CSV            
    file    = open(csv, 'r')          
    h       = None if s.IS_CSV_HEADERLESS else 0
    parsedt = [s.CSV_HEADER_DATE, s.CSV_HEADER_TIME] if s.IS_INTRADAY else s.CSV_HEADER_DATE    
    
    data         = pd.read_csv( file, header=h, usecols=s.CSV_FIELDS, parse_dates=[parsedt], infer_datetime_format=True)    
    data.columns = s.DB_FIELDS    
    file.close()

    # Apply DB Filters                                                        
    if( len(s.SCRIPS) > 0 and not s.USE_FILENAME_AS_TICKER ):   # If Scrip filter is set, filter out symbols that are not in List
        data = data[ data['S'].isin(s.SCRIPS)  ]                 # Already handled if USE_FILENAME_AS_TICKER

    try:                                                          # Remove data before s.DB_FROM_DATE
        if s.DB_FROM_DATE != "" :
            data = data[ data['D'] > s.DB_FROM_DATE  ]
    except AttributeError:
        pass

    # Save File
    if( s.USE_FILENAME_AS_TICKER ) :
        __saveDBScrip( scrip, data )
    else :
        data.reset_index(drop=True, inplace=True)               # group by symbol and save other columns per symbol
        scrips = data.groupby('S')                               
        data   = data.drop('S', axis=1 )

        for scrip, index in scrips.groups.items():              # Output of groupby = HM with key = scrip and value = indices of scrip rows in data 
            d = data.iloc[index]
            __saveDBScrip( scrip, d )

# Save data file for input scrip
# Set indices, sort if needed and save to file
def __saveDBScrip( scrip, d ):
    
    d.set_index(['D'], drop=True, inplace=True)
    if( not d.index.is_monotonic_increasing ):
        d.sort_index(inplace=True)

    if( s.DB_RESAMPLE_TF != "" ):                                # Upscale Timeframe. Include Right extreme in bar and use right extreme as label    
        d = d.resample(s.DB_RESAMPLE_TF, label ='right', closed='right', base=s.DB_RESAMPLE_BASE).agg( {'O':'first', 'H':'max', 'L':'min', 'C':'last'} ).dropna()

    with open( str(s.DBPATH + scrip), "wb" ) as f:        
        pickle.dump( d, f )

'''
Take returns for existing scrip data, randomly reorder the returns series and apply it on starting price
If the market moves randomly, you won't be able to extract profits above the baseline return
'''
def __createRandomDBForScrip( scrip ):
    b = loadScripDB( scrip )             
                    
    prevCloseInv = 1/(b['C'].shift(1))

    C = b['C'].pct_change(periods=1, fill_method=None)        # Save % diff between close and next O/H/L/C
    H = b['H'] * prevCloseInv - 1
    L = b['L'] * prevCloseInv - 1
    O = b['O'] * prevCloseInv - 1            
    
    shuffle  = pd.concat( [O, H, L, C], axis=1)
    shuffle.iloc[0] = [0,0,0,0]
    shuffle.columns = ['O','H','L','C']
    
    shuffle       = shuffle.sample(frac=1).reset_index(drop=True)  # Shuffle randomly ( sample all without replacement )
    shuffle.index = b.index                                         # Copy index to allow adding shuffled returns as columns in b            
    b['O%'], b['H%'], b['L%'], b['C%'] = [ shuffle['O'], shuffle['H'], shuffle['L'], shuffle['C'] ]
    
    
    # Generate OHLC by applying randomly ordered returns series to 1st bar close
    firstRow   = b.iloc[0]                                        # 1st bar must be copied 
    firstClose = firstRow['C']
    
    b['C%'] = (b['C%']+1).cumprod()-1                            # Add up returns and generate close array using cumulative returns
    b['C']  = firstClose + firstClose * b['C%']

    prevC     = b['C'].shift(1)                                   # From close we can derive O/H/L directly
    b['O']    = prevC + prevC * b['O%']
    b['H']    = prevC + prevC * b['H%']
    b['L']    = prevC + prevC * b['L%']            
    b.iloc[0] = firstRow

    b.drop( ['O%','H%','L%','C%'], axis=1, inplace=True)       
    
    with open(str(s.RANDOM_DBPATH + scrip), "wb") as f:
        pickle.dump( b, f )   
            
