#!/usr/bin/env bash


# ----------------------------------------------------------------------

# loader-extended.bash
#
# This script implements Shell Script Loader Extended for all versions
# of bash starting 2.04.
#
# The script works faster with associative arrays.  To use associative
# arrays, run the script with bash 4.0 or newer and include it globally
# (not use '.' or 'source' inside a function).
#
# Please see loader-extended.txt for more info on how to use this
# script.
#
# This script complies with the Requiring Specifications of
# Shell Script Loader Extended version 0X (RS0X).
#
# Version: 0X.1
#
# Author: konsolebox
# Copyright Free / Public Domain
# Aug. 30, 2009 (Last Updated 2011/04/08)

# Limitations of Shell Script Loader with integers and associative
# arrays:
#
# With versions of bash earlier than 4.2, a variable can't be declared
# global with the use of 'typeset' and 'declare' builtins when inside a
# function.  With Shell Script Loader, shell scripts are always loaded
# inside functions so variables that can only be declared using the said
# builtin commands cannot be declared global.  These kinds of variables
# that cannot be declared global are the newer types like associative
# arrays and integers.  Unlike Zsh, we can add '-g' as an option to
# 'typeset' or 'declare' to declare global variables but we can't do
# that in bash.
#
# For example, if we do something like
#
# > include file.sh
#
# Where the contents of file.sh is
#
# > declare -A associative_array
# > declare -i integer
#
# After include() ends, the variables automatically gets lost since
# variables are only local and not global if declare or typeset is used
# inside a function and we know that include() is a function.
#
# However it's safe to declare other types of variables like indexed
# arrays in simpler way.
#
# For example:
#
# > SIMPLEVAR=''
# > ARRAYVAR=()
#
# These declarations are even just optional.
#
# Note: These conditions do not apply if you only plan to run the code
# in compiled form since you no longer have to use the functions.  For
# more info about compilation, please see the available compilers of
# Shell Script Loader.

# ----------------------------------------------------------------------


if [ "$LOADER_ACTIVE" = true ]; then
	echo "loader: loader cannot be loaded twice."
	exit 1
fi
if [ -z "$BASH_VERSION" ]; then
	echo "loader: bash is needed to run this script."
	exit 1
fi
case "$BASH" in
sh|*/sh)
	echo "loader: this script doesn't work if bash is running sh-emulation mode."
	exit 1
	;;
esac
if ! [ "$BASH_VERSINFO" -ge 3 -o "$BASH_VERSION" '>' 2.03 ]; then
	echo "loader: this script is only compatible with versions of bash not earlier than 2.04."
	exit 1
fi
if ! declare -a LOADER_TEST0; then
	echo "loader: it seems that this build of bash does not include support for arrays."
	exit 1
fi
unset LOADER_TEST0


#### PUBLIC VARIABLES ####

LOADER_ACTIVE=true
LOADER_RS=0X
LOADER_VERSION=0X.1


#### PRIVATE VARIABLES ####

LOADER_ARGS=()
LOADER_CS=()
LOADER_CS_I=0
LOADER_EXPR=''
LOADER_FILEEXPR=''
LOADER_LIST=()
LOADER_PATHS=()
LOADER_PLAIN=''
LOADER_R=0
LOADER_REGEXPREFIX=''
LOADER_TESTOPT=''

if [[ BASH_VERSINFO -ge 5 || (BASH_VERSINFO -eq 4 && BASH_VERSINFO[1] -ge 2) ]]; then
	declare -g -A LOADER_FLAGS=()
	declare -g -A LOADER_PATHS_FLAGS=()
	LOADER_USEAARRAYS=true
elif [[ BASH_VERSINFO -eq 4 ]] && declare -A LOADER_TEST1 &>/dev/null && ! local LOADER_TEST2 &>/dev/null; then
	declare -A LOADER_FLAGS=()
	declare -A LOADER_PATHS_FLAGS=()
	LOADER_USEAARRAYS=true
else
	LOADER_USEAARRAYS=false
