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
	local value																// All variables global except these
	
	IniRead, Mode, Settings.ini, BackfillMan, Mode
	IniRead, DoIndex, Settings.ini, BackfillMan, DoIndex

	IniRead, NowWindowTitle,  Settings.ini, BackfillMan, NowWindowTitle
	IniRead, DTWindowTitle,   Settings.ini, BackfillMan, DTWindowTitle
	IniRead, VWAPWindowTitle, Settings.ini, BackfillMan, VWAPWindowTitle	

	IniRead, BackfillExePath,        Settings.ini, BackfillMan, BackfillExePath
	IniRead, BackfillExe,  		     Settings.ini, BackfillMan, BackfillExe
	IniRead, DTBackfillFileName,     Settings.ini, BackfillMan, DTBackfillFileName
	IniRead, VWAPBackfillFileName,   Settings.ini, BackfillMan, VWAPBackfillFileName
	IniRead, EODBackfillTriggerTime, Settings.ini, BackfillMan, EODBackfillTriggerTime
	IniRead, HKBackfill, 			 Settings.ini, BackfillMan, HKBackfill
	IniRead, HKFlattenTL, 			 Settings.ini, BackfillMan, HKFlattenTL
	
	IniRead, value, Settings.ini, BackfillMan, PingerPeriod	
	PingerPeriod  :=  value * 60 * 1000										// Mins to ms	

	VWAPCount = 0
	Loop{	
		IniRead, value, Settings.ini, BackfillMan, VWAP%A_Index%
		if value = ERROR 
			break	
		VWAP%A_Index%  :=  value
		VWAPCount 	   :=  A_Index
	}

	DTCount = 0
	Loop{	
		IniRead, value, Settings.ini, BackfillMan, DataTable%A_Index%
		if value = ERROR 
			break	
		DT%A_Index%  :=  value
		DTCount 	 :=  A_Index
	}

	IndexCount = 0
	Loop{	
		IniRead, value, Settings.ini, BackfillMan, Index%A_Index%
		if value = ERROR 
			break	
		Index%A_Index%  := value
		IndexCount 	    := A_Index
	}
}
