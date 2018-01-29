#!/usr/bin/env ksh

# ----------------------------------------------------------------------

# loader.ksh
#
# This script implements Shell Script Loader for Ksh - the original
# Ksh (KornShell 93+), the public domain Korn shell (PD KSH), and
# MirBSD Korn shell (mksh).
#
# Please see loader.txt for more info on how to use this script.
#
# This script complies with the Requiring Specifications of
# Shell Script Loader version 0 (RS0)
#
# Version: 0.2.2
#
# Author: konsolebox
# Copyright Free / Public Domain
# Aug. 29, 2009 (Last Updated 2018/01/29)

# Limitations of Shell Script Loader in PD KSH:
#
# In PD KSH (not the Ksh 93+), typeset declarations inside functions
# always make variables only available within the encapsulating function
# therefore scripts that have typeset declarations that are meant to
# create global variables when called within a loader function like
# include() will only have visibility inside include().
#
# Array indices in PD KSH are currently limited to the range of 0
# through 1023 but this value is big enough for the list of search paths
# and for the call stack.

# ----------------------------------------------------------------------

if [ "$LOADER_ACTIVE" = true ]; then
	echo "loader: Loader cannot be loaded twice." >&2
	exit 1
fi

if ( eval '[ -n "${.sh.version}" ] && exit 10' ) >/dev/null 2>&1; [ "$?" -eq 10 ]; then
	LOADER_SHELL=ksh93
else
	case $KSH_VERSION in
	'@(#)PD KSH '*)
		LOADER_SHELL=pdksh
		;;
	'@(#)MIRBSD KSH '*)
		LOADER_SHELL=mksh
		;;
	'')
		if [ "$ZSH_NAME" = ksh ]; then
			echo "loader: Emulated Ksh from Zsh does not work with this script." >&2
		else
			echo "loader: Ksh is needed to run this script." >&2
		fi

		exit 1
		;;
	*)
		echo "loader: Version of Ksh is not supported." >&2
		exit 1
		;;
	esac
fi

#### PUBLIC VARIABLES ####

LOADER_ACTIVE=true
LOADER_RS=0
LOADER_VERSION=0.2.2

#### PRIVATE VARIABLES ####

set -A LOADER_CS
set -A LOADER_PATHS
LOADER_CS_I=0

#### PUBLIC FUNCTIONS ####

