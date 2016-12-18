// main.cpp : Defines the entry point for the console application.

#include "stdafx.h"
#include "util.h"

#include <iostream>

// Workaround for crash on calling CComObject::CreateInstance
// Probably need to create 'ATL' project otherwise
CComModule _Module;
extern __declspec(selectany) CAtlModule* _pAtlModule=&_Module;

Worker  *worker  = 0;
Worker  *worker2 = 0;

void worker2thread(void* param);

// Cleanup before exit
BOOL CtrlHandler( DWORD fdwCtrlType ){

    worker->stop();                                                            // Stop and cleanup Amibroker Feeder thread in worker
    delete worker;  worker = 0;                                                // Delete RTD Client, Worker

	if( worker2 ){
		worker2->stop();
		delete worker2;  worker2 = 0;
	}

    return false;
}


int _tmain(int argc, _TCHAR* argv[]){

    SetConsoleCtrlHandler( (PHANDLER_ROUTINE) CtrlHandler, TRUE );             // Register callback for program close

    try{
        worker = new Worker( ".\\RTDMan.ini" );
        worker->connect();

		if( PathFileExists( L".\\RTDMan2.ini") ) {
			_beginthread( worker2thread, 0, NULL );
		}

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

void worker2thread(void* param){
	try{
		worker2 = new Worker( ".\\RTDMan2.ini" );
		worker2->connect();
		worker2->poll();
	}
    catch( const std::string msg ){
        Util::printException(msg);
    }
    catch( const char *msg ){
        Util::printException(msg);        
    }

	delete worker2;  worker2 = 0;
}
