  
#include "stdafx.h"

#include "settings.h"
#include "reader.h"
#include "amibroker_feed.h"
#include "misc_util.h"
#include <iostream>
          

int _tmain(int argc, _TCHAR* argv[]){

    try{
        //LARGE_INTEGER start, finish, freq;
        //QueryPerformanceFrequency(&freq);
        //QueryPerformanceCounter(&start);
        
        // Read settings.ini
        Settings settings;
        settings.loadSettings();        

        // Read Input and convert to CSV
        Reader reader;     
        bool vwap = reader.parseVWAPToCsv     ( settings.vwap_file_path,        settings.csv_file_path ) ;
        bool dt   = reader.parseDataTableToCsv( settings.data_table_file_path,  settings.csv_file_path ) ;
        reader.closeOutput();

        if( !vwap && !dt ){
            throw "Both VWAP and DT Input missing. VWAP:" + settings.vwap_file_path + "DT:" + settings.data_table_file_path ;
        }

        //QueryPerformanceCounter(&finish);
        //std::cout << "CSV Creation Time:" << ((finish.QuadPart - start.QuadPart) / (double)freq.QuadPart) << std::endl;

        // send CSV to AB
        Amibroker AB( settings.ab_db_path, settings.csv_file_path, "backfill.format"); 
        AB.import();        
        AB.refreshAll();
        AB.saveDB();       

        std::cout << "Done" << std::endl ;
    }    
    catch( const std::string msg ){    
        MiscUtil::printException( msg );
    }
    catch( const char *msg ){    
        MiscUtil::printException( msg );
    }

    return 0;
}

