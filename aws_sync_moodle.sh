#!/bin/bash

# Script for syncing directories to an AWS S3 server.
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
# Check if at least 3 arguments are provided
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 CUSTOMER_NAME DB_NAME DOMAIN_NAME [SUBDOMAIN_NAME]"
    exit 1
fi

# Assign variables from arguments
CUSTOMER_NAME="$1"
DB_NAME="$2"
DOMAIN_NAME="$3"
SUBDOMAIN_NAME="${4:-}" # Optional: If not provided, defaults to an empty string

#####
# Get the current date & time
TIMESTAMP=`date +"%Y-%m-%d_%Hh%M"`

#####
# Get the date & time for old file to delete
DELDATE=$(date -d "-1 hour" +"%Y-%m-%d_%Hh%M")

#####
FILE=$CUSTOMER_NAME"-db-$TIMESTAMP.sql"
DEL_FILE=$CUSTOMER_NAME"-db-$DELDATE.sql.gz"

####
# Directory to backup; The directory or directories
# to be backed up (spacer separeted)
B_DIRECTORY_DB="/var/backups/aws/db-"$CUSTOMER_NAME
B_DIRECTORY_DATA="/var/www/vhosts/"$DOMAIN_NAME"/moodledata"
B_DIRECTORY_DOCS="/var/www/vhosts/"$DOMAIN_NAME"/httpdocs"
if [ -n "$SUBDOMAIN_NAME" ] && [ "$SUBDOMAIN_NAME" != "0" ]
then
	B_DIRECTORY_DOCS="/var/www/vhosts/"$DOMAIN_NAME"/"$SUBDOMAIN_NAME
fi
#echo "$B_DIRECTORY_DOCS"
#exit



####
# Remote directory; Put here the directory in the
# remote server where you can write your backup
S3_BUCKET="s3://"$CUSTOMER_NAME"/moodle/"
R_DIRECTORY_DB=$S3_BUCKET"db/"
R_DIRECTORY_DATA=$S3_BUCKET"moodledata/"
R_DIRECTORY_DOCS=$S3_BUCKET"httpdocs/"


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


#########################################
# DB MOODLE PART

####
# Make database backup
mariadb-dump --quick --single-transaction --max-allowed-packet=256M -uadmin -p`cat /etc/psa/.psa.shadow` $DB_NAME > $B_DIRECTORY_DB/$FILE

# Compress the database dump
gzip $B_DIRECTORY_DB/$FILE
COMPRESSED_FILE="$B_DIRECTORY_DB/$FILE.gz"

# Remove the uncompressed file to avoid sending both versions
if [ -f "$COMPRESSED_FILE" ]; then
	rm -f $B_DIRECTORY_DB/$FILE
else
	echo "Compression failed. Exiting."
	exit 1
fi

# Send the archive to the AWS server
$AWS_SYNC $B_DIRECTORY_DB $R_DIRECTORY_DB --delete
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
	$MAIL -s "MOODLE - "$CUSTOMER_NAME" - MOODLE DB - $(hostname) AWS Hourly Sync" $ADMIN_EMAIL < $EMAIL_FILE
	rm -f $EMAIL_FILE
fi

# On backup success
if [ $EXIT_V == 0 ]
then
	echo "$TIMESTAMP - MOODLE - "$CUSTOMER_NAME" - MOODLE DB - AWS Hourly Sync - succes"
fi

# On backup success remove one old archive from the server
if [ $EXIT_V == 0 ]
then
	cd $B_DIRECTORY_DB
	rm $DEL_FILE
fi


#########################################
# MOODLE DATA PART

# Send the archive to the AWS server
$AWS_SYNC $B_DIRECTORY_DATA $R_DIRECTORY_DATA --delete --exclude 'cache/*' --exclude 'temp/*' --exclude 'course-backups/*' 
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
	$MAIL -s "MOODLE - "$CUSTOMER_NAME" - MOODLEDATA - $(hostname) AWS Hourly Sync" $ADMIN_EMAIL < $EMAIL_FILE
	rm -f $EMAIL_FILE
fi

# On backup success
if [ $EXIT_V == 0 ]
then
	echo "$TIMESTAMP - MOODLE - "$CUSTOMER_NAME" - MOODLEDATA - AWS Hourly Sync - succes"
fi

#########################################
# MOODLE HTTPDOCS PART

# Send the archive to the AWS server
$AWS_SYNC $B_DIRECTORY_DOCS $R_DIRECTORY_DOCS --delete
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
	$MAIL -s "MOODLE - "$CUSTOMER_NAME" - MOODLE HTTPDOCS - $(hostname) AWS Hourly Sync" $ADMIN_EMAIL < $EMAIL_FILE
	rm -f $EMAIL_FILE
fi

# On backup success
if [ $EXIT_V == 0 ]
then
	echo "$TIMESTAMP - MOODLE - "$CUSTOMER_NAME" - MOODLE HTTPDOCS - AWS Hourly Sync - succes"
fi

