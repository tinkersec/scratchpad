#!/usr/bin/env bash

################################################################
#                                                              #
# Script to match a known GPO GUID to a list of hosts.         #
# Uses ldapsearch from ldap-utils.                             #
#                                                              #
# Don't use this script. It'll probably blow up everything.    #
#                                                              #
# Note: Functionality is only for GPOs with single links.      #
#       Need to build in for multiple links.                   #
#       Haven't tested on multiple links... so who knows?!?    #
#                                                              #
# Written by Tinker. For Demonstration Purposes Only.          #
#                                                              #
# Also should write in functionality for proxychains... Hmm... #
#                                                              #
################################################################


USAGE="
Bash script to determine which hosts a GPO GUID links to.

Flags:
  -u	Username to authenticate to domain controller.
  -p	Password to authenticate to domain controller.
  -d	Domain of user credentials used to authenticate to domain controller.
  -g	Group Policy Object (GPO) Global Unique Identifier (GUID).
  -c	Domain Controller IP Address.
  -h	Help text and usage example.

usage:	 gPOtoHost.sh -d <domain> -u <username> -p <password> -g <gpo guid> -c <domain controller>
example: gPOtoHost.sh -d GIBSON -u zerocool -p hunter2 -g 01234567-CAFE-DEAD-BEEF-89ABCDEF0123 -c 10.10.10.257
"

# Check if any flags were set. If not, print out help.
if [ $# -eq 0 ]; then
	echo "$USAGE"
	exit
fi

# Set flags.
while getopts "u:p:d:g:c:h" FLAG
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
		g)
			GPOGUID=$OPTARG
			;;
		c)
			DCIP=$OPTARG
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

# Make sure each flag was actually set.
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
elif [ -z ${GPOGUID+x} ]; then
	echo "GPO GUID flag (-g) is not set."
	echo "$USAGE"
	exit
elif [ -z ${DCIP+x} ]; then
	echo "Domain Controller IP flag (-c) is not set."
	echo "$USAGE"
	exit
fi

# Set Base DN
BASEDN=$(ldapsearch -LL -o ldif-wrap=no -H ldap://$DCIP -x -s base | grep defaultNamingContext | cut -d":" -f2 | sed -e 's/^[ \t]*//' )

# Find out where the GPO's are linked (Note this currently only works for GPO's with single links. Need to add functionality for multiple links.
GPLINK=$(ldapsearch -LL -o ldif-wrap=no -H ldap://$DCIP -x -D "$USERNAME@$DOMAIN" -w $PASSWORD -b "$BASEDN" "(gPLink=*$GPOGUID*)" distinguishedName | grep distinguishedName | cut -d":" -f2 | sed -e 's/^[ \t]*//')

# Print out all hostnames linked to GPO. One per line.
ldapsearch -E pr=1000/noprompt -LL -o ldif-wrap=no -H ldap://$DCIP -x -D "$USERNAME@$DOMAIN" -w $PASSWORD -b "$GPLINK" | grep dNSHostName | cut -d":" -f2 | sed -e 's/^[ \t]*//'