load() {
	[[ $# -eq 0 ]] && loader_fail "Function called with no argument." load

	case $1 in
	'')
		loader_fail "File expression cannot be null." load "$@"
		;;
	/*|./*|../*)
		if [[ -f $1 ]]; then
			loader_getcleanpath "$1"
			[[ -r $__ ]] || loader_fail "File not readable: $__" load "$@"
			shift
			loader_load "$@"
			__=$?
			unset 'LOADER_CS[LOADER_CS_I--]'
			return "$__"
		fi
		;;
	*)
		for __ in "${LOADER_PATHS[@]}"; do
			[[ -f $__/$1 ]] || continue
			loader_getcleanpath "$__/$1"
			[[ -r $__ ]] || loader_fail "Found file not readable: $__" load "$@"
			loader_flag_ "$1"
			shift
			loader_load "$@"
			__=$?
			unset 'LOADER_CS[LOADER_CS_I--]'
			return "$__"
		done
		;;
	esac

	loader_fail "File not found: $1" load "$@"
}

include() {
	[[ $# -eq 0 ]] && loader_fail "Function called with no argument." include

	case $1 in
	'')
		loader_fail "File expression cannot be null." include "$@"
		;;
	/*|./*|../*)
		loader_getcleanpath "$1"
		loader_flagged "$__" && return

		if [[ -f $__ ]]; then
			[[ -r $__ ]] || loader_fail "File not readable: $__" include "$@"
			shift
			loader_load "$@"
			__=$?
			unset 'LOADER_CS[LOADER_CS_I--]'
			return "$__"
		fi
		;;
	*)
		loader_flagged "$1" && return

		for __ in "${LOADER_PATHS[@]}"; do
			loader_getcleanpath "$__/$1"

			if loader_flagged "$__"; then
				loader_flag_ "$1"
				return 0
			elif [[ -f $__ ]]; then
				[[ -r $__ ]] || loader_fail "Found file not readable: $__" include "$@"
				loader_flag_ "$1"
				shift
				loader_load "$@"
				__=$?
				unset 'LOADER_CS[LOADER_CS_I--]'
				return "$__"
			fi
		done
		;;
	esac

	loader_fail "File not found: $1" include "$@"
}

call() {
	[[ $# -eq 0 ]] && loader_fail "Function called with no argument." call

	case $1 in
	'')
		loader_fail "File expression cannot be null." call "$@"
		;;
	/*|./*|../*)
		if [[ -f $1 ]]; then
			loader_getcleanpath "$1"
			[[ -r $__ ]] || loader_fail "File not readable: $__" call "$@"

			(
				shift
				loader_load "$@"
			)

			return
		fi
		;;
	*)
		for __ in "${LOADER_PATHS[@]}"; do
			[[ -f $__/$1 ]] || continue
			loader_getcleanpath "$__/$1"
			[[ -r $__ ]] || loader_fail "Found file not readable: $__" call "$@"

			(
				loader_flag_ "$1"
				shift
				loader_load "$@"
			)

			return
		done
		;;
	esac

	loader_fail "File not found: $1" call "$@"
}

loader_addpath() {
	for __; do
		[[ -d $__ ]] || loader_fail "Directory not found: $__" loader_addpath "$@"
		[[ -x $__ ]] || loader_fail "Directory not accessible: $__" loader_addpath "$@"
		[[ -r $__ ]] || loader_fail "Directory not searchable: $__" loader_addpath "$@"
		loader_getcleanpath "$__"
		loader_addpath_ "$__"
	done
}

loader_flag() {
	[[ $# -eq 1 ]] || loader_fail "Function requires a single argument." loader_flag "$@"
	loader_getcleanpath "$1"
	loader_flag_ "$__"
}

loader_reset() {
	if [[ $# -eq 0 ]]; then
		loader_reset_flags
		loader_reset_paths
	elif [[ $1 == flags ]]; then
		loader_reset_flags
	elif [[ $1 == paths ]]; then
		loader_reset_paths
	else
		loader_fail "Invalid argument: $1" loader_reset "$@"
	fi
}

loader_finish() {
	LOADER_ACTIVE=false
	loader_reset_flags

	unset -v LOADER_CS LOADER_CS_I LOADER_FLAGS LOADER_PATHS \
			LOADER_PATHS_FLAGS

	unset -f load include call loader_addpath loader_addpath_ \
			loader_fail loader_flagged loader_flag loader_flag_ \
			loader_getcleanpath loader_load loader_reset
}

#### PRIVATE FUNCTIONS ####

loader_load() {
	loader_flag_ "$__"
	LOADER_CS[++LOADER_CS_I]=$__
	. "$__"
}

loader_fail() {
	message=$1 func=$2
	shift 2

	{
		echo "loader: $func(): $message"
		echo
		echo "  Current scope:"

		if [[ LOADER_CS_I -gt 0 ]]; then
			print -r "    ${LOADER_CS[LOADER_CS_I]}"
		else
			echo "    (main)"
		fi

		echo

		if [[ $# -gt 0 ]]; then
			echo "  Command:"
			print -rn "    $func"

			for __; do
				print -rn " \"$__\""
			done

			echo
			echo
		fi

		if [[ LOADER_CS_I -gt 0 ]]; then
			echo "  Call stack:"
			echo "    (main)"
			typeset i=1

			while [[ i -le LOADER_CS_I ]]; do
				print -r "    -> ${LOADER_CS[i]}"
				(( ++i ))
			done

			echo
		fi

		echo "  Search paths:"

		if [[ ${#LOADER_PATHS[@]} -gt 0 ]]; then
			for __ in "${LOADER_PATHS[@]}"; do
				echo "    $__"
			done
		else
			echo "    (empty)"
		fi

		echo
		echo "  Working directory:"
		print -r "    $PWD"
		echo
	} >&2

	exit 1
}

#### VERSION DEPENDENT FUNCTIONS AND VARIABLES ####

if [[ $LOADER_SHELL == ksh93 ]]; then
	eval '
		LOADER_FLAGS=([.]=.)
		LOADER_PATHS_FLAGS=([.]=.)

		loader_addpath_() {
			if [[ -z ${LOADER_PATHS_FLAGS[$1]} ]]; then
				LOADER_PATHS[${#LOADER_PATHS[@]}]=$1
				LOADER_PATHS_FLAGS[$1]=.
			fi
		}

		loader_flag_() {
			LOADER_FLAGS[$1]=.
		}

		loader_flagged() {
			[[ -n ${LOADER_FLAGS[$1]} ]]
		}

		loader_reset_flags() {
			LOADER_FLAGS=()
		}

		loader_reset_paths() {
			set -A LOADER_PATHS
			LOADER_PATHS_FLAGS=()
		}
	'
else
	loader_addpath_() {
		for __ in "${LOADER_PATHS[@]}"; do
			[[ $1 == "$__" ]] && return
		done

		LOADER_PATHS[${#LOADER_PATHS[@]}]=$1
	}

	if [[ $LOADER_SHELL == mksh ]]; then
		loader_flag_() {
			typeset v
			v=${1//./_dt_}
			v=${v// /_sp_}
			v=${v//\//_sl_}
			v=LOADER_FLAGS_${v//[!A-Za-z0-9_]/_ot_}
			typeset -n r=$v
			r=.
		}

		loader_flagged() {
			typeset v
			v=${1//./_dt_}
			v=${v// /_sp_}
			v=${v//\//_sl_}
			v=LOADER_FLAGS_${v//[!A-Za-z0-9_]/_ot_}
			typeset -n r=$v
			[[ -n $r ]]
		}
	else
		loader_flag_() {
			typeset v
			v=$(echo "$1" | sed 's/\./_dt_/g; s/ /_sp_/g; s/\//_sl_/g; s/[^A-Za-z0-9_]/_ot_/g') || exit 1
			eval "LOADER_FLAGS_$v=."
		}

		loader_flagged() {
			typeset v
			v=$(echo "$1" | sed 's/\./_dt_/g; s/ /_sp_/g; s/\//_sl_/g; s/[^A-Za-z0-9_]/_ot_/g') || exit 1
			eval "[[ -n \$LOADER_FLAGS_$v ]]"
		}
	fi

	loader_reset_flags() {
		typeset v IFS=' '
		v=$(set | awk -F= '/^LOADER_FLAGS_/ { print $1 }' ORS=' ') || exit 1
		unset $v
	}

	loader_reset_paths() {
		set -A LOADER_PATHS
	}
fi

__='{
	typeset t i=0 IFS=/

	case $1 in
	/*)
		__=${1#/}
		;;
	*)
		__=${PWD#/}/$1
		;;
	esac

	case $- in
	*f*)
		set -- $__
		;;
	*)
		set -f
		set -- $__
		set +f
		;;
	esac

	for __; do
		case $__ in
		..)
			(( i )) && unset "t[--i]"
			continue
			;;
		.|"")
			continue
			;;
		esac

		t[i++]=$__
	done

	__="/${t[*]}"
}'

if [[ $LOADER_SHELL == ksh93 ]]; then
	eval "function loader_getcleanpath $__"
else
	eval "loader_getcleanpath() $__"
fi

unset -v LOADER_SHELL

# ----------------------------------------------------------------------

# * In some if not all versions of Ksh, "${@:X[:Y]}" always presents a
#   single null string if no positional parameter is matched.

# * In some versions of Ksh, 'read <<< "$VAR"' includes '"' in the
#   string.

# * Using 'set -- $VAR' to split strings inside variables will sometimes
#   yield different strings if one of the strings contain globs
#   characters like *, ? and the brackets [ and ] that are also valid
#   characters in filenames.

# * Changing the IFS causes buggy behaviors in PD KSH.

# * Newer versions of Ksh93 crashes with test (at least starting with
#   2011-02-08).  2007-03-28 works.  Other versions still need testing.

# * Unsetting functions requires explicit use of -f option.

# * PD KSH and mksh does not expand ${@:2}.

# * PD KSH and mksh interpretes backslash sequences in a single-quote
#   string so we should be careful with it.

# * In PD KSH or mksh, it doesn't matter whether we use the 'function'
#   keyword or not when defining a function that uses local variables.

# * 'echo' and 'print' interprets some backslash characters by default
#   in PD KSH and mksh.  We use 'print -r' instead.  It also musn't be
#   confused with how single quote strings are stored.

# * Sometimes in a function declared with the 'function' keyword, Ksh93
#   keeps a variable local even though it wasn't declared with
#   'typeset'.  The changes on the variable does not reflect on the
#   calling function if the calling function declares the variable as
#   local with 'typeset'.

# * Declaring functions in bourne-shell format is intuitively more
#   efficient for PD KSH and mksh since it doesn't touch $0 and doesn't
#   store OPTIND and shell options for local scoping.

# * PD KSH's 'set -A' doesn't seem to work well with local variables,
#   but it turns out we don't need it since all variants of ksh resets
#   local variables to empty value.  This means we don't need to create
#   another version of getcleanpath for PD KSH.

# ----------------------------------------------------------------------
