#!/usr/bin/env zsh

# ----------------------------------------------------------------------

# loader-extended.zsh
#
# This script implements Shell Script Loader Extended for all versions
# of Zsh not earlier than 4.2.0.
#
# Please see loader-extended.txt for more info on how to use this
# script.
#
# This script complies with the Requiring Specifications of
# Shell Script Loader Extended version 0X (RS0X).
#
# Version: 0X.2
#
# Author: konsolebox
# Copyright Free / Public Domain
# Aug. 30, 2009 (Last Updated 2016/06/28)

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
# functionally compatible with versions 4.0.* and 4.1.*, but these
# earlier versions of Zsh have limited execution stack (job tables) that
# are sometimes configured by default at small sizes and are also not
# expandable unlike in 4.2.* and newer, so I thought that it's better to
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
	echo "loader: loader cannot be loaded twice."
	exit 1
fi
if [ -z "$ZSH_VERSION" ]; then
	echo "loader: zsh is needed to run this script."
	exit 1
fi
if ! ( eval "set -- ${ZSH_VERSION//./ }"; [ "$1" -gt 4 ] || [ "$1" -eq 4 -a "$2" -ge 2 ]; exit "$?" ); then
	echo "loader: only versions of zsh not earlier than 4.2.0 can work properly with this script."
	exit 1
fi
if [ "$ZSH_NAME" = sh -o "$ZSH_NAME" = ksh ]; then
	echo "loader: this script doesn't work if zsh is running in sh or ksh emulation mode."
	exit 1
fi

#### PUBLIC VARIABLES ####

typeset -g LOADER_ACTIVE=true
typeset -g LOADER_RS=0X
typeset -g LOADER_VERSION=0X.2

#### PRIVATE VARIABLES ####

typeset -g -a LOADER_ARGS
typeset -g -a LOADER_CS
typeset -g -i LOADER_CS_I=0
typeset -g    LOADER_EXPR
typeset -g    LOADER_FILE_EXPR
typeset -g -A LOADER_FLAGS
typeset -g -a LOADER_LIST
typeset -g -a LOADER_PATHS
typeset -g -A LOADER_PATHS_FLAGS
typeset -g -i LOADER_R
typeset -g    LOADER_REGEX_PREFIX
typeset -g    LOADER_TEST_OPT

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
				return
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

