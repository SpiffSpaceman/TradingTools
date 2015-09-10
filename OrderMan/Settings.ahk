/*
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
*/

loadSettings(){
	
	local value												// All variables global by default
	
	IniRead, Qty, 	  		    settings.ini, OrderMan, Qty
	IniRead, ProdType, 		    settings.ini, OrderMan, ProdType
    IniRead, DefaultStopSize,	settings.ini, OrderMan, DefaultStopSize
    IniRead, MaxStopSize,   	settings.ini, OrderMan, MaxStopSize
    
    IniRead, value, settings.ini, OrderMan, AutoSubmit
    AutoSubmit   := value=="true"
        
    IniRead, value,	settings.ini, OrderMan, Scrip    
	local fields := StrSplit( value , ",")
	Scrip  		 := getScrip(fields[1], fields[2], fields[3], fields[4], fields[5], fields[6] )
}