fi


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

			loader_flag_ "$1"

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

		loader_flagged "$__" && \
			return

		if [[ -f $__ ]]; then
			[[ -r $__ ]] || loader_fail "file not readable: $__" include "$@"

			shift
			loader_load "$@"

			return
		fi
		;;
	*)
		loader_flagged "$1" && \
			return

		for __ in "${LOADER_PATHS[@]}"; do
			loader_getabspath "$__/$1"

			if loader_flagged "$__"; then
				loader_flag_ "$1"

				return
			elif [[ -f $__ ]]; then
				[[ -r $__ ]] || loader_fail "found file not readable: $__" include "$@"

				loader_flag_ "$1"

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
				loader_flag_ "$1"

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

				loader_flag_ "$1"

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

					loader_load "${@:LOADER_OFFSET}"
				done

				LOADER_LIST=()

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
						loader_flag_ "$LOADER_SUBPREFIX$__"

						__=$LOADER_ABSPREFIX$__

						[[ -r $__ ]] || loader_fail "found file not readable: $__" loadx "$@"

						loader_load "${@:LOADER_OFFSET}"
					done

					LOADER_LIST=()

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
		case "$1" in
		'')
			loader_fail "file expression cannot be null." includex "$@"
			;;
		/*|./*|../*)
			loader_getabspath "$1"

			loader_flagged "$__" && \
				return

			if [[ -f $__ ]]; then
				[[ -r $__ ]] || loader_fail "file not readable: $__" includex "$@"

				shift
				loader_load "$@"

				return
			fi
			;;
		*)
			loader_flagged "$1" && \
				return

			for __ in "${LOADER_PATHS[@]}"; do
				loader_getabspath "$__/$1"

				if loader_flagged "$__"; then
					loader_flag_ "$1"

					return
				elif [[ -f $__ ]]; then
					[[ -r $__ ]] || loader_fail "found file not readable: $__" includex "$@"

					loader_flag_ "$1"

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

					loader_flagged "$__" && \
						continue

					[[ -r $__ ]] || loader_fail "found file not readable: $__" includex "$@"

					loader_load "${@:LOADER_OFFSET}"
				done

				LOADER_LIST=()

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
						loader_flagged "$LOADER_ABSPREFIX$__" && \
							continue

						loader_flag_ "$LOADER_SUBPREFIX$__"

						__=$LOADER_ABSPREFIX$__

						[[ -r $__ ]] || loader_fail "found file not readable: $__" includex "$@"

						loader_load "${@:LOADER_OFFSET}"
					done

					LOADER_LIST=()

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
					loader_flag_ "$1"

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

					( loader_load "${@:LOADER_OFFSET}"; ) || LOADER_R=1
				done

				LOADER_LIST=()

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
						[[ -r $LOADER_ABSPREFIX$__ ]] || loader_fail "found file not readable: $LOADER_ABSPREFIX$__" callx "$@"

						(
							loader_flag_ "$LOADER_SUBPREFIX$__"

							__=$LOADER_ABSPREFIX$__

							loader_load "${@:LOADER_OFFSET}"
						) || LOADER_R=1
					done

					LOADER_LIST=()

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
		loader_addpath_ "$__"
	done
}

function loader_flag {
	[[ $# -eq 1 ]] || loader_fail "function requires a single argument." loader_flag
	loader_getabspath "$1"
	loader_flag_ "$__"
}

function loader_reset {
	if [[ $# -eq 0 ]]; then
		loader_resetflags
		loader_resetpaths
	elif [[ $1 = flags ]]; then
		loader_resetflags
	elif [[ $1 = paths ]]; then
		loader_resetpaths
	else
		loader_fail "invalid argument: $1" loader_reset "$@"
	fi
}

function loader_finish {
	LOADER_ACTIVE=false

	loader_unsetvars

	unset \
		load \
		include \
		call \
		loadx \
		includex \
		callx \
		loader_addpath \
		loader_addpath_ \
		loader_fail \
		loader_finish \
		loader_flag \
		loader_flag_ \
		loader_flagged \
		loader_getabspath \
		loader_getabspath_ \
		loader_list \
		loader_load \
		loader_load_ \
		loader_reset \
		loader_resetflags \
		loader_resetpaths \
		loader_unsetvars \
		LOADER_ARGS \
		LOADER_CS \
		LOADER_CS_I \
		LOADER_EXPR \
		LOADER_FILEEXPR \
		LOADER_LIST \
		LOADER_PATHS \
		LOADER_PLAIN \
		LOADER_R \
		LOADER_REGEXPREFIX \
		LOADER_TESTOPT
}


#### PRIVATE FUNCTIONS ####

function loader_load {
	loader_flag_ "$__"

	LOADER_CS[LOADER_CS_I++]=$__

	loader_load_ "$@"

	__=$?

	unset LOADER_CS\[--LOADER_CS_I\]

	return "$__"
}

function loader_load_ {
	. "$__"
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

function loader_fail {
	local MESSAGE=$1 FUNC=$2 MAIN A I
	shift 2

	if [[ -n $0 && ! "${0##*/}" = "${BASH##*/}" ]]; then
		MAIN=$0
	else
		MAIN='(main)'
	fi

	{
		echo "loader: ${FUNC}(): ${MESSAGE}"
		echo

		echo "  current scope:"
		if [[ LOADER_CS_I -gt 0 ]]; then
			echo "    ${LOADER_CS[LOADER_CS_I - 1]}"
		else
			echo "    $MAIN"
		fi
		echo

		if [[ $# -gt 0 ]]; then
			echo "  command:"
			echo -n "    $FUNC"
			for A; do
				echo -n " \"$A\""
			done
			echo
			echo
		fi

		if [[ LOADER_CS_I -gt 0 ]]; then
			echo "  call stack:"
			echo "    $MAIN"
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


#### VERSION DEPENDENT FUNCTIONS AND VARIABLES ####

if [[ $LOADER_USEAARRAYS = true ]]; then
	function loader_addpath_ {
		if [[ -z ${LOADER_PATHS_FLAGS[$1]} ]]; then
			LOADER_PATHS[${#LOADER_PATHS[@]}]=$1
			LOADER_PATHS_FLAGS[$1]=.
		fi
	}

	function loader_flag_ {
		LOADER_FLAGS[$1]=.
	}

	function loader_flagged {
		[[ -n ${LOADER_FLAGS[$1]} ]]
	}

	function loader_resetflags {
		LOADER_FLAGS=()
	}

	function loader_resetpaths {
		LOADER_PATHS=()
		LOADER_PATHS_FLAGS=()
	}

	function loader_unsetvars {
		unset LOADER_FLAGS LOADER_PATHS_FLAGS
	}
else
	function loader_addpath_ {
		for __ in "${LOADER_PATHS[@]}"; do
			[[ $1 = "$__" ]] && \
				return
		done

		LOADER_PATHS[${#LOADER_PATHS[@]}]=$1
	}

	function loader_flag_ {
		local V
		V=${1//./_dt_}
		V=${V// /_sp_}
		V=${V//\//_sl_}
		V=LOADER_FLAGS_${V//[^[:alnum:]_]/_ot_}
		eval "$V=."
	}

	function loader_flagged {
		local V
		V=${1//./_dt_}
		V=${V// /_sp_}
		V=${V//\//_sl_}
		V=LOADER_FLAGS_${V//[^[:alnum:]_]/_ot_}
		[[ -n ${!V} ]]
	}

	function loader_resetflags {
		local IFS=' '
		unset ${!LOADER_FLAGS_*}
	}

	function loader_resetpaths {
		LOADER_PATHS=()
	}

	function loader_unsetvars {
		loader_resetflags
	}
fi

if [[ BASH_VERSINFO -ge 3 ]]; then
	eval "
		function loader_getabspath_ {
			local -a T1 T2
			local -i I=0
			local IFS=/ A

			case \"\$1\" in
			/*)
				read -r -a T1 <<< \"\$1\"
				;;
			*)
				read -r -a T1 <<< \"/\$PWD/\$1\"
				;;
			esac

			T2=()

			for A in \"\${T1[@]}\"; do
				case \"\$A\" in
				..)
					[[ I -ne 0 ]] && unset T2\\[--I\\]
					continue
					;;
				.|'')
					continue
					;;
				esac

				T2[I++]=\$A
			done

			case \"\$1\" in
			*/)
				[[ I -ne 0 ]] && __=\"/\${T2[*]}/\" || __=/
				;;
			*)
				[[ I -ne 0 ]] && __=\"/\${T2[*]}\" || __=/.
				;;
			esac
		}
	"
elif [[ $BASH_VERSION = 2.05b ]]; then
	eval "
		function loader_getabspath_ {
			local -a T=()
			local -i I=0
			local IFS=/ A

			case \"\$1\" in
			/*)
				__=\$1
				;;
			*)
				__=/\$PWD/\$1
				;;
			esac

			while read -r -d / A; do
				case \"\$A\" in
				..)
					[[ I -ne 0 ]] && unset T\\[--I\\]
					continue
					;;
				.|'')
					continue
					;;
				esac

				T[I++]=\$A
			done <<< \"\$__/\"

			case \"\$1\" in
			*/)
				[[ I -ne 0 ]] && __=\"/\${T[*]}/\" || __=/
				;;
			*)
				[[ I -ne 0 ]] && __=\"/\${T[*]}\" || __=/.
				;;
			esac
		}
	"
else
	eval "
		function loader_getabspath_ {
			local -a T=()
			local -i I=0
			local IFS=/ A

			case \"\$1\" in
			/*)
				__=\$1
				;;
			*)
				__=/\$PWD/\$1
				;;
			esac

			while read -r -d / A; do
				case \"\$A\" in
				..)
					[[ I -ne 0 ]] && unset T\\[--I\\]
					continue
					;;
				.|'')
					continue
					;;
				esac

				T[I++]=\$A
			done << .
\$__/
.

			case \"\$1\" in
			*/)
				[[ I -ne 0 ]] && __=\"/\${T[*]}/\" || __=/
				;;
			*)
				[[ I -ne 0 ]] && __=\"/\${T[*]}\" || __=/.
				;;
			esac
		}
	"
fi

if [[ $BASH_VERSINFO -ge 4 ]]; then
	function loader_list {
		[[ -r $1 ]] || \
			loader_fail "directory not readable or searchable: $1" loader_list "$@"

		pushd "$1" >/dev/null || \
			loader_fail "failed to access directory: $1" loader_list "$@"

		local -i R=1

		if
			readarray -t LOADER_LIST \
				< <(exec find -maxdepth 1 -xtype f "$LOADER_TESTOPT" "${LOADER_REGEXPREFIX}${LOADER_FILEEXPR}" -printf %f\\n)
		then
			LOADER_ABSPREFIX=${PWD%/}/

			R=0
		fi

		popd >/dev/null || \
			loader_fail "failed to change back to previous directory." loader_list "$@"

		return "$R"
	}
else
	function loader_list {
		[[ -r $1 ]] || \
			loader_fail "directory not readable or searchable: $1" loader_list "$@"

		pushd "$1" >/dev/null || \
			loader_fail "failed to access directory: $1" loader_list "$@"

		local -i R=1 I=1

		{
			if read -r __; then
				LOADER_LIST=("$__")

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
fi

unset LOADER_TEST1 LOADER_TEST2 LOADER_USEAARRAYS


# ----------------------------------------------------------------------

# * Using 'set -- $VAR' to split strings inside variables will sometimes
#   yield different strings if one of the strings contain globs
#   characters like *, ? and the brackets [ and ] that are also valid
#   characters in filenames.

# * Using 'read -a' to split strings to arrays yields elements
#   that contain invalid characters when a null token is found.
#   (bash versions < 3.0)

# ----------------------------------------------------------------------
