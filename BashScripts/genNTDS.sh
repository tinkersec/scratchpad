#!/usr/bin/env bash

################################################################
#                                                              #
# Script to create an example NTDS.dit file.                   #
# Good for hash cracking demonstrations.                       #
#                                                              #
# Requires program 'mkpasswd'                                  #
#                                                              #
# Crack output with john-the-ripper:                           #
# ~$ john --format=NT --wordlist=rockyou.txt NTDS-example.dit  #
#                                                              #
# Written by Tinker. For Demonstration Purposes Only.          #
# Made for Sean because Bex asked me to.                       #
#                                                              #
################################################################


USAGE="
Bash script to create example NTDS.dit file.
For Demonstrational Purposes Only.

Flags:
  -d	Domain for example. Defaults to: ACME.domain
  -w	Wordlist to be used as for sample passwords, separated by newline.
  -c	Number of hashes in NTDS.dit sample. Defaults: 1000
  -o	Output filename.
  -h	Help text and usage example.

usage:	 genNTDS.sh -d <domain> -w <wordlist file> -c <hash count> -o <outputFileName.hash>
example: genNTDS.sh -d ACME.domain -w rockyou.txt -c 1000 -o NTDS-example.dit
"

# Check if any flags were set. If not, print out help.
if [ $# -eq 0 ]; then
	echo "$USAGE"
	exit
fi

# Set flags.
while getopts "d:c:w:o:h" FLAG
do
	case $FLAG in
		d)
			DOMAIN=$OPTARG

			;;
		c)
			LINEDEPTH=$OPTARG
			;;
		w)
			WORDLIST=$OPTARG
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
if [ -z ${WORDLIST+x} ]; then
	echo "Wordlist flag (-w) is not set."
	echo "$USAGE"
	exit
elif [ -z ${OUTPUT+x} ]; then
	echo "Output flag (-o) is not set."
	echo "$USAGE"
	exit
fi

if [ -z ${LINEDEPTH+x} ]; then
	LINEDEPTH="1000"
fi

if [ -z ${DOMAIN+x} ]; then
	DOMAIN="ACME.domain"
fi

# Set and initialize NUM for chronological username schema
declare -i NUM=1000

# Generate example NTDS.dit
shuf $WORDLIST | head -n $LINEDEPTH | while read PASS; 
do 
	echo $DOMAIN\\user$NUM:$NUM:aad3b435b51404eeaad3b435b51404ee:$(mkpasswd -m nt $PASS | cut -d"$" -f 4):::
	NUM=$(($NUM+1))
done > $OUTPUT

