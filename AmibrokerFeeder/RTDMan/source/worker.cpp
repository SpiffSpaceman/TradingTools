/**
  Copyright (C) 2014  SpiffSpaceman

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>
**/


#include "worker.h"
#include "util.h"

#include <windows.h> 
#include <process.h>
#include <mmsystem.h>

#include <limits>
 

/**
 * Read Scrips and setup DS. Start Timers and start AB thread
 */
Worker::Worker( const std::string &settings_file_name ):
    is_rtd_started(false),
    rtd_inactive_count(0),
	amibroker(0),
	ninja_trader(0)
{
                                                                           // _T()  - character set Neutral
    Event_RTD_Update = CreateEvent( NULL, false, FALSE, _T("RTD_UPDATE") );// Manual Reset = false - Event resets to nonsignaled on 1 wait release
    Event_StopNow    = CreateEvent( NULL, true,  FALSE, NULL );                // Initialize state to FALSE. Read data only after callback
    Event_Stopped    = CreateEvent( NULL, true,  FALSE, NULL );
    AB_timer         = CreateWaitableTimer( NULL, false,NULL );

    today_date       = Util::getTime("%Y%m%d");							  // Get todays date - yyyymmdd

    settings.loadSettings( settings_file_name );

    rtd_client = new RTDClient( settings.rtd_server_prog_id );
    current    = new ScripState[ settings.no_of_scrips ] ;
    previous   = new ScripState[ settings.no_of_scrips ] ;
                                                                                    
    for( int i=0 ; i<settings.no_of_scrips ; i++ ){                        // Make map key topic_id and value = scripd_id,field_id 
        for( int j=0 ; j<FIELD_COUNT ; j++ ){                              // topic_id generated using FIELD_COUNT as base multiplier for each scrip
            topic_id_to_scrip_field_map[ i*FIELD_COUNT + j  ]  =  std::make_pair( i,j );
        }
    }    

    LARGE_INTEGER start_now = {0};                                         // Start Timers immediately    
    SetWaitableTimer( AB_timer , &start_now, settings.bar_period, NULL, NULL, false );
    
    InitializeCriticalSection( &lock );
}


/**
 * Cleanup
 */
Worker::~Worker(){    
    CancelWaitableTimer( AB_timer ) ;
        
    CloseHandle(AB_timer) ;    
    CloseHandle(Event_RTD_Update) ;    
    CloseHandle(Event_StopNow) ;
    CloseHandle(Event_Stopped) ;

    if( csv_file_out.is_open() ){                                          // Close file if not done - just in case
        csv_file_out.close();
    }    

    delete [] current;     current    = 0;
    delete [] previous;    previous   = 0;
    delete rtd_client;     rtd_client = 0;
}

/**
 * Signal Thread to stop and wait for it - Wait Maximum 3 seconds
 **/
void Worker::stop(){    

    if( SetEvent(Event_StopNow)   ){        
        WaitForSingleObject( Event_Stopped, 3*1000 );        
    }    
}

Worker::ScripState::ScripState() : 
    ltp(0), vol_today(0), oi(0), bar_high(0), bar_low(std::numeric_limits<double>::infinity()), bar_open(0)    
{}

void Worker::ScripState::reset(){
    ltp = 0; vol_today = 0; oi =0; bar_high = 0; bar_low = std::numeric_limits<double>::infinity(); bar_open = 0; ltt=""; last_bar_ltt="";
}

bool Worker::ScripState::operator==(const ScripState& right) const{
    return (ltp == right.ltp)  && (vol_today == right.vol_today) &&
           (oi  == right.oi )  && (bar_high  == right.bar_high)  &&
           (ltt == right.ltt)  && (bar_low   == right.bar_low ); 
}


/** 
 * Connect Topics
 */
