#!/bin/sh
####################################################################
# MonitorCronJobList.sh
#
# To monitor the number of cron jobs by taking a snapshot of the
# crontab list at a frequency given in minutes.
#
# Creation Date: 2020-Feb-05 [Martinski W.]
# Version: 0.1.5
####################################################################
set -u 

#---------------------------------------------------#
# ***** START CUSTOMIZABLE PARAMETERS SECTION ***** #
#---------------------------------------------------#
# Set directory where the log file will be created #
defltLogDirPath="/opt/var/log"
altn1LogDirPath="/jffs/scripts/logs"

# Set maximum log file size in kilobytes #
maxLogFileSizeKB=512
#---------------------------------------------------#
# ****** END CUSTOMIZABLE PARAMETERS SECTION ****** #
#---------------------------------------------------#

readonly scriptDirPath="$(/usr/bin/dirname "$0")"
readonly scriptFileName="${0##*/}"
readonly scriptFileNTag="${scriptFileName%.*}"
readonly dateTimeFormat="%Y-%b-%d, %I:%M:%S %p %Z (%a)"
readonly semaphoreFile="/tmp/var/tmp/${scriptFileNTag}.SEM.txt"
readonly scriptLogName="${scriptFileNTag}.LOG"
readonly backupLogName="${scriptFileNTag}.BKP.LOG"
readonly altn2LogDirPath="/tmp/var/tmp"

scriptLogFile=""
backupLogFile=""
isInteractive=false
if [ "$scriptDirPath" = "." ] || \
   { [ -t 0 ] && ! tty | grep -qwi "not" ; }
then isInteractive=true ; fi

#-----------------------------------------------------------#
_ShowUsage_()
{
   cat <<EOF
--------------------------------------------------
SYNTAX:
   $0 {start "mins" | stop}

Where "mins" is the frequency, in number of minutes, at which 
the script takes a snapshot of the current list of cron jobs. 

EXAMPLES:
   $0 start 10
   $0 stop
--------------------------------------------------
EOF
}

#-----------------------------------------------------------#
_PrintMsg_()
{
   ! "$isInteractive" && return 1
   printf "${1}"
}

#-----------------------------------------------------------#
_IsCJMonitorRunning_()
{
   local thePID
   if [ $# -eq 0 ] || [ -z "$1" ]
   then thePID=""
   else thePID="$1"
   fi

   if [ -f "$semaphoreFile" ] && \
      [ "$(cat "$semaphoreFile")" != "$thePID" ] && \
      top -b -n 1 | grep -v "grep " | grep -qE "${scriptFileName}[[:blank:]]* (re)?start [[:blank:]]*"
   then return 0
   else return 1
   fi
}

#-----------------------------------------------------------#
_ValidateLogDirPath_()
{
   if [ $# -eq 0 ] || [ -z "$1" ] ; then return 1; fi

   [ ! -d "$1" ] && mkdir -m 755 "$1" 2>/dev/null
   if [ -d "$1" ]
   then
       if [ "$defltLogDirPath" != "$1" ]
       then
           _PrintMsg_ "\nUsing Alternative Log Directory [$1].\n"
       fi
       scriptLogFile="${1}/$scriptLogName"
       backupLogFile="${1}/$backupLogName"
       return 0
   fi
   _PrintMsg_ "\nLog Directory [$1] *NOT* FOUND.\n"
   return 1
}

#-----------------------------------------------------------#
_CheckLogFileSize_()
{
   [ ! -f "$scriptLogFile" ] && return 1

   local theFileSize=0
   theFileSize="$(ls -l "$scriptLogFile" | awk -F ' ' '{print $5}')"
   if [ "$theFileSize" -gt "$maxLogFileSize" ]
   then
       cp -fp "$scriptLogFile" "$backupLogFile"
       rm -f "$scriptLogFile"
       _PrintMsg_ "\nDeleted $scriptLogFile [$theFileSize > $maxLogFileSize]\n\n"
   fi
}

sleepSecs=2
maxLogFileSize="$((maxLogFileSizeKB * 1024))"

#-----------------------------------------------------------#
_StartCJMonitor_()
{
   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       _PrintMsg_ "\n**ERROR**: MISSING parameter [$*]\n\n"
       _ShowUsage_ ; return 1
   fi
   if ! echo "$1" | grep -qE "^[1-9][0-9]*$"
   then
       _PrintMsg_ "\n**ERROR**: INVALID parameter [$1]\n\n"
       _ShowUsage_ ; return 1
   fi

   if _IsCJMonitorRunning_ "$$"
   then
       _PrintMsg_ "\nScript [$scriptFileName] is already running.\n"
       return 0
   fi
   echo "$$" > "$semaphoreFile"
   ! "$isInteractive" && sleep 120

   local countSecs=0  freqSecs="$(($1 * 60))"
   local theCronJobCount=0  logMsg

   for LOG_DIR in "$defltLogDirPath" "$altn1LogDirPath" "$altn2LogDirPath"
   do _ValidateLogDirPath_ "$LOG_DIR" && break ; done

   _PrintMsg_ "\nThe log file is [$scriptLogFile]\n\n"
   _CheckLogFileSize_

   echo "START [frequency is $1 minutes]" >> "$scriptLogFile"

   while [ -f "$semaphoreFile" ]
   do
      if [ "$theCronJobCount" -eq 0 ] || [ "$((countSecs % freqSecs))" -eq 0 ]
      then
         logMsg=""
         if [ "$theCronJobCount" -gt 0 ] && \
            [ "$theCronJobCount" -ne "$(cru l | wc -l)" ]
         then
             logMsg="*NOTE*: Current number of Cron Jobs is different from previous count."
         fi
         theCronJobCount="$(cru l | wc -l)"
         {
           date +"$dateTimeFormat"
           echo "Number of Cron Jobs: [$theCronJobCount]"
           [ -n "$logMsg" ] && echo "$logMsg"
           echo "---------------------------------------"
           cru l
           echo "==========================================================="
         } >> "$scriptLogFile"
         _CheckLogFileSize_
      fi
      sleep "$sleepSecs"
      countSecs="$((countSecs + sleepSecs))"
   done

   echo "EXIT [$(date +"$dateTimeFormat")]" >> "$scriptLogFile"
   return 0
}

#-----------------------------------------------------------#
_StopCJMonitor_()
{
   if ! _IsCJMonitorRunning_
   then
       _PrintMsg_ "\nScript [$scriptFileName] is *NOT* running.\n\n"
       return 1
   fi
   local msgStr

   _PrintMsg_ "\nStopping script [$scriptFileName]...\n"
   rm -f "$semaphoreFile" && sleep "$((sleepSecs * 2))"

   if ! _IsCJMonitorRunning_
   then msgStr="The script [$scriptFileName] was stopped successfully."
   else msgStr="The script [$scriptFileName] was *NOT* stopped successfully."
   fi
   _PrintMsg_ "${msgStr}\n"
   return 0
}

if [ $# -eq 0 ] || [ -z "$1" ]
then _ShowUsage_ ; exit 0 ; fi

trap "_StopCJMonitor_ ; exit 0" HUP INT QUIT ABRT TERM

case "$1" in
    stop)
        _StopCJMonitor_
        ;;
    start)
        shift
        _StartCJMonitor_ "$@"
        ;;
    restart)
        shift
        _StopCJMonitor_
        _StartCJMonitor_ "$@"
        ;;
    *)
        _PrintMsg_ "\n**ERROR**: UNKNOWN parameter [$1]\n\n"
        _ShowUsage_
        ;;
esac

exit 0

#EOF#
