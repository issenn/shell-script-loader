#!/usr/bin/env sh

# ----------------------------------------------------------------------

# loader.sh
#
# This is a generic/universal implementation of Shell Script Loader
# that targets all shells based on sh.
#
# Please see loader.txt for more info on how to use this script.
#
# This script complies with the Requiring Specifications of
# Shell Script Loader version 0 (RS0).
#
# Version: 0.2.1
#
# Author: konsolebox
# Copyright Free / Public Domain
# Aug. 29, 2009 (Last Updated 2018/01/22)

# Note:
#
# Some shells or some shell versions may not not have the full
# capability of supporting Shell Script Loader.  For example, some
# earlier versions of Zsh (earlier than 4.2) have limitations to the
# number of levels or recursions that its functions and/or commands that
# can be actively executed.

# ----------------------------------------------------------------------

#### PUBLIC VARIABLES ####

LOADER_ACTIVE=true
LOADER_RS=0
LOADER_VERSION=0.2.1

#### PUBLIC FUNCTIONS ####

load() {
	[ "$#" -eq 0 ] && loader_fail "Function called with no argument." load

	case $1 in
	'')
		loader_fail "File expression cannot be null." load "$@"
		;;
	/*|./*|../*)
		if [ -f "$1" ]; then
			loader_getcleanpath "$1"
			[ -r "$__" ] || loader_fail "File not readable: $__" load "$@"
			shift
			"$LOADER_STORE_SCOPE" -- "$LOADER_SCOPE" "$@"
			loader_load "$@"
			__=$?
			[ "$LOADER_ACTIVE" = true ] && loader_revert_scope "$1"
			return "$__"
		fi
		;;
	*)
		if loader_find_file "$1"; then
			[ -r "$__" ] || loader_fail "Found file not readable: $__" load "$@"
			loader_flag_ "$1"
			shift
			"$LOADER_STORE_SCOPE" -- "$LOADER_SCOPE" "$@"
			loader_load "$@"
			__=$?
			[ "$LOADER_ACTIVE" = true ] && loader_revert_scope "$1"
			return "$__"
		fi
		;;
	esac

	loader_fail "File not found: $1" load "$@"
}

include() {
	[ "$#" -eq 0 ] && loader_fail "Function called with no argument." include

	case $1 in
	'')
		loader_fail "File expression cannot be null." include "$@"
		;;
	/*|./*|../*)
		loader_getcleanpath "$1"
		loader_flagged "$__" && return

		if [ -f "$__" ]; then
			[ -r "$__" ] || loader_fail "File not readable: $__" include "$@"
			shift
			"$LOADER_STORE_SCOPE" -- "$LOADER_SCOPE" "$@"
			loader_load "$@"
			__=$?
			[ "$LOADER_ACTIVE" = true ] && loader_revert_scope "$1"
			return "$__"
		fi
		;;
	*)
		loader_flagged "$1" && return
		loader_include_loop "$@" && return "$__"
		;;
	esac

	loader_fail "File not found: $1" include "$@"
}

call() {
	[ "$#" -eq 0 ] && loader_fail "Function called with no argument." call

	case $1 in
	'')
		loader_fail "File expression cannot be null." call "$@"
		;;
	/*|./*|../*)
		if [ -f "$1" ]; then
			loader_getcleanpath "$1"
			[ -r "$__" ] || loader_fail "File not readable: $__" call "$@"

			(
				shift
				"$LOADER_STORE_SCOPE" -- "$LOADER_SCOPE" "$@"
				loader_load "$@"
			)

			return
		fi
		;;
	*)
		if loader_find_file "$1"; then
			[ -r "$__" ] || loader_fail "Found file not readable: $__" call "$@"

			(
				loader_flag_ "$1"
				shift
				"$LOADER_STORE_SCOPE" -- "$LOADER_SCOPE" "$@"
				loader_load "$@"
			)

			return
		fi
		;;
	esac

	loader_fail "File not found: $1" call "$@"
}

loader_addpath() {
	for __
	do
		[ -d "$__" ] || loader_fail "Directory not found: $__" loader_addpath "$@"
		[ -x "$__" ] || loader_fail "Directory not accessible: $__" loader_addpath "$@"
		[ -r "$__" ] || loader_fail "Directory not searchable: $__" loader_addpath "$@"
		loader_getcleanpath "$__"
		loader_addpath_ "$__"
	done

	loader_update_funcs
}

loader_flag() {
	[ "$#" -eq 1 ] || loader_fail "Function requires a single argument." loader_flag "$@"
	loader_getcleanpath "$1"
	loader_flag_ "$__"
}

loader_reset() {
	if [ "$#" -eq 0 ]; then
		loader_reset_flags
		loader_reset_paths
	elif [ "$1" = flags ]; then
		loader_reset_flags
	elif [ "$1" = paths ]; then
		loader_reset_paths
	else
		loader_fail "Invalid argument: $1" loader_reset "$@"
	fi
}

loader_finish() {
	LOADER_ACTIVE=false
	loader_reset_flags

	unset LOADER_CS LOADER_CS_I LOADER_FLAGS LOADER_P LOADER_PATHS \
		LOADER_PATHS_FLAGS LOADER_SCOPE LOADER_STORE_SCOPE LOADER_V

	unset -f load include call loader_addpath loader_addpath_ \
		loader_fail loader_find_file loader_finish loader_flag \
		loader_flag_ loader_flagged loader_getcleanpath \
		loader_getcleanpath_ loader_gwd loader_include_loop \
		loader_load loader_reset loader_reset_flags loader_reset_paths \
		loader_revert_scope loader_update_funcs
}

#### PRIVATE VARIABLES AND SHELL-DEPENDENT FUNCTIONS ####

LOADER_SHELL=

if [ -n "$BASH_VERSION" ]; then
	if [ "$BASH_VERSINFO" -ge 3 ] || [ "$BASH_VERSION" '>' 2.03 ]; then
		eval '
			LOADER_CS=()
			LOADER_CS_I=0
			LOADER_PATHS=()

			if [[ BASH_VERSINFO -ge 5 || (BASH_VERSINFO -eq 4 && BASH_VERSINFO[1] -ge 2) ]]; then
				declare -g -A LOADER_FLAGS=()
				declare -g -A LOADER_PATHS_FLAGS=()
				LOADER_USE_ASSOC_ARRAYS=true
			elif [[ BASH_VERSINFO -eq 4 ]] && declare -A LOADER_TEST_1 &>/dev/null && ! local LOADER_TEST_2 &>/dev/null; then
				declare -A LOADER_FLAGS=()
				declare -A LOADER_PATHS_FLAGS=()
				LOADER_USE_ASSOC_ARRAYS=true
			else
				LOADER_USE_ASSOC_ARRAYS=false
			fi
		'

		if [[ $LOADER_USE_ASSOC_ARRAYS == true ]]; then
			eval '
				function loader_addpath_ {
					if [[ -z ${LOADER_PATHS_FLAGS[$1]} ]]; then
						LOADER_PATHS[${#LOADER_PATHS[@]}]=$1
						LOADER_PATHS_FLAGS[$1]=.
					fi
				}

				loader_flag_() {
					LOADER_FLAGS[$1]=.
				}

				function loader_flagged {
					[[ -n ${LOADER_FLAGS[$1]} ]]
				}

				function loader_reset_flags {
					LOADER_FLAGS=()
				}

				function loader_reset_paths {
					LOADER_PATHS=()
					LOADER_PATHS_FLAGS=()
				}
			'
		else
			eval '
				function loader_addpath_ {
					for __ in "${LOADER_PATHS[@]}"; do
						[[ $1 = "$__" ]] && return
					done

					LOADER_PATHS[${#LOADER_PATHS[@]}]=$1
				}

				loader_flag_() {
					local v
					v=${1//./_dt_}
					v=${v// /_sp_}
					v=${v//\//_sl_}
					v=LOADER_FLAGS_${v//[^[:alnum:]_]/_ot_}
					eval "$v=."
				}

				function loader_flagged {
					local v
					v=${1//./_dt_}
					v=${v// /_sp_}
					v=${v//\//_sl_}
					v=LOADER_FLAGS_${v//[^[:alnum:]_]/_ot_}
					[[ -n ${!v} ]]
				}

				function loader_reset_flags {
					unset "${!LOADER_FLAGS_@}"
				}

				function loader_reset_paths {
					LOADER_PATHS=()
				}

			'
		fi

		unset LOADER_USE_ASSOC_ARRAYS

		eval '
			function loader_getcleanpath_ {
				local t=() i=0 IFS=/

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
			}
		'

		LOADER_SHELL=bash
	fi
elif [ -n "$ZSH_VERSION" ]; then
	if [ ! "$ZSH_NAME" = sh ] && [ ! "$ZSH_NAME" = ksh ] && eval '[ "${ZSH_VERSION%%.*}" -ge 4 ]'; then
		typeset -g -a LOADER_CS
		typeset -g -i LOADER_CS_I=0
		typeset -g -A LOADER_FLAGS
		typeset -g -a LOADER_PATHS
		typeset -g -A LOADER_PATHS_FLAGS

		eval '
			function loader_addpath_ {
				if [[ -z ${LOADER_PATHS_FLAGS[$1]} ]]; then
					LOADER_PATHS[${#LOADER_PATHS[@]}+1]=$1
					LOADER_PATHS_FLAGS[$1]=.
				fi
			}

			loader_flag_() {
				LOADER_FLAGS[$1]=.
			}

			function loader_flagged {
				[[ -n ${LOADER_FLAGS[$1]} ]]
			}

			function loader_getcleanpath_ {
				local t i=0 IFS=/
				set -A t

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
						(( i )) && t[i--]=()
						continue
						;;
					.|"")
						continue
						;;
					esac

					t[++i]=$__
				done

				__="/${t[*]}"
			}

			function loader_reset_flags {
				set -A LOADER_FLAGS
			}

			function loader_reset_paths {
				set -A LOADER_PATHS
				set -A LOADER_PATHS_FLAGS
			}
		'

		LOADER_SHELL=zsh
	fi
else
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
		esac
	fi

	if [ -n "$LOADER_SHELL" ]; then
		set -A LOADER_CS
		LOADER_CS_I=0
		set -A LOADER_PATHS

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
			eval '
				loader_addpath_() {
					for __ in "${LOADER_PATHS[@]}"; do
						[[ $1 = "$__" ]] && return
					done

					LOADER_PATHS[${#LOADER_PATHS[@]}]=$1
				}
			'

			if [[ $LOADER_SHELL == mksh ]]; then
				eval '
					loader_flag_() {
						typeset v=${1//./_dt_}
						v=${v// /_sp_}
						v=${v//\//_sl_}
						v=LOADER_FLAGS_${v//[!a-zA-Z0-9_]/_ot_}
						typeset -n r=$v
						r=.
					}

					loader_flagged() {
						typeset v=${1//./_dt_}
						v=${v// /_sp_}
						v=${v//\//_sl_}
						v=LOADER_FLAGS_${v//[!a-zA-Z0-9_]/_ot_}
						typeset -n r=$v
						[[ -n $r ]]
					}
				'
			else
				hash sed

				loader_flag_() {
					eval "LOADER_FLAGS_$(echo "$1" | sed 's/\./_dt_/g; s/\//_sl_/g; s/ /_sp_/g; s/[^[:alnum:]_]/_ot_/g')=."
				}

				loader_flagged() {
					eval "[[ -n \$LOADER_FLAGS_$(echo "$1" | sed 's/\./_dt_/g; s/\//_sl_/g; s/ /_sp_/g; s/[^[:alnum:]_]/_ot_/g') ]]"
				}
			fi

			hash grep cut

			loader_reset_flags() {
				typeset IFS='
'
				unset `set | grep -a ^LOADER_FLAGS_ | cut -f 1 -d =`
			}

			loader_reset_paths() {
				set -A LOADER_PATHS
			}
		fi

		__='{
			typeset t i=0 IFS=/

			case $1 in
			/*)
				__=$1
				;;
			*)
				__=$PWD/$1
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
			eval "function loader_getcleanpath_ $__"
		else
			eval "loader_getcleanpath_() $__"
		fi
	fi
fi

if [ -n "$LOADER_SHELL" ]; then
	if [[ $LOADER_SHELL == ksh93 ]]; then
		LOADER_ECHO='print -r'
	else
		LOADER_ECHO='echo -E'
	fi

	eval "
		loader_fail() {
			MESSAGE=\$1 FUNC=\$2
			shift 2

			{
				$LOADER_ECHO \"loader: \$FUNC(): \$MESSAGE\"
				$LOADER_ECHO
				$LOADER_ECHO \"  Current scope:\"

				if [[ LOADER_CS_I -gt 0 ]]; then
					$LOADER_ECHO \"    \${LOADER_CS[LOADER_CS_I]}\"
				else
					$LOADER_ECHO \"    (main)\"
				fi

				$LOADER_ECHO

				if [[ \$# -gt 0 ]]; then
					$LOADER_ECHO \"  Command:\"
					$LOADER_ECHO -n \"    \$FUNC\"

					for __; do
						$LOADER_ECHO -n \" \\\"\$__\\\"\"
					done

					$LOADER_ECHO
					$LOADER_ECHO
				fi

				if [[ LOADER_CS_I -gt 0 ]]; then
					$LOADER_ECHO \"  Call stack:\"
					$LOADER_ECHO \"    (main)\"
					I=1

					while [[ I -le LOADER_CS_I ]]; do
						$LOADER_ECHO \"    -> \${LOADER_CS[I]}\"
						(( ++I ))
					done

					$LOADER_ECHO
				fi

				$LOADER_ECHO \"  Search paths:\"

				if [[ \${#LOADER_PATHS[@]} -gt 0 ]]; then
					for __ in \"\${LOADER_PATHS[@]}\"; do
						$LOADER_ECHO \"    \$__\"
					done
				else
					$LOADER_ECHO \"    (empty)\"
				fi

				$LOADER_ECHO
				$LOADER_ECHO \"  Working directory:\"
				$LOADER_ECHO \"    \$PWD\"
				$LOADER_ECHO
			} >&2

			exit 1
		}
	"

	unset LOADER_ECHO

	eval '
		loader_find_file() {
			for __ in "${LOADER_PATHS[@]}"; do
				if [[ -f $__/$1 ]]; then
					loader_getcleanpath "$__/$1"
					return 0
				fi
			done

			return 1
		}

		loader_getcleanpath() {
			case $1 in
			.|"")
				__=$PWD
				;;
			/)
				__=/
				;;
			..|../*|*/..|*/../*|./*|*/.|*/./*|*//*)
				loader_getcleanpath_ "$1"
				;;
			/*)
				__=${1%/}
				;;
			*)
				__=${PWD%/}/${1%/}
				;;
			esac
		}

		loader_include_loop() {
			for __ in "${LOADER_PATHS[@]}"; do
				loader_getcleanpath "$__/$1"

				if loader_flagged "$__"; then
					loader_flag_ "$1"
					__=0
					return 0
				elif [[ -f $__ ]]; then
					[[ -r $__ ]] || loader_fail "Found file not readable: $__" include "$@"
					loader_flag_ "$1"
					shift
					loader_load "$@"
					__=$?
					[[ $LOADER_ACTIVE == true ]] && loader_revert_scope
					return 0
				fi
			done

			return 1
		}

		loader_load() {
			loader_flag_ "$__"
			LOADER_CS[++LOADER_CS_I]=$__
			. "$__"
		}
	'

	LOADER_STORE_SCOPE=:

	if [[ $LOADER_SHELL == zsh ]]; then
		eval '
			loader_revert_scope() {
				LOADER_CS[LOADER_CS_I--]=()
			}
		'
	else
		eval '
			loader_revert_scope() {
				unset LOADER_CS\[LOADER_CS_I--\]
			}
		'
	fi

	loader_gwd() { :; }
	loader_update_funcs() { :; }
else
	LOADER_FLAGS=
	LOADER_PATHS=
	LOADER_SCOPE='(main)'
	LOADER_V=

	if ( [ "`type hash`" = 'hash is a shell builtin' ] ) >/dev/null 2>&1; then
		loader_hash() { hash "$@"; }
	else
		loader_hash() { :; }
	fi

	loader_addpath_() {
		LOADER_P=$1

		if [ -n "$LOADER_PATHS" ]; then
			eval "set -- $LOADER_PATHS"

			for __
			do
				[ "$__" = "$LOADER_P" ] && return
			done
		fi

		case $LOADER_P in
		*\'*)
			loader_fail "Can't support directory names with single quotes in this shell." loader_addpath "$@"
			;;
		esac

		LOADER_PATHS=$LOADER_PATHS" '$LOADER_P'"
	}

	loader_fail() {
		MESSAGE=$1 FUNC=$2
		shift 2

		{
			echo "loader: $FUNC(): $MESSAGE"
			echo
			echo "  Current scope:"
			echo "    $LOADER_SCOPE"
			echo

			if [ "$#" -gt 0 ]; then
				echo "  Command:"
				CMD="    $FUNC"

				for __
				do
					CMD=$CMD" \"$__\""
				done

				echo "$CMD"
				echo
			fi

			echo "  Search paths:"

			if [ -n "$LOADER_PATHS" ]; then
				eval "set -- $LOADER_PATHS"

				for __
				do
					echo "    $__"
				done
			else
				echo "    (empty)"
			fi

			echo
			echo "  Working directory:"
			loader_gwd
			echo "    $__"
			echo
		} >&2

		exit 1
	}

	loader_find_file() {
		return 1
	}

	if
		(
			eval '
				__="ABCabc. /*?" && \
				__=${__//./_dt_} && \
				__=${__// /_sp_} && \
				__=${__//\//_sl_} && \
				__=${__//[^A-Za-z0-9_]/_ot_} && \
				[ "$__" = "ABCabc_dt__sp__sl__ot__ot_" ] && \
				exit 10
			'
		) >/dev/null 2>&1
		[ "$?" -eq 10 ]
	then
		eval '
			loader_flag_() {
				LOADER_V=${1//./_dt_}
				LOADER_V=${LOADER_V// /_sp_}
				LOADER_V=${LOADER_V//\//_sl_}
				LOADER_V=LOADER_FLAGS_${LOADER_V//[^A-Za-z0-9_]/_ot_}
				eval "$LOADER_V=."
				LOADER_FLAGS=$LOADER_FLAGS\ $LOADER_V
			}

			loader_flagged() {
				LOADER_V=${1//./_dt_}
				LOADER_V=${LOADER_V// /_sp_}
				LOADER_V=${LOADER_V//\//_sl_}
				LOADER_V=LOADER_FLAGS_${LOADER_V//[^A-Za-z0-9_]/_ot_}
				eval "[ -n \"\$$LOADER_V\" ]"
			}
		'
	else
		loader_hash sed

		loader_flag_() {
			LOADER_V=LOADER_FLAGS_`echo "$1" | sed 's/\./_dt_/g; s/ /_sp_/g; s/\//_sl_/g; s/[^[:alnum:]_]/_ot_/g'`
			eval "$LOADER_V=."
			LOADER_FLAGS=$LOADER_FLAGS\ $LOADER_V
		}

		loader_flagged() {
			LOADER_V=LOADER_FLAGS_`echo "$1" | sed 's/\./_dt_/g; s/ /_sp_/g; s/\//_sl_/g; s/[^[:alnum:]_]/_ot_/g'`
			eval "[ -n \"\$$LOADER_V\" ]"
		}
	fi

	if
		(
			__=$PWD

			if [ -n "$__" ]; then
				for D in / /bin /dev /etc /home /lib /opt /run /usr /var /tmp; do
					[ ! "$D" = "$__" ] && cd "$D" && [ ! "$PWD" = "$__" ] && exit 0
				done
			fi

			exit 1
		) >/dev/null 2>&1
	then
		loader_gwd() {
			__=$PWD
		}
	elif ( [ "`type pwd`" = 'pwd is a shell builtin' ] ) >/dev/null 2>&1; then
		loader_gwd() {
			__=`pwd`
		}
	else
		loader_hash pwd

		loader_gwd() {
			__=`exec pwd`
		}
	fi

	__=
	loader_gwd
	[ -z "$__" ] && echo "loader: Unable to get current directory." >&2

	loader_getcleanpath() {
		case $1 in
		.|'')
			loader_gwd
			;;
		/)
			__=/
			;;
		..|../*|*/..|*/../*|./*|*/.|*/./*|*//*|*/)
			loader_getcleanpath_ "$1"
			;;
		/*)
			__=$1
			;;
		*)
			loader_gwd

			case $__ in
			/)
				__=/$1
				;;
			*)
				__=$__/$1
				;;
			esac
			;;
		esac
	}

	loader_getcleanpath_() {
		GETCLEANPATH_OLD_IFS=$IFS IFS=/
		GETCLEANPATH_FLAGS=$-
		set -f

		case $1 in
		/*)
			set -- $1
			;;
		*)
			loader_gwd
			set -- $__ $1
			;;
		esac

		__=

		while [ "$#" -gt 0 ]; do
			case $1 in
			.|''|..)
				shift
				continue
				;;
			esac

			GETCLEANPATH_TEMP=$1
			shift

			while [ "$#" -gt 0 ]; do
				case $1 in
				.|'')
					shift
					continue
					;;
				esac

				break
			done

			case $1 in
			..)
				shift
				set -- $__ "$@"
				__=
				continue
				;;
			esac

			__=$__/$GETCLEANPATH_TEMP
		done

		case $GETCLEANPATH_FLAGS in
		*f*)
			;;
		*)
			set +f
			;;
		esac

		IFS=$GETCLEANPATH_OLD_IFS
		[ -z "$__" ] && __=/
	}

	if
		(
			set -f || exit 1
			loader_getcleanpath_ '/.././a/b/c/../d'
			[ "$__" = '/a/b/d' ] || exit 1
			loader_getcleanpath_ '/./..//*/a/b/../c /../d 0/1/2/3/4/5/6/7/8/9'
			[ "$__" = '/*/a/d 0/1/2/3/4/5/6/7/8/9' ] || exit 1
			loader_gwd
			[ ! "$__" = / ] && PREFIX=$__ || PREFIX=
			__=
			loader_getcleanpath_ './*/a/b/../c /../d 0'
			[ "$__" = "$PREFIX/*/a/d 0" ] && exit 10
		)
		[ "$?" -ne 10 ]
	then
		if ( [ "`exec getcleanpath /a/../.`" = / ] ) >/dev/null 2>&1; then
			loader_hash getcleanpath

			loader_getcleanpath_() {
				__=`exec getcleanpath "$1"`
			}
		else
			loader_hash awk

			loader_getcleanpath_() {
				loader_gwd

				__=`
					exec awk -- '
						BEGIN {
							FS = "/"
							path = ARGV[1]

							if (path !~ /^\//)
								path = ARGV[2] FS path

							$0 = path
							t = 0

							for (f = 1; f <= NF; ++f) {
								if ($f == "." || $f == "") {
									continue
								} else if ($f == "..") {
									if (t)
										--t
								} else {
									tokens[t++]=$f
								}
							}

							if (t) {
								abs = FS tokens[0]

								for (i = 1; i < t; ++i)
									abs = abs FS tokens[i]

								print abs
							} else
								print FS

							exit
						}
					' "$1" "$__"
				`
			}
		fi
	fi

	loader_include_loop() {
		return 1
	}

	loader_load() {
		loader_flag_ "$__"
		LOADER_SCOPE=$1
		shift
		. "$__"
	}

	LOADER_STORE_SCOPE=set

	loader_revert_scope() {
		LOADER_SCOPE=$1
	}

	loader_reset_flags() {
		eval "unset LOADER_FLAGS $LOADER_FLAGS"
	}

	loader_reset_paths() {
		LOADER_PATHS=
		loader_update_funcs
	}

	loader_update_funcs() {
		if [ -n "$LOADER_PATHS" ]; then
			eval "
				loader_find_file() {
					for __ in $LOADER_PATHS; do
						if [ -f \"\$__/\$1\" ]; then
							loader_getcleanpath \"\$__/\$1\"
							return 0
						fi
					done

					return 1
				}

				loader_include_loop() {
					for __ in $LOADER_PATHS; do
						loader_getcleanpath \"\$__/\$1\"

						if loader_flagged \"\$__\"; then
							loader_flag_ \"\$1\"
							__=0
							return 0
						elif [ -f \"\$__\" ]; then
							[ -r \"\$__\" ] || loader_fail \"Found file not readable: \$__\" include \"\$@\"
							loader_flag_ \"\$1\"
							shift
							set -- \"\$LOADER_SCOPE\" \"\$@\"
							loader_load \"\$@\"
							__=\$?
							[ \"\$LOADER_ACTIVE\" = true ] && LOADER_SCOPE=\$1
							return 0
						fi
					done

					return 1
				}
			"
		else
			loader_find_file() { return 1; }
			loader_include_loop() { return 1; }
		fi
	}

	unset -f loader_hash
fi

unset LOADER_SHELL

# ----------------------------------------------------------------------

# * In loader_getcleanpath_() of ordinary shells, we require 'set -f' to
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

# * When no argument is passed to 'set --' in heirloom-sh, the
#   positional parameters are not reset.

# * Some shells can only contain 9 active positional parameters.

# ----------------------------------------------------------------------
