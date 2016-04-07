#ifndef NINJATRADER_H
#define NINJATRADER_H

#include<string>
#include <windows.h>

class NinjaTrader{

private:	
	HMODULE ninja_trader;

	typedef int (__stdcall * Last_type) ( const char * instrument, double price, int size, const char * timestamp4); 
	Last_type Last_ptr;
	//Inserted Ask Bid by Boarders
	typedef int (__stdcall * Ask_type) ( const char * instrument, double price, int size, const char * timestamp4); 
	Ask_type Ask_ptr;
	typedef int (__stdcall * Bid_type) ( const char * instrument, double price, int size, const char * timestamp4); 
	Bid_type Bid_ptr;

public:
	NinjaTrader(void);
	~NinjaTrader(void);

//	int Last(std::string instrument, double price, int size); removed by Boarders
	//Inserted Ask Bid by Boarders
	int LastPlayback(std::string instrument, double price, int size, std::string timestamp4);
	int AskPlayback(std::string instrument, double price, int size, std::string timestamp4);
	int BidPlayback(std::string instrument, double price, int size, std::string timestamp4);

};

#endif