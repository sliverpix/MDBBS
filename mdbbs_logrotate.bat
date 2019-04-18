@echo Off

REM		MDBBS - LogRotate
REM		version:  	2.0
REM		Filename:  	mdbbs_logrotate.bat
REM		Created:  	11-02-2018
REM		Modified:  	03-20-2019
REM		Authored: 	James Griffith
REM		Summary:  	The purpose of this batch file is to rotate the log of the MongoDB
REM					instance. Mongo does not do this automatically. This script will open
REM					a mongo shell, use adminDB and runCommand to start the internal LogRotate.
REM					Regardless if a logrotate is issued, the script will also clean up old log files.
REM					This script should be set to a scheduled task to be most effective.
REM
REM		ToDo:		add dynamics to the subroutines 'CheckMongoLogSize' and 'RemOldLog' to allow
REM					dynamic targetting of a given log file.

SETLOCAL ENABLEDELAYEDEXPANSION 
SETLOCAL ENABLEEXTENSIONS

:: Number of Days to keep old logs (default 7 days)
SET /A _iDaystoKeep=7

:: maximum file size (in bytes) before 'logrotate' is issued to mongo (default 20 MB)
set /A _iMaxByteSize=20480000

:: file names and directories
SET _sBaseMongoLog=mongod.log
SET _WORKDIR=C:\MongoDump\
SET _MONGODIR=C:\MongoDB\bin\
SET _MONGODBLOGDIR=C:\Data\log\
SET BASELOGFILE=!_WORKDIR!mdbbs.log
set _sFile=!_MONGODBLOGDIR!!_sBaseMongoLog!

SET _thisFILENAME=%~nx0

REM -------- Start Main Script Body -------
:Main
CALL :f_MakeLog

CALL :f_CheckMongoLogSize
SET MongoLogSizeResult=%ERRORLEVEL%

IF %MongoLogSizeResult% NEQ 0 (
	REM Mongod.log is to small to rotate so exit script
	IF %MongoLogSizeResult% EQU 10 (
		ECHO [%DATE% : %TIME%] %_sBaseMongoLog% found and is less than %_iMaxByteSize% >> %BASELOGFILE%
		ECHO [%DATE% : %TIME%] No need to rotate the log. >> %BASELOGFILE%
	)
	
	REM Mongod.log was not found - something is wrong - check path/variables above
	IF %MongoLogSizeResult% EQU 2 (
		ECHO [%DATE% : %TIME%] Something went wrong. Check variables "_sBaseMongoLog" and "_MONGODBLOGDIR". >> %BASELOGFILE%
		ECHO [%DATE% : %TIME%] Might need to check that the file IS NOT write/read protected. >> %BASELOGFILE%
	)
	
) ELSE (
	ECHO [%DATE% : %TIME%] Rotating %_sBaseMongoLog% to new log ... >> %BASELOGFILE%
	
	CALL :f_RotateLog
	SET RotateLogResult=%ERRORLEVEL%
	IF !RotateLogResult! NEQ 0 (
		REM mongo.exe was not found in the path.
		IF !RotateLogResult! EQU 2 (
			ECHO [%DATE% : %TIME%] Failed to find mongo in the path specifed in variable "_MONGODIR" >> %BASELOGFILE%
		)
		
		REM mongo shell broke. capture error code and return 1 for application failure
		IF !RotateLogResult! EQU 1 (
			ECHO [%DATE% : %TIME%] Mongo shell returned an unexpected error. >> %BASELOGFILE%
		)
		
	) else (
		REM RotateLog was successfull.
		ECHO [%DATE% : %TIME%] DONE with MongoDB - LogRotate completed successfully. >> %BASELOGFILE%
	)
)


CALL :f_RemOldLog
SET RemOldLogResult=%ERRORLEVEL%
IF !RemOldLogResult! NEQ 0 (
	ECHO [%DATE% : %TIME%] Subroutine RemOldLog failed with code: %RemOldLogResult% >> %BASELOGFILE%
)

ECHO [%DATE% : %TIME%] End of Main Body. Exiting %_thisFILENAME% >> %BASELOGFILE%
GOTO :eof

REM -------- End Main Script Body --------


REM -------- Start Subroutines --------

:f_RemOldLog
ECHO [%DATE% : %TIME%] Checking for %_sBaseMongoLog%s older than %_iDaystoKeep% days >> %BASELOGFILE%
ECHO [%DATE% : %TIME%] TARGETING: %_MONGODBLOGDIR% ... >> %BASELOGFILE%
ECHO [%DATE% : %TIME%] Removing the following file(s) ... >> %BASELOGFILE%

FORFILES /p !_MONGODBLOGDIR! /m "!_sBaseMongoLog!.*" /C "cmd /c echo @file ... @fdate&del @file" /D -!_iDaystoKeep! >> !BASELOGFILE!
SET ForFilesResult=%ERRORLEVEL%
ECHO [%DATE% : %TIME%] ForFiles Exit: %ForFilesResult% >> %BASELOGFILE%

