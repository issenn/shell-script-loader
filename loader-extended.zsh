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
# Version: 0X.1.2
#
# Author: konsolebox
# Copyright Free / Public Domain
# Aug. 30, 2009 (Last Updated 2016/06/22)

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
if ! ( eval "set -- ${ZSH_VERSION//./ }"; [ "$1" -gt 4 ] || [ "$1" -eq 4 -a "$2" -ge 2 ]; exit "$?"; ); then
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
typeset -g LOADER_VERSION=0X.1.2


#### PRIVATE VARIABLES ####

typeset -g -a LOADER_ARGS
typeset -g -a LOADER_CS
typeset -g -i LOADER_CS_I=0
typeset -g    LOADER_EXPR
typeset -g    LOADER_FILEEXPR
typeset -g -A LOADER_FLAGS
typeset -g -a LOADER_LIST
typeset -g -a LOADER_PATHS
typeset -g -A LOADER_PATHS_FLAGS
typeset -g    LOADER_PLAIN
typeset -g -i LOADER_R
typeset -g    LOADER_REGEXPREFIX
typeset -g    LOADER_TESTOPT


#### PUBLIC FUNCTIONS ####

function load {
	[[ $# -eq 0 ]] && loader_fail "function called with no argument." load

	case "$1" in
	'')
		loader_fail "file expression cannot be null." load "$@"
		;;
	/*|./*|../*)
		if [[ -f $1 ]]; then
			loader_getabspath "$1"

			[[ -r $__ ]] || loader_fail "file not readable: $__" load "$@"

			shift
			loader_load "$@"

			return
		fi
		;;
	*)
		for __ in "${LOADER_PATHS[@]}"; do
			[[ -f $__/$1 ]] || continue

			loader_getabspath "$__/$1"

			[[ -r $__ ]] || loader_fail "found file not readable: $__" load "$@"

			LOADER_FLAGS[$1]=.

			shift
			loader_load "$@"

			return
		done
		;;
	esac

	loader_fail "file not found: $1" load "$@"
}

function include {
	[[ $# -eq 0 ]] && loader_fail "function called with no argument." include

	case "$1" in
	'')
		loader_fail "file expression cannot be null." include "$@"
		;;
	/*|./*|../*)
		loader_getabspath "$1"

		[[ -n ${LOADER_FLAGS[$__]} ]] && \
			return

		if [[ -f $__ ]]; then
			[[ -r $__ ]] || loader_fail "file not readable: $__" include "$@"

			shift
			loader_load "$@"

			return
		fi
		;;
	*)
		[[ -n ${LOADER_FLAGS[$1]} ]] && \
			return

		for __ in "${LOADER_PATHS[@]}"; do
			loader_getabspath "$__/$1"

			if [[ -n ${LOADER_FLAGS[$__]} ]]; then
				LOADER_FLAGS[$1]=.

				return
			elif [[ -f $__ ]]; then
				[[ -r $__ ]] || loader_fail "found file not readable: $__" include "$@"

				LOADER_FLAGS[$1]=.

				shift
				loader_load "$@"

				return
			fi
		done
		;;
	esac

	loader_fail "file not found: $1" include "$@"
}

function call {
	[[ $# -eq 0 ]] && loader_fail "function called with no argument." call

	case "$1" in
	'')
		loader_fail "file expression cannot be null." call "$@"
		;;
	/*|./*|../*)
		if [[ -f $1 ]]; then
			loader_getabspath "$1"

			[[ -r $__ ]] || loader_fail "file not readable: $__" call "$@"

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

			loader_getabspath "$__/$1"

			[[ -r $__ ]] || loader_fail "found file not readable: $__" call "$@"

			(
				LOADER_FLAGS[$1]=.

				shift
				loader_load "$@"
			)

			return
		done
		;;
	esac

	loader_fail "file not found: $1" call "$@"
}

function loadx {
	[[ $# -eq 0 ]] && loader_fail "function called with no argument." loadx

	case "$1" in
	*[?*]*)
		LOADER_EXPR=$1
		LOADER_PLAIN=false
		LOADER_TESTOPT=-name
		LOADER_REGEXPREFIX=
		local -i LOADER_OFFSET=2
		;;
	-name|-iname)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=
		local -i LOADER_OFFSET=3
		;;
	-regex|-iregex)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=\\./
		local -i LOADER_OFFSET=3
		;;
	*)
		LOADER_PLAIN=true
		;;
	esac

	if [[ $LOADER_PLAIN = true ]]; then
		[[ $# -eq 0 ]] && loader_fail "function called with no argument." loadx

		case "$1" in
		'')
			loader_fail "file expression cannot be null." loadx "$@"
			;;
		/*|./*|../*)
			if [[ -f $1 ]]; then
				loader_getabspath "$1"

				[[ -r $__ ]] || loader_fail "file not readable: $__" loadx "$@"

				shift
				loader_load "$@"

				return
			fi
			;;
		*)
			for __ in "${LOADER_PATHS[@]}"; do
				[[ -f $__/$1 ]] || continue

				loader_getabspath "$__/$1"

				[[ -r $__ ]] || loader_fail "found file not readable: $__" loadx "$@"

				LOADER_FLAGS[$1]=.

				shift
				loader_load "$@"

				return
			done
			;;
		esac

		loader_fail "file not found: $1" loadx "$@"
	else
		local LOADER_ABSPREFIX LOADER_SUBPREFIX

		case "$LOADER_EXPR" in
		'')
			loader_fail "file expression cannot be null." loadx "$@"
			;;
		*/*)
			LOADER_FILEEXPR=${LOADER_EXPR##*/}
			LOADER_SUBPREFIX=${LOADER_EXPR%/*}/

			[[ -z $LOADER_FILEEXPR ]] && \
				loader_fail "expression does not represent files: $LOADER_EXPR" loadx "$@"
			;;
		*)
			LOADER_FILEEXPR=$LOADER_EXPR
			LOADER_SUBPREFIX=''
			;;
		esac

		case "$LOADER_SUBPREFIX" in
		*[*?]*)
			loader_fail "expressions for directories are not supported: $LOADER_SUBPREFIX" loadx "$@"
			;;
		/*|./*|../*)
			[[ -d $LOADER_SUBPREFIX ]] || \
				loader_fail "directory not found: $LOADER_SUBPREFIX" loadx "$@"

			if loader_list "$LOADER_SUBPREFIX"; then
				for __ in "${LOADER_LIST[@]}"; do
					__=$LOADER_ABSPREFIX$__

					[[ -r $__ ]] || loader_fail "found file not readable: $__" loadx "$@"

					loader_load "${@[LOADER_OFFSET,-1]}"
				done

				set -A LOADER_LIST

				return
			fi
			;;
		*)
			for __ in "${LOADER_PATHS[@]}"; do
				__=$__/$LOADER_SUBPREFIX

				[[ -d $__ ]] || \
					continue

				if loader_list "$__"; then
					for __ in "${LOADER_LIST[@]}"; do
						LOADER_FLAGS[$LOADER_SUBPREFIX$__]=.

						__=$LOADER_ABSPREFIX$__

						[[ -r $__ ]] || loader_fail "found file not readable: $__" loadx "$@"

						loader_load "${@[LOADER_OFFSET,-1]}"
					done

					set -A LOADER_LIST

					return
				fi
			done
			;;
		esac

		loader_fail "no file was found with expression: $LOADER_EXPR" loadx "$@"
	fi
}

function includex {
	[[ $# -eq 0 ]] && loader_fail "function called with no argument." includex

	case "$1" in
	*[?*]*)
		LOADER_EXPR=$1
		LOADER_PLAIN=false
		LOADER_TESTOPT=-name
		LOADER_REGEXPREFIX=
		local -i LOADER_OFFSET=2
		;;
	-name|-iname)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=
		local -i LOADER_OFFSET=3
		;;
	-regex|-iregex)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=\\./
		local -i LOADER_OFFSET=3
		;;
	*)
		LOADER_PLAIN=true
		;;
	esac

	if [[ $LOADER_PLAIN = true ]]; then
		[[ $# -eq 0 ]] && loader_fail "function called with no argument." includex

		case "$1" in
		'')
			loader_fail "file expression cannot be null." includex "$@"
			;;
		/*|./*|../*)
			loader_getabspath "$1"

			[[ -n ${LOADER_FLAGS[$__]} ]] && \
				return

			if [[ -f $__ ]]; then
				[[ -r $__ ]] || loader_fail "file not readable: $__" includex "$@"

				shift
				loader_load "$@"

				return
			fi
			;;
		*)
			[[ -n ${LOADER_FLAGS[$1]} ]] && \
				return

			for __ in "${LOADER_PATHS[@]}"; do
				loader_getabspath "$__/$1"

				if [[ -n ${LOADER_FLAGS[$__]} ]]; then
					LOADER_FLAGS[$1]=.

					return
				elif [[ -f $__ ]]; then
					[[ -r $__ ]] || loader_fail "found file not readable: $__" includex "$@"

					LOADER_FLAGS[$1]=.

					shift
					loader_load "$@"

					return
				fi
			done
			;;
		esac

		loader_fail "file not found: $1" includex "$@"
	else
		local LOADER_ABSPREFIX LOADER_SUBPREFIX

		case "$LOADER_EXPR" in
		'')
			loader_fail "file expression cannot be null." includex "$@"
			;;
		*/*)
			LOADER_FILEEXPR=${LOADER_EXPR##*/}
			LOADER_SUBPREFIX=${LOADER_EXPR%/*}/

			[[ -z $LOADER_FILEEXPR ]] && \
				loader_fail "expression does not represent files: $LOADER_EXPR" includex "$@"
			;;
		*)
			LOADER_FILEEXPR=$LOADER_EXPR
			LOADER_SUBPREFIX=''
			;;
		esac

		case "$LOADER_SUBPREFIX" in
		*[*?]*)
			loader_fail "expressions for directories are not supported: $LOADER_SUBPREFIX" includex "$@"
			;;
		/*|./*|../*)
			[[ -d $LOADER_SUBPREFIX ]] || \
				loader_fail "directory not found: $LOADER_SUBPREFIX" includex "$@"

			if loader_list "$LOADER_SUBPREFIX"; then
				for __ in "${LOADER_LIST[@]}"; do
					__=$LOADER_ABSPREFIX$__

					[[ -n ${LOADER_FLAGS[$__]} ]] && \
						continue

					[[ -r $__ ]] || loader_fail "found file not readable: $__" includex "$@"

					loader_load "${@[LOADER_OFFSET,-1]}"
				done

				set -A LOADER_LIST

				return
			fi
			;;
		*)
			for __ in "${LOADER_PATHS[@]}"; do
				__=$__/$LOADER_SUBPREFIX

				[[ -d $__ ]] || \
					continue

				if loader_list "$__"; then
					for __ in "${LOADER_LIST[@]}"; do
						[[ -n ${LOADER_FLAGS[$LOADER_ABSPREFIX$__]} ]] && \
							continue

						LOADER_FLAGS[$LOADER_SUBPREFIX$__]=.

						__=$LOADER_ABSPREFIX$__

						[[ -r $__ ]] || loader_fail "found file not readable: $__" includex "$@"

						loader_load "${@[LOADER_OFFSET,-1]}"
					done

					set -A LOADER_LIST

					return
				fi
			done
			;;
		esac

		loader_fail "no file was found with expression: $LOADER_EXPR" includex "$@"
	fi
}

function callx {
	[[ $# -eq 0 ]] && loader_fail "function called with no argument." callx

	case "$1" in
	*[?*]*)
		LOADER_EXPR=$1
		LOADER_PLAIN=false
		LOADER_TESTOPT=-name
		LOADER_REGEXPREFIX=
		local -i LOADER_OFFSET=2
		;;
	-name|-iname)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=
		local -i LOADER_OFFSET=3
		;;
	-regex|-iregex)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=\\./
		local -i LOADER_OFFSET=3
		;;
	*)
		LOADER_PLAIN=true
		;;
	esac

	if [[ $LOADER_PLAIN = true ]]; then
		[[ $# -eq 0 ]] && loader_fail "function callxed with no argument." callx

		case "$1" in
		'')
			loader_fail "file expression cannot be null." callx "$@"
			;;
		/*|./*|../*)
			if [[ -f $1 ]]; then
				loader_getabspath "$1"

				[[ -r $__ ]] || loader_fail "file not readable: $__" callx "$@"

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

				loader_getabspath "$__/$1"

				[[ -r $__ ]] || loader_fail "found file not readable: $__" callx "$@"

				(
					LOADER_FLAGS[$1]=.

					shift
					loader_load "$@"
				)

				return
			done
			;;
		esac

		loader_fail "file not found: $1" callx "$@"
	else
		local LOADER_ABSPREFIX LOADER_SUBPREFIX

		case "$LOADER_EXPR" in
		'')
			loader_fail "file expression cannot be null." callx "$@"
			;;
		*/*)
			LOADER_FILEEXPR=${LOADER_EXPR##*/}
			LOADER_SUBPREFIX=${LOADER_EXPR%/*}/

			[[ -z $LOADER_FILEEXPR ]] && \
				loader_fail "expression does not represent files: $LOADER_EXPR" callx "$@"
			;;
		*)
			LOADER_FILEEXPR=$LOADER_EXPR
			LOADER_SUBPREFIX=''
			;;
		esac

		case "$LOADER_SUBPREFIX" in
		*[*?]*)
			loader_fail "expressions for directories are not supported: $LOADER_SUBPREFIX" callx "$@"
			;;
		/*|./*|../*)
			[[ -d $LOADER_SUBPREFIX ]] || \
				loader_fail "directory not found: $LOADER_SUBPREFIX" callx "$@"

			if loader_list "$LOADER_SUBPREFIX"; then
				LOADER_R=0

				for __ in "${LOADER_LIST[@]}"; do
					__=$LOADER_ABSPREFIX$__

					[[ -r $__ ]] || loader_fail "found file not readable: $__" callx "$@"

					( loader_load "${@[LOADER_OFFSET,-1]}"; ) || LOADER_R=1
				done

				set -A LOADER_LIST

				return "$LOADER_R"
			fi
			;;
		*)
			for __ in "${LOADER_PATHS[@]}"; do
				__=$__/$LOADER_SUBPREFIX

				[[ -d $__ ]] || \
					continue

				if loader_list "$__"; then
					LOADER_R=0

					for __ in "${LOADER_LIST[@]}"; do
						[[ -r $LOADER_ABSPREFIX$__ ]] || \
							loader_fail "found file not readable: $LOADER_ABSPREFIX$__" callx "$@"

						(
							LOADER_FLAGS[$LOADER_SUBPREFIX$__]=.

							__=$LOADER_ABSPREFIX$__

							loader_load "${@[LOADER_OFFSET,-1]}"
						) || LOADER_R=1
					done

					set -A LOADER_LIST

					return "$LOADER_R"
				fi
			done
			;;
		esac

		loader_fail "no file was found with expression: $LOADER_EXPR" callx "$@"
	fi
}

function loader_addpath {
	for __ in "$@"; do
		[[ -d $__ ]] || loader_fail "directory not found: $__" loader_addpath "$@"
		[[ -x $__ ]] || loader_fail "directory not accessible: $__" loader_addpath "$@"
		[[ -r $__ ]] || loader_fail "directory not searchable: $__" loader_addpath "$@"

		loader_getabspath_ "$__/."

		if [[ -z ${LOADER_PATHS_FLAGS[$__]} ]]; then
			LOADER_PATHS[$(( ${#LOADER_PATHS[@]} + 1 ))]=$__
			LOADER_PATHS_FLAGS[$__]=.
		fi
	done
}

function loader_flag {
	[[ $# -eq 1 ]] || loader_fail "function requires a single argument." loader_flag "$@"
	loader_getabspath "$1"
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
		loader_fail "invalid argument: $1" loader_reset "$@"
	fi
}

function loader_finish {
	LOADER_ACTIVE=false

	unset \
		load \
		include \
		call \
		loadx \
		includex \
		callx \
		loader_addpath \
		loader_fail \
		loader_finish \
		loader_flag \
		loader_getabspath \
		loader_getabspath_ \
		loader_list \
		loader_load \
		loader_load_ \
		loader_reset \
		LOADER_ARGS \
		LOADER_CS \
		LOADER_CS_I \
		LOADER_EXPR \
		LOADER_FILEEXPR \
		LOADER_FLAGS \
		LOADER_LIST \
		LOADER_PATHS \
		LOADER_PATHS_FLAGS \
		LOADER_PLAIN \
		LOADER_R \
		LOADER_REGEXPREFIX \
		LOADER_TESTOPT
}


#### PRIVATE FUNCTIONS ####

function loader_load {
	LOADER_FLAGS[$__]=.

	LOADER_CS[++LOADER_CS_I]=$__

	loader_load_ "$@"

	__=$?
	[[ LOADER_CS_I -gt 0 ]] && LOADER_CS[LOADER_CS_I--]=()
	return "$__"
}

function loader_load_ {
	. "$__"
}

function loader_list {
	[[ -r $1 ]] || \
		loader_fail "directory not readable or searchable: $1" loader_list "$@"

	pushd "$1" >/dev/null || \
		loader_fail "failed to access directory: $1" loader_list "$@"

	local -i R=1 I=2

	{
		if read -r __; then
			set -A LOADER_LIST "$__"

			while read -r __; do
				LOADER_LIST[I++]=$__
			done

			LOADER_ABSPREFIX=${PWD%/}/

			R=0
		fi
	} < <(exec find -maxdepth 1 -xtype f "$LOADER_TESTOPT" "${LOADER_REGEXPREFIX}${LOADER_FILEEXPR}" -printf %f\\n)

	popd >/dev/null || \
		loader_fail "failed to change back to previous directory." loader_list "$@"

	return "$R"
}

function loader_getabspath {
	case "$1" in
	.|'')
		case "$PWD" in
		/)
			__=/.
			;;
		*)
			__=${PWD%/}
			;;
		esac
		;;
	..|../*|*/..|*/../*|./*|*/.|*/./*|*//*)
		loader_getabspath_ "$1"
		;;
	/*)
		__=$1
		;;
	*)
		__=${PWD%/}/$1
		;;
	esac
}

function loader_getabspath_ {
	local -a TOKENS; set -A TOKENS
	local -i I=0
	local IFS=/ T

	__=$1

	case "$1" in
	/*)
		set -- ${=1}
		;;
	*)
		set -- ${=PWD} ${=1}
		;;
	esac

	for T; do
		case "$T" in
		..)
			[[ I -ne 0 ]] && TOKENS[I--]=()
			continue
			;;
		.|'')
			continue
			;;
		esac

		TOKENS[++I]=$T
	done

	case "$__" in
	*/)
		[[ I -ne 0 ]] && __="/${TOKENS[*]}/" || __=/
		;;
	*)
		[[ I -ne 0 ]] && __="/${TOKENS[*]}" || __=/.
		;;
	esac
}

function loader_fail {
	local MESSAGE=$1 FUNC=$2 A I
	shift 2

	{
		echo "loader: ${FUNC}(): ${MESSAGE}"
		echo

		echo "  current scope:"
		if [[ LOADER_CS_I -gt 0 ]]; then
			echo "    ${LOADER_CS[LOADER_CS_I]}"
		else
			echo "    (main)"
		fi
		echo

		if [[ $# -gt 0 ]]; then
			echo "  command:"
			echo -n "    $FUNC"
			for A; do
				echo -n " $A"
			done
			echo
			echo
		fi

		if [[ LOADER_CS_I -gt 0 ]]; then
			echo "  call stack:"
			echo "    (main)"
			for A in "${LOADER_CS[@]}"; do
				echo "    -> $A"
			done
			echo
		fi

		echo "  search paths:"
		if [[ ${#LOADER_PATHS[@]} -gt 0 ]]; then
			for A in "${LOADER_PATHS[@]}"; do
				echo "    $A"
			done
		else
			echo "    (empty)"
		fi
		echo

		echo "  working directory:"
		echo "    $PWD"
		echo
	} >&2

	exit 1
}