void Worker::connect(){
    
	rtd_client->initializeServer();
    rtd_client->startServer();

	_beginthread( threadEntryDummy, 0, this );                             // RTD Server ready. Start Amibroker Poller Thread

    for( int i=0 ; i<settings.no_of_scrips ; i++ ){        
        
        std::cout <<  settings.scrips_array[i].ticker  << std::endl ;

        long        topic_id = i * FIELD_COUNT;
        std::string topic_1  = settings.scrips_array[i].topic_name;
                        
        rtd_client->connectTopic(topic_id+LTP,          topic_1, settings.scrips_array[i].topic_LTP       );
        rtd_client->connectTopic(topic_id+LTT,          topic_1, settings.scrips_array[i].topic_LTT       );
        rtd_client->connectTopic(topic_id+VOLUME_TODAY, topic_1, settings.scrips_array[i].topic_vol_today );
        rtd_client->connectTopic(topic_id+OI,           topic_1, settings.scrips_array[i].topic_OI        );
    }     
}

    
/**
 * Wait for RTD Update event. On event, read new data and setup Current Bars
 */
void Worker::poll(){
        
    while(1){    
        if( WaitForSingleObject( Event_RTD_Update, INFINITE ) ==  WAIT_OBJECT_0 ){                    

            std::map<long,CComVariant>*  data = rtd_client->readNewData() ;
            if( data != 0 && !data->empty() ){
                processRTDData( data );                
            }
            delete data;            
        }
    }
}


/**
 * Read TopicId-Value data from COM and update Current Bar
 **/
void Worker::processRTDData( const std::map<long,CComVariant>* data ){
    
    notifyActive();

    for( auto i=data->begin(), end=data->end() ;  i!=end ; ++i  ){
            
        const long   topic_id     = i->first;
        CComVariant  topic_value  = i->second;
                
        std::pair<int,int> &ids = topic_id_to_scrip_field_map.at( topic_id ) ; 
        int script_id   =  ids.first;                                      // Resolve Topic id to Scrip id and field
        int field_id    =  ids.second;

        EnterCriticalSection( &lock );                                     // Lock when accessing current[] / previous[]

        switch( field_id ){                        
            case LTP :{
                double      ltp      = Util::getDouble( topic_value ) * settings.scrips_array[script_id].ltp_multiplier;
                ScripState *_current = & current[script_id];

                _current->ltp = ltp;
                if( _current->bar_high < ltp )    _current->bar_high = ltp;
                if( _current->bar_low  > ltp )    _current->bar_low  = ltp;
                if( _current->bar_open == 0  )    _current->bar_open = ltp;
                break ;
            }
            case VOLUME_TODAY :{  
                long long vol_today          = Util::getLong  ( topic_value ) * settings.scrips_array[script_id].vol_multiplier;
                current[script_id].vol_today = vol_today;

                if( vol_today !=0  &&  previous[script_id].vol_today == 0  ){
                    previous[script_id].vol_today = vol_today;             // On startup prev vol is 0, Set it so that we can get first bar volume
                }
                break ;
            }
            case LTT  :  current[script_id].ltt  = Util::getString( topic_value ); break ;            
            case OI   :  current[script_id].oi   = Util::getLong  ( topic_value ); break ;
        }

        LeaveCriticalSection( &lock ) ;
    }    
}


/**
 *    New Thread Entry Point
 **/
void Worker::threadEntryDummy(void* _this){
    ((Worker*)_this)->amibrokerPoller();
}

