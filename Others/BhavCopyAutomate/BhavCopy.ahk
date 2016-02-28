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

																			// If scrip name change, add both old and new names, old will be replaced by new name using sed later
scrips := "LT|MARUTI|PFC|SUNPHARMA|TATAMOTORS|TATASTEEL"
bhavCopyPath := "../NSE/*"

//bhavCopyPath := "Archive/*"


FileDelete, Data\*.csv

RunWait, rebol.exe -s ABCD.r, ..

command := "grep.exe -h -w -E """ . scrips . """ " . bhavCopyPath . " > data/output.csv"	// Extract quotes
RunWait %comspec% /c %command%,, hide

//command := "sed.exe -i ""s/PIRHEALTH/PEL/g;"" data/output.csv"				        // Replace old name with new
//RunWait %comspec% /c %command%,, hide										            // For Multiple add after ';' Example - s/JAM/BUTTER/g;s/BREAD/CRACKER/g

Run, cscript.exe ImportRT.js,, hide

return
