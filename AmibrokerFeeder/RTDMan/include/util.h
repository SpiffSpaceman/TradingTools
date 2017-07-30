#ifndef  RTDMAN_UTIL_H
#define  RTDMAN_UTIL_H
  
#include <string>
#include <vector>
#include <OAIdl.h>

class Util{

public:
    static void            printVariant( const VARIANT &var );
    
    static long    long    getLong  ( const VARIANT &var );
    static double          getDouble( const VARIANT &var );
    static std::string     getString( const VARIANT &var );

    static std::string     getINIString( const char *ini, const char *section, const char *key );
    static int             getINIInt   ( const char *ini, const char *section, const char *key );

    static void            splitString( const std::string & string,  char seperator, std::vector<std::string> &output );

    static std::string     getTime(   const char *format = "%H:%M:%S"  );    
	static std::string	   addMinute( const std::string &time );
	static std::string	   subSecond( const std::string &time );
	static std::string	   addLeadingZero( long long no );

    static void            trimString          ( std::string & string  );
    static void            replaceTabsWithSpace( std::string & string  );

    static void            createDirectory( const std::string & dir  );

    static void            printException( const std::string &msg );
    static void            printExceptionSilent( const std::string &msg );

    static bool            isStringEqualIC( std::string str1 , std::string str2 ) ; 
};

 
#endif
