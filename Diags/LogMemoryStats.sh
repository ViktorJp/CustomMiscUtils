#!/bin/sh
#####################################################################
# LogMemoryStats.sh
#
# To log a snapshot of current RAM usage stats, including the
# "tmpfs" filesystem (i.e. a virtual drive that uses RAM).
#
# It also takes snapshots of file/directory usage in JFFS,
# and the current top 10 processes based on "VSZ" size for
# context and to capture any correlation between the stats.
#
# NOTE:
# The *OPTIONAL* parameter indicates whether to keep track of
# file/directory sizes in KByte or MByte. Since we're usually
# looking for unexpected large files, we filter out < 750KBytes.
# If no parameter is given the default is the "Human Readable"
# format.
#
#    ShowMemoryUsage.sh  [kb|KB|mb|MB]
#
# FOR DIAGNOSTICS PURPOSES:
# -------------------------
# Set a cron job to periodically monitor & log RAM usage stats
# every 30 minutes or every hour to check for any "trends" in 
# rapid and unusual peaks in RAM usage, especially unexpected
# large files found stored in "tmpfs" (or "jffs") filesystem.
#
# EXAMPLE:
# cru a LogMemStats "*/30 * * * * /jffs/scripts/LogMemoryStats.sh"
#--------------------------------------------------------------------
# Creation Date: 2021-Apr-03 [Martinski W.]
# Last Modified: 2024-Mar-12 [Martinski W.]
# Version: 0.5.4
#####################################################################
set -u

#===================================================#
# ***** START CUSTOMIZABLE PARAMETERS SECTION ***** #
#===================================================#
#---------------------------------------------------
# Make sure to set the log directory to a location 
# that survives a reboot so logs are not deleted.
#---------------------------------------------------
scriptLogDPath="/opt/var/log"

#---------------------------------------------------
# Set the maximum log file size in KByte units.
# 1.0MByte should be enough to save at least 5 days
# worth of log entries, assuming you run the script 
# no more frequent than every 20 minutes.
#---------------------------------------------------
readonly maxLogFileSizeKB=1024   #1.0MB#
#===================================================#
# ****** END CUSTOMIZABLE PARAMETERS SECTION ****** #
#===================================================#

readonly scriptDirPath="$(/usr/bin/dirname "$0")"
readonly scriptFileName="${0##*/}"
readonly scriptFileNTag="${scriptFileName%.*}"
readonly scriptLogFName="${scriptFileNTag}.LOG"
readonly backupLogFName="${scriptFileNTag}.BKP.LOG"
readonly tempLogFPath="/tmp/var/tmp/${scriptFileNTag}.TMP.LOG"
readonly maxLogFileSize="$((maxLogFileSizeKB * 1024))"
readonly duFilterSizeKB=750   #Filter for "du" output#
readonly tempAltLogDPath="/jffs/scripts/logs"
readonly CPU_TempProcDMU=/proc/dmu/temperature
readonly CPU_TempThermal=/sys/devices/virtual/thermal/thermal_zone0/temp

scriptLogFPath="${scriptLogDPath}/$scriptLogFName"
backupLogFPath="${scriptLogDPath}/$backupLogFName"

isInteractive=false
if [ -t 0 ] && ! tty | grep -qwi "not"
then isInteractive=true ; fi

