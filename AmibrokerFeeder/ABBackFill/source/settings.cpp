
#include "settings.h"
#include "util.h"


void Settings::loadSettings(){

    csv_file_path          = Util::getINIString("CSVFolderPath",             "ABBackFill");   
    vwap_file_path         = Util::getINIString("VWAPBackFillInputFilePath", "ABBackFill");
    data_table_file_path   = Util::getINIString("DTBackFillInputFilePath",   "ABBackFill");

    open_minute            = Util::getINIString("OpenMinute",     "ABBackFill"); 
    close_minute           = Util::getINIString("CloseMinute",    "ABBackFill"); 

    is_skip_open_minute    = Util::getINIString("SkipOpenMinute", "ABBackFill") == "true";
    is_skip_volume         = Util::getINIString("SkipVolume",     "ABBackFill") == "true";
    is_intraday_mode       = Util::getINIString("IntradayMode",   "ABBackFill") == "true";
    is_eod_tickmode        = Util::getINIString("EODTickMode",    "ABBackFill") == "true";

    Util::createDirectory( csv_file_path );                            // If folder does not exist, create it
    csv_file_path.append("quotes.bfill");
}



