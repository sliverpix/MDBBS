@echo off


:: MDBBS - LogRotate
:: version:  	1.0
:: Filename:  	mdbbs_logrotate.bat
:: Created:  	11-02-2018
:: Modified:  	02-21-2019
:: Authored: 	James Griffith
:: Summary:  	The purpose of this batch file is to rotate the log of the MongoDB
::				instance. Mongo does not do this automatically. This script will open
::				a mongo shell, used adminDB and runCommand to start the internal LogRotate.
::				This script should be set to a scheduled task to be most effective.
::
:: ToDo:
::					-- remove old logs every 30 days (to start)
::					-- schedule 1/day @ 0200 CST

SETLOCAL ENABLEEXTENSIONS

:: set variables
SET _WORKDIR=C:\MongoDump\
SET _MONGODIR=C:\MongoDB\bin
SET _MONGODBLOGDIR=C:\Data\Log
SET BASELOGFILE=%_WORKDIR%mdbbs.log
SET _thisFILENAME=%~nx0

:MakeLog
:: create/append base log file
IF EXIST %BASELOGFILE% (
 ECHO [%DATE% : %TIME%] --:: Starting %_thisFILENAME% script ... adding to log. >> %BASELOGFILE%
 GOTO :f_RotateLog
) ELSE (
 ECHO [%DATE% : %TIME%] --:: Starting NEW Log ::-- > %BASELOGFILE%
 ECHO [%DATE% : %TIME%] --:: MongoDB Backup and Store - MDBBS >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] --:: version:	1.0 >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] --:: Filename:	%_thisFILENAME% >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] --:: Created:	11-2-2018 >> %BASELOGFILE%
 ECHO [%DATE% : %TIME%] --:: Modified:	02-20-2019 >> %BASELOGFILE%
)


:f_RotateLog
cd %_MONGODIR%
ECHO [%DATE% : %TIME%] Having fun with mongo ... >> %BASELOGFILE%
IF EXIST "mongo.exe" (
	ECHO [%DATE% : %TIME%] Found MONGO ... trying logrotate >> %BASELOGFILE%
	mongo admin --eval "db.runCommand({logRotate:1})"
	SET _ROTATERESULT=%ERRORLEVEL%
) else (
	ECHO [%DATE% : %TIME%] Couldnt find mongo in %_MONGODIR% ... Terminating. >> %BASELOGFILE%
	exit /b 1
)
	
IF %_ROTATERESULT% NEQ 0 (
	ECHO [%DATE% : %TIME%] MONGO shell failed >> %BASELOGFILE%
	exit /b 1
)

CD C:\MongoDump\
ECHO [%DATE% : %TIME%] --:: DONE with MongoDB - LogRotate completed successfully. >> %BASELOGFILE%