function loadx {
	[[ $# -eq 0 ]] && loader_fail "Function called with no argument." loadx

	case $1 in
	*[?*]*)
		LOADER_EXPR=$1
		LOADER_TEST_OPT=-name
		LOADER_REGEX_PREFIX=
		local LOADER_OFFSET=2
		;;
	-name|-iname)
		LOADER_EXPR=$2
		LOADER_TEST_OPT=$1
		LOADER_REGEX_PREFIX=
		local LOADER_OFFSET=3
		;;
	-regex|-iregex)
		LOADER_EXPR=$2
		LOADER_TEST_OPT=$1
		LOADER_REGEX_PREFIX=\\./
		local LOADER_OFFSET=3
		;;
	'')
		loader_fail "File expression cannot be null." loadx "$@"
		;;
	/*|./*|../*)
		if [[ -f $1 ]]; then
			loader_getcleanpath "$1"
			[[ -r $__ ]] || loader_fail "File not readable: $__" loadx "$@"
			loader_load "$@[2,-1]"
			__=$?
			[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
			return "$__"
		fi

		loader_fail "File not found: $1" loadx "$@"
		;;
	*)
		for __ in "${LOADER_PATHS[@]}"; do
			[[ -f $__/$1 ]] || continue
			loader_getcleanpath "$__/$1"
			[[ -r $__ ]] || loader_fail "Found file not readable: $__" loadx "$@"
			LOADER_FLAGS[$1]=.
			loader_load "$@[2,-1]"
			__=$?
			[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
			return "$__"
		done

		loader_fail "File not found: $1" loadx "$@"
		;;
	esac

	local LOADER_ABS_PREFIX LOADER_SUBPREFIX

	case $LOADER_EXPR in
	'')
		loader_fail "File expression cannot be null." loadx "$@"
		;;
	*/*)
		LOADER_FILE_EXPR=${LOADER_EXPR##*/}
		LOADER_SUBPREFIX=${LOADER_EXPR%/*}/
		[[ -z $LOADER_FILE_EXPR ]] && loader_fail "Expression does not represent files: $LOADER_EXPR" loadx "$@"
		;;
	*)
		LOADER_FILE_EXPR=$LOADER_EXPR
		LOADER_SUBPREFIX=
		;;
	esac

	case $LOADER_SUBPREFIX in
	*[*?]*)
		loader_fail "Expressions for directories are not supported: $LOADER_SUBPREFIX" loadx "$@"
		;;
	/*|./*|../*)
		[[ -d $LOADER_SUBPREFIX ]] || loader_fail "Directory not found: $LOADER_SUBPREFIX" loadx "$@"

		if loader_list "$LOADER_SUBPREFIX"; then
			LOADER_R=0

			for __ in "${LOADER_LIST[@]}"; do
				__=$LOADER_ABS_PREFIX$__
				[[ -r $__ ]] || loader_fail "Found file not readable: $__" loadx "$@"
				loader_load "${@[LOADER_OFFSET,-1]}" || LOADER_R=1
				[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
			done

			set -A LOADER_LIST
			return "$LOADER_R"
		fi
		;;
	*)
		for __ in "${LOADER_PATHS[@]}"; do
			__=$__/$LOADER_SUBPREFIX
			[[ -d $__ ]] || continue

			if loader_list "$__"; then
				LOADER_R=0

				for __ in "${LOADER_LIST[@]}"; do
					LOADER_FLAGS[$LOADER_SUBPREFIX$__]=.
					__=$LOADER_ABS_PREFIX$__
					[[ -r $__ ]] || loader_fail "Found file not readable: $__" loadx "$@"
					loader_load "${@[LOADER_OFFSET,-1]}" || LOADER_R=1
					[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
				done

				set -A LOADER_LIST
				return "$LOADER_R"
			fi
		done
		;;
	esac

	loader_fail "No file was found with expression: $LOADER_EXPR" loadx "$@"
}

function includex {
	[[ $# -eq 0 ]] && loader_fail "Function called with no argument." includex

	case $1 in
	*[?*]*)
		LOADER_EXPR=$1
		LOADER_TEST_OPT=-name
		LOADER_REGEX_PREFIX=
		local LOADER_OFFSET=2
		;;
	-name|-iname)
		LOADER_EXPR=$2
		LOADER_TEST_OPT=$1
		LOADER_REGEX_PREFIX=
		local LOADER_OFFSET=3
		;;
	-regex|-iregex)
		LOADER_EXPR=$2
		LOADER_TEST_OPT=$1
		LOADER_REGEX_PREFIX=\\./
		local LOADER_OFFSET=3
		;;
	'')
		loader_fail "File expression cannot be null." includex "$@"
		;;
	/*|./*|../*)
		loader_getcleanpath "$1"
		[[ -n ${LOADER_FLAGS[$__]} ]] && return

		if [[ -f $__ ]]; then
			[[ -r $__ ]] || loader_fail "File not readable: $__" includex "$@"
			loader_load "$@[2,-1]"
			__=$?
			[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
			return "$__"
		fi

		loader_fail "File not found: $1" includex "$@"
		;;
	*)
		[[ -n ${LOADER_FLAGS[$1]} ]] && return

		for __ in "${LOADER_PATHS[@]}"; do
			loader_getcleanpath "$__/$1"

			if [[ -n ${LOADER_FLAGS[$__]} ]]; then
				LOADER_FLAGS[$1]=.
				return
			elif [[ -f $__ ]]; then
				[[ -r $__ ]] || loader_fail "Found file not readable: $__" includex "$@"
				LOADER_FLAGS[$1]=.
				loader_load "$@[2,-1]"
				__=$?
				[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
				return "$__"
			fi
		done

		loader_fail "File not found: $1" includex "$@"
		;;
	esac

	local LOADER_ABS_PREFIX LOADER_SUBPREFIX

	case $LOADER_EXPR in
	'')
		loader_fail "File expression cannot be null." includex "$@"
		;;
	*/*)
		LOADER_FILE_EXPR=${LOADER_EXPR##*/}
		LOADER_SUBPREFIX=${LOADER_EXPR%/*}/
		[[ -z $LOADER_FILE_EXPR ]] && loader_fail "Expression does not represent files: $LOADER_EXPR" includex "$@"
		;;
	*)
		LOADER_FILE_EXPR=$LOADER_EXPR
		LOADER_SUBPREFIX=
		;;
	esac

	case $LOADER_SUBPREFIX in
	*[*?]*)
		loader_fail "Expressions for directories are not supported: $LOADER_SUBPREFIX" includex "$@"
		;;
	/*|./*|../*)
		[[ -d $LOADER_SUBPREFIX ]] || loader_fail "Directory not found: $LOADER_SUBPREFIX" includex "$@"

		if loader_list "$LOADER_SUBPREFIX"; then
			LOADER_R=0

			for __ in "${LOADER_LIST[@]}"; do
				__=$LOADER_ABS_PREFIX$__
				[[ -n ${LOADER_FLAGS[$__]} ]] && continue
				[[ -r $__ ]] || loader_fail "Found file not readable: $__" includex "$@"
				loader_load "${@[LOADER_OFFSET,-1]}" || LOADER_R=1
				[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
			done

			set -A LOADER_LIST
			return "$LOADER_R"
		fi
		;;
	*)
		for __ in "${LOADER_PATHS[@]}"; do
			__=$__/$LOADER_SUBPREFIX
			[[ -d $__ ]] || continue

			if loader_list "$__"; then
				LOADER_R=0

				for __ in "${LOADER_LIST[@]}"; do
					[[ -n ${LOADER_FLAGS[$LOADER_ABS_PREFIX$__]} ]] && continue
					LOADER_FLAGS[$LOADER_SUBPREFIX$__]=.
					__=$LOADER_ABS_PREFIX$__
					[[ -r $__ ]] || loader_fail "Found file not readable: $__" includex "$@"
					loader_load "${@[LOADER_OFFSET,-1]}" || LOADER_R=1
					[[ $LOADER_ACTIVE == true ]] && LOADER_CS[LOADER_CS_I--]=()
				done

				set -A LOADER_LIST
				return "$LOADER_R"
			fi
		done
		;;
	esac

	loader_fail "No file was found with expression: $LOADER_EXPR" includex "$@"
}

function callx {
	[[ $# -eq 0 ]] && loader_fail "Function called with no argument." callx

	case $1 in
	*[?*]*)
		LOADER_EXPR=$1
		LOADER_TEST_OPT=-name
		LOADER_REGEX_PREFIX=
		local LOADER_OFFSET=2
		;;
	-name|-iname)
		LOADER_EXPR=$2
		LOADER_TEST_OPT=$1
		LOADER_REGEX_PREFIX=
		local LOADER_OFFSET=3
		;;
	-regex|-iregex)
		LOADER_EXPR=$2
		LOADER_TEST_OPT=$1
		LOADER_REGEX_PREFIX=\\./
		local LOADER_OFFSET=3
		;;
	'')
		loader_fail "File expression cannot be null." callx "$@"
		;;
	/*|./*|../*)
		if [[ -f $1 ]]; then
			loader_getcleanpath "$1"
			[[ -r $__ ]] || loader_fail "File not readable: $__" callx "$@"
			( loader_load "$@[2,-1]" )
			return
		fi

		loader_fail "File not found: $1" callx "$@"
		;;
	*)
		for __ in "${LOADER_PATHS[@]}"; do
			[[ -f $__/$1 ]] || continue
			loader_getcleanpath "$__/$1"
			[[ -r $__ ]] || loader_fail "Found file not readable: $__" callx "$@"

			(
				LOADER_FLAGS[$1]=.
				loader_load "$@[2,-1]"
			)

			return
		done

		loader_fail "File not found: $1" callx "$@"
		;;
	esac

	local LOADER_ABS_PREFIX LOADER_SUBPREFIX

	case $LOADER_EXPR in
	'')
		loader_fail "File expression cannot be null." callx "$@"
		;;
	*/*)
		LOADER_FILE_EXPR=${LOADER_EXPR##*/}
		LOADER_SUBPREFIX=${LOADER_EXPR%/*}/
		[[ -z $LOADER_FILE_EXPR ]] && loader_fail "Expression does not represent files: $LOADER_EXPR" callx "$@"
		;;
	*)
		LOADER_FILE_EXPR=$LOADER_EXPR
		LOADER_SUBPREFIX=
		;;
	esac

	case $LOADER_SUBPREFIX in
	*[*?]*)
		loader_fail "Expressions for directories are not supported: $LOADER_SUBPREFIX" callx "$@"
		;;
	/*|./*|../*)
		[[ -d $LOADER_SUBPREFIX ]] || loader_fail "Directory not found: $LOADER_SUBPREFIX" callx "$@"

		if loader_list "$LOADER_SUBPREFIX"; then
			LOADER_R=0

			for __ in "${LOADER_LIST[@]}"; do
				__=$LOADER_ABS_PREFIX$__
				[[ -r $__ ]] || loader_fail "Found file not readable: $__" callx "$@"
				( loader_load "${@[LOADER_OFFSET,-1]}" ) || LOADER_R=1
			done

			set -A LOADER_LIST
			return "$LOADER_R"
		fi
		;;
	*)
		for __ in "${LOADER_PATHS[@]}"; do
			__=$__/$LOADER_SUBPREFIX
			[[ -d $__ ]] || continue

			if loader_list "$__"; then
				LOADER_R=0

				for __ in "${LOADER_LIST[@]}"; do
					[[ -r $LOADER_ABS_PREFIX$__ ]] || loader_fail "Found file not readable: $LOADER_ABS_PREFIX$__" callx "$@"

					(
						LOADER_FLAGS[$LOADER_SUBPREFIX$__]=.
						__=$LOADER_ABS_PREFIX$__
						loader_load "${@[LOADER_OFFSET,-1]}"
					) || LOADER_R=1
				done

				set -A LOADER_LIST
				return "$LOADER_R"
			fi
		done
		;;
	esac

	loader_fail "No file was found with expression: $LOADER_EXPR" callx "$@"
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

	unset -v LOADER_ARGS LOADER_CS LOADER_CS_I LOADER_EXPR \
		LOADER_FILE_EXPR LOADER_FLAGS LOADER_LIST LOADER_PATHS \
		LOADER_PATHS_FLAGS LOADER_R LOADER_REGEX_PREFIX LOADER_TEST_OPT

	unset -f load include call loadx includex callx loader_addpath \
		loader_fail loader_finish loader_flag loader_getcleanpath \
		loader_list loader_load loader_reset
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

function loader_list {
	[[ -r $1 ]] || loader_fail "Directory not readable or searchable: $1" loader_list "$@"
	pushd "$1" >/dev/null || loader_fail "Failed to access directory: $1" loader_list "$@"
	local R=1 I=2

	if read -r __; then
		set -A LOADER_LIST "$__"

		while read -r __; do
			LOADER_LIST[I++]=$__
		done

		LOADER_ABS_PREFIX=${PWD%/}/
		R=0
	fi < <(exec find -maxdepth 1 -xtype f "$LOADER_TEST_OPT" "$LOADER_REGEX_PREFIX$LOADER_FILE_EXPR" -printf %f\\n)

	popd >/dev/null || loader_fail "Failed to change back to previous directory." loader_list "$@"
	return "$R"
}
