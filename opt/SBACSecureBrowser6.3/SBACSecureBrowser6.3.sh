#!/bin/sh
#
# The contents of this file are subject to the Netscape Public License
# Version 1.0 (the "NPL"); you may not use this file except in
# compliance with the NPL.  You may obtain a copy of the NPL at
# http://www.mozilla.org/NPL/
#
# Software distributed under the NPL is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the NPL
# for the specific language governing rights and limitations under the
# NPL.
#
# The Initial Developer of this code under the NPL is Netscape
# Communications Corporation.  Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation.  All Rights
# Reserved.
#

## 
## Usage:
##
## $ mozilla [args]
##
## This script is meant to run the mozilla-bin binary from either 
## mozilla/xpfe/bootstrap or mozilla/dist/bin.
##
## The script will setup all the environment voodoo needed to make
## the mozilla-bin binary to work.
##

PATH=/sbin:usr/sbin:/usr/local/sbin:$PATH

export PATH

# ensure there are no instances running already.

for PARAM; do
    if [ $next ]; then 
      sb_profile=$PARAM;
      echo Profile: $sb_profile;
      break;
    fi

    if [ "$PARAM" = "-P" ]; then
      next=1;
    fi
done

os=`uname -s`
ts=`date "+SBACSecureBrowser6.3-%s"`

if [ "$sb_profile" ]; then
  process=`ps aux | grep SBACSecureBrowser6.3 | grep "$sb_profile"`;
fi

if [ "$process" ]; then
  if [ "$sb_profile" ]; then
    echo Running Process Found for this profile: ["$sb_profile"];
    ps aux | grep "./run-mozilla.sh ./SBACSecureBrowser6.3 -P $sb_profile$" | cut -f4 -d" " | xargs kill; 
    ps aux | grep "./SBACSecureBrowser6.3 -P $sb_profile$" | cut -f4 -d" " | xargs kill; 
  fi
fi

moz_pis_startstop_scripts()
{
  MOZ_USER_DIR="%MOZ_USER_DIR%"
  # MOZ_PIS_ is the name space for "Mozilla Plugable Init Scripts"
  # These variables and there meaning are specified in
  # mozilla/xpfe/bootstrap/init.d/README
  MOZ_PIS_API=2
  MOZ_PIS_MOZBINDIR="${dist_bin}"
  MOZ_PIS_SESSION_PID="$$"
  MOZ_PIS_USER_DIR="${MOZ_USER_DIR}"
  export MOZ_PIS_API MOZ_PIS_MOZBINDIR MOZ_PIS_SESSION_PID MOZ_PIS_USER_DIR
  
  case "${1}" in
    "start")
      for curr_pis in "${dist_bin}/init.d"/S* "${HOME}/${MOZ_USER_DIR}/init.d"/S* ; do
        if [ -x "${curr_pis}" ] ; then
          case "${curr_pis}" in
            *.sh) .  "${curr_pis}"         ;;
            *)       "${curr_pis}" "start" ;;
          esac
        fi
      done
      ;;
    "stop")
      for curr_pis in "${HOME}/${MOZ_USER_DIR}/init.d"/K* "${dist_bin}/init.d"/K* ; do
        if [ -x "${curr_pis}" ] ; then
          case "${curr_pis}" in
            *.sh) . "${curr_pis}"        ;;
            *)      "${curr_pis}" "stop" ;;
          esac
        fi
      done
      ;;
    *)
      echo 1>&2 "$0: Internal error in moz_pis_startstop_scripts."
      exit 1
      ;;
  esac
}

# uncomment for debugging
# set -x

moz_libdir=/usr/local/lib/SBACSecureBrowser6.3-6.3
MRE_HOME=%MREDIR%

# Use run-mozilla.sh in the current dir if it exists
# If not, then start resolving symlinks until we find run-mozilla.sh
found=0
progname="$0"
curdir=`dirname "$progname"`
progbase=`basename "$progname"`
run_moz="$curdir/run-mozilla.sh"
if test -x "$run_moz"; then
  dist_bin="$curdir"
  found=1
else
  here=`/bin/pwd`
  while [ -h "$progname" ]; do
    bn=`basename "$progname"`
    cd `dirname "$progname"`
    progname=`/bin/ls -l "$bn" | sed -e 's/^.* -> //' `
    if [ ! -x "$progname" ]; then
      break
    fi
    curdir=`dirname "$progname"`
    run_moz="$curdir/run-mozilla.sh"
    if [ -x "$run_moz" ]; then
      cd "$curdir"
      dist_bin=`pwd`
      run_moz="$dist_bin/run-mozilla.sh"
      found=1
      break
    fi
  done
  cd "$here"
fi
if [ $found = 0 ]; then
  # Check default compile-time libdir
  if [ -x "$moz_libdir/run-mozilla.sh" ]; then
    dist_bin="$moz_libdir"
  else 
    echo "Cannot find mozilla runtime directory. Exiting."
    exit 1
  fi
fi

script_args=""
moreargs=""
debugging=0
MOZILLA_BIN="SBACSecureBrowser6.3"

# The following is to check for a currently running instance.
# This is taken almost verbatim from the Mozilla RPM package's launch script.
MOZ_CLIENT_PROGRAM="$dist_bin/mozilla-xremote-client"
check_running() {
    "${run_moz}" "$MOZ_CLIENT_PROGRAM" -a "${progbase}" 'ping()' 2>/dev/null >/dev/null
    RETURN_VAL=$?
    if [ $RETURN_VAL -eq 0 ]; then
        echo 1
        return 1
    else
        echo 0
        return 0
    fi
}