void Worker::amibrokerPoller(){

    std::vector<ScripBar>  new_bars;
	std::stringstream	   current_prices;	

	if( settings.isTargetNT()){
		ninja_trader = new NinjaTrader();
	}
	else{
		amibroker = new Amibroker( settings.ab_db_path, settings.csv_path, std::string("rtd.format") );
	}
                                                                           // amibroker constructor has to be called in new thread 
    while(1){    
        // Use events and timers instead of sleep which would be blocking 
        // Need to exit thread cleanly and immediately on application quit - sleep would block

        HANDLE   events[]    = {Event_StopNow,AB_timer};                   // (A) Wait For Timer Event / Application Quit Event
        DWORD    return_code = WaitForMultipleObjects( 2, events , false, INFINITE );                
                                                                            
        if( return_code == WAIT_OBJECT_0 ){                                // Quit Event
            if(amibroker)
				delete amibroker; amibroker = 0;
			if(ninja_trader)
				delete ninja_trader; ninja_trader = 0;

			SetEvent(Event_Stopped);
            std::cout << "AB Feeder Thread Stopped" << std::endl;
            return;
        }
        else if( return_code != WAIT_OBJECT_0 + 1 ){                       // If not Timer Event, then we have some error
            std::stringstream msg;  msg << "WaitForSingleObject Failed - " << return_code;
            throw( msg.str() );           
        }        

    // Shared data access start
        EnterCriticalSection( &lock );             

        for( int i=0 ; i<settings.no_of_scrips ; i++  ){                   // (B) Setup Bar data for each updated scrip using current and previous

            ScripState *_current  =  &current[i];
            ScripState *_prev     =  &previous[i];
            long long bar_volume  =  _current->vol_today - _prev->vol_today ;
																		  // Archive Close price for each Scrip
			double ltp = _current->ltp == 0 ? _prev->ltp : _current->ltp;
            current_prices << settings.scrips_array[i].ticker << ":" << ltp << std::endl;
                                                                           // If data not changed, skip
            if( (_current->bar_open == 0)                   ||             // 1. No New data from readNewData()
                (bar_volume==0 && _current->vol_today!=0)   ||             // 2. Also skip if bar volume 0 but allow 0 volume scrips like forex
                ((*_current) == (*_prev))                                  // 3. We got new data from readNewData() but its duplicate
              )    continue;                                               //    NEST RTD sends all fields even if unconnected field (ex B/A) changes    
                                    
            std::string bar_ltt;                                           // Use ltt if present else use current time  
            !_current->ltt.empty()  ? bar_ltt = _current->ltt : bar_ltt = Util::getTime( "%H:%M:%S" );
            
            if(  bar_ltt == _prev->last_bar_ltt  ){                        // IF LTT is same as previous LTT of this scrip ( but data is different )
                continue;                                                  //   skip to avoid overwrite with same timestamp.
            }                                                              // This can happen if we have more than 1 update in a second 
                                                                           //   and poller took data in between.

			std::vector<std::string>  split;							   // Skip 15:29:XX if current hour is not 15 	
			Util::splitString( bar_ltt, ':', split ) ;					   //   to avoid yesterdays quote on open in NOW.
            if( split[0] == "15" && split[1] == "29" && Util::getTime("%H") != "15"  ){   
                _current->reset();										   // Reset Bars to avoid yesterday data in open bar 
                _prev->reset();                                            
                continue;                                                  
            }
            // Skip quotes outside market hours
            if( !isMarketTime( bar_ltt  )){
                _current->reset(); 
                _prev->reset();
                continue;
            }

            new_bars.push_back( ScripBar() );
            ScripBar* bar = &new_bars.back();

            bar->ltt                = bar_ltt;
             _current->last_bar_ltt = bar_ltt;

            _prev->vol_today !=0    ? bar->volume = bar_volume    : bar->volume = 0;
                                                                           // Ignore First bar volume as prev bar is not set.
            bar->ticker     = settings.scrips_array[i].ticker;             // Otherwise, we get today's volume = First Bar volume
            bar->bar_open   = _current->bar_open;                                
            bar->bar_high   = _current->bar_high;
            bar->bar_low    = _current->bar_low;
            bar->bar_close  = _current->ltp;            
            bar->oi         = _current->oi;                                            
                
            (*_prev)  =  (*_current) ;                                     // Copy current to previous and reset current
            _current->reset();
        }
        LeaveCriticalSection( &lock );
    // Shared data access end
        
        if( new_bars.empty() ){                                           // Notify if RTD inactive  
            notifyInactive();
        }
        else{                                                             // (C) Write to csv and Send to Amibroker
			if( settings.isTargetNT()){	
				pushToNT( new_bars );
			}
			else{
				writeABCsv( new_bars );
				amibroker->import();
			}

			if( settings.is_archive )
				writeArchiveCsv( new_bars );							 // Archive ticks to be used for backfill
				writeCurrentPrices(current_prices);						 // Output latest prices for each scrip
        }
        new_bars.clear();
    }
}
 
void Worker::notifyActive(){
    rtd_inactive_count = 0 ;
    
    if( !is_rtd_started ){
        is_rtd_started = true;

        std::cout << "RTD Active" << "\t\t\t\t\t\t\t" << "\r";       // Status in Console
        std::flush(std::cout);         
    }
}
void Worker::notifyInactive(){
       
    if( settings.bell_wait_time <= 0 )
        return;    

    rtd_inactive_count++;

    if( rtd_inactive_count >= settings.bell_wait_time ){                     // Wait time up?
        
        rtd_inactive_count = 0; 

        std::cout << "RTD Inactive : " <<  Util::getTime() << "\r"   ;       // Status in Console
        std::flush(std::cout);         

        if( is_rtd_started ){        
            is_rtd_started  = false;                                         // Play only Once
            if( isMarketTime( Util::getTime() ))                             // and only in market hours
                PlaySound( L"NotifyBell.wav" , NULL, SND_FILENAME | SND_ASYNC);                            
            
        }
    }    
}

