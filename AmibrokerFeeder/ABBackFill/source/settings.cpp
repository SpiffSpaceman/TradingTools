
#include "settings.h"
#include "util.h"


void Settings::loadSettings(){

    csv_file_path          = Util::getINIString("CSVFolderPath",             "ABBackFill");
   // ab_db_path             = Util::getINIString("AbDbPath",                  "ABBackFill");
    vwap_file_path         = Util::getINIString("VWAPBackFillInputFilePath", "ABBackFill");
    data_table_file_path   = Util::getINIString("DTBackFillInputFilePath",   "ABBackFill");

    Util::createDirectory( csv_file_path );                            // If folder does not exist, create it
    csv_file_path.append("quotes.bfill");
}



