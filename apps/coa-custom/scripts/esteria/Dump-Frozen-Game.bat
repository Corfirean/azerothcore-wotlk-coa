@echo off
rem Run this while the game is frozen ("not responding"): it writes a full memory dump of Ascension.exe
rem to C:\CoA-Build\esteria\hang_full.dmp for Claude. Then you can close the game.
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\CoA-Build\esteria\dump_full32.ps1"
pause
