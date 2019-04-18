# MDBBS - MongoDB Backup and Store


## Description

* __Filename:__		mdbbs_logrotate.bat
* __Created:__		11-02-2018
* __Modified:__		03-20-2019
* __Author:__		James Griffith
* __Version:__		2.0


The purpose of this batch file is to rotate the log of the MongoDB instance. Mongo does not do this automatically. This script will open a mongo shell, use adminDB and runCommand to start the internal LogRotate. Regardless if a logrotate is issued, the script will also clean up old log files. This script should be set to a scheduled task to be most effective.


## ToDo:
- [X] * Cron/Schedule logrotate task
- [X] * Add ability to target number of days to keep log files
- [X] * Add ability to reduce the size of logs during rotate. something less than 40MB file size
- [ ] * Add dynamics to the subroutines 'CheckMongoLogSize' and 'RemOldLog' to allow dynamic targetting of a given log file. Maybe command line flags




* __Filename:__		mdbbs_s3xfer.sh
* __Created:__		01-10-2019
* __Modified:__		01-10-2019
* __Author:__		James Griffith
* __Version:__ 		1.0


Cron script to catch the compressed backup made and off-loaded by mongoDBBackupandStore.bat. It will target a known S3 AWS bucket and upload the file to that bucket using the AWS CLI (must have AWS CLI installed on client machine for this script to function)

## ToDo:
- [ ] * placeholder



* __Filename:__		mongoDBBackupandStore.bat
* __Created:__		11-02-2018
* __Modified:__		01-16-2019
* __Author:__		James Griffith
* __Version:__		1.0


The purpose of this batch file is to compress a backup of the Monge DB using 7zip and then off load it to a network accessable storage device. Currently we will off load to the TVE OPS server to then be uploaded to an S3 bucket "tve-mongo-db-backup". From testing it looks like this will run best between midnight (server time) and prior to 5am. The over all running time averages to about 1 hour and 15 minutes total time for this script.

## ToDo:
- [ ] * placeholder



## History

* 11/02/2018 - Initial project creation
	* created mongoDBBackupandStore.bat
	* created mdbbs_logrotate.bat
* 01/10/2019 - Created mdbbs_s3xfer.sh
* 01/16/2019 - v1.0 mongoDBBackupandStore.bat released from testing. awaiting prod approval
* 03/20/2019 - v2.0 mdbbs_logrotate released to production
