/*
  Copyright (C) 2017  SpiffSpaceman

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

/* 
  Overides control ids and Windows Title specific to Nest
*/
class NestControlsClass extends NowControlsClass{

	// Menu to open VWAP
	static VWAP_MENU := "Market,VWAP Statistics"		// Takes 2 comma separated values
	
	static VWAP_HEADER_START_TIME := ""
	static VWAP_HEADER_END_TIME   := "Time"
    
    static DT_INDEX_CHART_ID	  := "Static6"			// Id of a control within chart. Used to open datatable
}