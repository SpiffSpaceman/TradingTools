import os
import pathlib
import threading
from typing    import Callable, Any, Dict

from settings  import s

class Server():
    def __init__( self, callback:Callable[[str, Dict], Any] ):
        if not os.path.exists( s.IO_PATH ):                             # Input commands directory
            os.makedirs( s.IO_PATH )
        
        self.inputFile   = pathlib.Path( s.IO_PATH + '/input.csv')      # Commands received in this file. Once read it will be deleted
        self.sendMessage = callback
    
    def waitForInput(self):
        print( "Waiting for Input" )
        
        self.STOP = threading.Event()
                
        while not self.STOP.wait(timeout=s.TIMER_PERIOD):
            if self.inputFile.is_file():
                self.processInput()                


    def processInput(self):
        input  = self.inputFile.read_text()     # Path('README.md').write_text('Read the Docs!')
        
        print( 'Input received', input )
        
        fields = input.split(',')
        self.pickPrices( fields )

        '''
        command = fields[0]
        if( command == 'CREATE' ):
            self.create( fields )
        '''

        self.inputFile.unlink()                 # Delete file

    # Scrip, Entry, Stop, Target
    def pickPrices( self, fields ) :
        #try:
            inputs = { "contractSymbol":fields[0], "entryPrice":float(fields[1]), "stopPrice":float(fields[2]), "targetPrice":float(fields[3]) } 
            self.sendMessage( "pickPrices", inputs ) 
        #except Exception as e:
        #    print('pickPrices - Input error: ', e )
        
    # Expected format :   'CREATE,SymbolName,BUY/SELL,PriceIn,InitialStop'
    def create(self, fields ):
        try:
            inputs = { "contractSymbol":fields[1], "entryPrice":float(fields[2]), "stopPrice":float(fields[3]) } 
            self.sendMessage( "CREATE", inputs ) 
        except Exception as e:
            print('CREATE - Input error: ', e )




    
    
    