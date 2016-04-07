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

class Worker{

public:
    Worker();
    ~Worker();

    void connect();
    void poll();    
    void stop();                                                            // Stop Thread and quit    

private:
    struct ScripBar; struct ScripState;                                     // Forward Declare
	struct RTData;															// Forward Declare by Josh1 

    RTDClient                           *rtd_client;
    Amibroker                           *amibroker;
	NinjaTrader							*ninja_trader;
    Settings                             settings;

    std::map< long, std::pair<int,int>>  topic_id_to_scrip_field_map;       // topic_id  :  scripd_id,field_id
    ScripState                          *current, *previous;                // Maintains Current and last state of each Scrip
    std::string                          today_date;                            // (in same order as Settings::Scrip::topic_name)
    std::ofstream                        csv_file_out;    

	// Inserted by Josh1 ------------------------------------------------------------------------------
	std::string                          timestamp1;                            // (in same order as Settings::Scrip::topic_name)
	std::string                          timestamp2;
	std::string                          timestamp3;
	std::string                          timestamp4;

	std::string							 cur_tm;							// to store current time
	int									 prev_field;						// to keep track of previous field id
	std::string							 bar_ltt;							// Inserted by Josh1 - Purpose ?????
	int									 records;							// to keep track of records received from RTD feed
	// End Inserted by Josh1 ------------------------------------------------------------------------------

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
	void		writeArchiveCsv ( const std::vector<ScripBar> & bars  );    // Archive Ticks in seperate csv. Used in backfill
	void		pushToNT( const std::vector<ScripBar> & bars  );			// Push ticks to Ninjatrader
    void        notifyActive    ();
    void        notifyInactive  ();                                         // Ring Bell if RTD Inactive    
    bool        isMarketTime  ( const std::string &time);                   // Is input time within OpenTime and CloseTime

    Worker( const Worker& );                                                // Disable copy
    Worker operator=(const Worker& );
    
    // Used to create and resolve Topic ids ---------  order changed by Josh1 ------------- 
    enum SCRIP_FIELDS{                                                      // -- Topic 2 --        
        OI=0,                                                               // "Open Interest"       
        LTT=1,                                                              // "LTT"        
        VOLUME_TODAY=2,                                                     // "Volume Traded Today"
	//Inserted by Josh1
		BID_RATE=3,                                                         // "Bid Rate" 
		ASK_RATE=4,                                                         // "Ask Rate" 
		BID_QTY=5,                                                          // "Bid Qty" 
		ASK_QTY=6,                                                          // "Ask Qty" 

        LTP=7,                                                              // This topic should be last since
																			// Index has only "LTP"
        FIELD_COUNT=8                                                       // No of Fields used
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
		
		//Inserted by Josh1 -----------------------------------------------------------------------------------
		long	    volume;												
        double	     ask_rate;    
		long	     ask_qty;    
		double	     bid_rate;    
		long	     bid_qty;    
		short		 push;													//Flag for data pushed to AB
        //End Inserted by Josh1 -------------------------------------------------------------------------------

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
        long		 volume;
        long long    oi;
	// Inserted by Josh1
		double	     ask_rate;    
		long	     ask_qty;    
		double	     bid_rate;    
		long	     bid_qty;    
    };

	//Structure RTData Inserted by Josh1
    struct RTData {   
        double       ltp;                                                    
        std::string  ltt;                                                   // ltt can be empty for index scrips
        long long    vol_today;												//to use as volume or LTQ now
        long long    oi;
		long	     volume;												
		double	     ask_rate;    
		long	     ask_qty;    
		double	     bid_rate;    
		long	     bid_qty;    

		RTData();
		void  reset();
    };

};

#endif