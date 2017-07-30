#include "util.h"

#include <windows.h> 
#include <atlconv.h>

#include <iostream> 
#include <sstream>  
#include <fstream>
#include <algorithm>
#include <ctime>


 void Util::printVariant( const VARIANT &var ){
    if( var.vt == VT_I4  ){                    // Long        
        std::cout << var.lVal; 
    }
    else if( var.vt == VT_R8 ){                // Double        
        std::cout << var.dblVal ; 
    }
    else if( var.vt == VT_BSTR ){              // BSTR
        std::wcout << var.bstrVal ; 
    }    
} 
  
// 'Index Value' Field is sent by NEST as BSTR instead of double - so just make generic getters and handle all types
long long Util::getLong( const VARIANT &var ){
    long long output = 0; 

    if( var.vt == VT_I4  ){                    // Long
        output = var.lVal; 
    }
    else if( var.vt == VT_R8 ){                // Double
        output = (long long) var.dblVal ; 
    }
    else if( var.vt == VT_BSTR ){              // BSTR
		try{
			output = std::stoll( getString(var) );
		}
		catch(std::exception const & )
		{
			output = 0;
		}
    }
    return  output;
}

double Util::getDouble( const VARIANT &var ){
    double output = 0; 

    if( var.vt == VT_I4  ){                    // Long        
        output = (double)var.lVal; 
    }
    else if( var.vt == VT_R8 ){                // Double        
        output = var.dblVal ; 
    }
    else if( var.vt == VT_BSTR ){              // BSTR
		try{
			output = std::stod( getString(var)  );
		}
		catch(std::exception const & )
		{
			output = 0;
		}
    }    
    return  output;
}

std::string Util::getString( const VARIANT &var ){
    std::string output;

    if( var.vt == VT_I4  ){                    // Long        
        output = std::to_string((long long)var.lVal);            // VC++ 2010 - Initial C++11
    }                                                                // std::to_string - long long but not long
    else if( var.vt == VT_R8 ){                // Double        
        output = std::to_string((long double)var.dblVal) ; 
    }
    else if( var.vt == VT_BSTR){
        USES_CONVERSION;
        output = std::string ( OLE2A(var.bstrVal)) ;            // OLE2A dangerous - always copy output
    }    
    return output;
} 


std::string Util::getINIString(  const char *ini, const char *section, const char *key ){
        
    char buffer[512];
    GetPrivateProfileStringA( section, key, "", buffer, 512, ini);

    return std::string(buffer);
}

int Util::getINIInt( const char *ini, const char *section, const char *key ){
            
    return GetPrivateProfileIntA( section, key, 0  , ini );        
}


void Util::splitString( const std::string & string , char seperator,  std::vector<std::string> &output ){
    
    if( ! output.empty() ){
        output.clear();
    }

    std::stringstream  string_stream(string);
    std::string        segment;    

    while(std::getline(string_stream, segment, seperator)) {    // get line using ';' as end of line character
        output.push_back(segment);
    }    
}


std::string  Util::getTime( const char *format ){
        
    std::time_t  raw = std::time(0);    
    std::tm      local;
    localtime_s( &local, &raw );
    
    char buffer[64];
    strftime(buffer,64, format, &local );

    return std::string( buffer );
}

/* Input HH:MM:SS	
*/
std::string Util::addMinute( const std::string &time ){
	
	std::vector<std::string>  split;
	Util::splitString( time, ':', split ) ;
	
	long long HH = std::stoi( split[0] );						// long long needed for std::stoi  - VS 2010
	long long MM = std::stoi( split[1] );

	if( MM == 59 ){
		HH++;
		MM = 0;
	}
	else{
		MM++;
	}

	return addLeadingZero(HH) + ":" + addLeadingZero(MM) + ":" + split[2] ;
}

/* Input HH:MM:SS	
   Not handling 00:00:00  ( HH change )
*/
std::string Util::subSecond( const std::string &time ){
	
	std::vector<std::string>  split;
	Util::splitString( time, ':', split ) ;
	
	long long HH = std::stoi( split[0] );						// long long needed for std::stoi  - VS 2010
	long long MM = std::stoi( split[1] );
	long long SS = std::stoi( split[2] );

	// 12:00:00	12:01:00
	
	if( SS == 0 ){
		SS = 59;
		HH = MM==0 ? HH-1 : HH ;
		MM = MM==0 ? 59 : MM-1 ;
	}
	else{
		SS--;
	}

	return addLeadingZero(HH) + ":" + addLeadingZero(MM) + ":" + addLeadingZero(SS) ;
}

/*	Add leading 0 for single digit numbers
*/
std::string	Util::addLeadingZero( long long no ){
	return no<10	?	"0" + std::to_string(no)	:	std::to_string(no)  ;
}


void Util::trimString( std::string  &string  ){

    size_t begin = string.find_first_not_of(" \t\r\n");
    if (begin == std::string::npos){                            // Empty Line
        string = ""; 
        return;
    }

    size_t end    = string.find_last_not_of(" \t\r\n");    
    size_t length = end - begin + 1;

    string = string.substr(begin, length);
}

void Util::replaceTabsWithSpace( std::string & string  ){
    
    size_t size = string.size();
    
    for( size_t i=0 ; i<size ; i++ ){
        if( string[i] == '\t')
            string.replace(i, 1, " ");    
    }
}

// If folder does not exist, create it. Abort if failed
void Util::createDirectory( const std::string & dir  ){
        
    if( !CreateDirectoryA( dir.c_str(), NULL)  &&  ERROR_ALREADY_EXISTS != GetLastError()  ){
        DWORD                error = GetLastError();
        std::stringstream    msg;  msg << "Could not create folder - " << dir << " Error-" << error << std::endl ;
        throw  msg.str();
    }
}

void Util::printExceptionSilent( const std::string &msg ){
    std::cout << msg << std::endl;

    std::ofstream log_out( "./errorLog.txt", std::ios_base::app | std::ios_base::out );     // Append mode, open for writing.
    if( log_out .is_open()){ 
        log_out << Util::getTime("%Y:%m:%d %H:%M:%S") << " : " << msg << std::endl;        
        log_out.close();
    } 
}

void Util::printException( const std::string &msg ){
    printExceptionSilent( msg );  

    std::cout << "Press Enter to Quit" << std::endl;
    std::cin.ignore(); 
}

// Compare strings ignoring case
bool Util::isStringEqualIC(std::string str1 , std::string str2 ){
    std::transform(str1.begin(), str1.end(), str1.begin(), ::tolower);
    std::transform(str2.begin(), str2.end(), str2.begin(), ::tolower);

    return str1 == str2 ;
} 
