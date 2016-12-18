#ifndef RTDMAN_SETTINGS_H
#define RTDMAN_SETTINGS_H

#include <string>
#include <vector>

class Settings{

public:
    void loadSettings( std::string file = ".\\RTDMan.ini");
	bool isTargetNT();													  // Is target Client NinjaTrader

	std::string settings_file_path;										  // ini file

    std::string rtd_server_prog_id;
    int         bar_period;                                               // In milliseconds    
    int         bell_wait_time;                                           // No of bar_periods
	std::string csv_folder_path;										  // Folder in which we will save csv for AB and archived csv
    std::string csv_path;                                                 // path for csv file to be sent to Amibroker - Use ram drive
	bool        is_archive;												  // If true, also save quotes in separate csv for each scrip
	std::string target_client;											  // Push to AB / NT	
    std::string ab_db_path;

    std::string  open_time;
    std::string  close_time;

    struct Scrip {
        std::string topic_name;                                           // Scrip Name = Topic 1
        std::string ticker;                                               // Ticker Alias sent to Amibroker                        
        std::string topic_LTP;                                            // Topic 2 for each field
        std::string topic_LTT;                        
        std::string topic_vol_today;
        std::string topic_OI; 
        int         ltp_multiplier;                                       // Multiple LTP with this- Default 1
		int         vol_multiplier;                                       // Multiple Volume with this- Default 1
    };

    std::vector<Scrip> scrips_array;                                      // RTD Topics for each scrip
    int                no_of_scrips;

private:
    std::string     getINIString( const char *key );
    int             getINIInt   ( const char *key );
};


#endif

