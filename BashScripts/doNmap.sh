#!/usr/bin/env bash

#################################################################
#                                                              	#
# Wrapper to run various nmap scans concurrently.	       	#
#							       	#
# Uses nmap.			                               	#
#                                                              	#
# Don't use this script. It'll probably blow up everything.    	#
#                                                              	#
# Written by Tinker. For Demonstration Purposes Only.          	#
#                                                              	#
# Tweak as you like. Add ports, flags, what have you.          	#
#								#
#################################################################


USAGE="
Bash wrapper to run various nmap scans.
Run as root.

usage:   sudo doNmap.sh <CIDR or IP Range>
example: sudo doNmap.sh 192.168.1.2
example: sudo doNmap.sh 10.0.0.0/8
example: sudo doNmap.sh 172.16-31.0-255.0-255
"

# Check if running as root.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root or use sudo. (You can trust me... you read the full script, right?)"
  exit
fi

# Check if any flags were set. If not, print out help.
if [ $# -eq 0 ]; then
	echo "$USAGE"
	exit
fi

# Set flags.
while getopts "h" FLAG
do
	case $FLAG in
		h)	echo "$USAGE"
			exit
			;;
		*)
			echo "$USAGE"
			exit
			;;
	esac
done

IPCIDR=$1

# Find common UDP ports
echo "Looking for common UDP ports. Saving output to udp-$IPCIDR.*"
sudo nmap -sU -A -p 53,161 -T4 -oA udp-$IPCIDR &

# Find common web ports
echo "Looking for common web ports. Saving output to web-$IPCIDR.*"
sudo nmap -sSV -sC -p 80,443,8008,8080,8443 -T4 --open -oA web-$IPCIDR $IPCIDR &

# Find common database ports
echo "Looking for common database ports. Saving output to db-$IPCIDR.*"
sudo nmap -sSV -sC -p 1433,1434,1521,1583,3306,3050,3351,5432 -T4 --open -oA db-$IPCIDR $IPCIDR &

# Find common doors, or common ways to remote connect
echo "Looking for common doors. Saving output to doors-$IPCIDR.*"
sudo nmap -sSV -sC -p 21,22,23,139,389,445,3389,5800,5801,5900,5901 -T4 --open -oA doors-$IPCIDR $IPCIDR &

# Conduct full TCP port scan.
echo "Running full TCP port scan. This'll take a bit. Saving output to all-$IPCIDR.*"
sudo nmap -sSV -sC -p- -T4 --open -oA all-$IPCIDR $IPCIDR &
