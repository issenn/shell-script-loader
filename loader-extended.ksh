#!/usr/bin/env ksh


# ----------------------------------------------------------------------

# loader-extended.ksh
#
# This script implements Shell Script Loader Extended for ksh (both the
# original (KornShell 93+) and the public domain (PD KSH) Korn shell.
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

# Limitations of Shell Script Loader in PD KSH:
#
# In PD KSH (not the Ksh 93+), typeset declarations inside functions
# always make variables visible only within the function therefore
# scripts that have typeset declarations that are meant to
# create global variables when called within a loader function like
# include() will only have visibility inside include().
#
# Array indices in PD KSH are currently limited to the range of 0
# through 1023 but this value is big enough for the list of search paths
# and for the call stack.

# ----------------------------------------------------------------------


if [ "$LOADER_ACTIVE" = true ]; then
	echo "loader: loader cannot be loaded twice."
	exit 1
fi
if [ -n "$KSH_VERSION" ]; then
	LOADER_KSH_VERSION=1
elif
	( eval 'test -n "${.sh.version}" && exit 10'; ) >/dev/null 2>&1
	[ "$?" -eq 10 ]
then
	LOADER_KSH_VERSION=0
elif
	[ -n "$ZSH_VERSION" ] && \
	[[ $ZSH_NAME = ksh ]] && \
	eval '[ "${ZSH_VERSION%%.*}" -ge 4 ]'
then
	LOADER_KSH_VERSION=0.Z
else
	echo "loader: ksh is needed to run this script."
	exit 1
fi


#### PUBLIC VARIABLES ####

LOADER_ACTIVE=true
LOADER_RS=0X
LOADER_VERSION=0X.1


#### PRIVATE VARIABLES ####

set -A LOADER_ARGS
set -A LOADER_CS
set -A LOADER_PATHS
LOADER_ABSPREFIX=''
LOADER_CS_I=0
LOADER_EXPR=''
LOADER_FILEEXPR=''
LOADER_OWD=''
LOADER_PLAIN=''
LOADER_R=0
LOADER_REGEXPREFIX=''
LOADER_SHIFTS=0
LOADER_SHIFTS_0=0
LOADER_SHIFTS_1=0
LOADER_SUBPREFIX=''
LOADER_TESTOPT=''


#### PUBLIC FUNCTIONS ####

