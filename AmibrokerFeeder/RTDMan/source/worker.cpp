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

#include <sstream>
#include <limits>
 

/**
 * Read Scrips and setup DS. Start Timers and start AB thread
 */
Worker::Worker():
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

    settings.loadSettings();

    rtd_client = new RTDClient();
    current    = new ScripState[ settings.no_of_scrips ] ;
    previous   = new ScripState[ settings.no_of_scrips ] ;
                                                                                    
    for( int i=0 ; i<settings.no_of_scrips ; i++ ){                        // Make map key topic_id and value = scripd_id,field_id 
        for( int j=0 ; j<FIELD_COUNT ; j++ ){                              // topic_id generated using FIELD_COUNT as base multiplier for each scrip
            topic_id_to_scrip_field_map[ i*FIELD_COUNT + j  ]  =  std::make_pair( i,j );
        }
    }    

    LARGE_INTEGER start_now = {0};                                         // Start Timers immediately    
//    SetWaitableTimer( AB_timer , &start_now, settings.bar_period, NULL, NULL, false );
    SetWaitableTimer( AB_timer , &start_now, settings.refresh_period, NULL, NULL, false );	// Bar period changed by Josh1
    
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
    ltp(0), vol_today(0), oi(0), bar_high(0), bar_low(std::numeric_limits<double>::infinity()), bar_open(0),
		push(0),															// Push flag added by Josh1    
		ask_rate(0), ask_qty(0), bid_rate(0), bid_qty(0)					//added by Boarders
{}

void Worker::ScripState::reset(){
    ltp = 0; vol_today = 0; oi =0; bar_high = 0; bar_low = std::numeric_limits<double>::infinity(); bar_open = 0; ltt=""; last_bar_ltt="";
		push = 0;														// Push flag added by Josh1    
		ask_rate =0; ask_qty =0; bid_rate =0; bid_qty =0;				// added by Boarders
}

bool Worker::ScripState::operator==(const ScripState& right) const{
    return (ltp == right.ltp)  && (vol_today == right.vol_today) &&
           (oi  == right.oi )  && (bar_high  == right.bar_high)  &&
           (ltt == right.ltt)  && (bar_low   == right.bar_low )  &&
		   //Inserted by Boarders
		   (bid_rate  == right.bid_rate ) && (ask_rate  == right.ask_rate ) &&  
		   (ask_qty  == right.ask_qty )   &&  (bid_qty  == right.bid_qty ); 
}

//Inserted by Josh1 --------------------------------------------------------------------
Worker::RTData::RTData() : 
    ltp(0), vol_today(0), oi(0),volume(0), ltt(""),ask_rate(0), ask_qty(0), bid_rate(0), bid_qty(0)
{}

void Worker::RTData::reset(){
    ltp = 0; vol_today = 0; oi =0; volume= 0; ltt.clear(); ask_rate =0; ask_qty =0; bid_rate =0; bid_qty =0;
}
//end Inserted by Josh1 --------------------------------------------------------------------

/** 
 * Connect Topics
 */
