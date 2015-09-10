
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
    vwap_file_path         = getINIString("VWAPBackFillInputFilePath");
    data_table_file_path   = getINIString("DTBackFillInputFilePath");

    open_minute            = getINIString("OpenMinute");
    close_minute           = getINIString("CloseMinute");

    is_skip_open_minute    = getINIString("SkipOpenMinute") == "true";
    is_skip_volume         = getINIString("SkipVolume") == "true";
    is_intraday_mode       = getINIString("IntradayMode") == "true";
    is_eod_tickmode        = getINIString("EODTickMode") == "true";

    Util::createDirectory( csv_file_path );                            // If folder does not exist, create it
    csv_file_path.append("quotes.bfill");
}



