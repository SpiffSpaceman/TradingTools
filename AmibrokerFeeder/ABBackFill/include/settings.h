#ifndef  ABBACKFILL_SETTINGS_H
#define  ABBACKFILL_SETTINGS_H

#include <string>

class Settings{

public:
    std::string   csv_file_path;
    std::string   ab_db_path;
    std::string   vwap_file_path;
    std::string   data_table_file_path;

    std::string   open_minute;
    std::string   close_minute;

    bool          is_skip_open_minute;
    bool          is_backfill_volume;
    bool          is_intraday_mode;    
    bool          is_eod_tickmode;
    bool          is_force_tickmode;

    void loadSettings();

private:
    static std::string     getINIString( const char *key );
    static int             getINIInt   ( const char *key );
};


#endif