#!/bin/sh
####################################################################
# TEST_SendEMailNotification.sh
# 
# To test using the "CustomEMailFunctions.lib.sh" shell library.
# A simple example.
#
# Creation Date: 2020-Jun-11 [Martinski W.]
# Last Modified: 2024-Feb-03 [Martinski W.]
####################################################################

readonly scriptFileName="${0##*/}"
readonly scriptFileNTag="${scriptFileName%.*}"

CUSTOM_EMAIL_LIB="/jffs/scripts/libs/CustomEMailFunctions.lib.sh"
if [ -f "$CUSTOM_EMAIL_LIB" ]
then
   . "$CUSTOM_EMAIL_LIB"
else
   logTag="**WARNING**_${scriptFileName}_$$"
   logMsg="Email library script [$CUSTOM_EMAIL_LIB] *NOT* FOUND."
   printf "\n%s: %s\n\n" "$logTag" "$logMsg"
   /usr/bin/logger -t "$logTag" "$logMsg"
fi

#-----------------------------------------------------------#
# ARG1: The email address to be used as "FROM_NAME"
# ARG1: The email Subject string
# ARG2: Full path of file containing the email Body msg.
#-----------------------------------------------------------#
_SendEMailNotification_()
{
   if [ -z "${amtmIsEMailConfigFileEnabled:+xSETx}" ]
   then
       logTag="**ERROR**_${scriptFileName}_$$"
       logMsg="Email library script [$CUSTOM_EMAIL_LIB] *NOT* FOUND."
       printf "\n%s: %s\n\n" "$logTag" "$logMsg"
       /usr/bin/logger -t "$logTag" "$logMsg"
       return 1
   fi

   if [ $# -lt 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]
   then
       printf "\n**ERROR**: INSUFFICIENT email parameters\n"
       return 1
   fi

   FROM_NAME="$1"
   if _SendEMailNotification_CEM_ "$2" "-F=$3"
   then
       logTag="INFO:"
       logMsg="The email notification was sent successfully [$2]."
   else
       logTag="**ERROR**:"
       logMsg="Failure to send email notification [$2]."
   fi
   printf "\n${logTag} ${logMsg}\n"

   return 0
}

#---------#
# Example #
#---------#
emailSubject="TESTING Email Notifications"
tmpEMailBodyFile="/tmp/var/tmp/tmpEMailBody_${scriptFileNTag}.$$.TXT"

{
  printf "This is a TEST to check & verify if sending email notifications"
  printf " is working well from the \"${0}\" shell script.\n"
} > "$tmpEMailBodyFile"

_SendEMailNotification_ "FooBar@google.com" "$emailSubject" "$tmpEMailBodyFile"

#EOF#
