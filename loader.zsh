#!/usr/bin/env zsh

# ----------------------------------------------------------------------

# loader.zsh
#
# This script implements Shell Script Loader for all versions of Zsh
# starting 4.2.
#
# Please see loader.txt for more info on how to use this script.
#
# This script complies with the Requiring Specifications of
# Shell Script Loader version 0 (RS0).
#
# Version: 0.2
#
# Author: konsolebox
# Copyright Free / Public Domain
# Aug. 29, 2009 (Last Updated 2016/06/26)

# Notes:
#
# When using "typeset" or "declare" to declare global variables in
# scripts, always add '-g' as an option.  Not adding this option will
# make the variables only have a local scope inside any of the functions
# here that will be used to load the script.  Among the major known
# shells, only Zsh and Bash (ver. 4.2+) are the only shells that are
# capable of having this explicit feature (as of this writing).  There
# are also other ways to declare global variables in other shells but
# not through the use of "typeset" or "declare".  Variables that can
# only be declared using the two builtin commands sometimes can never be
# declared global unless declared outside any function or the main
# scope.
#
# This implementation script for Zsh actually is also tested to be
# functionally compatible with versions 4.0.* and 4.1.* but these
# earlier versions of Zsh have limited execution stack (job tables) that
# are sometimes configured by default at small sizes and are also not
# expandable unlike in 4.2.* and newer so I thought that it's better to
# exclude these versions just to keep integrity.
#
# If you know what you're doing you may change the conditional
# expression below to something like '[ ! "${ZSH_VERSION%%.*}" -ge 4 ]'.
# You may want to do this for example, if you want your scripts to be
# more compatible with most versions of Zsh and if you're sure that your
# scripts doesn't make too much recursions in which even the earlier
# versions will be able to handle.  You may verify this by testing your
# scripts with the earlier versions of Zsh that is configured to have
# its limit set to minimum (see MAXJOB in zshconfig.ac).  If you don't
# find an error message like "job table full or recursion limit
# exceeded", then as with respect to this issue, your scripts should
# probably run just fine.

# ----------------------------------------------------------------------

if [ "$LOADER_ACTIVE" = true ]; then
	echo "loader: Loader cannot be loaded twice." >&2
	exit 1
fi

if [ -z "$ZSH_VERSION" ]; then
	echo "loader: Zsh is needed to run this script." >&2
	exit 1
fi

if ! ( IFS=.; set -- ${=ZSH_VERSION}; [ "$1" -gt 4 ] || [ "$1" -eq 4 -a "$2" -ge 2 ] ); then
	echo "loader: Only versions of Zsh not earlier than 4.2.0 can work properly with this script." >&2
	exit 1
fi

if [ "$ZSH_NAME" = sh ] || [ "$ZSH_NAME" = ksh ]; then
	echo "loader: This script doesn't work if Zsh is running in sh or ksh emulation mode." >&2
	exit 1
fi

#### PUBLIC VARIABLES ####

typeset -g LOADER_ACTIVE=true
typeset -g LOADER_RS=0
typeset -g LOADER_VERSION=0.2

#### PRIVATE VARIABLES ####

typeset -g -a LOADER_CS
typeset -g -i LOADER_CS_I=0
typeset -g -A LOADER_FLAGS
typeset -g -a LOADER_PATHS
typeset -g -A LOADER_PATHS_FLAGS

#### PUBLIC FUNCTIONS ####