if [ "$OSTYPE" = "beos" ]; then
  mimeset -F "$MOZILLA_BIN"
fi

ALREADY_RUNNING=`check_running`

################################################################ Parse Arguments
# If there's a command line argument but it doesn't begin with a -
# it's probably a url.  Try to send it to a running instance.
_USE_EXIST=0
_optOne="$1"
case "${_optOne}" in
	-*) 
		;;
	*)
		_USE_EXIST=1
		;;
esac

_optLast=
for i in "$@"; do 
	_optLast="${i}"
done #last arg

if [ `expr "${_optLast}" : '.*:/.*'` -eq 0 -a \( -f "${_optLast}" -o -d "${_optLast}" \) ]; then
	# Last argument seems to be a local file/directory
	# Check, if it is absolutely specified (ie. /home/foo/file vs. ./file)
	# If it is just "relatively" (./file) specified, make it absolutely
	[ `expr "${_optLast}" : '/.*'` -eq 0 ] && _optLast="file://`pwd`/${_optLast}"
fi
################################################################ Parse Arguments

########################################################################### Main
if [ $ALREADY_RUNNING -eq 1 ]; then
	# There's an instance already running. Use it.
	# Any command line args passed in?
	if [ $# -gt 0 ]; then
		# There were "some" command line args.
		if [ ${_USE_EXIST} -eq 1 ]; then
			# We should use an existing instance, as _USE_EXIST=$_USE_EXIST=-1
			_remote_cmd="openURL(${_optLast})"
			"${run_moz}" "$MOZ_CLIENT_PROGRAM" -a "${progbase}" "${_remote_cmd}"
			unset _remote_cmd
			exit $?
		fi
	else
		# No command line args. Open new window/tab
		#exec "${run_moz}" "$MOZ_CLIENT_PROGRAM" -a "${progbase}" "xfeDoCommand(openBrowser)"
		"${run_moz}" "$MOZ_CLIENT_PROGRAM" -a "${progbase}" "xfeDoCommand(openBrowser)"
		exit $?
	fi
fi
# Default action - no running instance or _USE_EXIST (${_USE_EXIST}) ! -eq 1
########################################################################### Main

while [ $# -gt 0 ]
do
  case "$1" in
    -p | --pure | -pure)
      MOZILLA_BIN="${MOZILLA_BIN}.pure"
      shift
      ;;
    -g | --debug)
      script_args="$script_args -g"
      debugging=1
      shift
      ;;
    -d | --debugger)
      script_args="$script_args -d $2"
      shift 2
      ;;
    *)
      moreargs="$moreargs \"$1\""
      shift 1
      ;;
  esac
done

export MRE_HOME
eval "set -- $moreargs"

## Start addon scripts
moz_pis_startstop_scripts "start"

# Disabling active corners. Ony works for KDE
if [ "$DESKTOP_SESSION" = "kde" -o "$KDE_FULL_SESSION" = "true" ] 
then

   if [ -e "${HOME}/.kde/share/config/kwinrc" ]
   then
      #Backup existing config
      cp ${HOME}/.kde/share/config/kwinrc ${HOME}/.kde/share/config/kwinrc.securebrowser
   fi

   #deactivate active corners
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "Effect-PresentWindows" --key "BorderActivateAll" 9
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "Effect-PresentWindows" --key "BorderActivate" 9
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "Effect-Cube" --key "BorderActivate" 9
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "Effect-Cube" --key "BorderActivateCylinder" 9
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "Effect-Cube" --key "BorderActivateSphere" 9
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "Effect-DesktopGrid" --key "BorderActivate" 9
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "ElectricBorders" --key "Bottom" none
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "ElectricBorders" --key "BottomLeft" none
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "ElectricBorders" --key "BottomRight" none
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "ElectricBorders" --key "Left" none
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "ElectricBorders" --key "Right" none
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "ElectricBorders" --key "Top" none
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "ElectricBorders" --key "TopLeft" none
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "ElectricBorders" --key "TopRight" none
   kwriteconfig --file ${HOME}/.kde/share/config/kwinrc --group "Windows" --key "ElectricBorders" 0 

   #Get KDE to reload its configuration file
   qdbus org.kde.kwin /KWin reconfigure

fi

if [ $debugging = 1 ]
then
  echo $dist_bin/run-mozilla.sh $script_args $dist_bin/$MOZILLA_BIN "$@"
fi

if [ "$os" = "Linux" ] && [ $# -eq 0 ]; then
  "$dist_bin/run-mozilla.sh" $script_args "$dist_bin/$MOZILLA_BIN" "-CreateProfile" "$ts"
  wait;
  "$dist_bin/run-mozilla.sh" $script_args "$dist_bin/$MOZILLA_BIN" "-P" "$ts" "$@"
else
  "$dist_bin/run-mozilla.sh" $script_args "$dist_bin/$MOZILLA_BIN" "$@"
fi

exitcode=$?

## Stop addon scripts
moz_pis_startstop_scripts "stop"

# Reenable active corners in case we disabled it
if [ "$DESKTOP_SESSION" = "kde" -o "$KDE_FULL_SESSION" = "true" ]
then

   if [ -e "${HOME}/.kde/share/config/kwinrc.securebrowser" ]
   then
      #Restore existing backup config
      cp ${HOME}/.kde/share/config/kwinrc.securebrowser ${HOME}/.kde/share/config/kwinrc
   fi

   #Get KDE to reload its configuration file
   qdbus org.kde.kwin /KWin reconfigure
   
fi

exit $exitcode
# EOF.
