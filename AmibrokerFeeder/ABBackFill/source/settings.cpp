
#include "settings.h"
#include "util.h"

std::string Settings::getINIString( const char *key ){
    return Util::getINIString(".\\ABBackFill.ini", "ABBackFill", key );
}
int Settings::getINIInt( const char *key ){
    return Util::getINIInt(".\\ABBackFill.ini", "ABBackFill", key );
}

void Settings::loadSettings(){

    csv_file_path          = getINIString("CSVFolderPath");
	tick_path              = getINIString("TickPath");
    vwap_file_path         = getINIString("VWAPBackFillInputFilePath");
    data_table_file_path   = getINIString("DTBackFillInputFilePath");

    open_minute            = getINIString("OpenMinute");
    close_minute           = getINIString("CloseMinute");

	is_no_tick_mode		   = getINIString("NoTickMode") == "true";
	is_filter_time		   = getINIString("FilterTime") == "true";
	is_singleday_mode	   = getINIString("SingleDay") == "true";
		
    Util::createDirectory( csv_file_path );                            // If folder does not exist, create it
	csv_file_path.append("backfill.csv");
    
}



