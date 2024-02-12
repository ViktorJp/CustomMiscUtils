#!/bin/sh
######################################################################
# FILENAME: CustomEMailFunctions.lib.sh
# TAG: _LIB_CustomEMailFunctions_SHELL_
#
# Custom miscellaneous definitions & functions to send
# email notifications using AMTM optional email config.
#
# Creation Date: 2020-Jun-11 [Martinski W.]
# Last Modified: 2024-Feb-11 [Martinski W.]
######################################################################

if [ -z "${_LIB_CustomEMailFunctions_SHELL_:+xSETx}" ]
then _LIB_CustomEMailFunctions_SHELL_=0
else return 0
fi

CEM_LIB_VERSION="0.9.10"
CEM_TXT_VERFILE="cemVersion.txt"

CEM_LIB_SCRIPT_TAG="develop"
CEM_LIB_SCRIPT_URL="https://raw.githubusercontent.com/Martinski4GitHub/CustomMiscUtils/${CEM_LIB_SCRIPT_TAG}/EMail"

if [ -z "${cemIsVerboseMode:+xSETx}" ]
then cemIsVerboseMode=true ; fi

if [ -z "${cemIsFormatHTML:+xSETx}" ]
then cemIsFormatHTML=true ; fi

if [ -z "${cemDoSystemLogFile:+xSETx}" ]
then cemDoSystemLogFile=true ; fi

if [ -z "${cemSendEMailNotificationsFlag:+xSETx}" ]
then cemSendEMailNotificationsFlag=true ; fi

cemScriptDirPath="$(/usr/bin/dirname "$0")"
cemScriptFileName="${0##*/}"
cemScriptFNameTag="${cemScriptFileName%.*}"

cemTempEMailLogFile="/tmp/var/tmp/tmpEMail_${cemScriptFNameTag}.LOG"
cemTempEMailContent="/tmp/var/tmp/tmpEMailContent_${cemScriptFNameTag}.TXT"

cemSysLogger="$(which logger)"
cemLogInfoTag="INFO_${cemScriptFileName}_$$"
cemLogErrorTag="ERROR_${cemScriptFileName}_$$"

amtmEMailDirPath="/jffs/addons/amtm/mail"
amtmEMailConfFile="${amtmEMailDirPath}/email.conf"
amtmEMailPswdFile="${amtmEMailDirPath}/emailpw.enc"

amtmIsEMailConfigFileEnabled=false
cemDateTimeFormat="%Y-%b-%d, %I:%M:%S %p %Z (%a)"

cemIsInteractive=false
[ -t 0 ] && ! tty | grep -qwi "NOT" && cemIsInteractive=true
if ! "$cemIsInteractive" ; then cemIsVerboseMode=false ; fi

#------------------------------------#
# AMTM email configuration variables #
#------------------------------------#
FROM_NAME=""  FROM_ADDRESS=""
TO_NAME=""  TO_ADDRESS=""
USERNAME=""  SMTP=""  PORT=""  PROTOCOL=""
PASSWORD=""  emailPwEnc=""

# Custom Additions ##
CC_NAME=""  CC_ADDRESS=""

if [ -f "$amtmEMailConfFile" ]
then
    . "$amtmEMailConfFile"
else
    cemSendEMailNotificationsFlag=false
fi

#-------------------------------------------------------#
_DoReInit_CEM_()
{
   unset amtmIsEMailConfigFileEnabled \
         cemSendEMailNotificationsFlag \
         _LIB_CustomEMailFunctions_SHELL_
}