void Worker::connect(){
    
	rtd_client->initializeServer( settings.rtd_server_prog_id  );
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
	//Inserted by Boarders
		rtd_client->connectTopic(topic_id+BID_RATE,     topic_1, settings.scrips_array[i].topic_Bid_Rate  );
		rtd_client->connectTopic(topic_id+ASK_RATE,     topic_1, settings.scrips_array[i].topic_Ask_Rate  );
		rtd_client->connectTopic(topic_id+BID_QTY,      topic_1, settings.scrips_array[i].topic_Bid_Qty   );
		rtd_client->connectTopic(topic_id+ASK_QTY,      topic_1, settings.scrips_array[i].topic_Ask_Qty   );
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
    
	//inserted by Josh1 ------------------------------------------------------------
	RTData newdata;												
	int prev_field    = 999999999;
	int notified	  = 0;
	cur_tm			  = Util::getTime("%H"); //
	//end inserted by Josh1 ------------------------------------------------------------

	for( auto i=data->begin(), end=data->end() ;  i!=end ; ++i  ){
            
        const long   topic_id     = i->first;
        CComVariant  topic_value  = i->second;
                
        std::pair<int,int> &ids = topic_id_to_scrip_field_map.at( topic_id ) ; 
        int script_id   =  ids.first;                                      // Resolve Topic id to Scrip id and field
        int field_id    =  ids.second;

/********* Following code replaced by Josh1 with his code for two arrays current and previous ************************************************
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
                long long vol_today          = Util::getLong  ( topic_value );
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
/********* End code replaced by Josh1 with his code for two arrays current and previous ************************************************/
//		Changes made by Josh1  ****************************************************************************
        ScripState *_current = & current[script_id];
        ScripState *_previous = & previous[script_id];

		switch( field_id ){                        
            case VOLUME_TODAY :{  
                long long vol_today          = Util::getLong  ( topic_value );
               newdata.vol_today = vol_today;
			   break ;
            }
            case LTT  : {
				newdata.ltt  = Util::getString( topic_value );  
				break ;
			}

            case OI   :  newdata.oi   = Util::getLong  ( topic_value ); break ;
            case BID_RATE   :  newdata.bid_rate   = Util::getDouble  ( topic_value ); break ;
            case BID_QTY   :  newdata.bid_qty   = Util::getLong  ( topic_value ); break ;
            case ASK_RATE   :  newdata.ask_rate   = Util::getDouble  ( topic_value ); break ;
            case ASK_QTY   :  newdata.ask_qty   = Util::getLong  ( topic_value ); break ;

			case LTP :{													// This is last field received from RTD Server (Enum = 3)
				std::string  str ;
				str      = Util::getString( topic_value );
				if (str.length() < 1) {									//empty LTP sent by server in the morning in some cases
						newdata.reset();								//crashes RTDMan....  so skip  
						continue;
				}
				else {
					newdata.ltp  = Util::getDouble( topic_value );
				}

				std::string bar_ltt = newdata.ltt.substr(0,2);			//get time hour from newdata.ltt
					if(cur_tm == "09" && bar_ltt == "15"){				// Compare with current hour. If yesterdays's tick in the morning,
						newdata.reset();								//skip
						continue;
					}

				newdata.ltp = newdata.ltp * settings.scrips_array[script_id].ltp_multiplier ;

				if(newdata.ltt.length() < 5 ) newdata.ltt =  Util::getTime("%H:%M:%S"); 	//This is for Index which have no LTT field;

/**********************************************************************************************************
	            if( !isMarketTime( newdata.ltt  )){						
					newdata.reset();								//skip quotes outside market hours
		            continue;
			    }
/********************************************************************************************************/
/************************* Append milliseconds to LTT ------- Inserted by Josh1 **************************/
				if(settings.bar_period==0) {
					SYSTEMTIME lt;
					GetLocalTime(&lt); 
					std::stringstream stream;
					stream <<lt.wMilliseconds/10;
					std::string wM;
					wM  = stream.str();	
					newdata.ltt.append(".");
					newdata.ltt.append(wM);
				}
/**********************************************************************************************************/
				//Convert time from "%H:%M:%S" to "HHmmss" format
				if(!settings.bar_period==0) {
					newdata.ltt.erase(2,1);								// Remove colons in the time string
																		// If Bar Period is 60000 then "HHmm" format, 
																		//remove all characters after 4th else
					settings.bar_period == 60000 ? newdata.ltt.erase(4) : newdata.ltt.erase(4,1);	// Remove Colon and Seconds from time string
				}
				if (settings.view_raw_data == 1){
					std::cout <<"\n"<< script_id << "- ";
					std::cout << settings.scrips_array[script_id].topic_name << ",";
					std::cout << "LTT- " << newdata.ltt << ",";
					std::cout << "LTP- " << newdata.ltp << ",";
					std::cout << "N_Vtd- " << newdata.vol_today << ",";
					std::cout << "C_Vtd- " << _current->vol_today << ",";
					std::cout << "OI- " <<newdata.oi << ",";
					std::cout << "B- " <<newdata.bid_rate << ",";
					std::cout << "A- " <<newdata.ask_rate << ",";
					std::cout << "Bq- " <<newdata.bid_qty << ",";
					std::cout << "Aq- " <<newdata.ask_qty << ",";

				}
/**********************************************************************************************************/
			if(settings.scrips_array[script_id].topic_vol_today == "Volume Traded Today" ){
				settings.use_ltq = 0;
			}
				if (settings.use_ltq != 1){ 
					if(newdata.vol_today !=0 && newdata.vol_today == _current->vol_today){
						newdata.reset();								//If there is no change in volume means no trade so Skip !
						continue;
					}
				}
 				break ;    
            }
		}	
/**********************************************************************************************************/
				if (settings.view_tic_data == 1){
					std::cout <<"\n"<< script_id << " - ";
					std::cout << settings.scrips_array[script_id].topic_name << ", ";
					std::cout << "LTT - "		<< newdata.ltt		 << ", ";
					std::cout << "LTP - "		<< newdata.ltp		 << ", ";
					std::cout << "Vol_today - " << newdata.vol_today << ", ";
					std::cout << "OI - " <<newdata.oi << " ";
					std::cout << "B- " <<newdata.bid_rate << ",";
					std::cout << "A- " <<newdata.ask_rate << ",";
					std::cout << "Bq- " <<newdata.bid_qty << ",";
					std::cout << "Aq- " <<newdata.ask_qty << ",";
				}
/**********************************************************************************************************/

/********************************************************************************************************************
		Data from RTD server comes in pairs of Topic_id and field_id. We have topic _id as row numbers of scrips 
		from settings.ini. Whereas field_ids are columns. We have enumerated these field_id in worker.h as  
		LTT=0, VOLUME_TODAY=1, OI=2,LTP=3. Fortunately RTD Server sends data of each topic_id together and also in                                                           
		order of their ENUM. Hence data pairs come sequentially in the order OI=0,LTT=1, VOLUME_TODAY=2,BID_RATE=3,                                                         // "Bid Rate" 
		ASK_RATE=4, BID_QTY=5,ASK_QTY=6,LTP=7 
		Index does not have any field other than LTP. Equity will not have OI. However every scrip will have LTP.
		Therefore LTP is kept last at no.7 
		Once LTP is received, bar for that scrip is completed and it can be written to current bar.
*********************************************************************************************************************/

		if (field_id == LTP) {

			notifyActive();

			EnterCriticalSection( &lock );                                     // Lock when accessing current[] / previous[]

			if (newdata.ltt != current[script_id].ltt) {			// For startup or subsequent period, ltt != previous ltt
				if (_current->push == 1) {
					*_previous = *_current;							
				}
				else{
					previous[script_id].ltt = current[script_id].ltt;
					previous[script_id].vol_today = _current->vol_today;
				}
				if (settings.use_ltq != 1){ 
					if( newdata.vol_today !=0  &&  previous[script_id].vol_today == 0){
						if(newdata.ltt.substr(0,3) != "0915" || (newdata.ltt.substr(0,3) != "1000" 
							&& settings.scrips_array[script_id].topic_name.substr(0,3)=="mcx")){	//// Except for start of day
							previous[script_id].vol_today = newdata.vol_today;             // On startup prev vol is 0,
							_current->vol_today = newdata.vol_today;
						}																//Set it so that we can get first bar volume
					}																	
				}
                _current->bar_high	= _current->bar_low  = _current->bar_open = _current->ltp = newdata.ltp;
				_current->ltt		= newdata.ltt;
				_current->oi		= newdata.oi;
				if(settings.use_ltq == 1) {
					_current->volume	= newdata.vol_today ;
				}
				else { 
					if(settings.bar_period == 0){
						_current->volume	= newdata.vol_today - _current->vol_today; 
					}
					else{
						_current->volume	= newdata.vol_today- previous[script_id].vol_today;		//Changed by Josh1
					}
				}
				_current->vol_today = newdata.vol_today;
				_current->bid_rate	= newdata.bid_rate ;
				_current->ask_rate	= newdata.ask_rate;
				_current->bid_qty	= newdata.bid_qty ;
				_current->ask_qty	= newdata.ask_qty ;

				_current->push = 1;
				newdata.reset();
			}
			else {
                _current->ltp = newdata.ltp;
				_current->oi = newdata.oi;
				if( _current->bar_high < _current->ltp )    _current->bar_high = _current->ltp;
                if( _current->bar_low  > _current->ltp )    _current->bar_low  = _current->ltp;
				if(settings.use_ltq == 1) {
					_current->volume	= _current->volume + newdata.vol_today;
				}
				else  {
					if(settings.bar_period =0){												//Inserted 11-4-16
						_current->volume	= newdata.vol_today - _current->vol_today; 
					}
					else{
						_current->volume	= newdata.vol_today - previous[script_id].vol_today; 
					}
				}
				_current->vol_today = newdata.vol_today;     
				_current->bid_rate	= newdata.bid_rate ;
				_current->ask_rate	= newdata.ask_rate;
				_current->bid_qty	= newdata.bid_qty ;
				_current->ask_qty	= newdata.ask_qty ;
				_current->push = 1;
				newdata.reset();
			}
/**********************************************************************************************************/
				if (settings.view_bar_data == 1){
					std::cout <<"\n"<< script_id << " - ";
					std::cout << settings.scrips_array[script_id].ticker << " ";
					std::cout << "LTT- "	<< _current->ltt		<< ", ";
					std::cout << "LTP- "	<< _current->ltp		<< ", ";
					std::cout << "Vol- "	<< _current->volume		<< ", ";
					std::cout << "OI- "		<< _current->oi			<< ", ";
					std::cout << "B - "		<< _current->bid_rate	<< ", ";
					std::cout << "A - "		<< _current->ask_rate	<< ", ";	
					std::cout << "Bq - "	<< _current->bid_qty	<< ", ";
					std::cout << "Aq - "	<< _current->ask_qty	<< ", ";
				}
/**********************************************************************************************************/

		LeaveCriticalSection( &lock ) ;

		}
		prev_field = field_id;										//Set previous field id
	
//****** End Changes made by Josh1 **********************************************************************
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

/********* Following code replaced by Josh1 with his code for two arrays current and previous ************************************************
    // Shared data access start
        EnterCriticalSection( &lock );             

        for( int i=0 ; i<settings.no_of_scrips ; i++  ){                   // (B) Setup Bar data for each updated scrip using current and previous

            ScripState *_current  =  &current[i];
            ScripState *_prev     =  &previous[i];
            long long bar_volume  =  _current->vol_today - _prev->vol_today ;
            
            // if( i==0) std::cout << i <<": " << *_current << std::endl ; 
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
            if( bar_ltt == "15:29:59" && Util::getTime("%H") != "15"  ){   // Skip 15:29:59 if current hour is not 15 
                _current->reset();                                         //   to avoid yesterdays quote on open in NOW.
                _prev->reset();                                            // Reset Bars to avoid yesterday data in open bar 
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
				writeArchiveCsv( new_bars );							  // Archive ticks to be used for backfill
        }
        new_bars.clear();
/********* End code replaced by Josh1 with his code for two arrays current and previous ************************************************/
//		Changes made by Josh1  ****************************************************************************

		csv_file_out.open( settings.csv_path  );                               // Setup output stream to csv file
		if( !csv_file_out.is_open() ){                                         // Reopening will also clear old content by default
			throw( "Error opening file - " + settings.csv_path );        
		}

		int records =0;
	
        for( int i=0 ; i<settings.no_of_scrips ; i++  ){                   // (B) Setup Bar data for each updated scrip using current and previous

			ScripState *_current  =  &current[i];
            ScripState *_prev     =  &previous[i];
			std::string Scripname = settings.scrips_array[i].ticker;

		    // Shared data access start
			EnterCriticalSection( &lock );						    // Shared data access start

			if (_prev->push == 1) {
					if( settings.isTargetNT()){	
						if(settings.bar_period==0) {
							timestamp4=today_date+_prev->ltt.substr(0,2)+_prev->ltt.substr(3,2)+_prev->ltt.substr(6,2);
						} else {timestamp4=today_date+_prev->ltt.substr(6);}
						ninja_trader->LastPlayback( Scripname, _prev->ltp, _prev->volume, timestamp4 );
						if (!(_prev->bid_rate == 0 && _prev->ask_rate == 0)){
							if (_prev->bid_qty == 0 && _prev->ask_qty == 0){
								if((_prev->ltp - _prev->bid_rate) < (_prev->ask_rate - _prev->ltp)){
									_prev->bid_qty = _prev->volume;
								}
								else { _prev->ask_qty = _prev->volume;
								}
							}
							ninja_trader->AskPlayback( Scripname, _prev->ask_rate, _prev->ask_qty, timestamp4);  //bar->ask_qty, timestamp4 );
							ninja_trader->BidPlayback( Scripname, _prev->bid_rate, _prev->bid_qty, timestamp4 ); //bar->bid_qty, timestamp4);
/***********************************************************************************************************************
							std::cout << Scripname     << ','		// $FORMAT Ticker, Date_YMD, Time, Open, High, 
						        << timestamp4							<< ','		// Low, Close, Volume, OpenInt
								<< _prev->ltp						<< ','		// ltp is close
								<< _prev->volume					<< ',' 
								<< _prev->bid_rate					<< ',' // Say Aux1
								<< _prev->ask_rate					
								<< _prev->bid_qty		<< ','		//bid_qty goes to Volume
								<< _prev->ask_qty		<< ','		//ask_qty goes to Oi
								<< std::endl ;
/**********************************************************************************************************************/
						}
					}
			
					else{
						csv_file_out <<  Scripname    << ','		// $FORMAT Ticker, Date_YMD, Time, Open, High, 
			            << today_date							<< ','		// Low, Close, Volume, OpenInt
				        << _prev->ltt						<< ',' 
					    << _prev->bar_open					<< ',' 
						<< _prev->bar_high					<< ',' 
						<< _prev->bar_low					<< ',' 
						<< _prev->ltp						<< ','		// ltp is close
						<< _prev->volume					<< ',' 
						<< _prev->oi	;
						if (!(_prev->bid_rate == 0 && _prev->ask_rate == 0)){
							csv_file_out	<< ','
								<< _prev->bid_rate					<< ',' // Say Aux1
								<< _prev->ask_rate					
								<< std::endl ;

							if(!(_prev->bid_qty == 0 && _prev->ask_qty == 0)){
								csv_file_out	<<  Scripname+"e"    << ','		// $FORMAT Ticker, Date_YMD, Time, Open, High, 
												<< today_date			<< ','		// Low, Close, Volume, OpenInt
												<< _prev->ltt			<< ',' 
												<< ','								//open					<< 
												<< _prev->ask_rate		<< ','		//high					<< 
												<< _prev->bid_rate		<< ','		//Low					<< 
												<< _prev->ltp			<< ','		//Close						<<
												<< _prev->bid_qty		<< ','		//bid_qty goes to Volume
												<< _prev->ask_qty		<< ','		//ask_qty goes to Oi
												<< std::endl			;				//<< Aux1 and Aux2 empty
							}
						}
						else{csv_file_out << std::endl ;}
					}
					_prev->push = 0;
					records++;
			}

			if (_current->push == 1) {
					if( settings.isTargetNT()){	
						if(settings.bar_period==0) {
							timestamp4=today_date+_current->ltt.substr(0,2)+_current->ltt.substr(3,2)+_current->ltt.substr(6,2);
						} else {
							timestamp4=today_date+_current->ltt.substr(6);}

						ninja_trader->LastPlayback( Scripname, _current->ltp, _current->volume, timestamp4 );
						if (!(_current->bid_rate == 0 && _current->ask_rate == 0)){
							if (_current->bid_qty == 0 && _current->ask_qty == 0){
								if((_current->ltp - _current->bid_rate) < (_current->ask_rate - _current->ltp)){
									_current->bid_qty = _current->volume;
								}
								else { _current->ask_qty = _current->volume;
								}
							}
							ninja_trader->AskPlayback( Scripname, _current->ask_rate, _current->ask_qty, timestamp4);  //bar->ask_qty, timestamp4 );
							ninja_trader->BidPlayback( Scripname, _current->bid_rate, _current->bid_qty, timestamp4 ); //bar->bid_qty, timestamp4);
/***********************************************************************************************************************
							std::cout << Scripname     << ','		// $FORMAT Ticker, Date_YMD, Time, Open, High, 
						        << timestamp4							<< ','		// Low, Close, Volume, OpenInt
								<< _current->ltp						<< ','		// ltp is close
								<< _current->volume						<< ',' 
								<< _current->bid_rate					<< ','		// bid_rate goes to Say Aux1
								<< _current->ask_rate					<< ','		// ask_rate goes to say Aux2
								<< _current->bid_qty					<< ','		// bid_qty goes to Volume
								<< _current->ask_qty					<< ','		// ask_qty goes to OI
								<< std::endl ;
/**********************************************************************************************************************/
						}
					}
					else{
						csv_file_out	<< Scripname     << ','		// $FORMAT Ticker, Date_YMD, Time, Open, High, 
										<< today_date							<< ','		// Low, Close, Volume, OpenInt
										<< _current->ltt						<< ',' 
										<< _current->bar_open					<< ','		// O
										<< _current->bar_high					<< ','		// H
										<< _current->bar_low					<< ','		// L
										<< _current->ltp						<< ','		// ltp is close
										<< _current->volume						<< ',' 
										<< _current->oi ;        
						if (!(_current->bid_rate == 0 && _current->ask_rate == 0)){
							csv_file_out << ','
								<< _current->bid_rate	<< ','		// bid_rate goes to Say Aux1
								<< _current->ask_rate							// ask_rate goes to say Aux2
								<< std::endl ;

							if(!(_current->bid_qty == 0 && _current->ask_qty == 0)){
								csv_file_out	<< Scripname+"e"   << ','		// $FORMAT Ticker, Date_YMD, Time, Open, High, 
												<< today_date					<< ','		// Low, Close, Volume, OpenInt
												<< _current->ltt				<< ',' 
												<< ','										// O
												<< _current->ask_rate			<< ','		// H 
												<< _current->bid_rate			<< ','		// L
												<< _current->ltp				<< ','		// C 
												<< _current->bid_qty			<< ','		// bid_qty goes to Volume
												<< _current->ask_qty			<< ','		// ask_qty goes to OI
												<< std::endl					;			//<< Aux1 and Aux2 empty
							}
						}
						else{csv_file_out << std::endl ;}
					}
						_current->push = 0;
						records++;
			}

		LeaveCriticalSection( &lock );    // Shared data access end

		}

		csv_file_out.close();
		if(records == 0){
            notifyInactive();
		}
		if( !settings.isTargetNT()){	
			amibroker->import();    
			if(settings.request_refresh == 1){				// AmiBroker version 5.3 and below do not refresh automatically after import
			amibroker->refreshAll();
			}
		}

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

/***************************** Removed by Josh1 ***********************************************************
	Send OHLC to NinjaTrader
	Workaround - Send OHLC as ticks with 1/4 volume

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
			csv_file_out.open( settings.csv_folder_path + filename + + ".csv",  std::fstream::out | std::fstream::app  );
			if( !csv_file_out.is_open() ){
				throw( "Error opening file - " + settings.csv_folder_path + filename + + ".csv" );
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
/**********************   end removed by Josh1 *******************************************/
