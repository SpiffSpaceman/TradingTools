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


#include "reader.h"
#include "util.h"

#include <vector>
#include <iostream>
#include <sstream>

Reader::Reader(  const Settings &in_settings  ) :
  settings(in_settings)
{    
    today_date = Util::getTime("%Y%m%d");                                   // Todays date - yyyymmdd
}

Reader::~Reader(){
    if( fin.is_open() ){
        fin.close();
    }
    if( fout.is_open() ){
        fout.close();
    }                                                        
} 

// Common stuff before starting parsing of data
bool Reader::preProcess( const std::string &input_file ){
    if( !setUpInputStream(input_file) ){
        return false;
    }
    if( !fout.is_open() ){                                                  // Dont reset - use single csv import
        setUpOutputStream( settings.csv_file_path );
    }    
    return true;
}

bool Reader::parseVWAPToCsv(){
    
    if( !preProcess(settings.vwap_file_path) ) 
        return false;
        
    std::string               line;
    std::string               scrip_name;
    std::vector<std::string>  split;

    while( std::getline( fin, line  ) ){
                
        Util::trimString( line );                                                      // Remove leading and trailing spaces
        Util::replaceTabsWithSpace(line);                                              // Replace Tabs with space

        if( line.empty() ) continue;                                                   // Ignore Empty lines
                
        Util::splitString( line , '=', split ) ;                                       // Check for Scrip Name
        if( split.size() == 2 && split[0] == "name" ){
            scrip_name = split[1];
            continue;
        }

        if( scrip_name.empty() ){
            throw "Scrip Name not Found";
        }        
        
        Util::splitString( line , ' ', split ) ;                                       // Data. Expected format is 
                                                                                       // "09:15:00 AM 6447.00 6465.00 6439.55 6444.40 318900"  
        if( split.size() != 7){														   // Time AM/PM O H L C V
            std::stringstream msg;                                                     
            msg << "Could Not Parse Line. Split Size - " << split.size() << " Line - " << line;
            throw msg.str();            
        }
        
        std::string time  = split[0];
        std::string am_pm = split[1];
        if( am_pm == "PM" || am_pm == "pm" ){
            changeHHFrom12To24( time );    
        }

        postParse(scrip_name, today_date, time,split[2], split[3], split[4], split[5], split[6] );
    }   

    writeTickModeData();
    return true;
}

// "NIFTY14MARFUT    17-02-2014 09:20:00    6078.7000    6081.2000    6078.5000    6080.9500    53350"
bool Reader::parseDataTableToCsv( ){     
    
    if( !preProcess(settings.data_table_file_path) ) 
        return false;
        
    std::string               line;
    std::string               custom_name;
    std::vector<std::string>  split;
    std::vector<std::string>  date_split;
    std::string               today_date = Util::getTime("%Y%m%d");        // Get todays date - yyyymmdd
    
    while( std::getline( fin, line  ) ){
                
        Util::trimString( line );                                          // Remove leading and trailing spaces
        Util::replaceTabsWithSpace(line);                                  // Replace Tabs with space

        if( line.empty() ) continue;                                       // Ignore Empty lines
                
        Util::splitString( line , '=', split ) ;                           // Check for Scrip Name
        if( split.size() > 0 && split[0] == "name" ){
            if( split.size() == 2 ){
                custom_name = split[1];
            }
            else custom_name = "" ; 
            continue;
        }        
        
        Util::splitString( line , ' ', split ) ;                           // Data. Expected format is 
                                                                               // Name dd-mm-yyyy Time O H L C V
        if( split.size() != 8 && split.size() != 9 ){                          // Name can have one extra space - ex "CNX Nifty"
            std::stringstream msg;  
            msg << "Could Not Parse Line. Split Size - " << split.size() << " Line - " << line;
            throw msg.str();
        }

        bool is_2_name = split.size() == 9;                               // Does name have extra space? 
        std::string name, date, time, open, high, low, close, volume;                  
                    
        name    = !custom_name.empty()    ? custom_name  :  ( is_2_name ? split[0] + " " + split[1] : split[0] ); 
        
        volume  = is_2_name ? split[8] : split[7];
        date    = is_2_name ? split[2] : split[1];
        time    = is_2_name ? split[3] : split[2];
        open    = is_2_name ? split[4] : split[3];
        high    = is_2_name ? split[5] : split[4];
        low     = is_2_name ? split[6] : split[5];
        close   = is_2_name ? split[7] : split[6];
        
        Util::splitString( date, '-', date_split ) ;                               // Remove '-' from date 
        date = date_split[2]  + date_split[1] + date_split[0];

        postParse( name, date, time, open, high, low, close, volume );             
    }
    
    writeTickModeData();
    return true;
}
 