#-----------------------------------------------------------#
_LogMsg_CEM_()
{
   if ! "$cemDoSystemLogFile" || \
      [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then return 1 ; fi
   $cemSysLogger -t "$1" "$2"

   "$cemIsInteractive" && "$cemIsVerboseMode" && \
   printf "${1}: ${2}\n"
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
   local libraryVerNum  dlCheckVerNum  dlCheckVerStr
   local showMsg  retCode

   if [ $# -gt 1 ] && [ "$2" = "quiet" ]
   then showMsg=false ; else showMsg=true ; fi

   "$cemIsInteractive" && "$cemIsVerboseMode" && "$showMsg" && \
   printf "\nChecking for shared library script updates...\n"

   curl -kLSs --retry 3 --retry-delay 5 --retry-connrefused \
   "${CEM_LIB_SCRIPT_URL}/$CEM_TXT_VERFILE" -o "$theVersTextFile"

   [ ! -f "$theVersTextFile" ] && return 1
   chmod 666 "$theVersTextFile"
   dlCheckVerStr="$(cat "$theVersTextFile")"

   dlCheckVerNum="$(_VersionStrToNum_ "$dlCheckVerStr")"
   libraryVerNum="$(_VersionStrToNum_ "$CEM_LIB_VERSION")"

   if [ "$dlCheckVerNum" -le "$libraryVerNum" ]
   then
       retCode=1
       "$cemIsInteractive" && "$cemIsVerboseMode" && "$showMsg" && \
       printf "\nDone.\n"
   else
       _DoReInit_CEM_
       retCode=0
       "$cemIsInteractive" && "$cemIsVerboseMode" && "$showMsg" && \
       printf "\nNew library version update [$dlCheckVerStr] available.\n"
   fi

   rm -f "$theVersTextFile"
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

   if [ -n "$CC_NAME" ] && [ -n "$CC_ADDRESS" ]
   then
       CC_ADDRESS_ARG="--mail-rcpt $CC_ADDRESS"
       CC_ADDRESS_STR="\"$CC_NAME\" <$CC_ADDRESS>"
   fi

   ## Header-1 ##
   cat <<EOF > "$cemTempEMailContent"
From: "$FROM_NAME" <$FROM_ADDRESS>
To: "$TO_NAME" <$TO_ADDRESS>
EOF

[ -n "CC_ADDRESS_STR" ] && \
printf "Cc: ${CC_ADDRESS_STR}\n" >> "$cemTempEMailContent"

   ## Header-2 ##
   cat <<EOF >> "$cemTempEMailContent"
Subject: $1
Date: $(date -R)
EOF

   "$cemIsFormatHTML" && \
   cat <<EOF >> "$cemTempEMailContent"
MIME-Version: 1.0
Content-Type: text/html; charset="UTF-8"
<!DOCTYPE html><html><body><pre>
<p style="color:black; font-family:sans-serif; font-size:100%;">
EOF

   ## Body ##
   printf "${emailBodyMsg}\n" >> "$cemTempEMailContent"

   ## Footer-A ##
   ! "$cemIsFormatHTML" && \
   cat <<EOF >> "$cemTempEMailContent"

Sent by the "${cemScriptFileName}" script.
From the "${FRIENDLY_ROUTER_NAME}" router.

$(date +"$cemDateTimeFormat")
EOF

   ## Footer-B ##
   "$cemIsFormatHTML" && \
   cat <<EOF >> "$cemTempEMailContent"

Sent by the "<b>${cemScriptFileName}</b>" script.
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
   local CC_ADDRESS_STR=""  CC_ADDRESS_ARG=""

   [ -z "$FROM_NAME" ] && FROM_NAME="$cemScriptFNameTag"
   [ -z "$FRIENDLY_ROUTER_NAME" ] && FRIENDLY_ROUTER_NAME="$(_GetRouterModelID_CEM_)"

   ! _CreateEMailContent_CEM_ "$@" && return 1

   if "$cemIsInteractive" && "$cemIsVerboseMode"
   then
       printf "\nSending email notification [$1]."
       printf "\nPlease wait...\n"
   fi

   date +"$cemDateTimeFormat" > "$cemTempEMailLogFile"

   /usr/sbin/curl -v --url "${PROTOCOL}://${SMTP}:${PORT}" \
   --mail-from "$FROM_ADDRESS" \
   --mail-rcpt "$TO_ADDRESS" $CC_ADDRESS_ARG \
   --user "${USERNAME}:$(/usr/sbin/openssl aes-256-cbc "$emailPwEnc" -d -in "$amtmEMailPswdFile" -pass pass:ditbabot,isoi)" \
   --upload-file "$cemTempEMailContent" \
   $SSL_FLAG --ssl-reqd --crlf >> "$cemTempEMailLogFile" 2>&1
   curlCode="$?"

   if [ "$curlCode" -eq 0 ]
   then
       sleep 2
       retCode=0
       rm -f "$cemTempEMailLogFile"
       logTag="$cemLogInfoTag"
       logMsg="The email notification was sent successfully."
   else
       retCode=1
       logTag="$cemLogErrorTag"
       logMsg="**ERROR**: Failure to send email notification [$curlCode]."
   fi
   rm -f "$cemTempEMailContent"
   _LogMsg_CEM_ "$logTag" "$logMsg"

   return "$retCode"
}

_LIB_CustomEMailFunctions_SHELL_=1

#EOF#
