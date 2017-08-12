#ifndef  ABBACKFILL_READER_H
#define  ABBACKFILL_READER_H

#include "settings.h"

#include <map>
#include <string>
#include <fstream>

class Reader{

public:
    Reader(  const Settings &in_settings );
    ~Reader();

    bool parseVWAPToCsv     ();
    bool parseDataTableToCsv();    
    void closeOutput();

private:
    std::ifstream    fin;
    std::ofstream    fout;   

    Settings         settings;
    std::string      today_date;
	
	std::map<std::string, std::string>  scrip_end_time;		 // Key = Ticker. Value = timestamp of last backfill quote
    std::map<std::string, std::string>  sorted_data;         // Key = Scripname+ltt. Value = output row. Used to sort based on ltt for each scrip. Needed for $TICKMODE 1

    Reader( const Reader& );
    Reader operator=(const Reader& );
        
    bool setUpInputStream  ( const std::string &in_file  );
    void setUpOutputStream ( const std::string &out_file  );

    bool preProcess( const std::string &input_file  );
    void postParse(  const std::string &ticker, const std::string &date, const std::string &time, const std::string &open,
                     const std::string &high,   const std::string &low,  const std::string &close,      std::string &volume );															
															
	std::string getOutputLine(  const std::string &ticker, const std::string &date, const std::string &time, const std::string &open,		
								const std::string &high,   const std::string &low,  const std::string &close,      std::string &volume );
    
	void writeTickModeData();								// Writes Backfill data to csv in sorted order used only with $TICKMODE 1
	void writeRTDTicks();									// Add tick data with timestamp greater than Backfill data's last minute

    void changeHHFrom12To24( std::string &time ); 
    bool isMarketHours     ( const std::string &time );
	bool isToday		   ( const std::string &date = "" );

};

#endif

