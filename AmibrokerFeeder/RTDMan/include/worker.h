#ifndef RTDMAN_WORKER_H
#define RTDMAN_WORKER_H

#include "rtd_client.h"
#include "amibroker.h"
#include "ninja_trader.h"
#include "settings.h"

#include <string>
#include <vector>
#include <map>
#include <utility>
#include <iostream>
#include <fstream> 
#include <sstream>

class Worker{

public:
    Worker(  const std::string &settings_file_name = ""  );
    ~Worker();

    void connect();
    void poll();    
    void stop();                                                            // Stop Thread and quit    

private:
    struct ScripBar; struct ScripState;                                     // Forward Declare

    RTDClient                           *rtd_client;
    Amibroker                           *amibroker;
	NinjaTrader							*ninja_trader;
    Settings                             settings;

    std::map< long, std::pair<int,int>>  topic_id_to_scrip_field_map;       // topic_id  :  scripd_id,field_id
    ScripState                          *current, *previous;                // Maintains Current and last state of each Scrip
    std::string                          today_date;                            // (in same order as Settings::Scrip::topic_name)
    std::ofstream                        csv_file_out; 
            
    CRITICAL_SECTION                     lock;                              // Thread Data sync    
    HANDLE                               Event_RTD_Update;                  // Signaled by RTD Callback
    HANDLE                               AB_timer;                          // Timer for AB poller    
    HANDLE                               Event_StopNow;                     // This will be used to stop AB thread 
    HANDLE                               Event_Stopped;                     // This will be fired after thread is done    
    
    bool                                 is_rtd_started;                    // Indicates whether RTD has started sending data   
    int                                  rtd_inactive_count;                // No of 'BarPeriod' for which RTD is inactive ( since last time it was active)     

    void        loadSettings    ();    
    void        processRTDData  ( const std::map<long,CComVariant>* data );
    static void threadEntryDummy( void* _this);                             // Entry Point for Amibroker Feeder thread
    void        amibrokerPoller ();                                             // Fetches Bar data and feeds to Amibroker    
	void        writeABCsv      ( const std::vector<ScripBar> & bars  );        // This thread uses members - current , previous, settings
	void		writeArchiveCsv ( const std::vector<ScripBar> & bars);      // Archive Ticks in seperate csv. Used in backfill
	void		writeCurrentPrices( const std::stringstream	  & current_prices);	// Write Current prices of all scrips
	void		pushToNT( const std::vector<ScripBar> & bars  );			// Push ticks to Ninjatrader
    void        notifyActive    ();
    void        notifyInactive  ();                                         // Ring Bell if RTD Inactive    
    bool        isMarketTime  ( const std::string &time);                   // Is input time within OpenTime and CloseTime

    Worker( const Worker& );                                                // Disable copy
    Worker operator=(const Worker& );
    
    // Used to create and resolve Topic ids
    enum SCRIP_FIELDS{                                                      // -- Topic 2 --        
        LTP=0,                                                              // "LTP"
        LTT=1,                                                              // "LTT"        
        VOLUME_TODAY=2,                                                     // "Volume Traded Today"
        OI=3,                                                               // "Open Interest"        
        FIELD_COUNT=4                                                       // No of Fields used
    };
    struct ScripState {
        double       ltp;                                                    
        std::string  ltt;                                                   // ltt can be empty for index scrips
        std::string  last_bar_ltt;                                          // last_bar_ltt will be always set with last sent bar's ltt
        long long    vol_today;
        long long    oi;
                
        double       bar_high;
        double       bar_low;
        double       bar_open;        

        ScripState();
        void  reset();
        bool  operator==(const ScripState& right) const ;

        friend std::ostream& operator<<(std::ostream& os, const Worker::ScripState& bar){
            return os << " LTT:" << bar.ltt      << " Open:"  << bar.bar_open << " High:" << bar.bar_high \
                      << " Low:" << bar.bar_low  << " Close:" << bar.ltp ;
        }
        
    };
    struct ScripBar{                                                        // Bar data to Amibroker
        std::string  ticker;
        std::string  ltt;

        double       bar_open;    
        double       bar_high;
        double       bar_low;
        double       bar_close;
        long long    volume;
        long long    oi;
    };
};



#endif