bool Worker::isMarketTime ( const std::string &time ){                       // Time is in hh:mm:ss - lexicographical order. 
    return  time >= settings.open_time && time <= settings.close_time ;      // So string compare works
}

void Worker::writeABCsv( const std::vector<ScripBar> & bars ){
    
    csv_file_out.open( settings.csv_path  );                               // Setup output stream to csv file
    if( !csv_file_out.is_open() ){                                         // Reopening will also clear old content by default
        throw( "Error opening file - " + settings.csv_path );        
    }

    size_t          size = bars.size();
    const ScripBar *bar;

    for( size_t i=0 ; i<size ; i++ ){                                      // $FORMAT Ticker, Date_YMD, Time, Open, High, Low, Close, Volume, OpenInt
        bar = &bars[i];     
        
        csv_file_out << bar->ticker     << ',' 
                     << today_date      << ',' 
                     << bar->ltt        << ',' 
                     << bar->bar_open   << ',' 
                     << bar->bar_high   << ',' 
                     << bar->bar_low    << ',' 
                     << bar->bar_close  << ',' 
                     << bar->volume     << ',' 
                     << bar->oi         << std::endl ;
    }

    csv_file_out.close();
}

/*
	Send OHLC to NinjaTrader
	Workaround - Send OHLC as ticks with 1/4 volume
*/
void Worker::pushToNT( const std::vector<ScripBar> & bars  ){
	
	int		volume = 0 ;
	size_t  size   = bars.size();
    const ScripBar *bar;

    for( size_t i=0 ; i<size ; i++ ){
        
		bar    = &bars[i];
		volume = (int)bar->volume/4;	// int should be atleast 4Bytes

		ninja_trader->Last( bar->ticker, bar->bar_open,  volume );
		ninja_trader->Last( bar->ticker, bar->bar_high,  volume );
		ninja_trader->Last( bar->ticker, bar->bar_low,   volume );
		ninja_trader->Last( bar->ticker, bar->bar_close, volume );
	}
}

void Worker::writeArchiveCsv( const std::vector<ScripBar> & bars  ){
	    
    size_t          size = bars.size();
    const ScripBar *bar;
	std::string		filename;

    for( size_t i=0 ; i<size ; i++ ){                                      // $FORMAT Ticker, Date_YMD, Time, Open, High, Low, Close, Volume, OpenInt

        bar	= &bars[i];

		if( filename != bar->ticker ){									   // Open new file stream for each ticker

			filename = bar->ticker;										  // Use Scrip Alias as filename
			if( csv_file_out.is_open() )
				csv_file_out.close();
																		  // Open file for - write + append	mode
			csv_file_out.open( settings.csv_folder_path + filename + ".csv",  std::fstream::out | std::fstream::app  );
			if( !csv_file_out.is_open() ){
				throw( "Error opening file - " + settings.csv_folder_path + filename + ".csv" );
			}
		}

		csv_file_out << bar->ticker     << ',' 
					 << today_date      << ',' 
					 << bar->ltt        << ',' 
					 << bar->bar_open   << ',' 
					 << bar->bar_high   << ',' 
					 << bar->bar_low    << ',' 
					 << bar->bar_close  << ',' 
					 << bar->volume     << ',' 
					 << bar->oi         << std::endl ;
    }

	if( csv_file_out.is_open() )
		csv_file_out.close();
}

void Worker::writeCurrentPrices( const std::stringstream  & current_prices){

	if( csv_file_out.is_open() )
		csv_file_out.close();

	csv_file_out.open( settings.csv_folder_path + "last_prices.csv",  std::fstream::out );
	if( !csv_file_out.is_open() ){
		throw( "Error opening file - last_prices.csv" );
	}

	csv_file_out << current_prices.rdbuf() << std::flush;
	
	if( csv_file_out.is_open() )
		csv_file_out.close();
}
