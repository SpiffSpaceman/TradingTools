
#include "ninja_trader.h"

NinjaTrader::NinjaTrader(void) :
	ninja_trader(NULL),
	Last_ptr(NULL)
{

	ninja_trader = LoadLibrary( L"NTDirect.dll" );
	
	if( !ninja_trader )
		throw( "Unable to load NTDirect.dll" );
	
	Last_ptr = (Last_type)GetProcAddress(ninja_trader, "Last");

	//Inserted by Josh1
	Ask_ptr = (Ask_type)GetProcAddress(ninja_trader, "AskPlayback");
	Bid_ptr = (Bid_type)GetProcAddress(ninja_trader, "BidPlayback");

	if( !Last_ptr )
		throw( "Unable to load Last() from NTDirect.dll" );

	//Inserted by Josh1
	if( !Ask_ptr)
		throw( "Unable to load Ask() from NTDirect.dll" );
	if( !Bid_ptr)
		throw( "Unable to load Bid() from NTDirect.dll" );

}


NinjaTrader::~NinjaTrader(void){

	//FreeLibrary(ninja_trader);
	ninja_trader = NULL;
	Last_ptr	 = NULL;

	//Inserted by Josh1
	Ask_ptr	 = NULL;
	Bid_ptr	 = NULL;

}

/***** Removed by Boarder
int NinjaTrader::Last( std::string instrument, double price, int size ){
	
	return Last_ptr( instrument.c_str(), price, size );	
}
****************End ********/

/************** Inserted by Boarder */
int NinjaTrader::LastPlayback( std::string instrument, double price, int size , std::string timestamp4 )
{
	
	return Last_ptr( instrument.c_str(), price, size , timestamp4.c_str());
}

int NinjaTrader::AskPlayback( std::string instrument, double price, int size, std::string timestamp4 )
{
	
	return Ask_ptr( instrument.c_str(), price, size , timestamp4.c_str());	
}

int NinjaTrader::BidPlayback( std::string instrument, double price, int size, std::string timestamp4 )
{
	
	return Bid_ptr( instrument.c_str(), price, size, timestamp4.c_str() );	
}