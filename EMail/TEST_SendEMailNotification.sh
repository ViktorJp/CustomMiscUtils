#!/bin/sh
####################################################################
# TEST_SendEMailNotification.sh
# 
# To test using the "CustomEMailFunctions.lib.sh" shell library.
# A simple example.
#
# Creation Date: 2020-Jun-11 [Martinski W.]
# Last Modified: 2024-Feb-13 [Martinski W.]
####################################################################
set -u

TEST_VERSION="0.5.7"

readonly scriptFileName="${0##*/}"
readonly scriptFileNTag="${scriptFileName%.*}"

readonly CEM_LIB_TAG="develop"
readonly CEM_LIB_URL="https://raw.githubusercontent.com/Martinski4GitHub/CustomMiscUtils/${CEM_LIB_TAG}/EMail"

readonly CUSTOM_EMAIL_LIBDir="/jffs/scripts/libs"
readonly CUSTOM_EMAIL_LIBName="CustomEMailFunctions.lib.sh"
readonly CUSTOM_EMAIL_LIBFile="${CUSTOM_EMAIL_LIBDir}/$CUSTOM_EMAIL_LIBName"

#-----------------------------------------------------------#
_DownloadCEMLibraryFile_()
{
   local msgStr  retCode
   case "$1" in
        update) msgStr="Updating" ;;
       install) msgStr="Installing" ;;
             *) return 1 ;;
   esac
   printf "\n${msgStr} the shared library script file to support email notifications...\n"

   mkdir -m 755 -p "$CUSTOM_EMAIL_LIBDir"
   curl -kLSs --retry 3 --retry-delay 5 --retry-connrefused \
   "${CEM_LIB_URL}/$CUSTOM_EMAIL_LIBName" -o "$CUSTOM_EMAIL_LIBFile"
   curlCode="$?"

   if [ "$curlCode" -eq 0 ] && [ -f "$CUSTOM_EMAIL_LIBFile" ]
   then
       retCode=0
       chmod 755 "$CUSTOM_EMAIL_LIBFile"
       . "$CUSTOM_EMAIL_LIBFile"
       printf "\nDone.\n"
   else
       retCode=1
       printf "\n**ERROR**: Unable to download the shared library script file [$CUSTOM_EMAIL_LIBName].\n"
   fi
   return "$retCode"
}

if [ -f "$CUSTOM_EMAIL_LIBFile" ]
then
   . "$CUSTOM_EMAIL_LIBFile"

   if [ -z "${CEM_LIB_VERSION:+xSETx}" ] || \
      _CheckLibraryUpdates_CEM_ "$CUSTOM_EMAIL_LIBDir"
   then
       _DownloadCEMLibraryFile_ "update"
   fi
else
    _DownloadCEMLibraryFile_ "install"
fi

#-----------------------------------------------------------#
# ARG1: The email name/alias to be used as "FROM_NAME"
# ARG1: The email Subject string
# ARG2: Full path of file containing the email Body text.
#-----------------------------------------------------------#
_SendEMailNotification_()
{
   if [ -z "${amtmIsEMailConfigFileEnabled:+xSETx}" ]
   then
       logTag="**ERROR**_${scriptFileName}_$$"
       logMsg="Email library script [$CUSTOM_EMAIL_LIBFile] *NOT* FOUND."
       printf "\n%s: %s\n\n" "$logTag" "$logMsg"
       /usr/bin/logger -t "$logTag" "$logMsg"
       return 1
   fi

   if [ $# -lt 3 ] || [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]
   then
       printf "\n**ERROR**: INSUFFICIENT email parameters\n"
       return 1
   fi
   local retCode

   cemIsFormatHTML=true            ## true OR false ##
   ## For DEBUG/TEST purposes set as follows ##
   cemIsVerboseMode=true           ## true OR false ##
   cemDeleteMailContentFile=false  ## true OR false ##

   FROM_NAME="$1"
   if _SendEMailNotification_CEM_ "$2" "-F=$3"
   then
       retCode=0
       logTag="INFO:"
       logMsg="The email notification was sent successfully [$2]."
   else
       retCode=1
       logTag="**ERROR**:"
       logMsg="Failure to send email notification [$2]."
   fi
   printf "\n${logTag} ${logMsg}\n"

   return "$retCode"
}

#---------#
# Example #
#---------#
emailSubject="TESTING Email Notifications"
tmpEMailBodyFile="/tmp/var/tmp/tmpEMailBody_${scriptFileNTag}.$$.TXT"

# Custom Optional Parameters #
addOptionalCC=false
if "$addOptionalCC"
then
   CC_NAME="CopyFooBar2"
   # THIS MUST BE A REAL EMAIL ADDRESS ##
   CC_ADDRESS="CopyFooBar2@google.com"
fi

{
  printf "This is a TEST to check & verify if sending email notifications"
  printf " is working well from the \"${0}\" shell script.\n"
} > "$tmpEMailBodyFile"

_SendEMailNotification_ "EMailNameAlias" "$emailSubject" "$tmpEMailBodyFile"

#EOF#
