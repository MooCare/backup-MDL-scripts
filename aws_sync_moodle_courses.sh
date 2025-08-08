#!/bin/bash

# Script for syncing a directory to an AWS S3 server.
#

#########################################
# Written by: Laurent Garnier
# Contact at: laurent@moocare.fr
# Date: 2025-08-07
# Version: 2.0 (with heartbeat support)
# License: GPLv3
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#########################################

#########################################
# Configuration section
#########################################

# Check if the required arguments are provided
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 CUSTOMER_NAME DOMAIN_NAME HEARTBEAT"
    exit 1
fi

# Assign variables from arguments
CUSTOMER_NAME="$1"
DOMAIN_NAME="$2"
HEARTBEAT="$3"

# Directory to backup
B_DIRECTORY_DATA="/var/www/vhosts/$DOMAIN_NAME/moodledata"
B_DIRECTORY_COURSES="$B_DIRECTORY_DATA/course-backups"

# Remote S3 bucket path
S3_BUCKET="s3://$CUSTOMER_NAME/moodle/"
R_DIRECTORY_COURSES="${S3_BUCKET}course-backups/"

# Timestamp for logs
TIMESTAMP=$(date +"%Y-%m-%d_%Hh%M")

# Email for notifications
ADMIN_EMAIL="contact@moocare.fr"

# Paths to commands
AWS="/usr/local/bin/aws"
MAIL="/usr/bin/mail"
AWS_SYNC="$AWS s3 sync --profile $CUSTOMER_NAME"

# Temporary email file
OUTDIR="/tmp"
EMAIL_FILE="$OUTDIR/email.txt"

#########################################
# COURSE BACKUPS SYNC
#########################################
$AWS_SYNC "$B_DIRECTORY_COURSES" "$R_DIRECTORY_COURSES" --delete
EXIT_COURSES=$?
case $EXIT_COURSES in
	0) O="Success.";;
	1) O="One or more Amazon S3 transfer operations failed.";;
	2) O="Command not parsed or files skipped.";;
	130) O="Command interrupted.";;
	252) O="Command syntax invalid.";;
	253) O="Invalid system environment or configuration.";;
esac

# Error notification
if [ $EXIT_COURSES -ne 0 ]; then
    echo "Backup result = $O" > "$EMAIL_FILE"
    echo "Date $(date)" >> "$EMAIL_FILE"
    $MAIL -s "MOODLE - $CUSTOMER_NAME - COURSES - $(hostname) AWS Daily Sync" $ADMIN_EMAIL < "$EMAIL_FILE"
    rm -f "$EMAIL_FILE"
else
    echo "$TIMESTAMP - MOODLE - $CUSTOMER_NAME - COURSES - AWS Daily Sync - success"
fi

#########################################
# HEARTBEAT if success
#########################################
if [ $EXIT_COURSES -eq 0 ]; then
    if [ -n "$HEARTBEAT" ]; then
        echo "$TIMESTAMP - MOODLE - $CUSTOMER_NAME - DAILY HEARTBEAT : $HEARTBEAT"
        # Uncomment the line below to send the heartbeat ping
        curl -fsS --retry 3 -X GET "$HEARTBEAT" > /dev/null
    fi
fi