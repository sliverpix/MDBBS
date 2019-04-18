#!/bin/bash

# ##############################################################
# Cron script to upload mongoDB backups to S3 bucket
# using AWS CLI
#
# version:  	1.0
# Filename:  	mdbbs_s3xfer.sh
# Created:  	01-10-2019
# Modified:  	01-10-2019
# Authored: 	James Griffith
#
# ##############################################################

# Ping-Pong here we go!
# variables
WORKING_DIR=/home/Backups/MongoDB/
LOGFILE=mdbbs.log
FTPTOCFILE=mdbbs_ftp.toc

# prep dat and time stamps
SDATE=$(date +%D)
STIME=$(date +%T)
LTIMESTAMP="[ ${SDATE} : ${STIME} ]"

# current backup file


# #-- FUNCTIONS --# ##
# Keep track of what we do - yeah logging!
function Write-Log (){
	TYPEFLAG=$1
	LOGMESSAGE=$2
	
	if [ -z "$1" ]
	then
		echo "${LTIMESTAMP} - (Write-Log) No Type Flag Given!" 1>&2		# might want to create an error trap instead
		exit 1
	fi
	
	if [ -z "$2" ]
	then
		echo "${LTIMESTAMP} - (Write-Log) Must include a message to log." 1>&2
		exit 1	
	fi
	
	# set our the TYPE of log entry
	case "$1" in
		# INFO type message
		-i) echo "${LTIMESTAMP} - (Write-Log) [INFO] ${2}" >> ${LOGFILE}
			return 0
			;;
		# WARNing type message
		-w) echo "${LTIMESTAMP} - (Write-Log) [WARN] ${2}" >> ${LOGFILE}
			return 0
			;;
		# ERROR type message
		-e) echo "${LTIMESTAMP} - (Write-Log) [ERROR] ${2}" >> ${LOGFILE}
			return 0
			;;
		# DEBUGgin type message
		-d) echo "${LTIMESTAMP} - (Write-Log) [DEBUG] ${2}" >> ${LOGFILE}
			return 0
			;;
		# default something is wrong so return 1 and log it anyway
		*) echo "${LTIMESTAMP} - (Write-Log) Invalid TYPEFLAG - Use -i (INFO), -w (WARN), -e (ERROR), -d (DEBUG)" >> ${LOGFILE}
			echo "${LTIMESTAMP} - (Write-Log) Write-Log rec'd '${1}' and '${2}' as input." >> ${LOGFILE}
			# need to capture line number where function call was made
			return 1
			;;
	esac
}


# #-- MAIN BODY --# ##

cd ${WORKING_DIR}

# check for log file and update
if [ -e ${LOGFILE} ] && [ -w ${LOGFILE} ]
then
	Write-Log -i "__:: -- Found log file. Appending --::__"
else
	touch ${LOGFILE}
	Write-Log -i "--:: NEW Log file created ::--"
fi

# we only need a single file to upload to s3
# use the s3 bucket management to keep more backups than this one

# check for TOC file and read it
if [ -e ${FTPTOCFILE} ] && [ -r ${FTPTOCFILE} ]
then
	STARGETFILE=`cat ${FTPTOCFILE} | tr -d '[:space:]\r\n'`
	Write-Log -i "Found TOC file. Looking for ${STARGETFILE}"
else
	TOCRESULT=$?
	Write-Log -e "Cant find TOC file!"
	Write-Log -e "Exiting with status ${TOCRESULT}"
	exit $?
fi

# upload found file with AWS CLI
if [[ -e ${STARGETFILE} ]]
then
	Write-Log -i "Found ${STARGETFILE}. Attempting S3 upload..."
	`~/.local/bin/aws s3 cp /home/Backups/MongoDB/${STARGETFILE} s3://tve-mongo-db-backup/`
	AWSRESULT=$?
	
	# 0 is successful, 127 is cant find executable in PATH but it still succeeds to transfer
	if [ ${AWSRESULT} -gt 0 ] && [ ${AWSRESULT} -ne 127 ]
	then
		Write-Log -e "AWS CLI transfer failed with exit status: ${AWSRESULT}"
		Write-Log -e "Exiting script."
		exit $?
	fi
else
	Write-Log -e "Compressed file not found or is not readable!"
	Write-Log -e "Exiting with status: $?"
	exit $?
fi

Write-Log -d "Uploaded ${STARGETFILE} to S3 bucket TVE-MONGO-DB-BACKUP"

# cleanup unnecessary files - remove any zip that doesnt match our toc file.
# find all .7z files and remove them EXCEPT our currently uploaded file from the .TOC
find ${WORKING_DIR} \! -name ${STARGETFILE} -name \*.7z -exec rm -f {} \;
Write-Log -d "Cleaning up old backups..."

Write-Log -d "Completed. Good-bye Dave!"
exit 0
# __EOF__