/*
  Copyright (C) 2015  SpiffSpaceman

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
	local split
	
	IniRead, Mode, BackfillMan.ini, BackfillMan, Mode
	IniRead, DoIndex, BackfillMan.ini, BackfillMan, DoIndex

	IniRead, NowWindowTitle,  BackfillMan.ini, BackfillMan, NowWindowTitle
	IniRead, DTWindowTitle,   BackfillMan.ini, BackfillMan, DTWindowTitle
	IniRead, VWAPWindowTitle, BackfillMan.ini, BackfillMan, VWAPWindowTitle	

	IniRead, BackfillExePath,        BackfillMan.ini, BackfillMan, BackfillExePath
	IniRead, BackfillExe,  		     BackfillMan.ini, BackfillMan, BackfillExe
	IniRead, DTBackfillFileName,     BackfillMan.ini, BackfillMan, DTBackfillFileName
	IniRead, VWAPBackfillFileName,   BackfillMan.ini, BackfillMan, VWAPBackfillFileName
	IniRead, EODBackfillTriggerTime, BackfillMan.ini, BackfillMan, EODBackfillTriggerTime
	
	IniRead, HKBackfill, 			 BackfillMan.ini, BackfillMan, HKBackfill
	IniRead, HKBackfillAll,			 BackfillMan.ini, BackfillMan, HKBackfillAll
	IniRead, HKFlattenTL, 			 BackfillMan.ini, BackfillMan, HKFlattenTL
	IniRead, HKSetLayer, 			 BackfillMan.ini, BackfillMan, HKSetLayer
	IniRead, HKDelStudies, 		 	 BackfillMan.ini, BackfillMan, HKDelStudies
	
	IniRead, ABActiveWatchListPath,  BackfillMan.ini, BackfillMan, ABActiveWatchListPath
	IniRead, RTDManPath,  			 BackfillMan.ini, BackfillMan, RTDManPath
	
	
	IniRead, Server, BackfillMan.ini, BackfillMan, Server
    isServerNOW := (Server == "Now")

	IniRead, value, BackfillMan.ini, BackfillMan, PingerPeriod	
	PingerPeriod  :=  value * 60 * 1000										// Mins to ms	

	IniRead, START_TIME, 			 BackfillMan.ini, BackfillMan, StartTime
	IniRead, END_TIME, 				 BackfillMan.ini, BackfillMan, EndTime

	split 			:= StrSplit( START_TIME, ":") 
	START_HOUR		:= split[1]
	START_MIN		:= split[2]
	START_TIME_VWAP := subMinute( split[1], split[2] )
	
	split 		:= StrSplit( END_TIME, ":") 
	END_HOUR	:= split[1]
	END_MIN		:= split[2]

	VWAPCount := 0
	Loop{	
		IniRead, value, BackfillMan.ini, BackfillMan, VWAP%A_Index%
		if value = ERROR 
			break	
		VWAP%A_Index%  :=  value
		VWAPCount 	   :=  A_Index
	}

	DTCount := 0
	Loop{	
		IniRead, value, BackfillMan.ini, BackfillMan, DataTable%A_Index%
		if value = ERROR 
			break	
		DT%A_Index%  :=  value
		DTCount 	 :=  A_Index
	}

	IndexCount := 0
	Loop{	
		IniRead, value, BackfillMan.ini, BackfillMan, Index%A_Index%
		if value = ERROR 
			break	
		Index%A_Index%  := value
		IndexCount 	    := A_Index
	}
}