function load {
	[[ $# -eq 0 ]] && loader_fail "Function called with no argument." load

	case $1 in
	'')
		loader_fail "File expression cannot be null." load "$@"
		;;
	/*|./*|../*)
		if [[ -f $1 ]]; then
			loader_getcleanpath "$1"
			[[ -r $__ ]] || loader_fail "File not readable: $__" load "$@"
			loader_load "$@[2,-1]"
			__=$?
			[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
			return "$__"
		fi
		;;
	*)
		for __ in "${LOADER_PATHS[@]}"; do
			[[ -f $__/$1 ]] || continue
			loader_getcleanpath "$__/$1"
			[[ -r $__ ]] || loader_fail "Found file not readable: $__" load "$@"
			LOADER_FLAGS[$1]=.
			loader_load "$@[2,-1]"
			__=$?
			[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
			return "$__"
		done
		;;
	esac

	loader_fail "File not found: $1" load "$@"
}

function include {
	[[ $# -eq 0 ]] && loader_fail "Function called with no argument." include

	case $1 in
	'')
		loader_fail "File expression cannot be null." include "$@"
		;;
	/*|./*|../*)
		loader_getcleanpath "$1"
		[[ -n ${LOADER_FLAGS[$__]} ]] && return

		if [[ -f $__ ]]; then
			[[ -r $__ ]] || loader_fail "File not readable: $__" include "$@"
			loader_load "$@[2,-1]"
			__=$?
			[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
			return "$__"
		fi
		;;
	*)
		[[ -n ${LOADER_FLAGS[$1]} ]] && return

		for __ in "${LOADER_PATHS[@]}"; do
			loader_getcleanpath "$__/$1"

			if [[ -n ${LOADER_FLAGS[$__]} ]]; then
				LOADER_FLAGS[$1]=.
				return 0
			elif [[ -f $__ ]]; then
				[[ -r $__ ]] || loader_fail "Found file not readable: $__" include "$@"
				LOADER_FLAGS[$1]=.
				loader_load "$@[2,-1]"
				__=$?
				[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
				return "$__"
			fi
		done
		;;
	esac

	loader_fail "File not found: $1" include "$@"
}

function call {
	[[ $# -eq 0 ]] && loader_fail "Function called with no argument." call

	case $1 in
	'')
		loader_fail "File expression cannot be null." call "$@"
		;;
	/*|./*|../*)
		if [[ -f $1 ]]; then
			loader_getcleanpath "$1"
			[[ -r $__ ]] || loader_fail "File not readable: $__" call "$@"
			( loader_load "$@[2,-1]" )
			return
		fi
		;;
	*)
		for __ in "${LOADER_PATHS[@]}"; do
			[[ -f $__/$1 ]] || continue
			loader_getcleanpath "$__/$1"
			[[ -r $__ ]] || loader_fail "Found file not readable: $__" call "$@"

			(
				LOADER_FLAGS[$1]=.
				loader_load "$@[2,-1]"
			)

			return
		done
		;;
	esac

	loader_fail "File not found: $1" call "$@"
}

function loader_addpath {
	for __; do
		[[ -d $__ ]] || loader_fail "Directory not found: $__" loader_addpath "$@"
		[[ -x $__ ]] || loader_fail "Directory not accessible: $__" loader_addpath "$@"
		[[ -r $__ ]] || loader_fail "Directory not searchable: $__" loader_addpath "$@"
		loader_getcleanpath "$__"

		if [[ -z ${LOADER_PATHS_FLAGS[$__]} ]]; then
			LOADER_PATHS[${#LOADER_PATHS[@]}+1]=$__
			LOADER_PATHS_FLAGS[$__]=.
		fi
	done
}

function loader_flag {
	[[ $# -eq 1 ]] || loader_fail "Function requires a single argument." loader_flag "$@"
	loader_getcleanpath "$1"
	LOADER_FLAGS[$__]=.
}

function loader_reset {
	if [[ $# -eq 0 ]]; then
		set -A LOADER_FLAGS
		set -A LOADER_PATHS
		set -A LOADER_PATHS_FLAGS
	elif [[ $1 = flags ]]; then
		set -A LOADER_FLAGS
	elif [[ $1 = paths ]]; then
		set -A LOADER_PATHS
		set -A LOADER_PATHS_FLAGS
	else
		loader_fail "Invalid argument: $1" loader_reset "$@"
	fi
}

function loader_finish {
	LOADER_ACTIVE=false

	unset -v LOADER_CS LOADER_CS_I LOADER_FLAGS LOADER_PATHS \
		LOADER_PATHS_FLAGS

	unset -f load include call loader_addpath loader_fail \
		loader_finish loader_flag loader_getcleanpath loader_load \
		loader_reset
}

#### PRIVATE FUNCTIONS ####

function loader_load {
	LOADER_FLAGS[$__]=.
	LOADER_CS[++LOADER_CS_I]=$__
	. "$__"
}

function loader_getcleanpath {
	case $1 in
	.|'')
		__=$PWD
		;;
	/)
		__=/
		;;
	..|../*|*/..|*/../*|./*|*/.|*/./*|*//*)
		local T I=0 IFS=/
		set -A T

		case $1 in
		/*)
			set -- ${=1#/}
			;;
		*)
			set -- ${=PWD#/} ${=1}
			;;
		esac

		for __; do
			case $__ in
			..)
				[[ I -gt 0 ]] && T[I--]=()
				continue
				;;
			.|'')
				continue
				;;
			esac

			T[++I]=$__
		done

		__="/${T[*]}"
		;;
	/*)
		__=${1%/}
		;;
	*)
		__=${PWD%/}/${1%/}
		;;
	esac
}

function loader_fail {
	local MESSAGE=$1 FUNC=$2
	shift 2

	{
		echo "loader: $FUNC(): $MESSAGE"
		echo
		echo '  Current scope:'

		if [[ LOADER_CS_I -gt 0 ]]; then
			echo "    ${LOADER_CS[LOADER_CS_I - 1]}"
		else
			echo '    (main)'
		fi

		echo

		if [[ $# -gt 0 ]]; then
			echo '  Command:'
			echo -n "    $FUNC"
			printf ' %q' "$@"
			echo
			echo
		fi

		if [[ LOADER_CS_I -gt 0 ]]; then
			echo '  Call stack:'
			echo '    (main)'
			printf '    -> %s\n' "${LOADER_CS[@]}"
			echo
		fi

		echo '  Search paths:'

		if [[ ${#LOADER_PATHS[@]} -gt 0 ]]; then
			printf '    %s\n' "${LOADER_PATHS[@]}"
		else
			echo '    (empty)'
		fi

		echo
		echo '  Working directory:'
		echo "    $PWD"
		echo
	} >&2

	exit 1
}

# ----------------------------------------------------------------------

# * Zsh does not expand filenames after ${=VAR} so we don't have to
#   worry about it.

# * Not using 'set -A' to a local array variable seems to cause
#   problems.

# ----------------------------------------------------------------------
