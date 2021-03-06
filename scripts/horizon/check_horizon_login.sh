#!/bin/bash
#
# Nova create instance monitoring script for Sensu / Nagios
#
# Copyright © 2014 eNovance <licensing@enovance.com>
#
# Author: Florian Lambert <florian.lambert@enovance.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Requirement: curl
#

# Nagios/Sensu return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

# Script options

usage ()
{
    echo "Usage: $0 [OPTIONS]"
    echo " -h                   Get help"
    echo " -E <Endpoint URL>    URL for horizon dashboard. Ex: http://os.enocloud.com"
    echo " -U <username>        Username to use to get an auth token"
    echo " -P <password>        Password to use ro get an auth token"
    echo " -c <cookieFile>      Temporaire file to store cookie. Ex: /tmp/check_horizon_cookieFile"
}

output_result () {
	# Output check result & refresh cache if requested
	MSG="$1"
	RETCODE=$2
	
	echo "$MSG"
	exit $RETCODE
}

while getopts 'hH:U:P:E:c' OPTION
do
    case $OPTION in
        h)
            usage
            exit 0
            ;;
        E)
            export ENDPOINT_URL=$OPTARG
            ;;
        U)
            export OS_USERNAME=$OPTARG
            ;;
        P)
            export OS_PASSWORD=$OPTARG
            ;;
        c)
            export COOKIE_FILE=$OPTARG
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

COOKIE_FILE=${COOKIE_FILE:-"/tmp/check_horizon_cookieFile"}

if [ -z "$OS_USERNAME" ] || [ -z "$OS_PASSWORD" ] || [ -z "$ENDPOINT_URL" ] 
then
    usage
    exit 1
fi

if ! which curl > /dev/null 2>&1
then
	output_result "UNKNOWN - curl is not installed." $STATE_UNKNOWN
fi


# Get CSRFTOKEN and REGION on index
GET_INDEX=`curl -c $COOKIE_FILE -i $ENDPOINT_URL 2> /dev/null`

if [ -z "$GET_INDEX" ]
then
    output_result "CRITICAL - $ENDPOINT_URL not respond." $STATE_CRITICAL
fi

CSRFTOKEN=$(echo $GET_INDEX | sed -r "s/.*csrfmiddlewaretoken['\"] value=['\"]([^'\"]+)['\"].*/\1/")
REGION=$(echo $GET_INDEX | sed -r "s/.*region['\"] value=['\"]([^\"']+)['\"].*/\1/")

# Send POST login with CSRFTOKEN and REGION on /auth/login/
RESULT=`curl -L -b "$COOKIE_FILE" --referer $ENDPOINT_URL --data "username=$OS_USERNAME&password=$OS_PASSWORD&region=$REGION&csrfmiddlewaretoken=$CSRFTOKEN" $ENDPOINT_URL/auth/login/ 2> /dev/null`


# If Auth work, find patterns Overview
if [[ $RESULT == *Overview* ]]
then
    output_result "OK - Find string Overview in $ENDPOINT_URL" $STATE_OK
else
    output_result "CRITICAL - String \"Overview\" not found in $ENDPOINT_URL" $STATE_OK
fi