// Common stuff to be done for each row
void  Reader::postParse( const std::string &ticker, const std::string &date, const std::string &time,  const std::string &open,
                         const std::string &high,   const std::string &low,  const std::string &close,       std::string &volume ){
                                 
    if( settings.is_filter_time && ! isMarketHours(time)  )										// Skip outside trading hours if configured
        return;
    
	if( settings.is_singleday_mode && !isToday(date)  )
		return;
	


    // $FORMAT Ticker, Date_YMD, Time, Open, High, Low, Close, Volume
	// Save 15:30:00 as 15:29:59 to avoid extra bar in AB
    //std::string output_line = ticker + ',' + date + ',' + (time==settings.close_minute ? Util::subSecond(time) : time  ) + ',' + open + ',' + high + ',' + low + ','  + close  + ',' + volume; 

	std::string output_line = getOutputLine(ticker, date, time, open, high, low, close, volume); 

    if( settings.is_no_tick_mode ){                                                            // Send in sorted ascending order for tickmode for each ticker
		fout << output_line  << std::endl ;
    }
    else {
        sorted_data[date+ticker+time]  = output_line;

		if(date == today_date && time > scrip_end_time[ticker] )							   // Save Today's latest quote's timestamp for each Scrip. We need to send all ticks after this from RTDMan
			scrip_end_time[ticker] = time;
    }
}

/* Print output string for quote.
   Move last last few ticks outside market hours to within market hours. They contain the final close price
*/
std::string Reader::getOutputLine( const std::string &ticker, const std::string &date, const std::string &time,  const std::string &open,
						   		   const std::string &high,   const std::string &low,  const std::string &close,       std::string &volume ){

	std::string output_line;

	// Hardcoding some substitutions for now to get close price 	
	
	if( time == "15:30:00" ){
		if( volume == "0" )
			output_line = ticker + ',' + date + ',' + "15:29:57" + ',' + close + ',' + close + ',' + close + ','  + close  + ',' + volume; 
		else
			output_line = ticker + ',' + date + ',' + "15:29:57" + ',' + open + ',' + high + ',' + low + ','  + close  + ',' + volume; 
	}
	else if( time == "15:31:00" ){
		if( volume == "0" )
			output_line = ticker + ',' + date + ',' + "15:29:58" + ',' + close + ',' + close + ',' + close + ','  + close  + ',' + volume; 
		else
			output_line = ticker + ',' + date + ',' + "15:29:58" + ',' + open + ',' + high + ',' + low + ','  + close  + ',' + volume; 
	}
	else if( time == "15:32:00" ){
		if( volume == "0" )
			output_line = ticker + ',' + date + ',' + "15:29:59" + ',' + close + ',' + close + ',' + close + ','  + close  + ',' + volume; 
		else
			output_line = ticker + ',' + date + ',' + "15:29:59" + ',' + open + ',' + high + ',' + low + ','  + close  + ',' + volume; 
	}   
	else{
		output_line = ticker + ',' + date + ',' + time + ',' + open + ',' + high + ',' + low + ','  + close  + ',' + volume; 
	}
	return output_line;
}

