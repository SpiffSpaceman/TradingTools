import urllib.request as url
import json
import configparser
import zipfile
from io import BytesIO
import subprocess
import shutil

import os
import sys
os.chdir(sys.path[0])                               # Set working dir

deltaUrl   = 'https://www.quandl.com/api/v3/datatables/WIKI/PRICES/delta.json?api_key='
ini        = "quandl.ini"
dataFolder = "Data"

updateAvailable = False

########

def getLastUpdateTS():
    global config
    return config.get('Quandl', 'LastUpdateTS')

def extractZipFromUrl( urlStr ):
    data = url.urlopen(urlStr).read()
    file = zipfile.ZipFile( BytesIO(data) )
    file.extractall(dataFolder)
    file.close()

def ProcessFile( datetime, insertUrl, updateUrl ):
    global config

    currentTime = getLastUpdateTS()

    if( datetime > currentTime ) :
        print( "Importing files with TS ", datetime )

        extractZipFromUrl( insertUrl )
        extractZipFromUrl( updateUrl )        

        config['Quandl']['LastUpdateTS'] = datetime
        updateAvailable = True
        

########


config = configparser.ConfigParser()
config.read(ini)

apiKey   	   = config['Quandl']['apiKey']

delta          = json.load( url.urlopen(deltaUrl + apiKey  )) 

deltaFiles     = delta['data']['files']
latestFullData = delta['data']['latest_full_data']


for file in deltaFiles:                                 # Ignore Deletions as they can be cleaned up later anyway   
    ProcessFile( file['to'],file['insertions'], file['updates'] )
    
with open(ini, 'w') as configfile:                      # Write to ini file
    config.write(configfile)


#if( updateAvailable ):                                  # Import Data
    #subprocess.run( ['cscript.exe', 'ImportRT.js'] )

#shutil.rmtree(dataFolder)                               # Delete Downloaded files


# TODO 
# Continous Futures, SP500
    # https://www.quandl.com/api/v3/datasets/CHRIS/CME_SP1.csv?api_key=xxx&start_date=1980-05-17
    # https://www.quandl.com/api/v3/datasets/CHRIS/CME_SP2.csv?api_key=xxx&start_date=1980-05-17
    # https://www.quandl.com/data/SCF-Continuous-Futures/documentation/roll-methodology

# test js call
# call import in correct order + update before inserts + TICKMODE 1
    # Or just merge them into 1 csv 




print( "Done")
