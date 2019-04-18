@echo off

:: MongoDB Backup and Store
:: version:  	1.0
:: Filename:  	mongoDBBackupandStore.bat
:: Created:  	11-02-2018
:: Modified:  	01-16-2019
:: Authored: 	James Griffith
:: Summary:  	The purpose of this batch file is to compress a backup of the Monge DB
::     			using 7zip and then off load it to a network accessable storage device.
::				Currently we will off load to the TVE OPS server to then be uploaded to
::				an S3 bucket "tve-mongo-db-backup". From testing it looks like this will
::				run best between midnight (server time) and prior to 5am. The over all
::				running time averages to about 1 hour and 15 minutes total time for this
::				script.

SETLOCAL ENABLEEXTENSIONS

SET WORKDIR=C:\MongoDump\
SET DUMPDIR=%WORKDIR%dump\
REM SET DUMPDIR=%WORKDIR%testxfer\

:: reconstruct date-time to add to filename
SET FHOUR=%time:~0,2%
 if "%FHOUR:~0,1%"==" " set FHOUR=0%FHOUR:~1,1%
SET FMIN=%time:~3,2%
 if "%FMIN:~0,1%"==" " set FMIN=0%FMIN:~1,1%
SET FMONTH=%date:~4,2%
SET FDAY=%date:~7,2%
SET FYEAR=%date:~-4%
SET FILEDATE=%FHOUR%%FMIN%_%FMONTH%%FDAY%%FYEAR%

:: Output archive file name
SET CDUMPFILE=mongodump_%FILEDATE%.7z

:: FTP TOC (table of contents) file
SET FTPTOC=%WORKDIR%mdbbs_ftp.toc
ECHO %CDUMPFILE% > %FTPTOC%

:: Set Log files
SET BASELOGFILE=mdbbs.log
SET FTPLOGFILE=mdbbs_ftp.log

CD %WORKDIR%

:MakeLog
:: Add log rotation
IF EXIST %BASELOGFILE% (
 ECHO [%DATE% : %TIME%] --:: Starting script ... adding to log. >> %BASELOGFILE%
 GOTO :MONGOCHECK
) ELSE (
 ECHO [%DATE% : %TIME%] --:: Starting NEW Log ::-- > %BASELOGFILE%
 ECHO [%DATE% : %TIME%] --:: MongoDB Backup and Store - MDBBS >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] --:: version:	1.0 >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] --:: Filename:	mongoDBBackupandStore.bat >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] --:: Created:	11-2-2018 >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] --:: Modified:	01-15-2019 >> %BASELOGFILE%
 GOTO :MONGOCHECK
)

:: create dump of mongoDBBackupandStore
:MONGOCHECK
IF EXIST "C:\MongoDB\bin\mongodump.exe" (
 ECHO [%DATE% : %TIME%] Mongodump.exe found. >> %BASELOGFILE%
 ) ELSE (
 ECHO [%DATE% : %TIME%] Failed to find C:\MongoDB\bin\mongodump.exe >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] Terminating Script. >> %BASELOGFILE%
 GOTO :EOF
)

IF EXIST %DUMPDIR% (
 ECHO [%DATE% : %TIME%] Already took a MONGO DUMP! >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] Moving to Compression. >> %BASELOGFILE%
 GOTO :COMPRESS
 ) ELSE (
 ECHO [%DATE% : %TIME%] Starting DUMP. >> %BASELOGFILE%
 START /wait "MDBBS - Backup Dump" "c:\MongoDB\bin\mongodump.exe" --port 27017 -u "mongoadmin" -p "mongoadmin1!" --authenticationDatabase "admin" --oplog
REM START /wait "MDBBS - Backup Dump" "c:\MongoDB\bin\mongodump.exe" --port 27017 -u "Mongobackupuser" -p "backup1user" --authenticationDatabase "admin" --oplog
 )
 
 SET Mongodump_Result=%ERRORLEVEL%
 IF %Mongodump_Result% NEQ 0 (
  ECHO [%DATE% : %TIME%] mongodump.exe failed to create DUMP file. Check Mongodump Oplog. >> %BASELOGFILE%
  ECHO [%DATE% : %TIME%] MONGO DUMP returned: %Mongodump_Result% >> %BASELOGFILE%
  GOTO :EOF
 ) ELSE (
  ECHO [%DATE% : %TIME%] Dump created. Attempting to compress. >> %BASELOGFILE%
  ECHO [%DATE% : %TIME%] MONGO DUMP returned: %Mongodump_Result% >> %BASELOGFILE%
  GOTO :COMPRESS
 )

:COMPRESS
:: check for 7zip compression program
IF EXIST %CDUMPFILE% (
 ECHO [%DATE% : %TIME%] Already COMPRESSed a DUMP. Moving to TRANSFER. >> %BASELOGFILE%
 GOTO :TRANSFER
)

