#!/usr/bin/env sh


# ----------------------------------------------------------------------

# loader-extended.sh
#
# This is a generic/universal implementation of Shell Script Loader
# Extended that targets all shells based on sh.
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

# Note:
#
# Some shells or some shell versions may not not have the full
# capability of supporting Shell Script Loader.  For example, some
# earlier versions of Zsh (earlier than 4.2) have limitations to the
# number of levels or recursions that its functions and/or commands
# can actively execute.

# ----------------------------------------------------------------------


#### PUBLIC VARIABLES ####

LOADER_ACTIVE=true
LOADER_RS=0X
LOADER_VERSION=0X.1.2


#### PRIVATE VARIABLES ####

LOADER_ABSPREFIX=''
LOADER_EXPR=''
LOADER_FILEEXPR=''
LOADER_LOCAL=:
LOADER_PLAIN=false
LOADER_R=0
LOADER_REGEXPREFIX=''
LOADER_SHIFTS=0
LOADER_SUBPREFIX=''
LOADER_TESTOPT=''


#### PUBLIC FUNCTIONS ####

load() {
	[ "$#" -eq 0 ] && loader_fail "function called with no argument." load

	case "$1" in
	'')
		loader_fail "file expression cannot be null." load "$@"
		;;
	/*|./*|../*)
		if [ -f "$1" ]; then
			loader_getabspath "$1"

			[ -r "$__" ] || loader_fail "file not readable: $__" load "$@"

			shift
			loader_load "$@"

			return
		fi
		;;
	*)
		if loader_findfile "$1"; then
			[ -r "$__" ] || loader_fail "found file not readable: $__" load "$@"

			loader_flag_ "$1"

			shift
			loader_load "$@"

			return
		fi
		;;
	esac

	loader_fail "file not found: $1" load "$@"
}

include() {
	[ "$#" -eq 0 ] && loader_fail "function called with no argument." include

	case "$1" in
	'')
		loader_fail "file expression cannot be null." include "$@"
		;;
	/*|./*|../*)
		loader_getabspath "$1"

		loader_flagged "$__" && \
			return

		if [ -f "$__" ]; then
			[ -r "$__" ] || loader_fail "file not readable: $__" include "$@"

			shift
			loader_load "$@"

			return
		fi
		;;
	*)
		loader_flagged "$1" && \
			return

		loader_include_loop "$@" && \
			return
		;;
	esac

	loader_fail "file not found: $1" include "$@"
}

call() {
	[ "$#" -eq 0 ] && loader_fail "function called with no argument." call

	case "$1" in
	'')
		loader_fail "file expression cannot be null." call "$@"
		;;
	/*|./*|../*)
		if [ -f "$1" ]; then
			loader_getabspath "$1"

			[ -r "$__" ] || loader_fail "file not readable: $__" call "$@"

			(
				shift
				loader_load "$@"
			)

			return
		fi
		;;
	*)
		if loader_findfile "$1"; then
			[ -r "$__" ] || loader_fail "found file not readable: $__" call "$@"

			(
				loader_flag_ "$1"

				shift
				loader_load "$@"
			)

			return
		fi
		;;
	esac

	loader_fail "file not found: $1" call "$@"
}

loadx() {
	[ "$#" -eq 0 ] && loader_fail "function called with no argument." loadx

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

	if [ "$LOADER_PLAIN" = true ]; then
		case "$1" in
		'')
			loader_fail "file expression cannot be null." loadx "$@"
			;;
		/*|./*|../*)
			if [ -f "$1" ]; then
				loader_getabspath "$1"

				[ -r "$__" ] || loader_fail "file not readable: $__" loadx "$@"

				shift
				loader_load "$@"

				return
			fi
			;;
		*)
			if loader_findfile "$1"; then
				[ -r "$__" ] || loader_fail "found file not readable: $__" loadx "$@"

				loader_flag_ "$1"

				shift
				loader_load "$@"

				return
			fi
			;;
		esac

		loader_fail "file not found: $1" loadx "$@"
	else
		"$LOADER_LOCAL" LOADER_ABSPREFIX LOADER_SUBPREFIX

		[ -z "$LOADER_EXPR" ] && \
			loader_fail "file expression cannot be null." loadx "$@"

		loader_getfileexprandsubprefix "$LOADER_EXPR"

		[ -z "$LOADER_FILEEXPR" ] && \
			loader_fail "expression does not represent files: $__" loadx "$@"

		case "$LOADER_SUBPREFIX" in
		*[*?]*)
			loader_fail "expressions for directories are not supported: $LOADER_SUBPREFIX" loadx "$@"
			;;
		/*|./*|../*)
			[ -d "$LOADER_SUBPREFIX" ] || \
				loader_fail "directory not found: $LOADER_SUBPREFIX" loadx "$@"

			if loader_list "$LOADER_SUBPREFIX"; then
				shift "$LOADER_SHIFTS"

				loader_loadx_loop_0 "$@"

				return
			fi
			;;
		*)
			if loader_findfiles; then
				shift "$LOADER_SHIFTS"

				loader_loadx_loop_1 "$@"

				return
			fi
			;;
		esac

		loader_fail "no file was found with expression: $LOADER_EXPR" loadx "$@"
	fi
}

includex() {
	[ "$#" -eq 0 ] && loader_fail "function called with no argument." includex

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

	if [ "$LOADER_PLAIN" = true ]; then
		case "$1" in
		'')
			loader_fail "file expression cannot be null." includex "$@"
			;;
		/*|./*|../*)
			loader_getabspath "$1"

			loader_flagged "$__" && \
				return

			if [ -f "$__" ]; then
				[ -r "$__" ] || loader_fail "file not readable: $__" includex "$@"

				shift
				loader_load "$@"

				return
			fi
			;;
		*)
			loader_flagged "$1" && \
				return

			loader_include_loop "$@" && \
				return
			;;
		esac

		loader_fail "file not found: $1" includex "$@"
	else
		"$LOADER_LOCAL" LOADER_ABSPREFIX LOADER_SUBPREFIX

		[ -z "$LOADER_EXPR" ] && \
			loader_fail "file expression cannot be null." includex "$@"

		loader_getfileexprandsubprefix "$LOADER_EXPR"

		[ -z "$LOADER_FILEEXPR" ] && \
			loader_fail "expression does not represent files: $__" includex "$@"

		case "$LOADER_SUBPREFIX" in
		*[*?]*)
			loader_fail "expressions for directories are not supported: $LOADER_SUBPREFIX" includex "$@"
			;;
		/*|./*|../*)
			[ -d "$LOADER_SUBPREFIX" ] || \
				loader_fail "directory not found: $LOADER_SUBPREFIX" includex "$@"

			if loader_list "$LOADER_SUBPREFIX"; then
				shift "$LOADER_SHIFTS"

				loader_includex_loop_0 "$@"

				return
			fi
			;;
		*)
			if loader_findfiles; then
				shift "$LOADER_SHIFTS"

				loader_includex_loop_1 "$@"

				return
			fi
			;;
		esac

		loader_fail "no file was found with expression: $LOADER_EXPR" includex "$@"
	fi
}

callx() {
	[ "$#" -eq 0 ] && loader_fail "function called with no argument." callx

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

	if [ "$LOADER_PLAIN" = true ]; then
		case "$1" in
		'')
			loader_fail "file expression cannot be null." callx "$@"
			;;
		/*|./*|../*)
			if [ -f "$1" ]; then
				loader_getabspath "$1"

				[ -r "$__" ] || loader_fail "file not readable: $__" callx "$@"

				(
					shift
					loader_load "$@"
				)

				return
			fi
			;;
		*)
			if loader_findfile "$1"; then
				[ -r "$__" ] || loader_fail "found file not readable: $__" callx "$@"

				(
					loader_flag_ "$1"

					shift
					loader_load "$@"
				)

				return
			fi
			;;
		esac

		loader_fail "file not found: $1" callx "$@"
	else
		"$LOADER_LOCAL" LOADER_ABSPREFIX LOADER_SUBPREFIX

		[ -z "$LOADER_EXPR" ] && \
			loader_fail "file expression cannot be null." callx "$@"

		loader_getfileexprandsubprefix "$LOADER_EXPR"

		[ -z "$LOADER_FILEEXPR" ] && \
			loader_fail "expression does not represent files: $__" callx "$@"

		case "$LOADER_SUBPREFIX" in
		*[*?]*)
			loader_fail "expressions for directories are not supported: $LOADER_SUBPREFIX" callx "$@"
			;;
		/*|./*|../*)
			[ -d "$LOADER_SUBPREFIX" ] || \
				loader_fail "directory not found: $LOADER_SUBPREFIX" callx "$@"

			if loader_list "$LOADER_SUBPREFIX"; then
				shift "$LOADER_SHIFTS"

				loader_callx_loop_0 "$@"

				return
			fi
			;;
		*)
			if loader_findfiles; then
				shift "$LOADER_SHIFTS"

				loader_callx_loop_1 "$@"

				return
			fi
			;;
		esac

		loader_fail "no file was found with expression: $LOADER_EXPR" callx "$@"
	fi
}

loader_addpath() {
	for __ in "$@"; do
		[ -d "$__" ] || loader_fail "directory not found: $__" loader_addpath "$@"
		[ -x "$__" ] || loader_fail "directory not accessible: $__" loader_addpath "$@"
		[ -r "$__" ] || loader_fail "directory not searchable: $__" loader_addpath "$@"
		loader_getabspath "$__/."
		loader_addpath_ "$__"
	done
	loader_updatefunctions
}

loader_flag() {
	[ "$#" -eq 1 ] || loader_fail "function requires a single argument." loader_flag "$@"
	loader_getabspath "$1"
	loader_flag_ "$__"
}

loader_reset() {
	if [ "$#" -eq 0 ]; then
		loader_resetflags
		loader_resetpaths
	elif [ "$1" = flags ]; then
		loader_resetflags
	elif [ "$1" = paths ]; then
		loader_resetpaths
	else
		loader_fail "invalid argument: $1" loader_reset "$@"
	fi
}

loader_finish() {
	LOADER_ACTIVE=false

	loader_unsetvars
	loader_unsetfunctions

	unset \
		load \
		include \
		call \
		loadx \
		includex \
		callx \
		loader_addpath \
		loader_addpath_ \
		loader_callx_loop_0 \
		loader_callx_loop_1 \
		loader_fail \
		loader_findfile \
		loader_findfiles \
		loader_finish \
		loader_flag \
		loader_flag_ \
		loader_flagged \
		loader_getabspath \
		loader_getfileexprandsubprefix \
		loader_include_loop \
		loader_includex_loop_0 \
		loader_includex_loop_1 \
		loader_list \
		loader_load \
		loader_loadx_loop_0 \
		loader_loadx_loop_1 \
		loader_reset \
		loader_resetflags \
		loader_resetpaths \
		loader_unsetfunctions \
		loader_unsetvars \
		loader_updatefunctions \
		LOADER_ABSPREFIX \
		LOADER_EXPR \
		LOADER_FILEEXPR \
		LOADER_LIST \
		LOADER_LOCAL \
		LOADER_PLAIN \
		LOADER_R \
		LOADER_REGEXPREFIX \
		LOADER_SHIFTS \
		LOADER_SUBPREFIX \
		LOADER_TESTOPT
}


#### PRIVATE VARIABLES AND FUNCTIONS ####

LOADER_ADVANCED=false
LOADER_KSH93=false

if [ -n "$BASH_VERSION" ]; then
	if ( case "$BASH" in sh|*/sh) exit 1;; esac; exit 0; ) && [ "$BASH_VERSION" '>' 2.03 ]; then
		eval '
			LOADER_CS=()
			LOADER_CS_I=0
			LOADER_LIST=()
			LOADER_PATHS=()

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
		'

		if [[ $LOADER_USEAARRAYS = true ]]; then
			eval '
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

				function loader_list {
					[[ -r $1 ]] || \
						loader_fail "directory not readable or searchable: $1" loader_list "$@"

					pushd "$1" >/dev/null || \
						loader_fail "failed to access directory: $1" loader_list "$@"

					LOADER_R=1

					if
						readarray -t LOADER_LIST \
							< <(exec find -maxdepth 1 -xtype f "$LOADER_TESTOPT" "$LOADER_REGEXPREFIX$LOADER_FILEEXPR" -printf %f\\n)
					then
						LOADER_ABSPREFIX=${PWD%/}/

						LOADER_R=0
					fi

					popd >/dev/null || \
						loader_fail "failed to change back to previous directory." loader_list "$@"

					return "$LOADER_R"
				}

				function loader_resetflags {
					LOADER_FLAGS=()
				}

				function loader_resetpaths {
					LOADER_PATHS=()
					LOADER_PATHS_FLAGS=()
				}

				function loader_unsetvars {
					unset LOADER_CS LOADER_CS_I LOADER_FLAGS LOADER_PATHS LOADER_PATHS_FLAGS
				}
			'
		else
			eval '
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

				function loader_list {
					[[ -r $1 ]] || \
						loader_fail "directory not readable or searchable: $1" loader_list "$@"

					pushd "$1" >/dev/null || \
						loader_fail "failed to access directory: $1" loader_list "$@"

					LOADER_R=1

					{
						if read -r __; then
							LOADER_LIST=("$__")

							local -i I=1
							while read -r __; do
								LOADER_LIST[I++]=$__
							done

							LOADER_ABSPREFIX=${PWD%/}/

							LOADER_R=0
						fi
					} < <(exec find -maxdepth 1 -xtype f "$LOADER_TESTOPT" "$LOADER_REGEXPREFIX$LOADER_FILEEXPR" -printf %f\\n)

					popd >/dev/null || \
						loader_fail "failed to change back to previous directory." loader_list "$@"

					return "$LOADER_R"
				}

				function loader_resetflags {
					unset "${!LOADER_FLAGS_@}"
				}

				function loader_resetpaths {
					LOADER_PATHS=()
				}

				function loader_unsetvars {
					unset LOADER_CS LOADER_CS_I LOADER_PATHS "${!LOADER_FLAGS_@}"
				}
			'
		fi

		unset LOADER_USEAARRAYS

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

		LOADER_ADVANCED=true
		LOADER_LOCAL=local
	fi
