#!/bin/sh
####################################################################
# nvramCustomClientList.sh
#
# To remove/modify entries in "custom_clientlist" NVRAM variable.
#
# Creation Date: 2021-Mar-13 [Martinski W.]
# Last Modified: 2023-Dec-02 [Martinski W.]
# Version: 0.8.3
####################################################################
set -u

readonly theScriptName="${0##*/}"
readonly NVRAM_VarKeyName='custom_clientlist'
readonly NVRAM_VarSavedDirPath='/tmp/var/tmp/NVRAM_VarsSAVED'
readonly NVRAM_VarBckupDirPath='/jffs/configs/NVRAM_VarsBACKUP'
readonly NVRAM_VarSavedFilePath="${NVRAM_VarSavedDirPath}/NVRAMvar_${NVRAM_VarKeyName}.SAVED.txt"
readonly NVRAM_VarBckupFilePath="${NVRAM_VarBckupDirPath}/NVRAMvar_${NVRAM_VarKeyName}.BACKUP.txt"

#------------------------------------------------------------------#
_ShowUsage_()
{
   cat <<EOF
=========================================================================
SYNTAX:

./$theScriptName [show] | [backup] | [restore] | [doclear] | [docommit] modify "OldClientName" "NewClientName"

EOF

   [ $# -eq 1 ] && [ "$1" -eq 1 ] && return 0
   _WaitForEnterKey_

   cat <<EOF
-------------------------------------------------------------------------
EXAMPLE CALLS:

To get this usage & syntax description:
   ./$theScriptName help

To show the current value of the NVRAM variable.
   ./$theScriptName show

To back up the original value of the NVRAM variable.
   ./$theScriptName backup

To restore the NVRAM variable to its original value.
   ./$theScriptName restore

To remove all temporary files, including the backup file.
   ./$theScriptName doclear

To modify the NVRAM variable by replacing the current "OldClientName"
with a "NewClientName" string [Client Name length <= 30 chars].
Example:
   ./$theScriptName modify "OldClientName" "NewClientName"

If the "NewClientName" is "-DELETE-" the "OldClientName" entry
is completely removed.
Example:
   ./$theScriptName modify "OldClientName" -DELETE-

NOTE:
If you don't specify "docommit" *BEFORE* the "modify" parameter, 
all changes made to the NVRAM variable are TEMPORARY. If you want
a change to be committed you MUST specify "docommit" parameter.
Examples:
   ./$theScriptName docommit modify "OldClientName" -DELETE-
   ./$theScriptName docommit modify "OldClientName" "NewClientName"

Not using the "docommit" parameter allows to test/verify the change
to be made *BEFORE* committing to make it permanent later on.
=========================================================================
EOF
}

#------------------------------------------------------------------#
_WaitForEnterKey_()
{
   local promptStr="Press Enter key to continue..."
   [ $# -eq 1 ] && [ "$1" = "stop" ] && \
   promptStr="Press Enter key to continue or type Ctrl-C to stop."
   printf "\n$promptStr "
   read -r EnterKEY ; echo
}

#------------------------------------------------------------------#
readonly nvramShowCmd='nvram show 2>/dev/null'
_NVRAM_ShowVar_()
{
   echo
   eval "$nvramShowCmd" | grep -E "^${NVRAM_VarKeyName}="
   echo
}

#------------------------------------------------------------------#
_NVRAM_DelDirFiles_()
{
   local backupKeyVal  currentKeyVal  doDeleteOK=false

   if [ -f "$NVRAM_VarBckupFilePath" ]
   then
       doDeleteOK=true
       backupKeyVal="$(cat "$NVRAM_VarBckupFilePath")"
       currentKeyVal="$(nvram get "$NVRAM_VarKeyName")"
       if [ "$currentKeyVal" != "$backupKeyVal" ]
       then
           printf "\n**WARNING**\nThis action will delete the current BACKUP of the original NVRAM value:\n"
           printf "\n${backupKeyVal}\n\n"
           printf "\nThe current value of the NVRAM variable is the following:\n"
           printf "\n${currentKeyVal}\n"
           printf "\nMake sure this current value of the NVRAM variable is exactly as you want it\n"
           printf "because once the backup file is deleted you cannot restore the original value.\n"
           _WaitForEnterKey_ stop
       fi
   fi
   [ -f "$NVRAM_VarSavedFilePath" ] && doDeleteOK=true
   rm -fr "$NVRAM_VarBckupDirPath" "$NVRAM_VarSavedDirPath"
   if ! "$doDeleteOK"
   then printf "\nNo files found. Nothing to remove.\n\n"
   else printf "\nTemporary & Backup files were removed.\n\n"
   fi
}

#------------------------------------------------------------------#
_NVRAM_SaveVar_()
{
   local retCode

   if [ -f "$NVRAM_VarSavedFilePath" ]
   then
       echo ; ls -l "$NVRAM_VarSavedFilePath"
       printf "Original NVRAM var has been temporarily saved already.\n\n"
       return 0
   fi

   [ ! -d "$NVRAM_VarSavedDirPath" ] && \
   mkdir -m 755 -p "$NVRAM_VarSavedDirPath"

   eval "$nvramShowCmd" | grep -qE "^${NVRAM_VarKeyName}=" && \
   nvram get "$NVRAM_VarKeyName" > "$NVRAM_VarSavedFilePath"

   if ls -l "$NVRAM_VarSavedFilePath" 2>/dev/null
   then
       retCode=0
       printf "NVRAM var was saved in temporary file.\n\n"
   else
       retCode=1
       printf "\nNVRAM var was *NOT* saved temporarily.\n\n"
   fi
   return "$retCode"
}

#------------------------------------------------------------------#
_NVRAM_BackUpVar_()
{
   local retCode

   if [ -f "$NVRAM_VarBckupFilePath" ]
   then
       echo ; ls -l "$NVRAM_VarBckupFilePath"
       printf "Original NVRAM var has been previously backed up already.\n\n"
       return 0
   fi

   [ ! -d "$NVRAM_VarBckupDirPath" ] && \
   mkdir -m 755 -p "$NVRAM_VarBckupDirPath"

   _NVRAM_SaveVar_ && \
   cp -fp "$NVRAM_VarSavedFilePath" "$NVRAM_VarBckupFilePath"

   if ls -l "$NVRAM_VarBckupFilePath" 2>/dev/null
   then
       retCode=0
       printf "NVRAM var was backed up successfully.\n\n"
   else
       retCode=1
       printf "\nNVRAM var was *NOT* backed up successfully.\n\n"
   fi
   return "$retCode"
}

#------------------------------------------------------------------#
_NVRAM_RestoreVar_()
{
   local retCode  backupKeyVal  currentKeyVal

   if [ ! -f "$NVRAM_VarBckupFilePath" ]
   then
       printf "\nNo backup of NVRAM var is currently found.\n\n"
       return 1
   fi

   backupKeyVal="$(cat "$NVRAM_VarBckupFilePath")"
   currentKeyVal="$(nvram get "$NVRAM_VarKeyName")"
   if [ "$currentKeyVal" = "$backupKeyVal" ]
   then
       printf "\nNVRAM key [$NVRAM_VarKeyName] does not need to be restored.\n\n"
       rm -f "$NVRAM_VarBckupFilePath" "$NVRAM_VarSavedFilePath"
       return 0
   fi

   printf "\n**WARNING**\nThis action will restore the current BACKUP of the original NVRAM value:\n"
   printf "\n${backupKeyVal}\n\n"
   printf "\nThe current value of the NVRAM variable is the following:\n"
   printf "\n${currentKeyVal}\n\n"
   printf "\nMake sure the BACKUP value of the NVRAM variable is exactly as you want it\n"
   printf "because the current value will be replaced with the BACKUP value.\n"
   _WaitForEnterKey_ stop

   if nvram set ${NVRAM_VarKeyName}="$backupKeyVal"
   then
       retCode=0
       nvram commit
       printf "\nNVRAM key [$NVRAM_VarKeyName] was restored successfully.\n"
       _NVRAM_ShowVar_
       rm -f "$NVRAM_VarBckupFilePath" "$NVRAM_VarSavedFilePath"
   else
       retCode=1
       printf "\nNVRAM var could *NOT* be restored.\n\n"
   fi
   return "$retCode"
}

#------------------------------------------------------------------#
# NVRAM variable entry MUST have the following format:
# "<{Client_Name}>{MAC_Address}>{NUMBER}>NUMBER}>>"
#------------------------------------------------------------------#
_NVRAM_ModifyVar_()
{
   if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]
   then
       printf "\n**ERROR**: INSUFFICIENT Client Name parameters were provided.\n\n"
       _ShowUsage_ 1 ; return 1
   fi
   if [ "$1" = "$2" ]
   then
       printf "\n**ERROR**: Client Name parameters are the same [$1]=[$2].\n\n"
       return 1
   fi
   if [ "${#2}" -gt 30 ]
   then
       printf "\n**ERROR**: Client Name [$2] is too long (>30 chars).\n\n"
       return 1
   fi

   local tempFile="/tmp/nvramTempStr.TMP"
   local nvramKeyVal  theClientEntry tempStr1  tempStr2
   local oldClientName="$1"  newClientName="$2"
   local MACregExp="([a-fA-F0-9]{2}\:){5}([a-fA-F0-9]{2})"
   local theRegExp="<${1}>${MACregExp}>([0-9]+)>([0-9]+)>>"

   if [ ! -s "/jffs/nvram/$NVRAM_VarKeyName" ]
   then nvramKeyVal="$(nvram get "$NVRAM_VarKeyName")"
   else nvramKeyVal="$(cat "/jffs/nvram/$NVRAM_VarKeyName")"
   fi

   if ! echo "$nvramKeyVal" | grep -qiE "$theRegExp"
   then
       printf "\n**ERROR*: Entry for client name [$1] NOT FOUND.\n\n"
       return 1
   fi
   theClientEntry="$(echo "$nvramKeyVal" | grep -ioE "$theRegExp")"
   [ -z "$theClientEntry" ] && return 1

   _WaitForEnterKey_ stop
   ! _NVRAM_SaveVar_ && return 1

   printf "\n**CURRENT** NVRAM Value:\n------------------------\n"
   printf "${nvramKeyVal}\n\n"
   printf "\n**CURRENT** Client Entry:\n-------------------------\n"
   printf "${theClientEntry}\n\n"

   if [ "$newClientName" = "-DELETE-" ]
   then
       tempStr1="$(echo "$theClientEntry" | sed 's/[\/.*-]/\\&/g')"
       echo "$nvramKeyVal" | sed "s/${tempStr1}//g" | sed '/^$/d' > "$tempFile"
       if "$doModifyTest"
       then
           printf "\n**TEST** Modified NVRAM Value:\n------------------------------\n"
           cat "$tempFile"
           printf "\nTEMPORARY modification is completed.\n\n"
       #
       elif nvram set ${NVRAM_VarKeyName}="$(cat "$tempFile")"
       then
           printf "\n*NEW* Modified NVRAM Value:\n---------------------------"
           _NVRAM_ShowVar_ ; nvram commit
           printf "Modification is completed.\n\n"
       fi
   else
       tempStr1="$(echo "$oldClientName" | sed 's/[\/.*-]/\\&/g')"
       tempStr2="$(echo "$newClientName" | sed 's/[\/.*-]/\\&/g')"
       echo "$nvramKeyVal" | sed "s/${tempStr1}/${tempStr2}/g" | sed '/^$/d' > "$tempFile"

       if "$doModifyTest"
       then
           printf "\n**TEST** Modified NVRAM Value:\n------------------------------\n"
           cat "$tempFile"
           printf "\nTEMPORARY modification is completed.\n\n"
       #
       elif nvram set ${NVRAM_VarKeyName}="$(cat "$tempFile")"
       then
           printf "\n*NEW* Modified NVRAM Value:\n---------------------------"
           _NVRAM_ShowVar_ ; nvram commit
           printf "Modification is completed.\n\n"
       fi
   fi
   rm -f "$tempFile"
}

if [ -z "$(nvram get "$NVRAM_VarKeyName")" ]
then
    printf "NVRAM var [$NVRAM_VarKeyName] is EMPTY. Nothing to do."
    exit 0
fi

#------------------------------------------------------------------#
if [ $# -eq 0 ] || [ -z "$1" ] || [ "$1" = "help" ]
then _ShowUsage_ ; exit 0 ; fi

doModifyTest=true
if [ "$1" = "docommit" ] && [ "$2" = "modify" ]
then doModifyTest=false ; shift ; fi

case "$1" in
      show) _NVRAM_ShowVar_ ;;
      save) _NVRAM_SaveVar_ ;;
    backup) _NVRAM_BackUpVar_ ;;
   restore) _NVRAM_RestoreVar_ ;;
   doclear) _NVRAM_DelDirFiles_ ;;
    modify) shift ; _NVRAM_ModifyVar_ "$@" ;;
         *)
            printf "\n**ERROR**: UNKNOWN or INVALID Parameter [$*].\n"
            _WaitForEnterKey_ ; _ShowUsage_ 1
            ;;
esac

exit 0

#EOF#