IF EXIST "C:\Program Files\7-Zip\7z.exe" (
 ECHO [%DATE% : %TIME%] 7zip found! Starting compression ... >> %BASELOGFILE%
 START /wait "MDBBS - Compress" "C:\Program Files\7-Zip\7z.exe" a %WORKDIR%%CDUMPFILE% %DUMPDIR% -r
 SET 7ZIP_RESULT=%ERRORLEVEL%
 ) else (
 ECHO [%DATE% : %TIME%] C:\Program Files\7-Zip\7z.exe NOT FOUND. >> %BASELOGFILE%
 GOTO :EOF
)

 IF %7ZIP_RESULT% EQU 255 (
   ECHO [%DATE% : %TIME%] [7Zip WARNING] - Compressioned stopped by USER or MANUAL termination. >> %BASELOGFILE%
   GOTO :EOF
 )

 IF %7ZIP_RESULT% EQU 8 (
   ECHO [%DATE% : %TIME%] [7Zip Error] - Not enough memory to complete compression operations! >> %BASELOGFILE%
   ECHO [%DATE% : %TIME%] [7Zip Error] - Cleaning up and Terminating script. >> %BASELOGFILE%
   GOTO :CLEANUP
 )

 IF %7ZIP_RESULT% EQU 7 (
   ECHO [%DATE% : %TIME%] [7Zip Error] - Command line error. Attempting to continue. >> %BASELOGFILE%
   GOTO :TRANSFER
 )

 IF %7ZIP_RESULT% EQU 2 (
   ECHO [%DATE% : %TIME%] [7Zip FATAL] - A FATAL Error occured while compressing %DUMPDIR%. Terminating script! >> %BASELOGFILE%
   GOTO :EOF
 )

 IF %7ZIP_RESULT% EQU 1 (
   ECHO [%DATE% : %TIME%] [7Zip WARNING] - Non Fatal Error occured while trying to compress %DUMPDIR%. >> %BASELOGFILE%
   ECHO [%DATE% : %TIME%] [7Zip WARNING] - One of the target files may have been locked by some process. These files were not compressed. >> %BASELOGFILE%
   ECHO [%DATE% : %TIME%] [7Zip WARNING] - Check if %CDUMPFILE% was created in %WORKDIR%. Attempting to transfer offsite. >> %BASELOGFILE%
   GOTO :TRANSFER
 )
  
 IF %7ZIP_RESULT% NEQ 0 (
  ECHO [%DATE% : %TIME%] Compression complete. Attempting to transfer. >> %BASELOGFILE%
  GOTO :TRANSFER
 )

 ECHO [%DATE% : %TIME%] [7Zip UNKNOWN] - An Unknown Error occured. Error Level reported %7ZIP_RESULT% >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] [7Zip UNKNOWN] - Terminating script. >> %BASELOGFILE%
 GOTO :EOF
   

:TRANSFER
:: move our compressed mongodump offsite
IF EXIST %WORKDIR%%CDUMPFILE% (
ECHO [%DATE% : %TIME%] %CDUMPFILE% found. Transfering ... >> %BASELOGFILE%

"C:\Program Files (x86)\WinSCP\WinSCP.com" ^
  /log="mdbbs_ftp.log" /ini=nul ^
  /command ^
	"option batch abort" ^
	"option confirm off" ^
    "open ftp://jgriffith:%%26mrcoffee__@10.250.83.92/" ^
    "cd /home/Backups/MongoDB" ^
    "put %CDUMPFILE%" ^
	"put %FTPTOC%" ^
    "exit"
) else (
 ECHO [%DATE% : %TIME%] Did compression fail? I cant find %CDUMPFILE% >> %BASELOGFILE%
 GOTO :EOF
)

set WINSCP_RESULT=%ERRORLEVEL%
if %WINSCP_RESULT% EQU 0 (
  ECHO [%DATE% : %TIME%] Successfully XFER'd %CDUMPFILE% to TVEOps-ToolServer: /home/Backups/MongoDB/ >> %BASELOGFILE%
  GOTO :CLEANUP
) else (
  ECHO [%DATE% : %TIME%] Unable to XFER %CDUMPFILE% to TVEOps-ToolServer. Check mdbbs_ftp.log for details. >> %BASELOGFILE%
  ECHO [%DATE% : %TIME%] Error Level returned %WINSCP_RESULT% >> %BASELOGFILE%
  GOTO :EOF
)

:CLEANUP
:: delete \dump\ directory from HYDRATXCAWDPP03
ECHO [%DATE% : %TIME%] Cleaning up... >> %BASELOGFILE%
IF EXIST %DUMPDIR% (
 RMDIR /Q /S %DUMPDIR%
 SET CLEANUP_RESULT=%ERRORLEVEL%
 IF %CLEANUP_RESULT% NEQ 0 (
	ECHO [%DATE% : %TIME%] FAILed to remove %DUMPDIR%! >> %BASELOGFILE%
	ECHO [%DATE% : %TIME%] CleanUp_Result = %CLEANUP_RESULT% >> %BASELOGFILE%
 ) else (
	ECHO [%DATE% : %TIME%] SUCESSfully removed %DUMPDIR% recursevily. >> %BASELOGFILE%
 )
) else (
 ECHO [%DATE% : %TIME%] Cant find %DUMPDIR%! Cleanup FAILED! >> %BASELOGFILE%
 GOTO :EOF
)

:: delete compressed file mongoDump.7z from HYDRATXCAWDPP03
IF EXIST %CDUMPFILE%(
	DEL /Q /F %WORKDIR%%CDUMPFILE%
	SET CLEANUP_RESULT=%ERRORLEVEL%
	IF %CLEANUP_RESULT% NEQ 0 (
		ECHO [%DATE% : %TIME%] FAILed to remove %CDUMPFILE% >> %BASELOGFILE%
		ECHO [%DATE% : %TIME%] CleanUp_Result = %CLEANUP_RESULT% >> %BASELOGFILE%
	) ELSE (
		ECHO [%DATE% : %TIME%] SUCCESSfully removed %CDUMPFILE% >> %BASELOGFILE%
	)	
) else (
	ECHO [%DATE% : %TIME%] Cant find %CDUMPFILE%! Cleanup FAILED! >> %BASELOGFILE%
	GOTO :EOF
)

:EOF
ECHO [%DATE% : %TIME%] EOF reached. Good-bye Dave! >> %BASELOGFILE%
EXIT /b