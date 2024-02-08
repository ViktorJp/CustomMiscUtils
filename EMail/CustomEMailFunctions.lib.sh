#!/bin/sh
######################################################################
# FILENAME: CustomEMailFunctions.lib.sh
# TAG: _LIB_CustomEMailFunctions_SHELL_
#
# Custom miscellaneous definitions & functions to send
# email notifications using AMTM optional email config.
#
# Creation Date: 2020-Jun-11 [Martinski W.]
# Last Modified: 2024-Feb-07 [Martinski W.]
######################################################################

if [ -z "${_LIB_CustomEMailFunctions_SHELL_:+xSETx}" ]
then _LIB_CustomEMailFunctions_SHELL_=0
else return 0
fi

if [ -z "${cemDoSystemLogFile:+xSETx}" ]
then cemDoSystemLogFile=true ; fi

if [ -z "${cemSendEMailNotificationsFlag:+xSETx}" ]
then cemSendEMailNotificationsFlag=true ; fi

readonly CEM_LIB_VERSION="0.9.4"
readonly CEM_TXT_VERFILE="cemVersion.txt"

readonly CEM_LIB_SCRIPT_TAG="master"
readonly CEM_LIB_SCRIPT_URL="https://raw.githubusercontent.com/Martinski4GitHub/CustomMiscUtils/${CEM_LIB_SCRIPT_TAG}/EMail"

readonly cemScriptDirPath="$(/usr/bin/dirname "$0")"
readonly cemScriptFileName="${0##*/}"
readonly cemScriptFNameTag="${cemScriptFileName%.*}"

readonly cemTempEMailLogFile="/tmp/var/tmp/tmpEMail_${cemScriptFNameTag}.LOG"
readonly cemTempEMailContent="/tmp/var/tmp/tmpEMailContent_${cemScriptFNameTag}.TXT"

readonly cemSysLogger="$(which logger)"
readonly cemLogInfoTag="INFO_${cemScriptFileName}_$$"
readonly cemLogErrorTag="ERROR_${cemScriptFileName}_$$"

readonly amtmEMailDirPath="/jffs/addons/amtm/mail"
readonly amtmEMailConfFile="${amtmEMailDirPath}/email.conf"
readonly amtmEMailPswdFile="${amtmEMailDirPath}/emailpw.enc"

amtmIsEMailConfigFileEnabled=false
readonly cemDateTimeFormat="%Y-%b-%d, %I:%M:%S %p %Z (%a)"

cemIsInteractive=false
[ -t 0 ] && ! tty | grep -qwi "NOT" && cemIsInteractive=true
"$cemIsInteractive" && cemSysLogFlags="-s -t" || cemSysLogFlags="-t"

#------------------------------------#
# AMTM email configuration variables #
#------------------------------------#
FROM_NAME=""  TO_NAME=""  FROM_ADDRESS=""  TO_ADDRESS=""
USERNAME=""  SMTP=""  PORT=""  PROTOCOL=""  emailPwEnc=""  PASSWORD=""

if [ -f "$amtmEMailConfFile" ]
then
    . "$amtmEMailConfFile"
else
    cemSendEMailNotificationsFlag=false
fi

#-------------------------------------------------------#
_DoReInit_CEM_()
{
   unset CEM_LIB_VERSION \
         CEM_TXT_VERFILE \
         CEM_LIB_SCRIPT_TAG \
         CEM_LIB_SCRIPT_URL \
         cemScriptDirPath \
         cemScriptFileName \
         cemScriptFNameTag \
         cemTempEMailLogFile \
         cemTempEMailContent \
         cemSysLogger \
         cemLogInfoTag \
         cemLogErrorTag \
         amtmEMailDirPath \
         amtmEMailConfFile \
         amtmEMailPswdFile \
         cemDateTimeFormat \
         _LIB_CustomEMailFunctions_SHELL_
}