load() {
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

include() {
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

call() {
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

loadx() {
	[[ $# -eq 0 ]] && loader_fail "function called with no argument." loadx

	case "$1" in
	*[?*]*)
		LOADER_EXPR=$1
		LOADER_PLAIN=false
		LOADER_TESTOPT=-name
		LOADER_REGEXPREFIX=
		LOADER_SHIFTS_0=3
		LOADER_SHIFTS_1=4
		;;
	-name|-iname)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=
		LOADER_SHIFTS_0=4
		LOADER_SHIFTS_1=5
		;;
	-regex|-iregex)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=\\./
		LOADER_SHIFTS_0=4
		LOADER_SHIFTS_1=5
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
				set -- "$LOADER_SHIFTS_0" "$LOADER_ABSPREFIX" "$@"

				for __ in "${LOADER_LIST[@]}"; do
					__=$2$__

					if [[ ! -r $__ ]]; then
						shift 2
						loader_fail "found file not readable: $__" loadx "$@"
					fi

					loader_load_s "$@"
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
					set -- "$LOADER_SHIFTS_1" "$LOADER_ABSPREFIX" "$LOADER_SUBPREFIX" "$@"

					for __ in "${LOADER_LIST[@]}"; do
						loader_flag_ "$3$__"

						__=$2$__

						if [[ ! -r $__ ]]; then
							shift 3
							loader_fail "found file not readable: $__" loadx "$@"
						fi

						loader_load_s "$@"
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

includex() {
	[[ $# -eq 0 ]] && loader_fail "function called with no argument." includex

	case "$1" in
	*[?*]*)
		LOADER_EXPR=$1
		LOADER_PLAIN=false
		LOADER_TESTOPT=-name
		LOADER_REGEXPREFIX=
		LOADER_SHIFTS_0=3
		LOADER_SHIFTS_1=4
		;;
	-name|-iname)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=
		LOADER_SHIFTS_0=4
		LOADER_SHIFTS_1=5
		;;
	-regex|-iregex)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=\\./
		LOADER_SHIFTS_0=4
		LOADER_SHIFTS_1=5
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
				set -- "$LOADER_SHIFTS_0" "$LOADER_ABSPREFIX" "$@"

				for __ in "${LOADER_LIST[@]}"; do
					__=$2$__

					loader_flagged "$__" && \
						continue

					if [[ ! -r $__ ]]; then
						shift 2
						loader_fail "found file not readable: $__" includex "$@"
					fi

					loader_load_s "$@"
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
					set -- "$LOADER_SHIFTS_1" "$LOADER_ABSPREFIX" "$LOADER_SUBPREFIX" "$@"

					for __ in "${LOADER_LIST[@]}"; do
						loader_flagged "$2$__" && \
							continue

						loader_flag_ "$3$__"

						__=$2$__

						if [[ ! -r $__ ]]; then
							shift 3
							loader_fail "found file not readable: $__" includex "$@"
						fi

						loader_load_s "$@"
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

callx() {
	[[ $# -eq 0 ]] && loader_fail "function called with no argument." callx

	case "$1" in
	*[?*]*)
		LOADER_EXPR=$1
		LOADER_PLAIN=false
		LOADER_TESTOPT=-name
		LOADER_REGEXPREFIX=
		LOADER_SHIFTS=1
		;;
	-name|-iname)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=
		LOADER_SHIFTS=2
		;;
	-regex|-iregex)
		LOADER_EXPR=$2
		LOADER_PLAIN=false
		LOADER_TESTOPT=$1
		LOADER_REGEXPREFIX=\\./
		LOADER_SHIFTS=2
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

					(
						shift "$LOADER_SHIFTS"

						loader_load "$@"
					) || LOADER_R=1
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
							loader_flag_ "$LOADER_SUBPREFIX$__"

							__=$LOADER_ABSPREFIX$__


							shift "$LOADER_SHIFTS"

							loader_load "$@"
						) || LOADER_R=1
					done

					set -A LOADER_LIST

					return "$LOADER_R"
				fi
			done
			;;
		esac

		loader_fail "no file was found with expression: $1" "callx" "$1" "$@"
	fi
}

loader_addpath() {
	for __ in "$@"; do
		[[ -d $__ ]] || loader_fail "directory not found: $__" loader_addpath "$@"
		[[ -x $__ ]] || loader_fail "directory not accessible: $__" loader_addpath "$@"
		[[ -r $__ ]] || loader_fail "directory not searchable: $__" loader_addpath "$@"
		loader_getabspath_ "$__/."
		loader_addpath_ "$__"
	done
}

loader_flag() {
	[[ $# -eq 1 ]] || loader_fail "function requires a single argument." loader_flag "$@"
	loader_getabspath "$1"
	loader_flag_ "$__"
}

loader_reset() {
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

loader_finish() {
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
		loader_fail \
		loader_flag \
		loader_flag_ \
		loader_flagged \
		loader_getabspath \
		loader_getabspath_ \
		loader_list \
		loader_load \
		loader_load_ \
		loader_load_s \
		loader_reset \
		loader_unsetvars \
        loader_finish \
		LOADER_ABSPREFIX \
		LOADER_ARGS \
		LOADER_CS \
		LOADER_CS_I \
		LOADER_EXPR \
		LOADER_FILEEXPR \
		LOADER_KSH_VERSION \
		LOADER_OWD \
		LOADER_PATHS \
		LOADER_PLAIN \
		LOADER_R \
		LOADER_REGEXPREFIX \
		LOADER_SHIFTS \
		LOADER_SHIFTS_0 \
		LOADER_SHIFTS_1 \
		LOADER_SUBPREFIX \
		LOADER_TESTOPT
}


#### PRIVATE FUNCTIONS ####

loader_addpath_() {
	for __ in "${LOADER_PATHS[@]}"; do
		[[ $1 = $__ ]] && \
			return
	done

	LOADER_PATHS[${#LOADER_PATHS[@]}]=$1
}

loader_load() {
	loader_flag_ "$__"

	LOADER_CS[++LOADER_CS_I]=$__

	loader_load_ "$@"

	__=$?

	LOADER_CS[LOADER_CS_I--]=

	return "$__"
}

loader_load_() {
	. "$__"
}

loader_load_s() {
	shift "$1"

	loader_flag_ "$__"

	LOADER_CS[++LOADER_CS_I]=$__

	loader_load_ "$@"

	__=$?

	LOADER_CS[LOADER_CS_I--]=

	return "$__"
}

function loader_list {
	[[ -r $1 ]] || \
		loader_fail "directory not readable or searchable: $1" loader_list "$@"

	LOADER_OWD=$PWD

	cd "$1" || \
		loader_fail "failed to access directory: $1" loader_list "$@"

	find -maxdepth 1 -xtype f "$LOADER_TESTOPT" "${LOADER_REGEXPREFIX}${LOADER_FILEEXPR}" -printf %f\\n |&

	LOADER_R=1

	if read -r -p __; then
		set -A LOADER_LIST "$__"

		typeset -i I=2
		while read -r -p __; do
			LOADER_LIST[I++]=$__
		done

		LOADER_ABSPREFIX=${PWD%/}/

		LOADER_R=0
	fi

	cd "$LOADER_OWD" || \
		loader_fail "failed to change back to previous directory." loader_list "$@"

	return "$LOADER_R"
}

loader_getabspath() {
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

loader_fail() {
	typeset MESSAGE FUNC A I

	MESSAGE=$1 FUNC=$2
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
				echo -n " \"$A\""
			done
			echo
			echo
		fi

		if [[ LOADER_CS_I -gt 0 ]]; then
			echo "  call stack:"
			echo "    (main)"
			I=1
			while [[ I -le LOADER_CS_I ]]; do
				echo "    -> ${LOADER_CS[I]}"
				(( ++I ))
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


#### VERSION DEPENDENT PRIVATE FUNCTIONS AND VARIABLES ####

if [[ $LOADER_KSH_VERSION = 0 ]]; then
	eval "
		LOADER_FLAGS=([.]=.)
		LOADER_PATHS_FLAGS=([.]=.)

		loader_addpath_() {
			if [[ -z \${LOADER_PATHS_FLAGS[\$1]} ]]; then
				LOADER_PATHS[\${#LOADER_PATHS[@]}]=\$1
				LOADER_PATHS_FLAGS[\$1]=.
			fi
		}

		loader_flag_() {
			LOADER_FLAGS[\$1]=.
		}

		loader_flagged() {
			[[ -n \${LOADER_FLAGS[\$1]} ]]
		}

		loader_resetflags() {
			LOADER_FLAGS=()
		}

		loader_resetpaths() {
			set -A LOADER_PATHS
			LOADER_PATHS_FLAGS=()
		}

		loader_unsetvars() {
			unset LOADER_FLAGS LOADER_PATHS_FLAGS LOADER_SHIFTS_0 LOADER_SHIFTS_1
		}
	"

	if
		eval "
			__=.
			read __ <<< \"\$__\"
			[[ \$__ = '\".\"' ]]
		"
	then
		eval "
			function loader_getabspath_ {
				typeset T1 T2
				typeset -i I=0
				typeset IFS=/ A

				case \"\$1\" in
				/*)
					read -r -A T1 <<< \$1
					;;
				*)
					read -r -A T1 <<< \$PWD/\$1
					;;
				esac

				set -A T2

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
	else
		eval "
			function loader_getabspath_ {
				typeset T1 T2
				typeset -i I=0
				typeset IFS=/ A

				case \"\$1\" in
				/*)
					read -r -A T1 <<< \"\$1\"
					;;
				*)
					read -r -A T1 <<< \"\$PWD/\$1\"
					;;
				esac

				set -A T2

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
	fi
else
	loader_addpath_() {
		for __ in "${LOADER_PATHS[@]}"; do
			[[ $1 = "$__" ]] && \
				return
		done

		LOADER_PATHS[${#LOADER_PATHS[@]}]=$1
	}

	loader_flag_() {
		eval "LOADER_FLAGS_$(echo "$1" | sed 's/\./_dt_/g; s/\//_sl_/g; s/ /_sp_/g; s/[^[:alnum:]_]/_ot_/g')=."
	}

	loader_flagged() {
		eval "[[ -n \$LOADER_FLAGS_$(echo "$1" | sed 's/\./_dt_/g; s/\//_sl_/g; s/ /_sp_/g; s/[^[:alnum:]_]/_ot_/g') ]]"
	}

	loader_getabspath_() {
		typeset A T IFS=/ TOKENS I=0 J=0

		A=${1%/}

		if [[ -n $A ]]; then
			while :; do
				T=${A%%/*}

				case "$T" in
				..)
					if [[ I -gt 0 ]]; then
						unset TOKENS\[--I\]
					else
						(( ++J ))
					fi
					;;
				.|'')
					;;
				*)
					TOKENS[I++]=$T
					;;
				esac

				case "$A" in
				*/*)
					A=${A#*/}
					;;
				*)
					break
					;;
				esac
			done
		fi

		__="/${TOKENS[*]}"

		if [[ $1 != /* ]]; then
			A=${PWD%/}

			while [[ J -gt 0 && -n $A ]]; do
				A=${A%/*}
				(( --J ))
			done

			[[ -n $A ]] && __=$A${__%/}
		fi

		if [[ $__ = / ]]; then
			[[ $1 != */ ]] && __=/.
		elif [[ $1 == */ ]]; then
			__=$__/
		fi
	}

	loader_resetflags() {
		unset $(set | grep -a ^LOADER_FLAGS_ | cut -f 1 -d =)
	}

	loader_resetpaths() {
		set -A LOADER_PATHS
	}

	loader_unsetvars() {
		loader_resetflags
	}
fi


# ----------------------------------------------------------------------

# * In some if not all versions of ksh, "${@:X[:Y]}" always presents a
#   single null string if no positional parameter is matched.
#
# * In some versions of ksh, 'read <<< "$VAR"' includes '"' in the
#   string.
#
# * Using 'set -- $VAR' to split strings inside variables will sometimes
#   yield different strings if one of the strings contain globs
#   characters like *, ? and the brackets [ and ] that are also valid
#   characters in filenames.
#
# * Changing the IFS causes buggy behaviors in PD KSH.

# ----------------------------------------------------------------------
