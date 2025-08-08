#!/bin/bash

# Script for syncing directories to an AWS S3 server.
#

#########################################
# Written by: Laurent Garnier
# Contact at: laurent@moocare.fr
# Date: 2025-08-07
# Version: 2.0
# License: GPLv3
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#########################################

#########################################
# Configuration section
#########################################
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    echo "Usage: $0 CUSTOMER_NAME DB_NAME DOMAIN_NAME HEARTBEAT [SUBDOMAIN_NAME]"
    exit 1
fi

CUSTOMER_NAME="$1"
DB_NAME="$2"
DOMAIN_NAME="$3"
HEARTBEAT="$4"
SUBDOMAIN_NAME="${5:-}"

TIMESTAMP=$(date +"%Y-%m-%d_%Hh%M")
DELDATE=$(date -d "-1 hour" +"%Y-%m-%d_%Hh%M")

FILE=$CUSTOMER_NAME"-db-$TIMESTAMP.sql"
DEL_FILE=$CUSTOMER_NAME"-db-$DELDATE.sql.gz"

B_DIRECTORY_DB="/var/backups/aws/db-$CUSTOMER_NAME"
B_DIRECTORY_DATA="/var/www/vhosts/$DOMAIN_NAME/moodledata"
B_DIRECTORY_DOCS="/var/www/vhosts/$DOMAIN_NAME/httpdocs"
if [ -n "$SUBDOMAIN_NAME" ] && [ "$SUBDOMAIN_NAME" != "0" ]; then
	B_DIRECTORY_DOCS="/var/www/vhosts/$DOMAIN_NAME/$SUBDOMAIN_NAME"
fi

S3_BUCKET="s3://$CUSTOMER_NAME/moodle/"
R_DIRECTORY_DB="${S3_BUCKET}db/"
R_DIRECTORY_DATA="${S3_BUCKET}moodledata/"
R_DIRECTORY_DOCS="${S3_BUCKET}httpdocs/"

ADMIN_EMAIL="contact@moocare.fr"

AWS="/usr/local/bin/aws"
MAIL="/usr/bin/mail"
AWS_SYNC="$AWS s3 sync --profile $CUSTOMER_NAME"

OUTDIR="/tmp"
EMAIL_FILE="$OUTDIR/email.txt"

#########################################
# DB BACKUP
#########################################
mariadb-dump --quick --single-transaction --max-allowed-packet=256M -uadmin -p$(cat /etc/psa/.psa.shadow) "$DB_NAME" > "$B_DIRECTORY_DB/$FILE"
gzip "$B_DIRECTORY_DB/$FILE"
COMPRESSED_FILE="$B_DIRECTORY_DB/$FILE.gz"

if [ ! -f "$COMPRESSED_FILE" ]; then
    echo "Compression failed. Exiting."
    exit 1
else
    rm -f "$B_DIRECTORY_DB/$FILE"
fi

$AWS_SYNC "$B_DIRECTORY_DB" "$R_DIRECTORY_DB" --delete
EXIT_DB=$?
case $EXIT_DB in
	0) O="Success.";;
	1) O="One or more Amazon S3 transfer operations failed.";;
	2) O="Command not parsed or files skipped.";;
	130) O="Command interrupted.";;
	252) O="Command syntax invalid.";;
	253) O="Invalid system environment or configuration.";;
esac

if [ $EXIT_DB != 0 ]; then
    echo "Backup result = $O" > "$EMAIL_FILE"
    echo "Date $(date)" >> "$EMAIL_FILE"
    $MAIL -s "MOODLE - $CUSTOMER_NAME - MOODLE DB - $(hostname) AWS Hourly Sync" $ADMIN_EMAIL < "$EMAIL_FILE"
    rm -f "$EMAIL_FILE"
else
    echo "$TIMESTAMP - MOODLE - $CUSTOMER_NAME - MOODLE DB - AWS Hourly Sync - success"
    rm -f "$B_DIRECTORY_DB/$DEL_FILE"
fi

#########################################
# MOODLEDATA BACKUP
#########################################
$AWS_SYNC "$B_DIRECTORY_DATA" "$R_DIRECTORY_DATA" --delete --exclude 'cache/*' --exclude 'temp/*' --exclude 'course-backups/*'
EXIT_DATA=$?
case $EXIT_DATA in
	0) O="Success.";;
	1) O="One or more Amazon S3 transfer operations failed.";;
	2) O="Command not parsed or files skipped.";;
	130) O="Command interrupted.";;
	252) O="Command syntax invalid.";;
	253) O="Invalid system environment or configuration.";;
esac

if [ $EXIT_DATA != 0 ]; then
    echo "Backup result = $O" > "$EMAIL_FILE"
    echo "Date $(date)" >> "$EMAIL_FILE"
    $MAIL -s "MOODLE - $CUSTOMER_NAME - MOODLEDATA - $(hostname) AWS Hourly Sync" $ADMIN_EMAIL < "$EMAIL_FILE"
    rm -f "$EMAIL_FILE"
else
    echo "$TIMESTAMP - MOODLE - $CUSTOMER_NAME - MOODLEDATA - AWS Hourly Sync - success"
fi

#########################################
# HTTPDOCS BACKUP
#########################################
$AWS_SYNC "$B_DIRECTORY_DOCS" "$R_DIRECTORY_DOCS" --delete
EXIT_DOCS=$?
case $EXIT_DOCS in
	0) O="Success.";;
	1) O="One or more Amazon S3 transfer operations failed.";;
	2) O="Command not parsed or files skipped.";;
	130) O="Command interrupted.";;
	252) O="Command syntax invalid.";;
	253) O="Invalid system environment or configuration.";;
esac

if [ $EXIT_DOCS != 0 ]; then
    echo "Backup result = $O" > "$EMAIL_FILE"
    echo "Date $(date)" >> "$EMAIL_FILE"
    $MAIL -s "MOODLE - $CUSTOMER_NAME - MOODLE HTTPDOCS - $(hostname) AWS Hourly Sync" $ADMIN_EMAIL < "$EMAIL_FILE"
    rm -f "$EMAIL_FILE"
else
    echo "$TIMESTAMP - MOODLE - $CUSTOMER_NAME - MOODLE HTTPDOCS - AWS Hourly Sync - success"
fi

#########################################
# HEARTBEAT if all 3 actions were successful
#########################################
if [ $EXIT_DB -eq 0 ] && [ $EXIT_DATA -eq 0 ] && [ $EXIT_DOCS -eq 0 ]; then
    if [ -n "$HEARTBEAT" ]; then
        echo "$TIMESTAMP - MOODLE - $CUSTOMER_NAME - HOURLY HEARTBEAT : $HEARTBEAT"
        # Uncomment the line below to send the heartbeat ping
        curl -fsS --retry 3 -X GET $HEARTBEAT > /dev/null
    fi
fi