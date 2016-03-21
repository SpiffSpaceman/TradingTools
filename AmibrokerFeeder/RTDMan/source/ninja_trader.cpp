
#include "ninja_trader.h"

NinjaTrader::NinjaTrader(void) :
	ninja_trader(NULL),
	Last_ptr(NULL)
{

	ninja_trader = LoadLibrary( L"NTDirect.dll" );
	
	if( !ninja_trader )
		throw( "Unable to load NTDirect.dll" );
	
	Last_ptr = (Last_type)GetProcAddress(ninja_trader, "Last");

	if( !Last_ptr )
		throw( "Unable to load Last() from NTDirect.dll" );
}


NinjaTrader::~NinjaTrader(void){

	//FreeLibrary(ninja_trader);
	ninja_trader = NULL;
	Last_ptr	 = NULL;
}


int NinjaTrader::Last( std::string instrument, double price, int size ){
	
	return Last_ptr( instrument.c_str(), price, size );	
}