elif [ -n "$ZSH_VERSION" ]; then
	if
		eval '[ "${ZSH_VERSION%%.*}" -ge 4 ]' && \
		[ ! "$ZSH_NAME" = sh -a ! "$ZSH_NAME" = ksh ]
	then
		eval "
			typeset -g -a LOADER_CS
			typeset -g -i LOADER_CS_I=0
			typeset -g -A LOADER_FLAGS
			typeset -g -a LOADER_LIST
			typeset -g -a LOADER_PATHS
			typeset -g -A LOADER_PATHS_FLAGS

			function loader_addpath_ {
				if [[ -z \${LOADER_PATHS_FLAGS[\$1]} ]]; then
					LOADER_PATHS[\$(( \${#LOADER_PATHS[@]}+1 ))]=\$1
					LOADER_PATHS_FLAGS[\$1]=.
				fi
			}

			function loader_flag_ {
				LOADER_FLAGS[\$1]=.
			}

			function loader_flagged {
				[[ -n \${LOADER_FLAGS[\$1]} ]]
			}

			function loader_getabspath_ {
				local -a TOKENS; set -A TOKENS
				local -i I=0
				local IFS=/ T

				__=\$1

				case \"\$1\" in
				/*)
					set -- \${=1}
					;;
				*)
					set -- \${=PWD} \${=1}
					;;
				esac

				for T; do
					case \"\$T\" in
					..)
						[[ I -ne 0 ]] && TOKENS[I--]=()
						continue
						;;
					.|'')
						continue
						;;
					esac

					TOKENS[++I]=\$T
				done

				case \"\$__\" in
				*/)
					[[ I -ne 0 ]] && __=\"/\${TOKENS[*]}/\" || __=/
					;;
				*)
					[[ I -ne 0 ]] && __=\"/\${TOKENS[*]}\" || __=/.
					;;
				esac
			}

			function loader_list {
				[[ -r \$1 ]] || \\
					loader_fail \"directory not readable or searchable: \$1\" loader_list \"\$@\"

				pushd \"\$1\" >/dev/null || \\
					loader_fail \"failed to access directory: \$1\" loader_list \"\$@\"

				LOADER_R=1 I=2

				{
					if read -r __; then
						set -A LOADER_LIST \"\$__\"

						while read -r __; do
							LOADER_LIST[I++]=\$__
						done

						LOADER_ABSPREFIX=\${PWD%/}/

						LOADER_R=0
					fi
				} < <(exec find -maxdepth 1 -xtype f \"\$LOADER_TESTOPT\" \"\${LOADER_REGEXPREFIX}\${LOADER_FILEEXPR}\" -printf %f\\\\n)

				popd >/dev/null || \\
					loader_fail \"failed to change back to previous directory.\" loader_list \"\$@\"

				return \"\$LOADER_R\"
			}

			function loader_resetflags {
				set -A LOADER_FLAGS
			}

			function loader_resetpaths {
				set -A LOADER_PATHS
				set -A LOADER_PATHS_FLAGS
			}

			function loader_unsetvars {
				unset LOADER_CS LOADER_CS_I LOADER_FLAGS LOADER_PATHS LOADER_PATHS_FLAGS
			}
		"

		LOADER_ADVANCED=true
		LOADER_LOCAL=local
	fi
elif [ -n "$KSH_VERSION" ]; then
	eval "
		set -A LOADER_CS
		LOADER_CS_I=0

		set -A LOADER_LIST

		LOADER_OWD=''

		set -A LOADER_PATHS

		loader_addpath_() {
			for __ in \"\${LOADER_PATHS[@]}\"; do
				[[ \$1 = \"\$__\" ]] && \\
					return
			done

			LOADER_PATHS[\${#LOADER_PATHS[@]}]=\$1
		}

		loader_getabspath_() {
			typeset A T IFS=/ TOKENS I=0 J=0

			A=\${1%/}

			if [[ -n \$A ]]; then
				while :; do
					T=\${A%%/*}

					case \"\$T\" in
					..)
						if [[ I -gt 0 ]]; then
							unset TOKENS\\[--I\\]
						else
							(( ++J ))
						fi
						;;
					.|'')
						;;
					*)
						TOKENS[I++]=\$T
						;;
					esac

					case \"\$A\" in
					*/*)
						A=\${A#*/}
						;;
					*)
						break
						;;
					esac
				done
			fi

			__=\"/\${TOKENS[*]}\"

			if [[ \$1 != /* ]]; then
				A=\${PWD%/}

				while [[ J -gt 0 && -n \$A ]]; do
					A=\${A%/*}
					(( --J ))
				done

				[[ -n \$A ]] && __=\$A\${__%/}
			fi

			if [[ \$__ = / ]]; then
				[[ \$1 != */ ]] && __=/.
			elif [[ \$1 == */ ]]; then
				__=\$__/
			fi
		}

		loader_flag_() {
			eval \"LOADER_FLAGS_\$(echo \"\$1\" | sed \"s/\\./_dt_/g; s/\\//_sl_/g; s/ /_sp_/g; s/[^[:alnum:]_]/_ot_/g\")=.\"
		}

		loader_flagged() {
			eval \"[[ -n \\\$LOADER_FLAGS_\$(echo \"\$1\" | sed \"s/\\./_dt_/g; s/\\//_sl_/g; s/ /_sp_/g; s/[^[:alnum:]_]/_ot_/g\") ]]\"
		}

		loader_resetflags() {
			unset \$(set | grep -a ^LOADER_FLAGS_ | cut -f 1 -d =)
		}

		loader_resetpaths() {
			set -A LOADER_PATHS
		}

		loader_list() {
			[[ -r \$1 ]] || \\
				loader_fail \"directory not readable or searchable: \$1\" loader_list \"\$@\"

			LOADER_OWD=\$PWD

			cd \"\$1\" || \\
				loader_fail \"failed to access directory: \$1\" loader_list \"\$@\"

			find -maxdepth 1 -xtype f \"\$LOADER_TESTOPT\" \"\${LOADER_REGEXPREFIX}\${LOADER_FILEEXPR}\" -printf %f\\\\n |&

			LOADER_R=1

			if read -r -p __; then
				set -A LOADER_LIST \"\$__\"

				local -i I=1
				while read -r -p __; do
					LOADER_LIST[I++]=\$__
				done

				LOADER_ABSPREFIX=\${PWD%/}/

				LOADER_R=0
			fi

			cd \"\$LOADER_OWD\" || \\
				loader_fail \"failed to change back to previous directory.\" loader_list \"\$@\"

			return \"\$LOADER_R\"
		}

		loader_unsetvars() {
			unset LOADER_CS LOADER_CS_I LOADER_OWD LOADER_PATHS
			loader_resetflags
		}
	"

	LOADER_ADVANCED=true
	LOADER_LOCAL=typeset
elif
	( eval '[ -n "${.sh.version}" ] && exit 10'; ) >/dev/null 2>&1
	[ "$?" -eq 10 ]
then
	eval "
		unset LOADER_CS
		unset LOADER_CS_I
		unset LOADER_FLAGS
		unset LOADER_PATHS
		unset LOADER_PATHS_FLAGS

		if [ -n \"\$ZSH_VERSION\" ]; then
			typeset -g -a LOADER_CS
			typeset -g -i LOADER_CS_I=0
			typeset -g -A LOADER_FLAGS
			typeset -g -A LOADER_PATHS_FLAGS
		else
			set -A LOADER_CS_I
			LOADER_CS_I=0
			set -A LOADER_PATHS
			LOADER_FLAGS=([.]=.)
			LOADER_PATHS_FLAGS=([.]=.)
		fi

		LOADER_OWD=''

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
			unset LOADER_FLAGS
			LOADER_FLAGS=([.]=.)
		}

		loader_resetpaths() {
			set -A LOADER_PATHS
			unset LOADER_PATHS_FLAGS
			LOADER_PATHS_FLAGS=([.]=.)
		}

		loader_load_s() {
			shift \"\$1\"

			loader_flag_ \"\$__\"

			LOADER_CS[++LOADER_CS_I]=\$1

			loader_load_ \"\$@\"

			__=\$?

			unset LOADER_CS\\[LOADER_CS_I--\\]

			return \"\$__\"
		}

		function loader_list {
			[[ -r \$1 ]] || \\
				loader_fail \"directory not readable or searchable: \$1\" loader_list \"\$@\"

			LOADER_OWD=\$PWD

			cd \"\$1\" || \\
				loader_fail \"failed to access directory: \$1\" loader_list \"\$@\"

			find -maxdepth 1 -xtype f \"\$LOADER_TESTOPT\" \"\${LOADER_REGEXPREFIX}\${LOADER_FILEEXPR}\" -printf %f\\\\n |&

			LOADER_R=1

			if read -r -p __; then
				set -A LOADER_LIST \"\$__\"

				typeset -i I=1
				while read -r -p __; do
					LOADER_LIST[I++]=\$__
				done

				LOADER_ABSPREFIX=\${PWD%/}/

				LOADER_R=0
			fi

			cd \"\$LOADER_OWD\" || \\
				loader_fail \"failed to change back to previous directory.\" loader_list \"\$@\"

			return \"\$LOADER_R\"
		}

		loader_loadx_loop_0() {
			set -- 2 \"\$LOADER_ABSPREFIX\" \"\$@\"
			for __ in \"\${LOADER_LIST[@]}\"; do
				__=\$2\$__
				[[ -r \$__ ]] || loader_fail \"found file not readable: \$__\" loader_loadx_loop_0
				loader_load_s \"\$@\"
			done
		}

		loader_loadx_loop_1() {
			set -- 3 \"\$LOADER_ABSPREFIX\" \"\$LOADER_SUBPREFIX\" \"\$@\"
			for __ in \"\${LOADER_LIST[@]}\"; do
				loader_flag_ \"\$3\$__\"
				__=\$2\$__
				[[ -r \$__ ]] || loader_fail \"found file not readable: \$__\" loader_loadx_loop_1
				loader_load_s \"\$@\"
			done
		}

		loader_includex_loop_0() {
			set -- 2 \"\$LOADER_ABSPREFIX\" \"\$@\"
			for __ in \"\${LOADER_LIST[@]}\"; do
				__=\$2\$__
				loader_flagged \"\$__\" && continue
				[[ -r \$__ ]] || loader_fail \"found file not readable: \$__\" loader_includex_loop_0
				loader_load_s \"\$@\"
			done
		}

		loader_includex_loop_1() {
			set -- 3 \"\$LOADER_ABSPREFIX\" \"\$LOADER_SUBPREFIX\" \"\$@\"
			for __ in \"\${LOADER_LIST[@]}\"; do
				loader_flagged \"\$2\$__\" && continue
				loader_flag_ \"\$3\$__\"
				__=\$2\$__
				[[ -r \$__ ]] || loader_fail \"found file not readable: \$__\" loader_includex_loop_1
				loader_load_s \"\$@\"
			done
		}

		loader_unsetvars() {
			unset LOADER_CS LOADER_CS_I LOADER_FLAGS LOADER_OWD LOADER_PATHS LOADER_PATHS_FLAGS
		}

		loader_unsetfunctions() {
			unset loader_getabspath_ loader_load_ loader_load_s
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

	LOADER_ADVANCED=true
	LOADER_KSH93=true
fi

if [ "$LOADER_ADVANCED" = true ]; then
	eval "
		loader_callx_loop_0() {
			LOADER_R=0

			for __ in \"\${LOADER_LIST[@]}\"; do
				__=\$LOADER_ABSPREFIX\$__
				[[ -r \$__ ]] || loader_fail \"found file not readable: \$__\" loader_callx_loop_0
				( loader_load \"\$@\"; ) || LOADER_R=1
			done

			return \"\$LOADER_R\"
		}

		loader_callx_loop_1() {
			LOADER_R=0

			for __ in \"\${LOADER_LIST[@]}\"; do
				[[ -r \$LOADER_ABSPREFIX\$__ ]] || loader_fail \"found file not readable: \$LOADER_ABSPREFIX\$__\" loader_callx_loop_1
				(
					loader_flag_ \"\$LOADER_SUBPREFIX\$__\"
					__=\$LOADER_ABSPREFIX\$__
					loader_load \"\$@\"
				) || LOADER_R=1
			done

			return \"\$LOADER_R\"
		}

		loader_fail() {
			typeset MESSAGE FUNC A I

			MESSAGE=\$1 FUNC=\$2
			shift 2

			{
				echo \"loader: \${FUNC}(): \${MESSAGE}\"
				echo

				echo \"  current scope:\"
				if [[ LOADER_CS_I -gt 0 ]]; then
					echo \"    \${LOADER_CS[LOADER_CS_I]}\"
				else
					echo \"    (main)\"
				fi
				echo

				if [[ \$# -gt 0 ]]; then
					echo \"  command:\"
					echo -n \"    \$FUNC\"
					for A in \"\$@\"; do
						echo -n \" \\\"\$A\\\"\"
					done
					echo
					echo
				fi

				if [[ LOADER_CS_I -gt 0 ]]; then
					echo \"  call stack:\"
					echo \"    (main)\"
					I=1
					while [[ I -le LOADER_CS_I ]]; do
						echo \"    -> \${LOADER_CS[I]}\"
						(( ++I ))
					done
					echo
				fi

				echo \"  search paths:\"
				if [[ \${#LOADER_PATHS[@]} -gt 0 ]]; then
					for A in \"\${LOADER_PATHS[@]}\"; do
						echo \"    \$A\"
					done
				else
					echo \"    (empty)\"
				fi
				echo

				echo \"  working directory:\"
				echo \"    \$PWD\"
				echo
			} >&2

			exit 1
		}

		loader_findfile() {
			for __ in \"\${LOADER_PATHS[@]}\"; do
				if [[ -f \$__/\$1 ]]; then
					loader_getabspath \"\$__/\$1\"
					return 0
				fi
			done
			return 1
		}

		loader_findfiles() {
			for __ in \"\${LOADER_PATHS[@]}\"; do
				__=\$__/\$LOADER_SUBPREFIX
				[[ -d \$__ ]] && loader_list \"\$__\" && return 0
			done
			return 1
		}

		loader_getabspath() {
			case \"\$1\" in
			.|'')
				case \"\$PWD\" in
				/)
					__=/.
					;;
				*)
					__=\${PWD%/}
					;;
				esac
				;;
			..|../*|*/..|*/../*|./*|*/.|*/./*|*//*)
				loader_getabspath_ \"\$1\"
				;;
			/*)
				__=\$1
				;;
			*)
				__=\${PWD%/}/\$1
				;;
			esac
		}

		loader_getfileexprandsubprefix() {
			if [[ \$1 == */* ]]; then
				LOADER_FILEEXPR=\${1##*/}
				LOADER_SUBPREFIX=\${1%/*}/
			else
				LOADER_FILEEXPR=\$1
				LOADER_SUBPREFIX=''
			fi
		}

		loader_include_loop() {
			for __ in \"\${LOADER_PATHS[@]}\"; do
				loader_getabspath \"\$__/\$1\"

				if loader_flagged \"\$__\"; then
					loader_flag_ \"\$1\"

					return 0
				elif [[ -f \$__ ]]; then
					[[ -r \$__ ]] || loader_fail \"found file not readable: \$__\" loader_include_loop \"\$@\"

					loader_flag_ \"\$1\"

					shift
					loader_load \"\$@\"

					return 0
				fi
			done

			return 1
		}

		loader_load() {
			loader_flag_ \"\$__\"

			LOADER_CS[++LOADER_CS_I]=\$__

			loader_load_ \"\$@\"

			__=\$?

			[[ LOADER_CS_I -gt 0 ]] && LOADER_CS[LOADER_CS_I--]=

			return \"\$__\"
		}

		loader_load_() {
			. \"\$__\"
		}

		loader_updatefunctions() {
			:
		}
	"

	if [ "$LOADER_KSH93" = false ]; then
		eval "
			loader_loadx_loop_0() {
				for __ in \"\${LOADER_LIST[@]}\"; do
					__=\$LOADER_ABSPREFIX\$__
					[[ -r \$__ ]] || loader_fail \"found file not readable: \$__\" loader_loadx_loop_0 \"\$@\"
					loader_load \"\$@\"
				done
			}

			loader_loadx_loop_1() {
				for __ in \"\${LOADER_LIST[@]}\"; do
					loader_flag_ \"\$LOADER_SUBPREFIX\$__\"
					__=\$LOADER_ABSPREFIX\$__
					[[ -r \$__ ]] || loader_fail \"found file not readable: \$__\" loader_loadx_loop_1 \"\$@\"
					loader_load \"\$@\"
				done
			}

			loader_includex_loop_0() {
				for __ in \"\${LOADER_LIST[@]}\"; do
					__=\$LOADER_ABSPREFIX\$__
					loader_flagged \"\$__\" && continue
					[[ -r \$__ ]] || loader_fail \"found file not readable: \$__\" loader_includex_loop_0 \"\$@\"
					loader_load \"\$@\"
				done
			}

			loader_includex_loop_1() {
				for __ in \"\${LOADER_LIST[@]}\"; do
					loader_flagged \"\$LOADER_ABSPREFIX\$__\" && continue
					loader_flag_ \"\$LOADER_SUBPREFIX\$__\"
					__=\$LOADER_ABSPREFIX\$__
					[[ -r \$__ ]] || loader_fail \"found file not readable: \$__\" loader_includex_loop_1 \"\$@\"
					loader_load \"\$@\"
				done
			}

			loader_unsetfunctions() {
				unset loader_getabspath_ loader_load_
			}
		"
	fi
else
	eval "
		LOADER_FLAGS=''
		LOADER_OWD=''
		LOADER_PATHS=''
		LOADER_SCOPE='(main)'
		LOADER_V=''

		loader_addpath_() {
			LOADER_V=\$1

			if [ -n \"\$LOADER_PATHS\" ]; then
				eval \"set -- \$LOADER_PATHS\"

				for __ in \"\$@\"; do
					[ \"\$__\" = \"\$LOADER_V\" ] && return
				done
			fi

			case \"\$LOADER_V\" in
			*[\\\\\\\"]*)
				loader_fail \"can't support directory names with characters '\\\\' and '\\\"'.\" loader_addpath_ \"\$@\"
				;;
			*\\\$*)
				LOADER_V=\`echo \"\$LOADER_V\" | sed 's/\\\$/\\\\\\\$/g'\`
				;;
			esac

			LOADER_PATHS=\$LOADER_PATHS' \"'\$LOADER_V'\"'
		}

		loader_callx_loop_0() {
			LOADER_R=0

			eval \"
				for __ in \$LOADER_LIST; do
					__=\\\$LOADER_ABSPREFIX\\\$__
					[ -r \\\"\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$__\\\" loader_callx_loop_0 \\\"\\\$@\\\"
					( loader_load \\\"\\\$@\\\"; ) || LOADER_R=1
				done
			\"

			return \"\$LOADER_R\"
		}

		loader_callx_loop_1() {
			LOADER_R=0

			eval \"
				for __ in \$LOADER_LIST; do
					[ -r \\\"\\\$LOADER_ABSPREFIX\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$LOADER_ABSPREFIX\\\$__\\\" loader_callx_loop_1 \\\"\\\$@\\\"
					(
						loader_flag_ \\\"\\\$LOADER_SUBPREFIX\\\$__\\\"
						__=\\\$LOADER_ABSPREFIX\\\$__
						loader_load \\\"\\\$@\\\"
					) || LOADER_R=1
				done
			\"

			return \"\$LOADER_R\"
		}

		loader_fail() {
			MESSAGE=\$1 FUNC=\$2
			shift 2

			{
				echo \"loader: \${FUNC}(): \${MESSAGE}\"
				echo

				echo \"  current scope:\"
				echo \"    \$LOADER_SCOPE\"
				echo

				if [ \"\$#\" -gt 0 ]; then
					echo \"  command:\"
					__=\"    \$FUNC\"
					for A in \"\$@\"; do
						__=\$__\" \\\"\$A\\\"\"
					done
					echo \"\$__\"
					echo
				fi

				echo \"  search paths:\"
				if [ -n \"\$LOADER_PATHS\" ]; then
					eval \"set -- \$LOADER_PATHS\"
					for A in \"\$@\"; do
						echo \"    \$A\"
					done
				else
					echo \"    (empty)\"
				fi
				echo

				echo \"  working directory:\"
				loader_getcwd
				echo \"    \$__\"
				echo
			} >&2

			exit 1
		}

		loader_findfile() {
			return 1
		}

		loader_findfiles() {
			return 1
		}

		if
			(
				eval '
					__=\"ABCabc. /*?\"
					__=\${__//./_dt_} && \\
					__=\${__// /_sp_} && \\
					__=\${__//\\//_sl_} && \\
					__=\${__//[^A-Za-z0-9_]/_ot_} && \\
					[ \"\$__\" = \"ABCabc_dt__sp__sl__ot__ot_\" ] && \\
					exit 10
				'
			) >/dev/null 2>&1
			[ \"\$?\" -eq 10 ]
		then
			eval '
				loader_flag_() {
					LOADER_V=\${1//./_dt_}
					LOADER_V=\${LOADER_V// /_sp_}
					LOADER_V=\${LOADER_V//\\//_sl_}
					LOADER_V=LOADER_FLAGS_\${LOADER_V//[^A-Za-z0-9_]/_ot_}
					eval \"\$LOADER_V=.\"
					LOADER_FLAGS=\$LOADER_FLAGS\\ \$LOADER_V
				}

				loader_flagged() {
					LOADER_V=\${1//./_dt_}
					LOADER_V=\${LOADER_V// /_sp_}
					LOADER_V=\${LOADER_V//\\//_sl_}
					LOADER_V=LOADER_FLAGS_\${LOADER_V//[^A-Za-z0-9_]/_ot_}
					eval \"[ -n \\\"\\\$\$LOADER_V\\\" ]\"
				}
			'
		else
			loader_flag_() {
				LOADER_V=LOADER_FLAGS_\`echo \"\$1\" | sed 's/\\./_dt_/g; s/ /_sp_/g; s/\\//_sl_/g; s/[^[:alnum:]_]/_ot_/g'\`
				eval \"\$LOADER_V=.\"
				LOADER_FLAGS=\$LOADER_FLAGS\\ \$LOADER_V
			}

			loader_flagged() {
				LOADER_V=LOADER_FLAGS_\`echo \"\$1\" | sed 's/\\./_dt_/g; s/ /_sp_/g; s/\\//_sl_/g; s/[^[:alnum:]_]/_ot_/g'\`
				eval \"[ -n \\\"\\\$\$LOADER_V\\\" ]\"
			}
		fi

		loader_getabspath() {
			case \"\$1\" in
			.|'')
				loader_getcwd

				case \"\$__\" in
				/)
					__=/.
					;;
				*)
					__=\$__
					;;
				esac
				;;
			..|../*|*/..|*/../*|./*|*/.|*/./*|*//*)
				loader_getabspath_ \"\$1\"
				;;
			/*)
				__=\$1
				;;
			*)
				loader_getcwd

				case \"\$__\" in
				/)
					__=/\$1
					;;
				*)
					__=\$__/\$1
					;;
				esac
				;;
			esac
		}

		loader_getabspath_() {
			case \"\$1\" in
			/*)
				__=\$1
				;;
			*)
				loader_getcwd
				__=\$__/\$1
				;;
			esac

			__=\`loader_getabspath__\`

			case \"\$1\" in
			*/)
				[ \"\$__\" = / ] || __=\$__/
				;;
			*)
				[ \"\$__\" = / ] && __=/.
				;;
			esac
		}

		loader_getabspath__() {
			set -f
			IFS=/
			set -- \$__

			while :; do
				__='' L=''

				for A
				do
					shift

					case \"\$A\" in
					..)
						[ -z \"\$L\" ] && continue
						shift \"\$#\"
						set -- \$__ \"\$@\"
						continue 2
						;;
					.|'')
						continue
						;;
					esac

					[ -n \"\$L\" ] && __=\$__/\$L
					L=\$A
				done

				__=\$__/\$L

				break
			done

			echo \"\$__\"
		}

		if
			(
				cd /bin || cd /usr/bin || cd /usr/local/bin || exit 1
				__=\$PWD
				cd /lib || cd /usr/lib || cd /usr/local/lib || exit 1
				[ ! \"\$__\" = \"\$PWD\" ]
				exit \"\$?\"
			) >/dev/null 2>&1
		then
			loader_getcwd() {
				__=\$PWD
			}
		else
			loader_getcwd() {
				__=\`exec pwd\`
			}
		fi

		if
			(
				set -f || exit 1
				loader_getabspath_ '/.././a/b/c/../d'
				[ \"\$__\" = '/a/b/d' ] || exit 1
				PREFIX=''
				loader_getcwd
				[ ! \"\$__\" = / ] && PREFIX=\$__
				loader_getabspath_ '/./..//*/a/b/../c /../d 0/1/2/3/4/5/6/7/8/9'
				[ \"\$__\" = \"/*/a/d 0/1/2/3/4/5/6/7/8/9\" ] || exit 1
				loader_getabspath_ './*/a/b/../c /../d 0'
				[ \"\$__\" = \"\$PREFIX/*/a/d 0\" ] && exit 10
			) >/dev/null 2>&1
			[ \"\$?\" -ne 10 ]
		then
			unset loader_getabspath_ loader_getabspath__

			if
				( [ \"\`exec getabspath /a/../.\`\" = /. ] && exit 10; ) >/dev/null 2>&1
				[ \"\$?\" -eq 10 ]
			then
				loader_getabspath_() {
					__=\`exec getabspath \"\$1\"\`
				}
			else
				loader_getabspath_() {
					loader_getcwd

					__=\`
						exec awk -- '
							BEGIN {
								PATH = ARGV[1]

								if (ARGV[1] !~ \"^[/]\")
									PATH = ARGV[2] \"/\" PATH

								FS = \"/\"
								\$0 = PATH

								T = 0

								for (F = 1; F <= NF; F++) {
									if (\$F == \".\" || \$F == \"\") {
										continue
									} else if (\$F == \"..\") {
										if (T)
											--T
									} else {
										TOKENS[T++]=\$F
									}
								}

								if (T) {
									for (I = 0; I < T; I++)
										ABS = ABS \"/\" TOKENS[I]
									if (PATH ~ /\\/\$/)
										ABS = ABS \"/\"
								} else if (PATH ~ /\\/\$/) {
									ABS = \"/\"
								} else {
									ABS = \"/.\"
								}

								print ABS

								exit
							}
						' \"\$1\" \"\$__\"
					\`
				}
			fi
		fi

		if
			(
				eval '
					__=\"a/b/c/d\"
					[ \"\${__##*/}\" = d ] && \\
					[ \"\${__%/*}\" = a/b/c ] && \\
					exit 10
				'
			) >/dev/null 2>&1
			[ \"\$?\" -eq 10 ]
		then
			eval \"
				loader_getfileexprandsubprefix() {
					case \\\"\\\$1\\\" in
					*/*)
						LOADER_FILEEXPR=\\\${1##*/}
						LOADER_SUBPREFIX=\\\${1%/*}/
						;;
					*)
						LOADER_FILEEXPR=\\\$1
						LOADER_SUBPREFIX=''
						;;
					esac
				}
			\"
		else
			loader_getfileexprandsubprefix() {
				case \"\$1\" in
				*/*)
					LOADER_FILEEXPR=\`echo \"\$1\" | sed 's@.*/@@'\`
					LOADER_SUBPREFIX=\`echo \"\$1\" | sed 's@[^/]\\+\$@@'\`
					;;
				*)
					LOADER_FILEEXPR=\$1
					LOADER_SUBPREFIX=''
					;;
				esac
			}
		fi

		loader_include_loop() {
			return 1
		}

		loader_list() {
			[ -r \"\$1\" ] || \\
				loader_fail \"directory not readable or searchable: \$1\" loader_list \"\$@\"

			loader_getcwd

			LOADER_OWD=\$__

			cd \"\$1\" || \\
				loader_fail \"failed to access directory: \$1\" loader_list \"\$@\"

			LOADER_R=1

			LOADER_LIST=\`find -maxdepth 1 -xtype f \"\$LOADER_TESTOPT\" \"\$LOADER_REGEXPREFIX\$LOADER_FILEEXPR\" -printf '\"%f\" '\`

			if [ -n \"\$LOADER_LIST\" ]; then
				loader_getcwd

				LOADER_ABSPREFIX=\$__

				[ \"\$LOADER_ABSPREFIX\" = / ] || LOADER_ABSPREFIX=\$LOADER_ABSPREFIX/

				LOADER_R=0
			fi

			cd \"\$LOADER_OWD\" || \\
				loader_fail \"failed to change back to previous directory.\" loader_list \"\$@\"

			return \"\$LOADER_R\"
		}

		loader_load() {
			loader_flag_ \"\$__\"

			set -- \"\$LOADER_SCOPE\" \"\$@\"
			LOADER_SCOPE=\$__

			loader_load_ \"\$@\"

			__=\$?
			[ -n \"\$LOADER_SCOPE\" ] && LOADER_SCOPE=\$1
			return \"\$__\"
		}

		loader_load_() {
			shift
			. \"\$__\"
		}

		if [ \"\`type local 2>/dev/null\`\" = 'local is a shell builtin' ]; then
			LOADER_LOCAL=local

			loader_loadx_loop_0() {
				eval \"
					for __ in \$LOADER_LIST; do
						__=\\\$LOADER_ABSPREFIX\\\$__
						[ -r \\\"\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$__\\\" loader_loadx_loop_0 \\\"\\\$@\\\"
						loader_load \\\"\\\$@\\\"
					done
				\"
			}

			loader_loadx_loop_1() {
				eval \"
					for __ in \$LOADER_LIST; do
						loader_flag_ \\\"\\\$LOADER_SUBPREFIX\\\$__\\\"
						__=\\\$LOADER_ABSPREFIX\\\$__
						[ -r \\\"\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$__\\\" loader_loadx_loop_1 \\\"\\\$@\\\"
						loader_load \\\"\\\$@\\\"
					done
				\"
			}

			loader_includex_loop_0() {
				eval \"
					for __ in \$LOADER_LIST; do
						__=\\\$LOADER_ABSPREFIX\\\$__
						loader_flagged \\\"\\\$__\\\" && continue
						[ -r \\\"\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$__\\\" loader_includex_loop_0 \\\"\\\$@\\\"
						loader_load \\\"\\\$@\\\"
					done
				\"
			}

			loader_includex_loop_1() {
				eval \"
					for __ in \$LOADER_LIST; do
						loader_flagged \\\"\\\$LOADER_ABSPREFIX\\\$__\\\" && continue
						loader_flag_ \\\"\\\$LOADER_SUBPREFIX\\\$__\\\"
						__=\\\$LOADER_ABSPREFIX\\\$__
						[ -r \\\"\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$__\\\" loader_includex_loop_1 \\\"\\\$@\\\"
						loader_load \\\"\\\$@\\\"
					done
				\"
			}

			loader_unsetfunctions() {
				unset loader_getabspath_ loader_getcwd
			}
		else
			loader_load_s() {
				shift \"\$1\"

				loader_flag_ \"\$__\"

				set -- \"\$LOADER_SCOPE\" \"\$@\"
				LOADER_SCOPE=\$__

				loader_load_ \"\$@\"

				__=\$?
				[ -n \"\$LOADER_SCOPE\" ] && LOADER_SCOPE=\$1
				return \"\$__\"
			}

			loader_loadx_loop_0() {
				set -- 2 \"\$LOADER_ABSPREFIX\" \"\$@\"
				eval \"
					for __ in \$LOADER_LIST; do
						__=\\\$2\\\$__
						[ -r \\\"\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$__\\\" loader_loadx_loop_0
						loader_load_s \\\"\\\$@\\\"
					done
				\"
			}

			loader_loadx_loop_1() {
				set -- 3 \"\$LOADER_ABSPREFIX\" \"\$LOADER_SUBPREFIX\" \"\$@\"
				eval \"
					for __ in \$LOADER_LIST; do
						loader_flag_ \\\"\\\$3\\\$__\\\"
						__=\\\$2\\\$__
						[ -r \\\"\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$__\\\" loader_loadx_loop_1
						loader_load_s \\\"\\\$@\\\"
					done
				\"
			}

			loader_includex_loop_0() {
				set -- 2 \"\$LOADER_ABSPREFIX\" \"\$@\"
				eval \"
					for __ in \$LOADER_LIST; do
						__=\\\$2\\\$__
						loader_flagged \\\"\\\$__\\\" && continue
						[ -r \\\"\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$__\\\" loader_includex_loop_0
						loader_load_s \\\"\\\$@\\\"
					done
				\"
			}

			loader_includex_loop_1() {
				set -- 3 \"\$LOADER_ABSPREFIX\" \"\$LOADER_SUBPREFIX\" \"\$@\"
				eval \"
					for __ in \$LOADER_LIST; do
						loader_flagged \\\"\\\$2\\\$__\\\" && continue
						loader_flag_ \\\"\\\$3\\\$__\\\"
						__=\\\$2\\\$__
						[ -r \\\"\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$__\\\" loader_includex_loop_1
						loader_load_s \\\"\\\$@\\\"
					done
				\"
			}

			loader_unsetfunctions() {
				unset loader_getabspath_ loader_getcwd loader_load_ loader_load_s
			}
		fi

		loader_resetflags() {
			eval \"unset __ \$LOADER_FLAGS\"
			LOADER_FLAGS=''
		}

		loader_resetpaths() {
			LOADER_PATHS=''
			loader_updatefunctions
		}

		loader_unsetvars() {
			loader_resetflags
			unset LOADER_FLAGS LOADER_OWD LOADER_PATHS LOADER_SCOPE LOADER_V
		}

		loader_updatefunctions() {
			if [ -n \"\$LOADER_PATHS\" ]; then
				eval \"
					loader_findfile() {
						for __ in \$LOADER_PATHS; do
							if [ -f \\\"\\\$__/\\\$1\\\" ]; then
								loader_getabspath \\\"\\\$__/\\\$1\\\"
								return 0
							fi
						done
						return 1
					}

					loader_findfiles() {
						for __ in \$LOADER_PATHS; do
							__=\\\$__/\\\$LOADER_SUBPREFIX
							[ -d \\\"\\\$__\\\" ] && loader_list \\\"\\\$__\\\" && return 0
						done
						return 1
					}

					loader_include_loop() {
						for __ in \$LOADER_PATHS; do
							loader_getabspath \\\"\\\$__/\\\$1\\\"

							if loader_flagged \\\"\\\$__\\\"; then
								loader_flag_ \\\"\\\$1\\\"

								return 0
							elif [ -f \\\"\\\$__\\\" ]; then
								[ -r \\\"\\\$__\\\" ] || loader_fail \\\"found file not readable: \\\$__\\\" loader_include_loop \\\"\\\$@\\\"

								loader_flag_ \\\"\\\$1\\\"

								shift
								loader_load \\\"\\\$@\\\"

								return 0
							fi
						done

						return 1
					}
				\"
			else
				loader_findfile() { return 1; }
				loader_findfiles() { return 1; }
				loader_include_loop() { return 1; }
			fi
		}
	"
fi

unset LOADER_ADVANCED LOADER_KSH93


# ----------------------------------------------------------------------

# * In loader_getabspath_() of ordinary shells, we require 'set -f' to
#   prevent glob characters from being parsed.  We have to place it
#   inside a subshell to make it not affect the current environment.
#   We also place the statements inside another function in an attempt
#   to make it not re-parse every command every time the subshell runs.
#   Zsh may also require 'setopt shwordsplit' but we don't have to do it
#   there since it already has its own function.

# * heirloom-sh 050706 doesn't recognize ; as a delimeter when [in ...]
#   argument is not mentioned in for loop. i.e. 'for VAR; do ...; done'
#   causes syntax error.  Also, when value of IFS is different, "$@"
#   doesn't expand to multiple arguments.

# * When no argument is passed to 'set --', it doesn't do anything.

# * Some shells can only contain 9 active positional parameters.

# ----------------------------------------------------------------------
