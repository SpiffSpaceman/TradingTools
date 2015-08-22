#ifndef  ABBACKFILL_READER_H
#define  ABBACKFILL_READER_H

#include "settings.h"

#include <string>
#include <fstream>

class Reader{

public:
    Reader(  const Settings &in_settings  );
    ~Reader();

    bool parseVWAPToCsv     ();
    bool parseDataTableToCsv();    
    void closeOutput();

private:
    std::ifstream    fin;
    std::ofstream    fout;   

    Settings         settings;
    std::string      today_date;

    Reader( const Reader& );
    Reader operator=(const Reader& );
        
    bool setUpInputStream  ( const std::string &in_file  );
    void setUpOutputStream ( const std::string &out_file  );
    void changeHHFrom12To24( std::string &time ); 
    bool isIntraday        ( const std::string &time, const std::string &date = "" );
    
};

#endif