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

#include <iostream>
#include <sstream>

Reader::Reader(  const Settings &in_settings ) :
settings(in_settings) {    
    today_date = Util::getTime("%Y%m%d");                                  // Todays date - yyyymmdd
}

Reader::~Reader(){
    if( fin.is_open() ){
        fin.close();
    }
    if( fout.is_open() ){
        fout.close();
    }                                                        
}
 

bool Reader::parseVWAPToCsv(){
        
    if( !setUpInputStream( settings.vwap_file_path) ){
        return false;
    }

    if( !fout.is_open() ){                                                 // Dont reset - use single csv import
        setUpOutputStream( settings.csv_file_path );
    }
        
    std::string               line;
    std::string               scrip_name;
    std::vector<std::string>  split;

    while( std::getline( fin, line  ) ){
                
        Util::trimString( line );                                          // Remove leading and trailing spaces
        Util::replaceTabsWithSpace(line);                                  // Replace Tabs with space

        if( line.empty() ) continue;                                           // Ignore Empty lines
                
        Util::splitString( line , '=', split ) ;                               // Check for Scrip Name
        if( split.size() == 2 && split[0] == "name" ){
            scrip_name = split[1];
            continue;
        }

        if( scrip_name.empty() ){
            throw "Scrip Name not Found";
        }        
        
        Util::splitString( line , ' ', split ) ;                                       // Data. Expected format is 
                                                                                       // "09:15:00 AM 6447.00 6465.00 6439.55 6444.40 318900"  
        if( (!settings.is_skip_volume && split.size() != 7)  ||                        // Time AM/PM O H L C V
            ( settings.is_skip_volume && split.size() != 7 && split.size() != 6 )      // Allow empty volume if dont need             
          ){
            std::stringstream msg;                                                     
            msg << "Could Not Parse Line. Split Size - " << split.size() << " Line - " << line;
            throw msg.str();            
        }
        
        std::string time  = split[0];
        std::string am_pm = split[1];
        if( am_pm == "PM" || am_pm == "pm" ){
            changeHHFrom12To24( time );    
        }

        if( settings.is_skip_open_minute && settings.open_minute == time )            // Skip 09:15:00
            continue;        
        if( settings.is_intraday_mode && ! isIntraday(time)  )
            continue;         

        std::string volume = settings.is_skip_volume ? "0" : split[6];        

        // $FORMAT Ticker, Date_YMD, Time, Open, High, Low, Close, Volume
        fout << scrip_name << ',' << today_date << ',' << time << ',' << split[2] << ',' << split[3] << ',' << split[4] << ',' 
             << split[5]   << ',' << volume     << std::endl ;             
    }   
    return true;
}


// "NIFTY14MARFUT    17-02-2014 09:20:00    6078.7000    6081.2000    6078.5000    6080.9500    53350"
bool Reader::parseDataTableToCsv(){
        
    if( !setUpInputStream( settings.data_table_file_path ) ) {
        return false;
    }

    if( !fout.is_open() ){                                                  // Dont reset - use single csv import
        setUpOutputStream( settings.csv_file_path );
    }
        
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
        volume  = settings.is_skip_volume ? "0"          :  ( is_2_name ? split[8] : split[7] ); 

        date    = is_2_name ? split[2] : split[1];
        time    = is_2_name ? split[3] : split[2];
        open    = is_2_name ? split[4] : split[3];
        high    = is_2_name ? split[5] : split[4];
        low     = is_2_name ? split[6] : split[5];
        close   = is_2_name ? split[7] : split[6];
                       
        if( settings.is_skip_open_minute && settings.open_minute == time )         // Skip 09:15:00
            continue;        
        
        Util::splitString( date, '-', date_split ) ;                               // Remove '-' from date 
        date = date_split[2]  + date_split[1] + date_split[0];      
        
        if( settings.is_intraday_mode && ! isIntraday(time, date)   )
            continue;                                             
        
        // $FORMAT Ticker, Date_YMD, Time, Open, High, Low, Close, Volume
        fout << name  << ',' << date << ',' << time << ','  << open   << ',' 
             << high  << ',' << low  << ',' << close << ',' << volume << std::endl ;
    }

    return true;
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

bool Reader::isIntraday( const std::string &time, const std::string &date ){    
    if( date != "" && date != today_date){                                  // 1. date should be today if not empty
        return false;
    }                                                                                
    if( time < settings.open_minute  || time > settings.close_minute ){     // 2. Time H::M should be within 
        return false;                                                       // This works as time is in lexicographical order with leading 0
    }
    return true;
}





