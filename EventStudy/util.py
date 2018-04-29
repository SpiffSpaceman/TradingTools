import os
import psutil
import bisect
import ctypes


def filesInDir( path ):
    files = [ file for file in os.listdir(path) if os.path.isfile(os.path.join(path, file)) ]
    return files

    
def printMemUsage():
    process = psutil.Process(os.getpid())
    print('Memory Used :', process.memory_info().rss/(1024*1024), "MB")


'''
import util
util.showMsgWin(s.SCRIPS)
'''
def showMsgWin( msg ):
    MessageBox = ctypes.windll.user32.MessageBoxW
    MessageBox(None, repr( msg ), 'Debug Message', 0)

    
    
    
    
    
# Merge Intraday monthly data files into one file per scrip
def mergeFiles():
    SOURCE   = "E:/Data/Stats/source/IntraDay/Nifty50_2017-10/" 
    DEST     = SOURCE + "OUTPUT/"

    if not os.path.exists(DEST):
        os.makedirs(DEST)
    
    ScripMap = {}  

    csvs = (file for file in os.listdir(SOURCE) 
            if os.path.isfile(os.path.join(SOURCE, file)))
    
    for csv in csvs:
        split = csv.split('_')        
        
        scrip = split[0]
        if( split[1] == 'F1' or split[1] == 'F2'):
            scrip += '_' + split[1]
                
        if( scrip not in ScripMap ):
            ScripMap[scrip] = [os.path.join(SOURCE, csv)]
        else:
            a = ScripMap[scrip]
            bisect.insort(  a, os.path.join(SOURCE, csv) )            
    
    for scrip in ScripMap :
        print( scrip )
        outputFile = open(DEST + scrip + '.txt', 'w')
        inputFiles = ScripMap[scrip]
        for file in inputFiles :
            fileO = open(file,'r')
            outputFile.write( fileO.read() )
            fileO.close()
        outputFile.close()

        
# Find missing months in intraday data using file names        
def missingMonths():
    SOURCE   = "E:/Data/Stats/source/IntraDay/Nifty50_2017-10/"
    
    count    = {}
    yr       = '2014'

    csvs = (file for file in os.listdir(SOURCE) 
            if os.path.isfile(os.path.join(SOURCE, file)))
    
    for csv in csvs:
        split = csv.split('_')        
        
        scrip = split[0]
        if( split[1] == 'F1' or split[1] == 'F2'):
            scrip += '_' + split[1]
                
        if( scrip not in count ):        
            count[scrip] = 0
            if( split[1] == yr or ( len(split)>2 and split[2] == yr)):
                count[scrip] = count[scrip] + 1
        else:
            if( split[1] == yr or ( len(split)>2 and split[2] == yr)):
                count[scrip] = count[scrip] + 1
                
    for scrip in count :
        if( count[scrip] > 1 and count[scrip] < 12 ):
            print( scrip, count[scrip] )

          
# DF to csv 
# print(shuffle.to_csv(sep=',', index=False))     
