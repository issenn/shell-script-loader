#!/bin/bash

# ----------------------------------------------------------------------

# This script is a prototype that implements include() function of 
# Shell Script Loader (RS0) for all versions of Bash starting 4.0.
#
# Features like compatibility checks, cleanups, detailed failure
# messages, etc. are not included.
#
# Author: konsolebox
# Copyright Free / Public Domain
# June 3, 2014

# ----------------------------------------------------------------------

LOADER_PATHS=()
declare -A LOADER_FLAGS=()
declare -A LOADER_PATHS_FLAGS=()

function include {
	[[ $# -eq 0 ]] && loader_fail "Function called with no argument." include

	case "$1" in
	'')
		loader_fail "File expression cannot be null." include "$@"
		;;
	/*|./*|../*)
		loader_getabspath "$1"

		[[ -n ${LOADER_FLAGS[$__]} ]] && \
			return

		if [[ -f $__ ]]; then
			[[ -r $__ ]] || loader_fail "File not readable: $__" include "$@"

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
				[[ -r $__ ]] || loader_fail "Found file not readable: $__" include "$@"

				LOADER_FLAGS[$1]=.

				shift
				loader_load "$@"

				return
			fi
		done
		;;
	esac

	loader_fail "File not found: $1" include "$@"
}

function loader_addpath {
	for __; do
		[[ -d $__ ]] || loader_fail "Directory not found: $__" loader_addpath "$@"
		[[ -x $__ ]] || loader_fail "Directory not accessible: $__" loader_addpath "$@"
		[[ -r $__ ]] || loader_fail "Directory not searchable: $__" loader_addpath "$@"
		loader_getabspath "$__/."
		if [[ -z ${LOADER_PATHS_FLAGS[$__]} ]]; then
			LOADER_PATHS[${#LOADER_PATHS[@]}]=$__
			LOADER_PATHS_FLAGS[$__]=.
		fi
	done
}

function loader_load {
	LOADER_FLAGS[$__]=.
	. "$__"
}

function loader_getabspath {
	local -a T1 T2
	local -i I=0
	local IFS=/ A

	case "$1" in
	/*)
		read -r -a T1 <<< "$1"
		;;
	*)
		read -r -a T1 <<< "/$PWD/$1"
		;;
	esac

	T2=()

	for A in "${T1[@]}"; do
		case "$A" in
		..)
			[[ I -ne 0 ]] && unset T2\[--I\]
			continue
			;;
		.|'')
			continue
			;;
		esac

		T2[I++]=$A
	done

	case "$1" in
	*/)
		[[ I -ne 0 ]] && __="/${T2[*]}/" || __=/
		;;
	*)
		[[ I -ne 0 ]] && __="/${T2[*]}" || __=/.
		;;
	esac
}

function loader_fail {
	echo "loader: ${2}(): $1"
	exit 1
}