if [ $# -eq 0 ] || [ -z "$1" ] || \
   ! echo "$1" | grep -qE "^(kb|KB|mb|MB)$"
then units="HR"
else units="$1"
fi

_PrintMsg_()
{
   ! "$isInteractive" && return 0
   printf "${1}"
}

_WaitForEnterKey_()
{
   ! "$isInteractive" && return 0
   printf "\nPress <Enter> key to continue..."
   read -r EnterKEY ; echo
}

_ValidateLogDirPath_()
{
   if [ $# -eq 0 ] || [ -z "$1" ]
   then
       _PrintMsg_ "\n**ERROR**: Log Directory path was *NOT* provided.\n"
       _PrintMsg_ "\nExiting now.\n\n"
       exit 1
   fi

   [ ! -d "$1" ] && mkdir -m 755 "$1" 2>/dev/null
   if [ -d "$1" ]
   then
       scriptLogFPath="${1}/$scriptLogFName"
       backupLogFPath="${1}/$backupLogFName"
       return 0
   fi
   _PrintMsg_ "\n**ERROR**: Log Directory [$1] *NOT* FOUND.\n"
   _WaitForEnterKey_

   if [ $# -gt 1 ] && [ -n "$2" ]
   then
       _PrintMsg_ "\n**INFO**: Using Temporary Log Directory [$2].\n"
       _ValidateLogDirPath_ "$2"
   else
       _PrintMsg_ "\nExiting now.\n\n"
       exit 2
   fi
}

_CheckLogFileSize_()
{
   [ ! -f "$scriptLogFPath" ] && return 1

   local theFileSize=0
   theFileSize="$(ls -l "$scriptLogFPath" | awk -F ' ' '{print $5}')"
   if [ "$theFileSize" -gt "$maxLogFileSize" ]
   then
       cp -fp "$scriptLogFPath" "$backupLogFPath"
       rm -f "$scriptLogFPath"
       _PrintMsg_ "\nDeleted $scriptLogFPath [$theFileSize > $maxLogFileSize]\n\n"
   fi
}

_ProcMemInfo_()
{
   printf "/proc/meminfo\n-------------\n"
   grep -E "^Mem[TFA].*:[[:blank:]]+ .* kB$" /proc/meminfo
   grep -E "^Buffers:[[:blank:]]+ .* kB$" /proc/meminfo
   grep -E "^Cached:[[:blank:]]+ .* kB$" /proc/meminfo
   grep -E "^Swap[TFC].*:[[:blank:]]+ .* kB$" /proc/meminfo
   grep -E "^Active(\([af].*\))?:[[:blank:]]+ .* kB$" /proc/meminfo
   grep -E "^Inactive(\([af].*\))?:[[:blank:]]+ .* kB$" /proc/meminfo
}

duMinKB="$duFilterSizeKB"
_InfoKBdu_()
{ du -axk "$1" | sort -nr -t ' ' -k 1 | awk -v minKB="$duMinKB" -F ' ' '{if ($1 > minKB) print $0}' | head -n "$2" ; }

_InfoMBdu_()
{
  tmpStr="$(du -axh "$1" | sort -nr -t ' ' -k 1 | grep -Ev "^([0-9]{1,3}([.][0-9]+K)?[[:blank:]]+)")"
  echo "$tmpStr" | grep -E "^([0-9]+[.][0-9]+M[[:blank:]]+)" | head -n "$2"
  echo "$tmpStr" | grep -E "^([0-9]+[.][0-9]+K[[:blank:]]+)" | head -n "$2"
}

_InfoHRdu_()
{
  tmpStr="$(du -axh "$1" | sort -nr -t ' ' -k 1 | grep -Ev "^([0-9]{1,3}[[:blank:]]+|([0-9]{1,2}[.][0-9]+K[[:blank:]]+))")"
  echo "$tmpStr" | grep -E "^([0-9]+[.][0-9]+M[[:blank:]]+)" | head -n "$2"
  echo "$tmpStr" | grep -E "^([0-9]+[.][0-9]+K[[:blank:]]+)" | awk -v minKB="$duMinKB" -F '.' '{if ($1 > minKB) print $0}' | head -n "$2"
}

_Get_CPU_Temp_DMU_()
{
   local rawTemp  charPos3  cpuTemp
   rawTemp="$(awk -F ' ' '{print $4}' "$CPU_TempProcDMU")"

   ## To check for a possible 3-digit value ##
   charPos3="${rawTemp:2:1}"
   if echo "$charPos3" | grep -qE "[0-9]"
   then cpuTemp="${rawTemp:0:3}.0"
   else cpuTemp="${rawTemp:0:2}.0"
   fi
   printf "CPU Temperature: ${cpuTemp} °C\n"
}

_Get_CPU_Temp_Thermal_()
{
   local rawTemp  cpuTemp
   rawTemp="$(cat "$CPU_TempThermal")"
   cpuTemp="$((rawTemp / 1000)).$(printf "%03d" "$((rawTemp % 1000))")"
   printf "CPU Temperature: ${cpuTemp} °C\n"
}

_CPU_Temperature_()
{
   if [ -f "$CPU_TempProcDMU" ]
   then _Get_CPU_Temp_DMU_ ; return 0
   fi
   if [ -f "$CPU_TempThermal" ]
   then _Get_CPU_Temp_Thermal_ ; return 0
   fi
   printf "\n**ERROR**: CPU Temperature file was *NOT* found.\n"
   return 1
}

_ValidateLogDirPath_ "$scriptLogDPath" "$tempAltLogDPath"
_CheckLogFileSize_

{
   echo "=================================="
   date +"%Y-%b-%d, %I:%M:%S %p %Z (%a)"
   printf "Uptime\n------\n" ; uptime ; echo
   _CPU_Temperature_ ; echo
   printf "free:\n" ; free ; echo
   _ProcMemInfo_ ; echo
   df -hT | grep -E "(^Filesystem|/jffs$|/tmp$|/var$)" | sort -d -t ' ' -k 1
   echo
   case "$units" in
       kb|KB) printf "KBytes [du /tmp/]\n-----------------\n"
              _InfoKBdu_ "/tmp" 15
              echo
              printf "KBytes [du /jffs]\n-----------------\n"
              _InfoKBdu_ "/jffs" 15
              ;;
       mb|MB) printf "MBytes [du /tmp/]\n-----------------\n"
              _InfoMBdu_ "/tmp" 15
              echo
              printf "MBytes [du /jffs]\n-----------------\n"
              _InfoMBdu_ "/jffs" 15
              ;;
       hr|HR) printf "[du /tmp/]\n----------\n"
              _InfoHRdu_ "/tmp" 15
              echo
              printf "[du /jffs]\n----------\n"
              _InfoHRdu_ "/jffs" 15
             ;;
   esac
   echo
   top -b -n1 | head -n 14
} > "$tempLogFPath"

"$isInteractive" && cat "$tempLogFPath"
cat "$tempLogFPath" >> "$scriptLogFPath"
rm -f "$tempLogFPath" 

_PrintMsg_ "\nLog entry was added to:\n${scriptLogFPath}\n\n"

#EOF#