// Write out data in sorted_data. Only used with $tickmode 1
void Reader::writeTickModeData(){
    if( sorted_data.empty() )
        return;
    
    // Data is already sorted by time. Just write it out
    
	for( std::map<std::string, std::string>::const_iterator it = sorted_data.begin(); it != sorted_data.end() ; ++it){
        fout << it->second << std::endl;
    }
    sorted_data.clear();

	writeRTDTicks();
}

/*
	For each scrip in backfill_end_time
		open RTD csv
		Fetch all lines after end time in sorted order
		Add lines to output csv
*/
void Reader::writeRTDTicks(){

	if( ! isMarketHours(Util::getTime()) ){										// RTD Ticks only needed during market hours. After EOD, only use VWAP/DT data
		scrip_end_time.clear();
		return;
	}

	for( std::map<std::string, std::string>::iterator it = scrip_end_time.begin(); it != scrip_end_time.end() ; ++it){		
		std::string	&time = it->second;											// HH:MM:SS			
		time			  = Util::addMinute( time );							// Shift time(start min) in scrip_end_time by 1 min forward to match with End Time
	}
	
	std::string				  alias, end_time, line;
	std::ifstream			  tickCsvFile;
	std::vector<std::string>  split;	

	std::string	today_date = Util::getTime("%Y%m%d");							// Get todays date - yyyymmdd 

	for( std::map<std::string, std::string>::const_iterator it = scrip_end_time.begin(); it != scrip_end_time.end() ; ++it){
    
		alias	  = it->first;
		end_time  = it->second;
		
		if( tickCsvFile.is_open() )
			tickCsvFile.close();

		tickCsvFile.open( settings.tick_path + alias + ".csv" ) ;
		if( !tickCsvFile.is_open() ){			
			continue;
		}

		while( std::getline( tickCsvFile, line ) ){								// Assuming tick file is already in sorted order with earlier ticks first
			 
			if( line.empty() ) continue; 
			Util::splitString( line , ',', split ) ; 
			
			if( split.size() < 3 ){
				std::stringstream msg;  
				msg << "Could Not Parse Line. Split Size - " << split.size() << " Line - " << line;
				throw msg.str();
			}

			if( today_date != split[1] )										// If date = today and time > end_time - Add line to csv
				continue;														// Format - "Ticker, Date_YMD, Time, Open, High, Low, Close, Volume, OpenInt"
			if( end_time > split[2] )											// Also take if time matches 
				continue;															// RTD Tick at exact timestamp as EndTime of VWAP/DT may or may not be part of VWAP/DT minute
																					// So we include it to make sure there is no price tick loss. At worst, will have some extra volume from that tick
			fout << line << std::endl;
		}
    }

    scrip_end_time.clear();
}

void Reader::closeOutput(){
    if( fout.is_open() ){
        fout.close();
    }
}

bool Reader::setUpInputStream(  const std::string &in_file  ){
    if( fin.is_open() ){
        fin.close();    
    }
    fin.open ( in_file );
    return fin.is_open();
}


void Reader::setUpOutputStream( const std::string &out_file   ){  
    if( fout.is_open() ){
        fout.close();
    }
    fout.open( out_file );
    if( !fout.is_open() ){
        throw "Error opening CSV file - " + out_file;        
    }
}

void Reader::changeHHFrom12To24( std::string &time ){                          // Increase hh by 12 (except 12 PM)
    
    std::vector<std::string>  split_strings;

    Util::splitString( time , ':', split_strings ) ;
    long long hh = std::stoll( split_strings[0] );

    if( hh < 12 ){
        hh += 12;
                
        std::stringstream concat;
        concat << hh << ':' << split_strings[1] << ':' << split_strings[2] ;
        time =  concat.str();
    } 
} 

bool Reader::isMarketHours( const std::string &time ){        
    if( time < settings.open_minute  || time > settings.close_minute ){     // Time H::M should be within open - close
        return false;                                                       // This works as time is in lexicographical order with leading 0
    }
    return true;
}

bool Reader::isToday( const std::string &date ){
	if( date != "" && date != today_date){
        return false;
    }
	return true;
}





