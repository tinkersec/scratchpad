# GPO GUID to Host Identifier
# Scratch Paper - Proof of Concept - by Tinker
# With a known GPO GUID, find out what hosts the GPO is allied to.
#
# Don't use this script, instead use harmj0y's Powerview scripts
# See: https://gist.github.com/HarmJ0y/184f9822b195c52dd50c379ed3117993#file-powerview-3-0-tricks-ps1-L31


# !!! Manually set the GPO GUID here. !!!
# !!! E.g. $GpoGuid = "412a632e-9cd1-87af-0010-ed8989a0bba1"            
#######################
$GpoGuid = "<GPO GUID>"
#######################

# Uses GroupPolicy and ActiveDirectory modules found in the RSAT toolset
Import-Module GroupPolicy
Import-Module ActiveDirectory

# Generate report in xml for string search.
# Then pull out the Scope of Management (SOM) Path for the GPO
# Note: String searching is slow. But I understand it logically.
[xml]$FullGPOxml = Get-GPOreport -guid $GpoGuid -ReportType xml
$SomPath = $FullGPOxml.GPO.LinksTo.SOMPath

# Print out hosts that fall within the SOM Path
"GPP #$GpoGuid is applied to the following hosts:"
Get-ADComputer -Filter * -Properties CanonicalName,DNSHostName | Where-Object {$_.CanonicalName -like "$SomPath*"} | select DNSHostName

# Script can take up to a minute to fully run due to creating a full report, string searching through it, 
# and pulling down every host on the AD to search each description.
# Lesson: I need to learn LDAP queries and query info directly, instead of gathering everything and parsing.
