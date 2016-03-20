// main.cpp : Defines the entry point for the console application.

#include "stdafx.h"
#include "util.h"

#include <iostream>

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



