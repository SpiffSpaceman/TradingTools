#ifndef  ABBACKFILL_READER_H
#define  ABBACKFILL_READER_H

#include "settings.h"

#include <map>
#include <string>
#include <fstream>

class Reader{

public:
    Reader(  const Settings &in_settings, bool in_is_tickmode  );
    ~Reader();

    bool parseVWAPToCsv     ();
    bool parseDataTableToCsv();    
    void closeOutput();

private:
    std::ifstream    fin;
    std::ofstream    fout;   

    Settings         settings;
    bool             is_tickmode;
    std::string      today_date;

    std::map<std::string, std::string>  sorted_data;         // Key = Scripname+ltt. Value = output row. Used in TickMode to sort based on ltt for each scrip.

    Reader( const Reader& );
    Reader operator=(const Reader& );
        
    bool setUpInputStream  ( const std::string &in_file  );
    void setUpOutputStream ( const std::string &out_file  );

    bool preProcess( const std::string &input_file  );
    void postParse(  const std::string &ticker, const std::string &date, const std::string &time, const std::string &open,
                     const std::string &high,   const std::string &low,  const std::string &close,      std::string &volume );
    void writeTickModeData();

    void changeHHFrom12To24( std::string &time ); 
    bool isIntraday        ( const std::string &time, const std::string &date = "" );
    
};

#endif

