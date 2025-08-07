#!/bin/bash

# Script for syncing a directory to an AWS S3 server.
#

#########################################
# Written by: Laurent Garnier
# Contact at: 
# Release 1.1
# Web Page: 
# 
#########################################

#########################################
# Configuration section

#####
# Check if the required arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 CUSTOMER_NAME DOMAIN_NAME"
    exit 1
fi

# Assign variables from arguments
CUSTOMER_NAME="$1"
DOMAIN_NAME="$2"


####
# Directory to backup; The directory or directories
# to be backed up (spacer separeted)
B_DIRECTORY_DATA="/var/www/vhosts/"$DOMAIN_NAME"/moodledata"
B_DIRECTORY_COURSES=$B_DIRECTORY_DATA"/course-backups"


####
# Remote directory; Put here the directory in the
# remote server where you can write your backup
S3_BUCKET="s3://"$CUSTOMER_NAME"/moodle/"
R_DIRECTORY_COURSES=$S3_BUCKET"course-backups/"

#####
# Get the current date & time
TIMESTAMP=`date +"%Y-%m-%d_%Hh%M"`

####
# Admin email; Put here the email of the person who
# should receive the reports
ADMIN_EMAIL="contact@moocare.fr"

####
# Command locations; where your commands are, use which
# command to find them
AWS="/usr/local/bin/aws"
MAIL="/usr/bin/mail"
AWS_SYNC=$AWS" s3 sync --profile "$CUSTOMER_NAME


#########################################
# Program section
#########################################
OUTDIR="/tmp"
EMAIL_FILE="$OUTDIR/email.txt"

# Send the archive to the AWS server
$AWS_SYNC $B_DIRECTORY_COURSES $R_DIRECTORY_COURSES --delete
EXIT_V="$?"
case $EXIT_V in
	0) O="Success.";;
	1) O="One or more Amazon S3 transfer operations failed. ";;
	2) O="Command not parsed or files skipped.";;
	130) O="Command interruped.";;
	252) O="Command syntax invalid.";;
	253) O="invalid system environment or configuration.";;
esac

# Send notification on completion
if [ $EXIT_V != 0 ]
then
	touch $EMAIL_FILE
	echo "Backup result = $O" >> $EMAIL_FILE
	echo "Date $(date)" >> $EMAIL_FILE
	$MAIL -s "MOODLE - "$CUSTOMER_NAME" - COURSES - $(hostname) AWS Daily Sync" $ADMIN_EMAIL < $EMAIL_FILE
	rm -f $EMAIL_FILE
fi

# On backup success remove one old archive from the AWS S3 server
if [ $EXIT_V == 0 ]
then
	echo "$TIMESTAMP - MOODLE - "$CUSTOMER_NAME" - COURSES - AWS Daily Sync - succes"
fi