#-----------------------------------------------------------#
_LogMsg_CEM_()
{
   if ! "$cemDoSystemLogFile" || \
      [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1 ; fi
   $cemSysLogger $cemSysLogFlags "$1" "$2"
}

#-----------------------------------------------------------#
_CheckLibraryUpdates_CEM_()
{
   _VersionStrToNum_()
   {
      if [ $# -eq 0 ] || [ -z "$1" ] ; then echo 0 ; return 1 ; fi
      local verNum  verStr
      
      verStr="$(echo "$1" | sed "s/['\"]//g")"
      verNum="$(echo "$verStr" | awk -F '.' '{printf ("%d%02d%02d\n", $1,$2,$3);}')"
      verNum="$(echo "$verNum" | sed 's/^0*//')"
      echo "$verNum" ; return 0
   }
   if [ $# -eq 0 ] || [ -z "$1" ] || [ ! -d "$1" ]
   then
       "$cemIsInteractive" && \
       printf "\n**ERROR**: INVALID parameter for directory [$1]\n"
       return 0
   fi
   local theVersTextFile="${1}/$CEM_TXT_VERFILE"
   local libraryVersNum  dlCheckVersNum  showMsg  retCode

   if [ $# -gt 1 ] && [ "$2" = "quiet" ]
   then showMsg=false ; else showMsg=true ; fi

   "$cemIsInteractive" && "$showMsg" && \
   printf "\nChecking for shared library script updates...\n"

   curl -kLSs --retry 3 --retry-delay 5 --retry-connrefused \
   "${CEM_LIB_SCRIPT_URL}/$CEM_TXT_VERFILE" -o "$theVersTextFile"
   chmod 666 "$theVersTextFile"

   [ ! -f "$theVersTextFile" ] && return 1

   libraryVersNum="$(_VersionStrToNum_ "$CEM_LIB_VERSION")"
   dlCheckVersNum="$(_VersionStrToNum_ "$(cat "$theVersTextFile")")"

   if [ "$dlCheckVersNum" -le "$libraryVersNum" ]
   then retCode=1  #NO Updates#
   else retCode=0  #NEW Update#
   fi
   rm -f "$theVersTextFile"
   "$cemIsInteractive" && "$showMsg" && printf "\nDone.\n"

   return "$retCode"
}

#-------------------------------------------------------#
_GetRouterModelID_CEM_()
{
   local retCode=1  routerModelID=""
   local nvramModelKeys="odmpid wps_modelnum model build_name"
   for nvramKey in $nvramModelKeys
   do
       routerModelID="$(nvram get "$nvramKey")"
       [ -n "$routerModelID" ] && retCode=0 && break
   done
   echo "$routerModelID" ; return "$retCode"
}

#-------------------------------------------------------#
CheckEMailConfigFileFromAMTM_CEM_()
{
   local logMsg
   amtmIsEMailConfigFileEnabled=false

   if [ ! -f "$amtmEMailConfFile" ] || [ ! -f "$amtmEMailPswdFile" ]
   then
       if "$cemIsInteractive"
       then
           printf "\n**ERROR**: Unable to send email notifications."
           printf "\nEmail configuration file is not yet set up or password has not been defined.\n"
       fi
       return 1
   fi

   if [ -z "$TO_NAME" ] || [ -z "$USERNAME" ] || \
      [ -z "$FROM_ADDRESS" ] || [ -z "$TO_ADDRESS" ] || \
      [ -z "$SMTP" ] || [ -z "$PORT" ] || [ -z "$PROTOCOL" ] || \
      [ -z "$emailPwEnc" ] || [ "$PASSWORD" = "PUT YOUR PASSWORD HERE" ]
   then
       if "$cemIsInteractive"
       then
           printf "\n**ERROR**: Unable to send email notifications."
           printf "\nSome email configuration variables are not yet set up.\n"
       fi
       return 1
   
   fi

   amtmIsEMailConfigFileEnabled=true
   return 0
}

#-------------------------------------------------------#
# ARG1: Email Subject String
# ARG2: Email Body File or String
#-------------------------------------------------------#
_CreateEMailContent_CEM_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1 ; fi
   local emailBodyMsg  emailBodyFile

   rm -f "$cemTempEMailContent"

   if ! echo "$2" | grep -q '^-F='
   then
       emailBodyMsg="$2"
   else
       emailBodyFile="${2##*=}"
       emailBodyMsg="$(cat "$emailBodyFile")"
       rm -f "$emailBodyFile"
   fi

   ## Header ##
   cat <<EOF > "$cemTempEMailContent"
From: "$FROM_NAME" <$FROM_ADDRESS>
To: "$TO_NAME" <$TO_ADDRESS>
Subject: $1
Date: $(date -R)
MIME-Version: 1.0
Content-Type: text/html; charset="UTF-8"
<!DOCTYPE html><html><body><pre>
<p style="color:black; font-family:sans-serif; font-size:100%;">
EOF

   ## Body ##
   printf "${emailBodyMsg}\n" >> "$cemTempEMailContent"

   ## Footer ##
   cat <<EOF >> "$cemTempEMailContent"

Sent by the "<b>${cemScriptFileName}</b>" Tool.
From the "<b>${FRIENDLY_ROUTER_NAME}</b>" router.

$(date +"$cemDateTimeFormat")
</p></pre></body></html>
EOF
    return 0
}

#-------------------------------------------------------#
# ARG1: Email Subject String
# ARG2: Email Body File or String
#-------------------------------------------------------#
_SendEMailNotification_CEM_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ] || \
      ! "$cemSendEMailNotificationsFlag" || \
      ! CheckEMailConfigFileFromAMTM_CEM_
   then return 1 ; fi

   local retCode  logTag  logMsg
   local theRouterModel="$(_GetRouterModelID_CEM_)"

   [ -z "$FROM_NAME" ] && FROM_NAME="$cemScriptFNameTag"
   [ -z "$FRIENDLY_ROUTER_NAME" ] && FRIENDLY_ROUTER_NAME="$theRouterModel"

   ! _CreateEMailContent_CEM_ "$@" && return 1

   if "$cemIsInteractive"
   then
       printf "\nSending email notification [$1]."
       printf "\nPlease wait...\n"
   fi

   date +"$cemDateTimeFormat" > "$cemTempEMailLogFile"

   /usr/sbin/curl -v --url ${PROTOCOL}://${SMTP}:${PORT} \
   --mail-from "$FROM_ADDRESS" --mail-rcpt "$TO_ADDRESS" \
   --user "${USERNAME}:$(/usr/sbin/openssl aes-256-cbc "$emailPwEnc" -d -in "$amtmEMailPswdFile" -pass pass:ditbabot,isoi)" \
   --upload-file "$cemTempEMailContent" \
   $SSL_FLAG --ssl-reqd --crlf >> "$cemTempEMailLogFile" 2>&1

   if [ $? -eq 0 ]
   then
       sleep 2
       retCode=0
       rm -f "$cemTempEMailLogFile"
       rm -f "$cemTempEMailContent"
       logTag="$cemLogInfoTag"
       logMsg="The email notification was sent successfully."
   else
       retCode=1
       logTag="$cemLogErrorTag"
       logMsg="**ERROR**: Failure to send email notification."
   fi
   _LogMsg_CEM_ "$logTag" "$logMsg"

   return "$retCode"
}

_LIB_CustomEMailFunctions_SHELL_=1

#EOF#
