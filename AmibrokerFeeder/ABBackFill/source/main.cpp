  
#include "stdafx.h"

#include "settings.h"
#include "reader.h"
#include "amibroker.h"
#include "util.h"
#include <iostream>

// TODO - Volume only if no quote in minute else find empty second and update extremes with 0 volume. 
    // Delete second quotes, just leave last 30 mins ( configurable ) 
    // Remove Volume Skip option
    // Open Minute - Still import if no data in AB and volume available    
// Or alternately - save quotes in RTDman, use $TICKMODE 1 backfill, recreate last 30 min data with saved ticks+backfill data

int _tmain(int argc, _TCHAR* argv[]){

    try{
        //LARGE_INTEGER start, finish, freq;
        //QueryPerformanceFrequency(&freq);
        //QueryPerformanceCounter(&start);
        
        // Read settings.ini
        Settings settings;
        settings.loadSettings();        

        // TickMode - Overwrite todays data with 1 min bars after market hours
        bool is_tickmode = settings.is_eod_tickmode && Util::getTime() > settings.close_minute;

        // Read Input and convert to CSV
        Reader reader( settings, is_tickmode );     
        bool vwap = reader.parseVWAPToCsv     () ;
        bool dt   = reader.parseDataTableToCsv() ;
        reader.closeOutput();

        if( !vwap && !dt ){
            throw "Both VWAP and DT Input missing. VWAP:" + settings.vwap_file_path + "DT:" + settings.data_table_file_path ;
        }

        //QueryPerformanceCounter(&finish);
        //std::cout << "CSV Creation Time:" << ((finish.QuadPart - start.QuadPart) / (double)freq.QuadPart) << std::endl;

        // send CSV to AB
        std::string format = is_tickmode ? "backfillTick.format" : "backfill.format" ;
                
        Amibroker AB( settings.ab_db_path, settings.csv_file_path, format );
        AB.import();
        AB.refreshAll();
        // AB.saveDB();                         // Save is called by ~Amibroker

        std::cout << "Done" << std::endl ;
    }    
    catch( const std::string msg ){    
        Util::printExceptionSilent( msg );
        return 1;
    }
    catch( const char *msg ){    
        Util::printExceptionSilent( msg );
        return 1;
    }

    return 0;
}

