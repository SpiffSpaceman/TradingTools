// main.cpp : Defines the entry point for the console application.

#include "stdafx.h"
#include "util.h"

#include <iostream>


// TODO        
	// Util::getLong / getDouble - Use Try Catch when converting from string
		// Also check references - handle bad data
	
	// Preopen Volume?
	
    // RTD Callback - Use array and construct bars in AB thread
        // More accurate mins - some data gets shifted now
        // Immediate update - use events instead of sleep. Manage minute change
        // Integrate with backfill - Export all ticks to another file per scrip - append data            
       
	// Change month in future / options scrips if cannot connect + detect last thrusday has passed + check current date month + setting to enable
		// Or just do it in OrderMan GUI
		
    // Bell - Change wav + in project 
    // Bug - Negative Volume ? 
            // Atleast set volume to 0. Currently check for ==0 but not <0
            // Maybe Current Volume not set - Not passed by RTD? 
    // Check direct call using quotations api - No need for csv, ram drive
	
        
	
	    
	
    // Check for memory leaks in COM calls/callbacks - esp SAFEARRAY/BSTR/VARIANT/COM input/output
        // https://vld.codeplex.com/
        // https://stackoverflow.com/questions/2820223/visual-c-memory-leak-detection
    // Profile - very sleepy





// Workaround for crash on calling CComObject::CreateInstance
// Probably need to create 'ATL' project otherwise
CComModule _Module;
extern __declspec(selectany) CAtlModule* _pAtlModule=&_Module;

Worker  *worker;

// Cleanup before exit
BOOL CtrlHandler( DWORD fdwCtrlType ){

    worker->stop();                                                            // Stop and cleanup Amibroker Feeder thread in worker

    delete worker;  worker = 0;                                                // Delete RTD Client, Worker
    return false;
}


int _tmain(int argc, _TCHAR* argv[]){

    SetConsoleCtrlHandler( (PHANDLER_ROUTINE) CtrlHandler, TRUE );             // Register callback for program close

    try{
        worker = new Worker;
        worker->connect();
        worker->poll();
    }
    catch( const std::string msg ){
        Util::printException(msg);
        return 1;
    }
    catch( const char *msg ){
        Util::printException(msg);
        return 1;
    }

    return 0;
}



