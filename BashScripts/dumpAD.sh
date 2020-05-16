#!/usr/bin/env bash

################################################################
#                                                              #
# Script to create an LDIF of Active Directory via LDAP.       #
# Fields are on single lines with object numbering to allow    #
# for easier grepping.                                         #
#                                                              #
# Uses ldapsearch from ldap-utils.                             #
#                                                              #
# Don't use this script. It'll probably blow up everything.    #
#                                                              #
# Written by Tinker. For Demonstration Purposes Only.          #
#                                                              #
################################################################


USAGE="
Bash script to dump Active Directory via LDAP.
Dont use this script. Will probably blow up everything

Flags:
  -u	Username to authenticate to domain controller.
  -p	Password to authenticate to domain controller.
  -d	Domain of user credentials used to authenticate to domain controller.
  -c	Domain Controller IP Address.
  -o	Output file name. (optional)
  -h	Help text and usage example.

usage:	 dumpAD.sh -d <domain> -u <username> -p <password> -c <domain controller> -o <outputFileName.ldif>
example: dumpAD.sh -d GIBSON -u zerocool -p hunter2 -c 10.10.10.257 -o gibsonAD.ldif
"

# Check if any flags were set. If not, print out help.
if [ $# -eq 0 ]; then
	echo "$USAGE"
	exit
fi

# Set flags.
while getopts "u:p:d:c:o:h" FLAG
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
		c)
			DCIP=$OPTARG
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
elif [ -z ${DCIP+x} ]; then
	echo "Domain Controller IP flag (-c) is not set."
	echo "$USAGE"
	exit
fi

# Set Base DN
BASEDN=$(ldapsearch -LL -o ldif-wrap=no -H ldap://$DCIP -x -s base | grep defaultNamingContext | cut -d":" -f2 | sed -e 's/^[ \t]*//' )

# Set and initialize LINECOUNT and LINESTRING
declare -i LINECOUNT=0
LINESTRING=$(printf "%08d" $LINECOUNT)

# Dump Active Directory via LDAP. Print each field on one line.
if [ -z ${OUTPUT+x} ]; then
	stdbuf -oL ldapsearch -E pr=1000/noprompt -LL -o ldif-wrap=no -H ldap://$DCIP -x -D "$USERNAME@$DOMAIN" -w $PASSWORD -b "$BASEDN" |
	while IFS= read -r LDIFLINE
	do
		if [ -z "$LDIFLINE" ]
		then
			LINECOUNT+=1
			LINESTRING=$(printf "%08d" $LINECOUNT)
			echo $LDIFLINE
		else
			echo "{$LINESTRING} "$LDIFLINE
		fi
	done
else
	stdbuf -oL ldapsearch -E pr=1000/noprompt -LL -o ldif-wrap=no -H ldap://$DCIP -x -D "$USERNAME@$DOMAIN" -w $PASSWORD -b "$BASEDN" |
	while IFS= read -r LDIFLINE
	do
		if [ -z "$LDIFLINE" ]
		then
			LINECOUNT+=1
			LINESTRING=$(printf "%08d" $LINECOUNT)
			echo $LDIFLINE
		else
			echo "{$LINESTRING} "$LDIFLINE
		fi
	done | tee $OUTPUT
fi
