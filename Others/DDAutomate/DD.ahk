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

#CommentFlag // 
#Include %A_ScriptDir%														// Set Include Directory path
#SingleInstance force														// Reloads if already running
#NoEnv																		// Recommended for new scripts
#Warn, All, StdOut

SendMode Input  															// Recommended for new scripts
SetWorkingDir %A_ScriptDir%  												// Ensures a consistent starting directory
SetTitleMatchMode, 2 														// A window's title can contain the text anywhere
SetControlDelay, -1 														// Without this ControlClick fails sometimes

TITLE := "Data Downloader"

fetchData()

FileDelete, Data\*.csv
FileMove, ..\*.csv, Data, 1

// Replace old name with new
// For Multiple add after ';' Example - s/JAM/BUTTER/g;s/BREAD/CRACKER/g

command := "sed.exe -i ""s/NIFTY,/NIFTY50,/g;s/15:30:00,/15:29:59,/g;"" Data/*.csv"
RunWait %comspec% /c %command%,, hide										            	

Run, cscript.exe ImportRT.js,, hide

return

/* open Data Downloader and fetch data 
*/
fetchData(){
	
	global TITLE
	
	Run, Data Downloader.exe, ..
	WinWait, %TITLE%, StatusStrip1
	WinSet, Transparent, 1, %TITLE%, StatusStrip1

	ControlSend, MenuStrip1, {Alt down}d{Alt up}ig , %TITLE%
	WinWait, %TITLE%, Heatmaps

	ControlSend, WindowsForms10.BUTTON.app.0.33c0d9d1, {Space}, %TITLE%
	WinWait, %TITLE%, Done

	WinClose, %TITLE%, StatusStrip1
}

