#ifndef NINJATRADER_H
#define NINJATRADER_H

#include<string>
#include <windows.h>

class NinjaTrader{

private:	
	HMODULE ninja_trader;

	typedef int (__stdcall * Last_type) ( const char * instrument, double price, int size); 
	Last_type Last_ptr;

public:
	NinjaTrader(void);
	~NinjaTrader(void);

	int Last(std::string instrument, double price, int size);
};

#endif