IF !ForFilesResult! NEQ 0 (
	ECHO [%DATE% : %TIME%] FORFILES failed to find any matches. >> %BASELOGFILE%
	ECHO [%DATE% : %TIME%] Search Path: %_MONGODBLOGDIR% >> %BASELOGFILE%
	ECHO [%DATE% : %TIME%] Search Mask: %_sBaseMongoLog%* >> %BASELOGFILE%
	ECHO [%DATE% : %TIME%] Days to Keep: %_iDaystoKeep% >> %BASELOGFILE%
	REM Forfiles failed for some reason. combine exit code 2 & 3 plus the number of days to keep and return
	EXIT /B 23!_iDaystoKeep!
) ELSE (
	ECHO [%DATE% : %TIME%] Old files removed successfully. >> %BASELOGFILE%
	EXIT /B 0
)


:f_CheckMongoLogSize
IF EXIST !_sFile! (
	REM Log File Exists
	ECHO [%DATE% : %TIME%] Checking file size of %_sBaseMongoLog% ... >> %BASELOGFILE%

	REM This whole piece worked but fails after i close the dos window... wtf eh!?!?!
	REM found the problem. this works now. There is a known bug with the way DOS handles
	REM FOR loop variable expansion. 
	REM https://www.robvanderwoude.com/variableexpansion.php
	FOR %%I IN (!_sFile!) DO (
		SET fSIZE=!fSIZE!%%~zI
		ECHO [%DATE% : %TIME%] Size of %%I is !fSIZE! bytes >> %BASELOGFILE%
	)
	
	IF !fSIZE! LSS !_iMaxByteSize! (
		ECHO [%DATE% : %TIME%] %_sBaseMongoLog% is ^< %_iMaxByteSize% bytes >> %BASELOGFILE%
		ECHO [%DATE% : %TIME%] Not rotating this time. >> %BASELOGFILE%
		REM return with 10 = File found and size is too small for log rotate
		EXIT /B 10
	) ELSE (
		ECHO [%DATE% : %TIME%] %_sBaseMongoLog% is ^>= %_iMaxByteSize% bytes >> %BASELOGFILE%
		REM return with 0 = File found and size is big enough to log rotate
		EXIT /B 0
	)
	
) ELSE (
	REM mongod.log File does NOT exist
	ECHO [%DATE% : %TIME%] Can not find %_sBaseMongoLog% in path %_MONGODBLOGDIR% >> %BASELOGFILE%
	REM return with 2 = Mongod.log not found in the path given
	EXIT /B 2
)


:f_MakeLog
:: create/append base log file
IF EXIST !BASELOGFILE! (
	ECHO [%DATE% : %TIME%] --:: Starting %_thisFILENAME% script ... adding to log. >> %BASELOGFILE%
	EXIT /B 0
) ELSE (
	ECHO [%DATE% : %TIME%] --:: Starting NEW Log ::-- > %BASELOGFILE%
	ECHO [%DATE% : %TIME%] --:: MongoDB Backup and Store - MDBBS >> %BASELOGFILE%
	ECHO [%DATE% : %TIME%] --:: Filename:	%_thisFILENAME% >> %BASELOGFILE%
	ECHO [%DATE% : %TIME%] --:: version:	2.0 >> %BASELOGFILE%
	ECHO [%DATE% : %TIME%] --:: Created:	11-2-2018 >> %BASELOGFILE%
	ECHO [%DATE% : %TIME%] --:: Modified:	03-19-2019 >> %BASELOGFILE%
	EXIT /B 0
)

:f_RotateLog
ECHO [%DATE% : %TIME%] Having fun with mongo ... >> %BASELOGFILE%
IF EXIST "!_MONGODIR!mongo.exe" (
	ECHO [%DATE% : %TIME%] Found MONGO ... trying logrotate >> %BASELOGFILE%
	mongo admin --eval "db.runCommand({logRotate:1})" --quiet >> !BASELOGFILE!
	SET MongoRotateResult=%ERRORLEVEL%
) ELSE (
	ECHO [%DATE% : %TIME%] Couldnt find mongo in %_MONGODIR% ... Terminating. >> %BASELOGFILE%
	REM mongo.exe was not found in the path.
	EXIT /B 2
)
	
IF %MongoRotateResult% NEQ 0 (
	ECHO [%DATE% : %TIME%] MONGO shell failed with EXIT CODE: %MongoRotateResult% >> %BASELOGFILE%
	ECHO [%DATE% : %TIME%] See https://docs.mongodb.com/manual/reference/exit-codes/ for list of exit codes. >> %BASELOGFILE%
	REM mongo shell broke. capture error code and return it for application failure
	EXIT /B %MongoRotateResult%
) ELSE (
	ECHO [%DATE% : %TIME%] MONGO shell completed successfully. >> %BASELOGFILE%
	REM shell command completed. return 0 for success
	EXIT /B 0
) 


REM -------- End Subroutines --------

:eof
EXIT