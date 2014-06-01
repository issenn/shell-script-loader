#!/usr/bin/env gawk -f

# ----------------------------------------------------------------------

# compiler.gawk
#
# This script is a prototype compiler and attempts to comply with the
# Requiring Specifications of Shell Script Loader version 0 (RS0) and
# derived or similar versions like RS0X, RS0L and RS0S.
#
# The script also still have some limitations with script runtime
# emulation like not yet being able to recurse to call() and callx()
# functions.  We know that call() summons file(s) inside a new
# environment or subshell so implementing it needs very careful planning
# and may cause heavy overhaul to the whole code.  One of difficult task
# with respect to this is knowing the proper way to handle code on files
# that are called after a call since virtually it should run to a new
# subshell and therefore things like errors (may it be syntactical or
# not) should be separated from the handling of the parent script.  One
# of the solutions I currently thought on how to make this work is by
# using double-indexed associative arrays on the virtual stacks that
# increments everytime a new context is entered.  That may be the a good
# solution but it may also cause a slight minus on runtime speed.  With
# relation to the handling of errors, I probably can also solve it by
# adding new options that may tell the compiler if it should bail out if
# an error is found in a sub-context or not.  Timewise though, making
# these changes will probably beat a lot of it and it's also not a
# guarantee if these big changes will yield a stable code soon.  Also,
# thinking that the current code is already about 97.0 to 99.5% stable
# (as tests shows), I thought that it's better if I just make a new
# release first than immediately starting to apply new changes to it.
#
# Hopefully, full support for Shell Script Loader may be finished when
# RSO is finalized or when the its first stable version is released.
#
# Aside from the functions, there are also additional directives that
# are recognized by this compiler:
#
# (a) #beginskipblock - #endskipblock /
#     #begincompilerskip - #endcompilerskip
#
#     specifies that text will not be included from compilation
#
# (a) #beginnoparseblock - #endnoparseblock /
#     #begincompilernoparse - #endcompilernoparse
#
#     specifies that text will be include but not parsed or will just be
#     treated as plain text
#
# (c) #beginnoindentblock - #endnoindentblock /
#     #begincompilernoindent - #endcompilernoindent
#
#     specifies that text will not be indented when included inside call
#     functions
#
# Example startup scripts that's compatible with the compiler
#
# ----------------------------------------------------------------------
#
#  #!/bin/sh
#
#  #beginskipblock
#  if [ "$LOADER_ACTIVE" = true ]; then
#      # Shell Script Loader was not yet loaded from any previous
#      # context. We'll load it here. The conditional expression above
#      # is only optional and may be excluded if the script is intended
#      # not to be called from call() or callx().
#      . "<some path to>/loader.sh"
#  else
#  #endskipblock
#      # Include a command that will prevent using flags if this script
#      # is called with call() or callx(). If the compiler sees this
#      # line, it should also reset the flags for this context but it's
#      # currently not yet supported. This is also just optional and
#      # also depends on the intended on usage of the script.
#      loader_reset
#  #beginskipblock
#  fi
#  #endskipblock
#
#  # Add paths, this block may also be quoted with #beginskipblock
#  # if the paths are intended to be added using the '--addpath' option
#  # of the compiler.
#  loader_addpath "<path1>" "<path2>"
#
#  # Since this is the main script, flag it. Just optional.
#  loader_flag "<path to this script>"
#
#  ....
#
# ----------------------------------------------------------------------
#
#  #!/bin/sh
#
#  # Simpler and less confusing version. This script is intended to be
#  # not included with any previous loader commands.
#
#  #beginskipblock
#  . "<some path to>/loader.sh"
#  #endskipblock
#
#  loader_addpath "<path1>" "<path2>"
#
#  #optional
#  loader_flag "<path to this script>"
#
#  ....
#
# ----------------------------------------------------------------------
#
# There's also a cleaner solution where you can just use two different
# scripts like start.sh and main.sh where start.sh is the starter script
# that loads Shell Script Loader and adds paths; and main.sh is the main
# script that also loads co-shell-scripts.  The starter script will not
# be specified during compile, it will only be called when the script is
# to run in the shell.  The main script will be the only one that will
# be specified during compile.  The paths also can just be specified
# with the option '--addpath' of this compiler.
#
# To know some more info about using this script, run it with the option
# '--usage' or '--help'.
#
# Version: 0.WP20131011 ( Working Prototype 2013/10/11
#                         for RS0, RS0X, RS0L and RS0S )
#
# Author: konsolebox
# Copyright Free / Public Domain
# Aug. 29, 2009 (Last Updated 2013/10/11)

# ----------------------------------------------------------------------


# Global Constants and Variables

function GLOBALS() {

	compiler_version = "0.WP20131011"

	compiler_defaultoutput   = "/dev/stdout"
	compiler_callsobjfile    = "compiler.calls.obj"
	compiler_mainobjfile     = "compiler.main.obj"
	compiler_completeobjfile = "compiler.comp.obj"
#	compiler_tempfile        = "compiler.temp"
	compiler_tempdir         = ""
	compiler_noinfo          = 0
	compiler_noindent        = 0
	compiler_debugmode       = 0
	compiler_deprecatedmode  = 0
	compiler_extended        = 0

#	compiler_calls_funcnames[]
#	compiler_calls_groupcallseeds[]
#	compiler_calls_hashes[]
#	compiler_flags[]
#	compiler_keywords[]
	compiler_ignoreaddpaths = 0
	compiler_ignoreresets = 0
#	compiler_makehash_ctable[]
#	compiler_makehash_defaulthashlength
#	compiler_makehash_itable[]
#	compiler_paths[]
	compiler_paths_count = 0
#	compiler_paths_flags[]
	compiler_walk_current_file = ""
	compiler_walk_current_line = ""
	compiler_walk_current_line_number = 0
	compiler_walk_current_noindent = 0
	compiler_walk_current_noindent_start = 0
#	compiler_walk_stack_file[]
	compiler_walk_stack_i = 0
#	compiler_walk_stack_line[]
#	compiler_walk_stack_line_number[]

}


# Main Function

function compiler \
( \
\
	a, abs, b, i, files, files_count, headerfile, outputfile, shell, sedargs, \
	strip, stripcomments, stripblanklines, stripextrablanklines, \
	stripleadingspaces, striptrailingcomments, striptrailingspaces, usesed \
)
{
	compiler_log_debug("compiler() [" ARGS "]")

	# Get current working directory

	compiler_wd = compiler_getwd()

	if (compiler_wd == "")
		compiler_log_failure("unable to get path of current working directory")

	# Parse Command-line

	for (i = 1; i < ARGC; ++i) {
		a = ARGV[i]

		if (a == "") {
			compiler_log_failure("one of the arguments is empty.")
		} else if (a == "-a" || a == "--addpath") {
			b = ARGV[++i]

			if (i == ARGC || length(b) == 0)
				compiler_log_failure("this option requires an argument: " a)

			if (! compiler_test("-d", b))
				compiler_log_failure("directory not found:" b)

			compiler_addpath(b)
		} else if (a == "--debug") {
			compiler_debugmode = 1
		} else if (a == "--deprecated") {
			compiler_deprecatedmode = 1
		} else if (a == "-x" || a == "--extended") {
			compiler_extended = 1
		} else if (a == "-h" || a == "--help" || a == "--usage") {
			compiler_showinfoandusage()
			exit(1)
		} else if (a == "-H" || a == "--header") {
			b = ARGV[++i]

			if (i == ARGC || length(b) == 0)
				compiler_log_failure("this option requires an argument: " a)

			if (! compiler_test("-f", b))
				compiler_log_failure("header file not found: " b)

			headerfile = b
		} else if (a == "-ia" || a == "--ignore-addpaths") {
			compiler_ignoreaddpaths = 1
		} else if (a == "-ir" || a == "--ignore-resets") {
			compiler_ignoreresets = 1
		} else if (a == "-n" || a == "--no-info") {
			compiler_noinfo = 1
		} else if (a == "-ni" || a == "--no-indent") {
			compiler_noindent = 1
		} else if (a == "-o" || a == "--output") {
			if (length(outputfile))
				compiler_log_failure("output file should not be specified twice")

			b = ARGV[++i]

			if (i == ARGC || length(b) == 0)
				compiler_log_failure("this option requires an argument: " a)

			outputfile = b
		} else if (a == "-O") {
			compiler_noinfo = 1
			strip = 1
			stripcomments = 1
			stripextrablanklines = 1
			striptrailingspaces = 1
		} else if (a == "--RS0") {
			# default always; just for reference
			compiler_deprecatedmode = 0
			compiler_extended = 0
		} else if (a == "--RS0X") {
			compiler_deprecatedmode = 0
			compiler_extended = 1
		} else if (a == "--RS0L") {
			compiler_deprecatedmode = 1
			compiler_extended = 0
		} else if (a == "--RS0S") {
			compiler_deprecatedmode = 1
			compiler_extended = 1
		} else if (a == "--sed") {
			usesed = 1
		} else if (a == "-s" || a == "--shell") {
			b = ARGV[++i]

			if (i == ARGC || length(b) == 0)
				compiler_log_failure("this option requires an argument: " a)

			shell = b
		} else if (a == "--strip-bl") {
			strip = 1
			stripblanklines = 1
		} else if (a == "--strip-c") {
			strip = 1
			stripcomments = 1
		} else if (a == "--strip-ebl") {
			strip = 1
			stripextrablanklines = 1
		} else if (a == "--strip-ls") {
			strip = 1
			stripleadingspaces = 1
		} else if (a == "--strip-tc") {
			strip = 1
			striptrailingcomments = 1
		} else if (a == "--strip-ts") {
			strip = 1
			striptrailingspaces = 1
		} else if (a == "--strip-all") {
			strip = 1
			stripblanklines = 1
			stripcomments = 1
			stripleadingspaces = 1
			striptrailingcomments = 1
			striptrailingspaces = 1
		} else if (a == "--strip-all-safe") {
			strip = 1
			stripcomments = 1
			stripextrablanklines = 1
			striptrailingspaces = 1
		} else if (a == "--tempdir") {
			b = ARGV[++i]

			if (i == ARGC || length(b) == 0)
				compiler_log_failure("this option requires an argument: " a)

			if (! compiler_test("-d", b))
				compiler_log_failure("directory not found:" b)

			compiler_tempdir = b
		} else if (a == "-V" || a == "--version") {
			compiler_showversioninfo()
			exit(1)
		} else if (compiler_test("-f", a)) {
			files[files_count++] = a
		} else if (compiler_test("-d", a)) {
			compiler_log_failure("argument is a directory and not a file: " a)
		} else if (a ~ /-.*/) {
			compiler_log_failure("invalid option: " a)
		} else {
			compiler_log_failure("invalid argument or file not found: " a)
		}
	}

	# Checks and Initializations

	if (files_count == 0)
		compiler_log_failure("no input file was entered")

	if (length(outputfile) == 0)
		outputfile = compiler_defaultoutput

	if (outputfile != "/dev/stdout" && outputfile != "/dev/stderr")
		if (! compiler_truncatefile(outputfile))
			compiler_log_failure("unable to truncate output file \"" outputfile "\"")

	if (compiler_tempdir) {
		compiler_mainobjfile = compiler_getabspath(compiler_tempdir "/") compiler_mainobjfile
		compiler_callsobjfile = compiler_getabspath(compiler_tempdir "/") compiler_callsobjfile
		compiler_completeobjfile = compiler_getabspath(compiler_tempdir "/") compiler_completeobjfile
	}

	if (! compiler_truncatefile(compiler_mainobjfile))
		compiler_log_failure("unable to truncate main object file \"" compiler_mainobjfile "\"")

	if (! compiler_truncatefile(compiler_callsobjfile))
		compiler_log_failure("unable to truncate calls object file \"" compiler_callsobjfile "\"")

	if (! compiler_truncatefile(compiler_completeobjfile))
		compiler_log_failure("unable to truncate complete object file \"" compiler_completeobjfile "\"")

	compiler_makehash_initialize(1, 8)

	# Reserved keywords

	compiler_keywords["load"] = 1
	compiler_keywords["include"] = 1
	compiler_keywords["call"] = 1

	if (compiler_extended) {
		compiler_keywords["loadx"] = 1
		compiler_keywords["includex"] = 1
		compiler_keywords["callx"] = 1
	}

	if (compiler_deprecatedmode) {
		compiler_keywords["addpath"] = 1
		compiler_keywords["resetloader"] = 1
		compiler_keywords["finishloader"] = 1
	} else {
		compiler_keywords["loader_addpath"] = 1
		compiler_keywords["loader_flag"] = 1
		compiler_keywords["loader_reset"] = 1
		compiler_keywords["loader_finish"] = 1
	}

	compiler_keywords["beginnoindentblock"] = 1
	compiler_keywords["BEGINNOINDENTBLOCK"] = 1
	compiler_keywords["begincompilernoindent"] = 1
	compiler_keywords["BEGINCOMPILERNOINDENT"] = 1
	compiler_keywords["endnoindentblock"] = 1
	compiler_keywords["ENDNOINDENTBLOCK"] = 1
	compiler_keywords["endcompilernoindent"] = 1
	compiler_keywords["ENDCOMPILERNOINDENT"] = 1
	compiler_keywords["beginskipblock"] = 1
	compiler_keywords["BEGINSKIPBLOCK"] = 1
	compiler_keywords["begincompilerskip"] = 1
	compiler_keywords["BEGINCOMPILERSKIP"] = 1
	compiler_keywords["endskipblock"] = 1
	compiler_keywords["ENDSKIPBLOCK"] = 1
	compiler_keywords["endcompilerskip"] = 1
	compiler_keywords["ENDCOMPILERSKIP"] = 1
	compiler_keywords["beginnoparseblock"] = 1
	compiler_keywords["BEGINNOPARSEBLOCK"] = 1
	compiler_keywords["begincompilernoparse"] = 1
	compiler_keywords["BEGINCOMPILERNOPARSE"] = 1
	compiler_keywords["endnoparseblock"] = 1
	compiler_keywords["ENDNOPARSEBLOCK"] = 1
	compiler_keywords["endcompilernoparse"] = 1
	compiler_keywords["ENDCOMPILERNOPARSE"] = 1

	# Walk Throughout

	for (i = 0; i < files_count; i++) {
		abs = compiler_getabspath(files[i])

		compiler_flags[abs] = 1

		compiler_walk(abs)
	}

	# Finish

	close(compiler_callsobjfile)
	close(compiler_mainobjfile)

	compiler_dump(compiler_callsobjfile, compiler_completeobjfile, 1)
	compiler_removefile(compiler_callsobjfile)

	compiler_dump(compiler_mainobjfile, compiler_completeobjfile, 1)
	compiler_removefile(compiler_mainobjfile)

	if (strip) {
		# just use sed for now

		compiler_log_message("strip: " compiler_completeobjfile)

		if (stripcomments) {
			sedargs = sedargs "'/^[[:blank:]]*#/d;'"
		}
		if (striptrailingcomments) {
			sedargs = sedargs "'s/[[:blank:]]\\+#[^'\\''|&;]*$//;'"
		}
		if (stripleadingspaces) {
			sedargs = sedargs "'s/^[[:blank:]]\\+//;'"
		}
		if (striptrailingspaces) {
			sedargs = sedargs "'s/[[:blank:]]\\+$//;'"
		}
		if (sedargs) {
			if (system("sed -i " sedargs " \"" compiler_completeobjfile "\"") != 0) {
				compiler_log_failure("failed to strip object file with sed.")
			}
		}
		if (stripblanklines) {
			if (system("sed -i '/^$/d;' \"" compiler_completeobjfile "\"") != 0) {
				compiler_log_failure("failed to strip object file with sed.")
			}
		} else if (stripextrablanklines) {
			if (system("sed -i '/./,/^$/!d;' \"" compiler_completeobjfile "\"") != 0) {
				compiler_log_failure("failed to strip object file with sed.")
			}
		}
	}

	if (shell) {
		compiler_log_message("add #! header: \"#!" shell "\" > " outputfile)
		print "#!" shell "\n" > outputfile
	}

	if (headerfile) {
		compiler_log_message("add header file: " headerfile " > " outputfile)
		compiler_dump(headerfile, outputfile, 1)
		print "" >> outputfile
	}

	# add info header here next time
	#
	# > if (!compiler_noinfo)
	# > 	... add compile info header >> outputfile

	compiler_dump(compiler_completeobjfile, outputfile, 1)

	compiler_removefile(compiler_completeobjfile)

	close(outputfile)

	close("/dev/stdout")
	close("/dev/stderr")

	exit(0)
}


# Info Functions

function compiler_showinfoandusage() {
	compiler_log_stderr("Prototype Compiler for shell scripts based from Shell Script Loader")
	compiler_log_stderr("Version: " compiler_version)
	compiler_log_stderr("")
	compiler_log_stderr("Usage Summary: compiler.gawk [options [optarg]] file1[, file2, ...]")
	compiler_log_stderr("")
	compiler_log_stderr("Options:")
	compiler_log_stderr("")
	compiler_log_stderr("-a,  --addpath [path]  Add a path to the search list.")
	compiler_log_stderr("     --debug           Enable debug mode.")
	compiler_log_stderr("     --deprecated      Deprecated mode. Parse deprecated functions instead.")
	compiler_log_stderr("-h,  --help|--usage    Show this message")
	compiler_log_stderr("-H,  --header [file]   Insert a file at the top of the compiled form. This can")
	compiler_log_stderr("		       be used to insert program description and license info.")
	compiler_log_stderr("-ia, --ignore-addpaths Ignore embedded addpath commands in scripts.")
	compiler_log_stderr("-ir, --ignore-resets   Ignore embedded reset commands in scripts.")
	compiler_log_stderr("-n,  --no-info         Do not add informative comments.")
	compiler_log_stderr("-ni, --no-indent       Do not add extra alignment indents to contents when compiling.")
	compiler_log_stderr("-o,  --output [file]   Use file for output instead of stdout.")
	compiler_log_stderr("-O                     Optimize. (enables --strip-all-safe, and --no-info)")
	compiler_log_stderr("     --RS0             Parse commands based from RS0 (default).")
	compiler_log_stderr("     --RS0X            Parse commands based from RS0X (--extended).")
	compiler_log_stderr("     --RS0L            Parse commands based from RS0L (--deprecated).")
	compiler_log_stderr("     --RS0S            Parse commands based from RS0S (--deprecated + --extended).")
	compiler_log_stderr("     --sed             Use sed by default in some operations like stripping.")
	compiler_log_stderr("-s,  --shell [path]    Includes a '#!<path>' header to the output.")
	compiler_log_stderr("     --strip-bl        Strip all blank lines.")
	compiler_log_stderr("     --strip-c         Strip comments from code. (safe)")
	compiler_log_stderr("     --strip-ebl       Strip extra blank lines. (safe)")
	compiler_log_stderr("     --strip-ls        Strip leading spaces in every line of the code.")
	compiler_log_stderr("     --strip-tc        Strip trailing comments. (not really implemented yet)")
	compiler_log_stderr("     --strip-ts        Strip trailing spaces in every line of the code. (safe)")
	compiler_log_stderr("     --strip-all       Do all the strip methods mentioned above.")
	compiler_log_stderr("     --strip-all-safe  Do all the safe strip methods mentioned above.")
	compiler_log_stderr("     --tempdir [path]  Use a different directory for temporary files.")
	compiler_log_stderr("-x,  --extended        Parse extended functions loadx(), includex() and callx().")
	compiler_log_stderr("-V,  --version         Show version.")
	compiler_log_stderr("")
}

function compiler_showversioninfo() {
	print(compiler_version)
}


# Walk Functions

function compiler_walk(file) {
	compiler_log_message("walk: " file)

	if (! compiler_test("-r", file))
		compiler_log_failure("file is not readable: " file,
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	compiler_writetomainobj_comment("--------------------------------------------------")
	compiler_writetomainobj_comment("(SOF) " file)
	compiler_writetomainobj_comment("--------------------------------------------------")

	compiler_walk_stack_file[compiler_walk_stack_i]           = compiler_walk_current_file
	compiler_walk_stack_line[compiler_walk_stack_i]           = compiler_walk_current_line
	compiler_walk_stack_line_number[compiler_walk_stack_i]    = compiler_walk_current_line_number
	compiler_walk_stack_noindent[compiler_walk_stack_i]       = compiler_walk_current_noindent
	compiler_walk_stack_noindent_start[compiler_walk_stack_i] = compiler_walk_current_noindent_start
	compiler_walk_stack_i++

	compiler_walk_current_file = file
	compiler_walk_current_line_number = 0
	compiler_walk_current_noindent = 0
	compiler_walk_current_noindent_start = 0

	while ((getline < file) > 0) {
		compiler_walk_current_line = $0
		++compiler_walk_current_line_number

		if ($1 in compiler_keywords) {
			if ($1 == "load") {
				compiler_walk_load()
			} else if ($1 == "include") {
				compiler_walk_include()
			} else if ($1 == "call") {
				compiler_walk_call()
			} else if ($1 == "loadx") {
				compiler_walk_loadx()
			} else if ($1 == "includex") {
				compiler_walk_includex()
			} else if ($1 == "callx") {
				compiler_walk_callx()
			} else if ($1 == "loader_addpath" || $1 == "addpath") {
				compiler_walk_addpath()
			} else if ($1 == "loader_flag") {
				# compiler_walk_flag()
				;
			} else if ($1 == "loader_reset" || $1 == "resetloader") {
				# compiler_walk_reset()
				;
			} else if ($1 == "loader_finish" || $1 == "finishloader") {
				# compiler_walk_finish()
				;
			} else if ($1 ~ /(beginnoindentblock|BEGINNOINDENTBLOCK|begincompilernoindent|BEGINCOMPILERNOINDENT)/) {
				compiler_walk_noindent_begin()
			} else if ($1 ~ /(endnoindentblock|ENDNOINDENTBLOCK|endcompilernoindent|ENDCOMPILERNOINDENT)/) {
				compiler_walk_noindent_end()
			} else if ($1 ~ /(beginskipblock|BEGINSKIPBLOCK|begincompilerskip|BEGINCOMPILERSKIP)/) {
				compiler_walk_skipblock_begin()
			} else if ($1 ~ /(endskipblock|ENDSKIPBLOCK|endcompilerskip|ENDCOMPILERSKIP)/) {
				compiler_walk_skipblock_end()
			} else if ($1 ~ /(beginnoparseblock|BEGINNOPARSEBLOCK|begincompilernoparse|BEGINCOMPILERNOPARSE)/) {
				compiler_walk_noparseblock_begin()
			} else if ($1 ~ /(endnoparseblock|ENDNOPARSEBLOCK|endcompilernoparse|ENDCOMPILERNOPARSE)/) {
				compiler_walk_noparseblock_end()
			} else {
				compiler_log_failure("compiler failure: entered invalid block in compiler_walk().")
			}
		} else {
			compiler_writetomainobj(compiler_walk_current_line)
		}
	}

	compiler_walk_noindent_end_check()

	compiler_writetomainobj_comment("--------------------------------------------------")
	compiler_writetomainobj_comment("(EOF) " file)
	compiler_writetomainobj_comment("--------------------------------------------------")

	close(file)

	if (compiler_walk_stack_i in compiler_walk_stack_file) {
		delete compiler_walk_stack_file[compiler_walk_stack_i]
		delete compiler_walk_stack_line_number[compiler_walk_stack_i]
		delete compiler_walk_stack_line[compiler_walk_stack_i]
	}

	--compiler_walk_stack_i
	compiler_walk_current_file           = compiler_walk_stack_file[compiler_walk_stack_i]
	compiler_walk_current_line           = compiler_walk_stack_line[compiler_walk_stack_i]
	compiler_walk_current_line_number    = compiler_walk_stack_line_number[compiler_walk_stack_i]
	compiler_walk_current_noindent       = compiler_walk_stack_noindent[compiler_walk_stack_i]
	compiler_walk_current_noindent_start = compiler_walk_stack_noindent_start[compiler_walk_stack_i]

}

function compiler_walk_load \
( \
\
	abs, argc, argv, base, costatements, eai, extraargs, i, leadingspaces, \
	tokenc, tokenv \
)
{
	compiler_log_debug("compiler_walk_load() [" compiler_walk_current_line "]")

	compiler_writetomainobj_comment(compiler_walk_current_line)

	tokenc = compiler_gettokens(compiler_walk_current_line, tokenv)

	argc = compiler_getargs(tokenv, tokenc, argv)

	if (argc < 2)
		compiler_log_failure("no argument entered",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	base = compiler_removequotes(argv[1])

	compiler_log_debug("compiler_walk_load: base = " base)

	if (base == "")
		compiler_log_failure("representing string cannot be null",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	if (argc > 2) {
		extraargs = argv[2]

		for (i = 3; i < argc; i++)
			extraargs = extraargs " " argv[i]
	} else {
		extraargs = 0
	}

	if (argc < tokenc && tokenv[argc] !~ /^#/) {
		costatements = tokenv[argc]

		for (i = argc + 1; i < tokenc; i++)
			costatements = costatements " " tokenv[i]

		leadingspaces = gensub(/[^ \t].*$/, "", 1, compiler_walk_current_line)
	} else {
		costatements = 0
	}

	if (base ~ /^\.?\.?\//) {
		if (compiler_test("-f", base)) {
			abs = compiler_getabspath(base)

			compiler_flags[abs] = 1

			if (extraargs)
				compiler_writetomainobj("set -- " extraargs)

			compiler_walk(abs)

			if (costatements)
				compiler_writetomainobj(leadingspaces ": " costatements)

			return
		}
	} else {
		for (i = 0; i < compiler_paths_count; i++) {
			if (! compiler_test("-f", compiler_paths[i] "/" base))
				continue

			abs = compiler_getabspath(compiler_paths[i] "/" base)

			compiler_flags[abs] = 1
			compiler_flags[base] = 1

			if (extraargs)
				compiler_writetomainobj("set -- " extraargs)

			compiler_walk(abs)

			if (costatements)
				compiler_writetomainobj(leadingspaces ": " costatements)

			return
		}
	}

	compiler_log_failure("file not found: " base,
			compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
}

function compiler_walk_include \
( \
\
	abs, argc, argv, base, costatements, extraargs, i, leadingspaces, \
	tokenc, tokenv \
)
{
	compiler_log_debug("compiler_walk_include() [" compiler_walk_current_line "]")

	compiler_writetomainobj_comment(compiler_walk_current_line)

	tokenc = compiler_gettokens(compiler_walk_current_line, tokenv)

	argc = compiler_getargs(tokenv, tokenc, argv)

	if (argc < 2)
		compiler_log_failure("no argument entered",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	base = compiler_removequotes(argv[1])

	if (base == "")
		compiler_log_failure("representing string cannot be null",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	if (argc > 2) {
		extraargs = argv[2]

		for (i = 3; i < argc; i++)
			extraargs = extraargs " " argv[i]
	} else {
		extraargs = 0
	}

	if (argc < tokenc && tokenv[argc] !~ /^#/) {
		costatements = tokenv[argc]

		for (i = argc + 1; i < tokenc; i++)
			costatements = costatements " " tokenv[i]

		leadingspaces = gensub(/[^ \t].*$/, "", 1, compiler_walk_current_line)
	} else {
		costatements = 0
	}

	if (base ~ /^\.?\.?\//) {
		abs = compiler_getabspath(base)

		if (abs in compiler_flags) {
			if (costatements)
				compiler_writetomainobj(leadingspaces ": " costatements)

			return
		}

		if (compiler_test("-f", base)) {
			compiler_flags[abs] = 1

			if (extraargs)
				compiler_writetomainobj("set -- " extraargs)

			compiler_walk(abs)

			if (costatements)
				compiler_writetomainobj(leadingspaces ": " costatements)

			return
		}
	} else {
		if (base in compiler_flags) {
			if (costatements)
				compiler_writetomainobj(leadingspaces ": " costatements)

			return
		}

		for (i = 0; i < compiler_paths_count; i++) {
			abs = compiler_getabspath(compiler_paths[i] "/" base)

			if (abs in compiler_flags) {
				compiler_flags[base] = 1

				if (costatements)
					compiler_writetomainobj(leadingspaces ": " costatements)

				return
			}

			if (compiler_test("-f", abs)) {
				compiler_flags[abs] = 1
				compiler_flags[base] = 1

				if (extraargs)
					compiler_writetomainobj("set -- " extraargs)

				compiler_walk(abs)

				if (costatements)
					compiler_writetomainobj(leadingspaces ": " costatements)

				return
			}
		}
	}

	compiler_log_failure("file not found: " base,
			compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
}

function compiler_walk_call \
( \
\
	abs, argc, argv, base, costatements, extraargs, funcname, i, \
	leadingspaces, tokenc, tokenv \
)
{
	compiler_log_debug("compiler_walk_call() [" compiler_walk_current_line "]")

	compiler_writetomainobj_comment(compiler_walk_current_line)

	tokenc = compiler_gettokens(compiler_walk_current_line, tokenv)

	argc = compiler_getargs(tokenv, tokenc, argv)

	if (argc < 2)
		compiler_log_failure("no argument entered",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	base = compiler_removequotes(argv[1])

	if (base == "")
		compiler_log_failure("representing string cannot be null",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	if (argc > 2) {
		extraargs = argv[2]

		for (i = 3; i < argc; i++)
			extraargs = extraargs " " argv[i]
	} else {
		extraargs = 0
	}

	if (argc < tokenc && tokenv[argc] !~ /^#/) {
		costatements = tokenv[argc]

		for (i = argc + 1; i < tokenc; i++)
			costatements = costatements " " tokenv[i]

	} else {
		costatements = 0
	}

	leadingspaces = gensub(/[^ \t].*$/, "", 1, compiler_walk_current_line)

	if (base ~ /^\.?\.?\//) {
		abs = compiler_getabspath(base)

		if (abs in compiler_calls_hashes) {
			funcname = compiler_calls_hashes[abs]

			compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces)

			return
		}

		if (compiler_test("-f", abs)) {
			funcname = compiler_calls_createfuncname(abs)

			compiler_calls_hashes[abs] = funcname

			compiler_calls_includefile(abs, funcname)

			compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces)

			return
		}
	} else {
		if (base in compiler_calls_hashes) {
			funcname = compiler_calls_hashes[base]

			compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces)

			return
		}

		for (i = 0; i < compiler_paths_count; i++) {
			abs =  compiler_getabspath(compiler_paths[i] "/" base)

			if (abs in compiler_calls_hashes) {
				funcname = compiler_calls_hashes[abs]

				compiler_calls_hashes[base] = funcname

				compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces)

				return
			}

			if (compiler_test("-f", abs)) {
				funcname = compiler_calls_createfuncname(abs)

				compiler_calls_hashes[abs] = funcname
				compiler_calls_hashes[base] = funcname

				compiler_calls_includefile(abs, funcname)

				compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces)

				return
			}
		}
	}
}

function compiler_walk_loadx \
( \
\
	abs, argc, argv, base, completeexpr, costatements, \
	cmd, eai, extraargs, fileexpr, filename, findpath, \
	findpath_quoted, i, leadingspaces, list, list_count, prefix, \
	prefixexpr, plain, sub_, subprefix, subprefix_quoted, temp, \
	testopt, tokenc, tokenv, wholepathmatching \
)
{
	compiler_log_debug("compiler_walk_loadx() [" compiler_walk_current_line "]")

	compiler_writetomainobj_comment(compiler_walk_current_line)

	tokenc = compiler_gettokens(compiler_walk_current_line, tokenv)

	argc = compiler_getargs(tokenv, tokenc, argv)

	if (argc < 2)
		compiler_log_failure("no argument follows",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	if (argv[1] ~ /[?*]/) {
		base = compiler_removequotes(argv[1])
		eai = 2
		plain = 0
		testopt = "-name"
		wholepathmatching = 0
	} else if (argv[1] ~ /^["']?(-name|-iname)["']?$/) {
		base = compiler_removequotes(argv[2])
		eai = 3
		plain = 0
		testopt = compiler_removequotes(argv[1])
		wholepathmatching = 0
	} else if (argv[1] ~ /^["']?(-regex|-iregex)["']?$/) {
		base = compiler_removequotes(argv[2])
		eai = 3
		plain = 0
		testopt = compiler_removequotes(argv[1])
		wholepathmatching = 1
	} else {
		base = compiler_removequotes(argv[1])
		eai = 2
		plain = 1
	}

	if (base == "")
		compiler_log_failure("representing string cannot be null",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	if (argc > eai) {
		extraargs = argv[eai]

		for (i = eai + 1; i < argc; i++)
			extraargs = extraargs " " argv[i]
	} else {
		extraargs = 0
	}

	if (argc < tokenc && tokenv[argc] !~ /^#/) {
		costatements = tokenv[argc]

		for (i = argc + 1; i < tokenc; i++)
			costatements = costatements " " tokenv[i]

		leadingspaces = gensub(/[^ \t].*$/, "", 1, compiler_walk_current_line)
	} else {
		costatements = 0
	}

	if (plain) {
		if (base ~ /^\.?\.?\//) {
			if (compiler_test("-f", base)) {
				abs = compiler_getabspath(base)

				compiler_flags[abs] = 1

				if (extraargs)
					compiler_writetomainobj("set -- " extraargs)

				compiler_walk(abs)

				if (costatements)
					compiler_writetomainobj(leadingspaces ": " costatements)

				return
			}
		} else {
			for (i = 0; i < compiler_paths_count; i++) {
				if (! compiler_test("-f", compiler_paths[i] "/" base))
					continue

				abs = compiler_getabspath(compiler_paths[i] "/" base)

				compiler_flags[abs] = 1
				compiler_flags[base] = 1

				if (extraargs)
					compiler_writetomainobj("set -- " extraargs)

				compiler_walk(abs)

				if (costatements)
					compiler_writetomainobj(leadingspaces ": " costatements)

				return
			}
		}

		compiler_log_failure("file not found: " base,
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
	} else {
		match(base, /^(.*\/)?(.*)/, temp)
		fileexpr = temp[2]
		subprefix = temp[1]

		list_count = 0

		if (fileexpr == "")
			compiler_log_failure("expression represents no file: " base,
					compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

		if (subprefix ~ /[*?]/)
			compiler_log_failure("expressions for directories are not supported: " subprefix,
					compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

		if (subprefix ~ /^\.?\.?\//) {
			if (! compiler_test("-d", subprefix))
				compiler_log_failure("directory not found: " subprefix,
						compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

			if (! compiler_test("-x", subprefix))
				compiler_log_failure("directory is not accessible: " subprefix,
						compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

			if (! compiler_test("-r", subprefix))
				compiler_log_failure("directory is not searchable: " subprefix,
						compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

			if (wholepathmatching) {
				prefixexpr = compiler_genregexliteral(subprefix)
			} else {
				prefixexpr = ""
			}

			completeexpr = compiler_gendoublequotesform(prefixexpr fileexpr)

			subprefix_quoted = compiler_gendoublequotesform(subprefix)

			cmd = "find " subprefix_quoted " -maxdepth 1 -xtype f " testopt " " completeexpr " -printf '%f\\n'"

			compiler_log_debug("cmd = " cmd)

			if ((cmd | getline filename) > 0) {
				do {
					list[list_count++] = filename
				} while ((cmd | getline filename) > 0)

				close(cmd)

				prefix = compiler_getabspath(subprefix)

				for (i = 0; i < list_count; i++) {
					abs = prefix list[i]

					compiler_flags[abs] = 1

					if (extraargs)
						compiler_writetomainobj("set -- " extraargs)

					compiler_walk(abs)
				}

				if (costatements)
					compiler_writetomainobj(leadingspaces ": " costatements)

				return
			}

			close(cmd)
		} else {
			for (i = 0; i < compiler_paths_count; i++) {

				findpath = compiler_paths[i] "/" subprefix

				if (! compiler_test("-d", findpath))
					continue

				if (! compiler_test("-x", findpath))
					compiler_log_failure("directory is not accessible: " findpath,
							compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

				if (! compiler_test("-r", findpath))
					compiler_log_failure("directory is not searchable: " findpath,
							compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

				if (wholepathmatching) {
					prefixexpr = compiler_genregexliteral(findpath)
				} else {
					prefixexpr = ""
				}

				completeexpr = compiler_gendoublequotesform(prefixexpr fileexpr)

				findpath_quoted = compiler_gendoublequotesform(findpath)

				cmd = "find " findpath_quoted " -maxdepth 1 -xtype f " testopt " " completeexpr " -printf '%f\\n'"

				compiler_log_debug("cmd = " cmd)

				if ((cmd | getline filename) > 0) {
					do {
						list[list_count++] = filename
					} while ((cmd | getline filename) > 0)

					close(cmd)

					prefix = compiler_getabspath(findpath)

					compiler_log_debug("prefix = " prefix)

					for (i = 0; i < list_count; i++) {
						filename = list[i]
						abs = prefix filename
						sub_ = subprefix filename

						compiler_flags[abs] = 1
						compiler_flags[sub_] = 1

						if (extraargs)
							compiler_writetomainobj("set -- " extraargs)

						compiler_walk(abs)
					}

					if (costatements)
						compiler_writetomainobj(leadingspaces ": " costatements)

					return
				}

				close(cmd)
			}
		}

		compiler_log_failure("no file was found with expression '" base "'",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
	}
}

function compiler_walk_includex \
( \
\
	abs, argc, argv, base, completeexpr, costatements, \
	cmd, eai, extraargs, fileexpr, filename, findpath, \
	findpath_quoted, i, leadingspaces, list, list_count, prefix, \
	prefixexpr, plain, sub_, subprefix, subprefix_quoted, temp, \
	testopt, tokenc, tokenv, wholepathmatching \
)
{
	compiler_log_debug("compiler_walk_includex() [" compiler_walk_current_line "]")

	compiler_writetomainobj_comment(compiler_walk_current_line)

	tokenc = compiler_gettokens(compiler_walk_current_line, tokenv)

	argc = compiler_getargs(tokenv, tokenc, argv)

	if (argc < 2)
		compiler_log_failure("no argument follows",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	if (argv[1] ~ /[?*]/) {
		base = compiler_removequotes(argv[1])
		eai = 2
		plain = 0
		testopt = "-name"
		wholepathmatching = 0
	} else if (argv[1] ~ /^["']?(-name|-iname)["']?$/) {
		base = compiler_removequotes(argv[2])
		eai = 3
		plain = 0
		testopt = compiler_removequotes(argv[1])
		wholepathmatching = 0
	} else if (argv[1] ~ /^["']?(-regex|-iregex)["']?$/) {
		base = compiler_removequotes(argv[2])
		eai = 3
		plain = 0
		testopt = compiler_removequotes(argv[1])
		wholepathmatching = 1
	} else {
		base = compiler_removequotes(argv[1])
		eai = 2
		plain = 1
	}

	if (base == "")
		compiler_log_failure("representing string cannot be null",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	if (argc > eai) {
		extraargs = argv[eai]

		for (i = eai + 1; i < argc; i++)
			extraargs = extraargs " " argv[i]
	} else {
		extraargs = 0
	}

	if (argc < tokenc && tokenv[argc] !~ /^#/) {
		costatements = tokenv[argc]

		for (i = argc + 1; i < tokenc; i++)
			costatements = costatements " " tokenv[i]

		leadingspaces = gensub(/[^ \t].*$/, "", 1, compiler_walk_current_line)
	} else {
		costatements = 0
	}

	if (plain) {
		if (base ~ /^\.?\.?\//) {
			abs = compiler_getabspath(base)

			if (abs in compiler_flags) {
				if (costatements)
					compiler_writetomainobj(leadingspaces ": " costatements)

				return
			}

			if (compiler_test("-f", base)) {
				compiler_flags[abs] = 1

				if (extraargs)
					compiler_writetomainobj("set -- " extraargs)

				compiler_walk(abs)

				if (costatements)
					compiler_writetomainobj(leadingspaces ": " costatements)

				return
			}
		} else {
			if (base in compiler_flags) {
				if (costatements)
					compiler_writetomainobj(leadingspaces ": " costatements)

				return
			}

			for (i = 0; i < compiler_paths_count; i++) {
				abs = compiler_getabspath(compiler_paths[i] "/" base)

				if (abs in compiler_flags) {
					compiler_flags[base] = 1

					if (costatements)
						compiler_writetomainobj(leadingspaces ": " costatements)

					return
				}

				if (compiler_test("-f", abs)) {
					compiler_flags[abs] = 1
					compiler_flags[base] = 1

					if (extraargs)
						compiler_writetomainobj("set -- " extraargs)

					compiler_walk(abs)

					if (costatements)
						compiler_writetomainobj(leadingspaces ": " costatements)

					return
				}
			}
		}

		compiler_log_failure("file not found: " base,
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
	} else {
		match(base, /^(.*\/)?(.*)/, temp)
		fileexpr = temp[2]
		subprefix = temp[1]

		list_count = 0

		if (fileexpr == "")
			compiler_log_failure("expression represents no file: " base,
					compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

		if (subprefix ~ /[*?]/)
			compiler_log_failure("expressions for directories are not supported: " subprefix,
					compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

		if (subprefix ~ /^\.?\.?\//) {
			if (! compiler_test("-d", subprefix))
				compiler_log_failure("directory not found: " subprefix,
						compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

			if (! compiler_test("-x", subprefix))
				compiler_log_failure("directory is not accessible: " subprefix,
						compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

			if (! compiler_test("-r", subprefix))
				compiler_log_failure("directory is not searchable: " subprefix,
						compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

			if (wholepathmatching) {
				prefixexpr = compiler_genregexliteral(subprefix)
			} else {
				prefixexpr = ""
			}

			completeexpr = compiler_gendoublequotesform(prefixexpr fileexpr)

			subprefix_quoted = compiler_gendoublequotesform(subprefix)

			cmd = "find " subprefix_quoted " -maxdepth 1 -xtype f " testopt " " completeexpr " -printf '%f\\n'"

			if ((cmd | getline filename) > 0) {
				do {
					list[list_count++] = filename
				} while ((cmd | getline filename) > 0)

				close(cmd)

				prefix = compiler_getabspath(subprefix)

				for (i = 0; i < list_count; i++) {
					abs = prefix list[i]

					if (abs in compiler_flags)
						continue

					compiler_flags[abs] = 1

					if (extraargs)
						compiler_writetomainobj("set -- " extraargs)

					compiler_walk(abs)
				}

				if (costatements)
					compiler_writetomainobj(leadingspaces ": " costatements)

				return
			}

			close(cmd)
		} else {
			for (i = 0; i < compiler_paths_count; i++) {
				findpath = compiler_paths[i] "/" subprefix

				if (! compiler_test("-d", findpath))
					continue

				if (! compiler_test("-x", findpath))
					compiler_log_failure("directory is not accessible: " findpath,
							compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

				if (! compiler_test("-r", findpath))
					compiler_log_failure("directory is not searchable: " findpath,
							compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

				if (wholepathmatching) {
					prefixexpr = compiler_genregexliteral(findpath)
				} else {
					prefixexpr = ""
				}

				completeexpr = compiler_gendoublequotesform(prefixexpr fileexpr)

				findpath_quoted = compiler_gendoublequotesform(findpath)

				cmd = "find " findpath_quoted " -maxdepth 1 -xtype f " testopt " " completeexpr " -printf '%f\\n'"

				if ((cmd | getline filename) > 0) {
					do {
						list[list_count++] = filename
					} while ((cmd | getline filename) > 0)

					close(cmd)

					prefix = compiler_getabspath(findpath)

					for (i = 0; i < list_count; i++) {
						filename = list[i]
						abs = prefix filename
						sub_ = subprefix filename

						if (abs in compiler_flags)
							continue

						compiler_flags[abs] = 1
						compiler_flags[sub_] = 1

						if (extraargs)
							compiler_writetomainobj("set -- " extraargs)

						compiler_walk(abs)
					}

					if (costatements)
						compiler_writetomainobj(leadingspaces ": " costatements)

					return
				}

				close(cmd)
			}
		}

		compiler_log_failure("no file was found with expression '" base "'",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
	}
}

function compiler_walk_callx \
( \
\
	abs, argc, argv, base,  completeexpr, costatements, cmd, eai, extraargs, \
	fileexpr, filename, findpath, findpath_quoted, funcname, i, leadingspaces, \
	list, list_count, prefix, prefixexpr, plain, sub_, subprefix, \
	subprefix_quoted, temp, testopt, tokenc, tokenv, wholepathmatching \
)
{
	compiler_log_debug("compiler_walk_callx() [" compiler_walk_current_line "]")

	compiler_writetomainobj_comment(compiler_walk_current_line)

	tokenc = compiler_gettokens(compiler_walk_current_line, tokenv)

	argc = compiler_getargs(tokenv, tokenc, argv)

	if (argc < 2)
		compiler_log_failure("no argument follows",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	if (argv[1] ~ /[?*]/) {
		base = compiler_removequotes(argv[1])
		eai = 2
		plain = 0
		testopt = "-name"
		wholepathmatching = 0
	} else if (argv[1] ~ /^["']?(-name|-iname)["']?$/) {
		base = compiler_removequotes(argv[2])
		eai = 3
		plain = 0
		testopt = compiler_removequotes(argv[1])
		wholepathmatching = 0
	} else if (argv[1] ~ /^["']?(-regex|-iregex)["']?$/) {
		base = compiler_removequotes(argv[2])
		eai = 3
		plain = 0
		testopt = compiler_removequotes(argv[1])
		wholepathmatching = 1
	} else {
		base = compiler_removequotes(argv[1])
		eai = 2
		plain = 1
	}

	if (base == "")
		compiler_log_failure("representing string cannot be null",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	if (argc > eai) {
		extraargs = argv[eai]

		for (i = eai + 1; i < argc; i++)
			extraargs = extraargs " " argv[i]
	} else {
		extraargs = 0
	}

	if (argc < tokenc && tokenv[argc] !~ /^#/) {
		costatements = tokenv[argc]

		for (i = argc + 1; i < tokenc; i++)
			costatements = costatements " " tokenv[i]

	} else {
		costatements = 0
	}

	leadingspaces = gensub(/[^ \t].*$/, "", 1, compiler_walk_current_line)

	if (plain) {
		if (base ~ /^\.?\.?\//) {
			abs = compiler_getabspath(base)

			if (abs in compiler_calls_hashes) {
				funcname = compiler_calls_hashes[abs]

				compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces)

				return
			}

			if (compiler_test("-f", abs)) {
				funcname = compiler_calls_createfuncname(abs)

				compiler_calls_hashes[abs] = funcname

				compiler_calls_includefile(abs, funcname)

				compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces)

				return
			}
		} else {
			if (base in compiler_calls_hashes) {
				funcname = compiler_calls_hashes[base]

				compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces)

				return
			}

			for (i = 0; i < compiler_paths_count; i++) {
				abs = compiler_getabspath(compiler_paths[i] "/" base)

				if (abs in compiler_calls_hashes) {
					funcname = compiler_calls_hashes[abs]

					compiler_calls_hashes[base] = funcname

					compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces)

					return
				}

				if (compiler_test("-f", abs)) {
					funcname = compiler_calls_createfuncname(abs)

					compiler_calls_hashes[abs] = funcname
					compiler_calls_hashes[base] = funcname

					compiler_calls_includefile(abs, funcname)

					compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces)

					return
				}
			}
		}

		compiler_log_failure("file not found: " base,
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
	} else {
		match(base, /^(.*\/)?(.*)/, temp)
		fileexpr = temp[2]
		subprefix = temp[1]

		list_count = 0

		if (fileexpr == "")
			compiler_log_failure("expression represents no file: " base,
					compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

		if (subprefix ~ /[*?]/)
			compiler_log_failure("expressions for directories are not supported: " subprefix,
					compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

		if (subprefix ~ /^\.?\.?\//) {
			if (! compiler_test("-d", subprefix))
				compiler_log_failure("directory not found: " subprefix,
						compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

			if (! compiler_test("-x", subprefix))
				compiler_log_failure("directory is not accessible: " subprefix,
						compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

			if (! compiler_test("-r", subprefix))
				compiler_log_failure("directory is not searchable: " subprefix,
						compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

			if (wholepathmatching) {
				prefixexpr = compiler_genregexliteral(subprefix)
			} else {
				prefixexpr = ""
			}

			completeexpr = compiler_gendoublequotesform(prefixexpr fileexpr)

			subprefix_quoted = compiler_gendoublequotesform(subprefix)

			cmd = "find " subprefix_quoted " -maxdepth 1 -xtype f " testopt " " completeexpr " -printf '%f\\n'"

			if ((cmd | getline filename) > 0) {
				prefix = compiler_getabspath(subprefix)

				do {
					abs = prefix filename

					if (abs in compiler_calls_hashes) {
						funcname = compiler_calls_hashes[abs]

						list[list_count++] = funcname
					} else {
						funcname = compiler_calls_createfuncname(abs)

						compiler_calls_hashes[abs] = funcname

						compiler_calls_includefile(abs, funcname)

						list[list_count++] = funcname
					}
				} while ((cmd | getline filename) > 0)

				close(cmd)

				if (list_count > 1) {
					compiler_calls_writegroupcall(list, extraargs, costatements, leadingspaces, base, testopt)
				} else {
					compiler_calls_writecall(list[0], extraargs, costatements, leadingspaces)
				}

				return
			}

			close(cmd)
		} else {
			for (i = 0; i < compiler_paths_count; i++) {
				findpath = compiler_paths[i] "/" subprefix

				if (! compiler_test("-d", findpath))
					continue

				if (! compiler_test("-x", findpath))
					compiler_log_failure("directory is not accessible: " findpath,
							compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

				if (! compiler_test("-r", findpath))
					compiler_log_failure("directory is not searchable: " findpath,
							compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

				if (wholepathmatching) {
					prefixexpr = compiler_genregexliteral(findpath)
				} else {
					prefixexpr = ""
				}

				completeexpr = compiler_gendoublequotesform(prefixexpr fileexpr)

				findpath_quoted = compiler_gendoublequotesform(findpath)

				cmd = "find " findpath_quoted " -maxdepth 1 -xtype f " testopt " " completeexpr " -printf '%f\\n'"

				if ((cmd | getline filename) > 0) {
					prefix = compiler_getabspath(findpath)

					do {
						abs = prefix filename
						sub_ = subprefix filename

						if (sub_ in compiler_calls_hashes) {
							funcname = compiler_calls_hashes[sub_]
						} else if (abs in compiler_calls_hashes) {
							funcname = compiler_calls_hashes[abs]

							compiler_calls_hashes[sub_] = funcname
						} else {
							funcname = compiler_calls_createfuncname(abs)

							compiler_calls_hashes[abs] = funcname
							compiler_calls_hashes[sub_] = funcname

							compiler_calls_includefile(abs, funcname)
						}

						list[list_count++] = funcname
					} while ((cmd | getline filename) > 0)

					close(cmd)

					if (list_count > 1) {
						compiler_calls_writegroupcall(list, extraargs, costatements, leadingspaces, base, testopt)
					} else {
						compiler_calls_writecall(list[0], extraargs, costatements)
					}

					return
				}

				close(cmd)
			}
		}

		compiler_log_failure("no file was found with expression '" base "'",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
	}
}

function compiler_walk_addpath(  argc, argv, i, path, tokenc, tokenv) {
	compiler_log_debug("compiler_walk_addpath() [" compiler_walk_current_line "]")

	if (compiler_ignoreaddpaths) {
		compiler_writetomainobj(compiler_walk_current_line)
		return
	}

	compiler_writetomainobj_comment(compiler_walk_current_line)

	tokenc = compiler_gettokens(compiler_walk_current_line, tokenv)

	argc = compiler_getargs(tokenv, tokenc, argv)

	if (argc < 2)
		compiler_log_failure("no argument entered",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	for (i = 1; i < argc; i++) {
		path = compiler_removequotes(argv[i])

		if (! compiler_test("-d", path)) {
			compiler_log_failure("directory not found: " path ", cwd: " compiler_getcwd(),
					compiler_walk_current_file, compiler_walk_current_line_number, $1 " " path)

			return
		}

		compiler_addpath(path)
	}
}


function compiler_walk_flag() {
	compiler_log_debug("compiler_walk_flag() [" compiler_walk_current_line "]")

	compiler_writetomainobj_comment(compiler_walk_current_line)

	tokenc = compiler_gettokens(compiler_walk_current_line, tokenv)

	argc = compiler_getargs(tokenv, tokenc, argv)

	if (argc < 2)
		compiler_log_failure("no argument entered",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	base = compiler_removequotes(argv[1])

	compiler_log_debug("compiler_walk_flag: base = " base)

	if (base == "")
		compiler_log_failure("representing string cannot be null",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)

	if (argc < tokenc && tokenv[argc] !~ /^#/) {
		costatements = tokenv[argc]

		for (i = argc + 1; i < tokenc; i++)
			costatements = costatements " " tokenv[i]

		leadingspaces = gensub(/[^ \t].*$/, "", 1, compiler_walk_current_line)
	} else {
		costatements = 0
	}

	if (costatements)
		compiler_writetomainobj(leadingspaces ": " costatements)

	abs = compiler_getabspath(base)

	compiler_flags[abs] = 1
}

function compiler_walk_reset(  argc, argv, tokenc, tokenv) {
	compiler_log_debug("compiler_walk_reset() [" compiler_walk_current_line "]")

	if (compiler_ignoreresets) {
		compiler_writetomainobj(compiler_walk_current_line)
		return
	}

	compiler_writetomainobj_comment(compiler_walk_current_line)

	tokenc = compiler_gettokens(compiler_walk_current_line, tokenv)

	argc = compiler_getargs(tokenv, tokenc, argv)

	if (argc < 2) {
		delete compiler_flags

		delete compiler_paths
		delete compiler_paths_flags
		compiler_paths_count = 0
	} else {
		type = compiler_removequotes(argv[1])

		if (type == "flags") {
			delete compiler_flags
		} else if (type == "paths") {
			delete compiler_paths
			delete compiler_paths_flags
			compiler_paths_count = 0
		} else {
			compiler_log_failure("invalid argument: \"" argv[1] "\"",
					compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
		}
	}
}

function compiler_walk_finish() {
	compiler_log_debug("compiler_walk_finish() [" compiler_walk_current_line "]")

	# ?
}

function compiler_walk_noindent_begin() {
	if (compiler_walk_current_noindent) {
		compiler_log_failure("already inside a no-indent block which started at line " compiler_walk_current_noindent_start ".",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
	} else {
		compiler_walk_current_noindent = 1
		compiler_walk_current_noindent_start = compiler_walk_current_line_number
	}
}

function compiler_walk_noindent_end() {
	if (compiler_walk_current_noindent) {
		compiler_walk_current_noindent = 0
		compiler_walk_current_noindent_start = 0
	} else {
		compiler_log_failure("not inside a no-indent block.",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
	}
}

function compiler_walk_noindent_end_check() {
	if (compiler_walk_current_noindent)
		compiler_log_failure("end of no-indent block that started at line " compiler_walk_current_noindent_start " was not found.",
				compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
}

function compiler_walk_skipblock_begin(  foundendofblock, startofblocklineno) {
	compiler_log_debug("compiler_walk_skipblock_begin() [ file = " compiler_walk_current_file ", line no = " compiler_walk_current_line_number "]")

	compiler_writetomainobj_comment(compiler_walk_current_line)

	foundendofblock = 0
	startofblocklineno = compiler_walk_current_line_number

	while ((getline < compiler_walk_current_file) > 0) {
		++compiler_walk_current_line_number

		if ($1 ~ /#(endskipblock|ENDSKIPBLOCK|endcompilerskip|ENDCOMPILERSKIP)/) {
			foundendofblock = 1
			break
		}
	}

	if (!foundendofblock)
		compiler_log_failure("end of skip block not found",
				compiler_walk_current_file, startofblocklineno)

	compiler_writetomainobj_comment($0)
}

function compiler_walk_skipblock_end() {
	compiler_log_failure("not inside a no-skip block.",
			compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
}

function compiler_walk_noparseblock_begin(  foundendofblock, startofblocklineno) {
	compiler_log_debug("compiler_walk_noparseblock_begin() [ file = " compiler_walk_current_file ", line no = " compiler_walk_current_line_number "]")

	compiler_writetomainobj_comment(compiler_walk_current_line)

	foundendofblock = 0
	startofblocklineno = compiler_walk_current_line_number

	while ((getline < compiler_walk_current_file) > 0) {
		++compiler_walk_current_line_number

		compiler_writetomainobj_comment($0)

		if ($1 ~ /#(endnoparseblock|ENDNOPARSEBLOCK|endcompilernoparse|ENDCOMPILERNOPARSE)/) {
			foundendofblock = 1
			break
		}

		compiler_writetomainobj($0)
	}

	if (!foundendofblock)
		compiler_log_failure("end of no parse block not found",
				compiler_walk_current_file, startofblocklineno)

	compiler_writetomainobj_comment($0)
}

function compiler_walk_noparseblock_end() {
	compiler_log_failure("not inside a no-parse block.",
			compiler_walk_current_file, compiler_walk_current_line_number, compiler_walk_current_line)
}


# Sub / Misc. Functions

function compiler_addpath(path) {
	compiler_log_debug("compiler_addpath(\"" path "\")")

	path = compiler_getabspath(path "/.")

	if (! (path in compiler_paths_flags)) {
		compiler_paths[compiler_paths_count++] = path
		compiler_paths_flags[path] = 1
	}
}

function compiler_calls_createfuncname(seed,   funcname, hash, i) {
	compiler_log_debug("compiler_calls_createfuncname(\"" seed "\")")

	hash = compiler_makehash(seed)
	i = 0

	do {
		funcname = "call_" hash sprintf("%02d", i++)
	} while (funcname in compiler_calls_funcnames)

	compiler_calls_funcnames[funcname] = 1

	return funcname
}

function compiler_calls_includefile(path, funcname) {
	compiler_log_debug("compiler_calls_includefile(\"" path "\", \"" funcname "\")")

	compiler_writetocallsobj_comment("--------------------------------------------------")
	compiler_writetocallsobj_comment("(CALL) " path)
	compiler_writetocallsobj_comment("--------------------------------------------------\n")

	compiler_writetocallsobj(funcname "() {\n\t(")

	if (compiler_noindent || compiler_walk_current_noindent) {
		compiler_dump(path, compiler_callsobjfile, 1)
	} else {
		compiler_dump(path, compiler_callsobjfile, 1, "\t\t")
	}

	compiler_writetocallsobj("\t)\n\treturn\n}\n")
}

function compiler_calls_writecall(funcname, extraargs, costatements, leadingspaces,   line) {
	compiler_log_debug("compiler_calls_writecall(\"" funcname "\", \"" extraargs "\", \"" costatements "\")")

	if (leadingspaces && leadingspaces != "") {
		line = leadingspaces funcname
	} else {
		line = funcname
	}

	if (extraargs)
		line = line " " extraargs

	if (costatements)
		line = line " " costatements

	compiler_writetomainobj(line)
}

function compiler_calls_writegroupcall(funclist, extraargs, costatements, leadingspaces, base, testopt,   comment, groupcallfuncname, i, seed) {
	compiler_log_debug("compiler_calls_writegroupcall({ " funclist[0] ", ... } , " extraargs ", " costatements ") [" base "]")

	for (i in funclist)
		seed = seed "." funclist[i]

	if (extraargs)
		seed = seed "." extraargs

	if (seed in compiler_calls_groupcallseeds) {
		groupcallfuncname = compiler_calls_groupcallseeds[seed]
	} else {
		groupcallfuncname = compiler_calls_createfuncname(seed)

		compiler_calls_groupcallseeds[seed] = groupcallfuncname

		comment = "(GROUPCALL) (" substr(testopt, 2) ") \"" base "\""

		if (extraargs)
			comment = comment " " extraargs

		compiler_writetocallsobj_comment("--------------------------------------------------")
		compiler_writetocallsobj_comment(comment)
		compiler_writetocallsobj_comment("--------------------------------------------------\n")

		compiler_writetocallsobj(groupcallfuncname "() {")

		compiler_writetocallsobj("\tr=0")

		if (extraargs) {
			for (i in funclist) {
				compiler_writetocallsobj("\t" funclist[i] " " extraargs)
				compiler_writetocallsobj("\ttest $? -ne 0 && r=1")
			}
		} else {
			for (i in funclist) {
				compiler_writetocallsobj("\t" funclist[i])
				compiler_writetocallsobj("\ttest $? -ne 0 && r=1")
			}
		}

		compiler_writetocallsobj("\treturn $r")
		compiler_writetocallsobj("}\n")
	}

	if (costatements) {
		compiler_writetomainobj(leadingspaces groupcallfuncname " " costatements)
	} else {
		compiler_writetomainobj(leadingspaces groupcallfuncname)
	}
}

function compiler_dump(input, output, append, indent,   arrow, line) {
	if (append) {
		arrow = " >> "
	} else {
		arrow = " > "
	}

	compiler_log_message("dump: " input arrow output)

	if ((getline line < input) > 0) {
		if (append) {
			print indent line >> output
		} else {
			close(output)

			# should truncate but no that's why we use
			# truncate() everywhere before using this function.
			# This won't be changed for the sake of
			# consistency.

			print indent line > output
		}

		while ((getline line < input) > 0)
			print indent line >> output

		# not sure if it's necessary to close the output but it's ok

		close(output)
	}

	close(input)
}

function compiler_getabspath(path,   abs, array, c, f, nf, node, t, tokens) {
	node = (path ~ /\/$/)

	if (path !~ /^\//)
		path = compiler_wd "/" path

	nf = split(path, array, "/")

	t = 0

	for (f = 1; f <= nf; f++) {
		c = array[f]

		if (c == "." || c == "") {
			continue
		} else if (c == "..") {
			if (t)
				--t
		} else {
			tokens[t++]=c
		}
	}

	if (t) {
		abs = "/" tokens[0]

		for (i = 1; i < t; i++)
			abs = abs "/" tokens[i]

		if (node)
			abs = abs "/"
	} else if (node) {
		abs = "/"
	} else {
		abs = "/."
	}

	return abs
}

function compiler_genregexliteral(string) {
	gsub(/[\$\(\)\*\+\.\?\[\\\]\^\{\|\}]/, "\\\\&", string)
	return string
}

function compiler_gendoublequotesform(string) {
	return "\"" gensub(/["\$`\\]/, "\\\\&", 1, string) "\""
}

function compiler_getargs(tokenv, tokenc, argv,   argc) {
	compiler_log_debug("compiler_getargs()")

	argc = 0

	for (i in argv)
		delete argv[i]

	# Sometimes 'for (i in array)' does not yield indices in sorted
	# order so we depend on tokenc.

	for (i = 0; i < tokenc; i++v) {
		if (tokenv[i] ~ /^(#|\||&|;|[[:digit:]]*[<>])/) {
			return argc
		} else {
			argv[argc++] = tokenv[i]
		}
	}

	return argc
}

function compiler_gettokens(string, tokenv,   i, temp, token, tokenc) {
	# TODO:
	# * Something feels not right with '\\.?' but perhaps it's already correct.
	# * In some comparisons, unexpected EOS is not reported.

	compiler_log_debug("compiler_gettokens(\"" string "\", ... )")

	for (i in tokenv)
		delete tokenv[i]

	delete tokenv

	# check if whole string is just a comment

	if (match(string, /^[[:blank:]]*(#.*)/, temp)) {
		tokenv[0] = temp[1]
		return 1
	}

	token = ""
	tokenc = 0
	subtokensize = 0

	while (length(string)) {
		# comments

		if (match(string, /^[[:blank:]]+(#.*)/, temp)) {
			if (length(token))
				tokenv[tokenc++] = token

			tokenv[tokenc++] = temp[1]

			return tokenc
		}

		# new tokens coming

		if (match(string, /^[[:blank:]]+(.*)/, temp)) {
			if (length(token)) {
				tokenv[tokenc++] = token
				token = ""
			}

			string = temp[1]

			if (! length(string))
				break
		}

		# single quoted strings

		if (match(string, /^('[^']*'?)(.*)/, temp)) {
			token = token temp[1]
			string = temp[2]
			continue
		}

		# backquotes (old command substitution)

		if (match(string, /^(`(\\`|[^`])*`?)(.*)/, temp)) {
			token = token temp[1]
			string = temp[2]
			continue
		}

		# double quoted strings /
		# dollar-sign based expansions or substitutions

		if (string ~ /^"/) {
			subtokensize = compiler_gettokens_getsubtokensize_doublequotes(string)
		} else if (string ~ /^\$/) {
			subtokensize = compiler_gettokens_getsubtokensize_dsbased(string)
		}

		if (subtokensize) {
			token = token substr(string, 1, subtokensize)
			string = substr(string, subtokensize + 1)
			subtokensize = 0
			continue
		}

		# redirections

		if (match(string, /^([[:digit:]]*[<>]&(-|[[:digit:]]+|[[:digit:]]+-)|[[:digit:]]*(<|>|<<|<>)|&>|<&|<<<|<<-?)(.*)/, temp)) {
			if (length(token)) {
				tokenv[tokenc++] = token
				token = ""
			}

			tokenv[tokenc++] = temp[1]
			string = temp[4]
			continue
		}

		# digits not followed by redirections

		if (match(string, /^([[:digit:]]+)(.*)/, temp)) {
			token = token temp[1]
			string = temp[2]
			continue
		}

		# control characters or metacharacters

		if (match(string, /^(\|\||\|&|&&|&\||\||&|;;|;)(.*)/, temp)) {
			if (length(token)) {
				tokenv[tokenc++] = token
				token = ""
			}

			tokenv[tokenc++] = temp[1]
			string = temp[2]
			continue
		}

		# all of the non-special characters or pairs

		if (match(string, /^(#?(\\.?|[^[:blank:][:digit:]"$&';<>|])+)(.*)/, temp)) {
			token = token temp[1]
			string = temp[3]
			continue
		}

		# compiler bug; something was not parsed

		compiler_log_failure("compiler_gettokens: failed to parse string.  This is probably a bug in the parser or the current locale is just not compatible.  String failed to parse was \"" string "\".")
	}

	if (length(token))
		tokenv[tokenc++] = token

	return tokenc
}

function compiler_gettokens_getsubtokensize_doublequotes(string,   size, temp) {
	compiler_log_debug("compiler_gettokens_getsubtokensize_doublequotes(\"" string "\")")

	size = 1
	string = substr(string, 2)

	while (length(string)) {
		# dollar-sign based expansion or substitution

		if (string ~ /^\$/) {
			subsubtokensize = compiler_gettokens_getsubtokensize_dsbased(string, 1)
			size = size + subsubtokensize
			string = substr(string, subsubtokensize + 1)
			continue
		}

		# old backquote command substitution

		if (match(string, /^(`(\\`|[^`])*`?)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[3]
			continue
		}

		# any non-enclosing pairs or characters

		if (match(string, /^((\\.?|[^"\$`\\])+)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[3]
			continue
		}

		# end of arithmetic expansion

		if (string ~ /^"/) {
			return size + 1
		}

		# invalid

		compiler_log_failure("compiler_gettokens_getsubtokensize_doublequotes: failed to parse string.  This is probably a bug in the parser or the current locale is just not compatible.  String failed to parse was \"" string "\".")
	}

	compiler_log_failure("compiler_gettokens_getsubtokensize_doublequotes: unexpected end of string while looking for matching '\"'",
			compiler_walk_current_file, compiler_walk_current_line_number,
			gensub(/^[[:blank:]]+/, "", 1, compiler_walk_current_line))
}

function compiler_gettokens_getsubtokensize_dsbased(string, fromdoublequotes,   temp) {
	compiler_log_debug("compiler_gettokens_getsubtokensize_dsbased(\"" string "\")")

	# specialized double quoted strings

	if (!fromdoublequotes && match(string, /^(\$"(\\"|[^"])*"?)/, temp)) {
		return temp[1, "length"]

	# specialized single quoted strings

	} else if (match(string, /^(\$'(\\'|[^'])*'?)/, temp)) {
		return temp[1, "length"]

	# arithmetic expansion

	} else if (string ~ /^\$\(\(/) {
		return compiler_gettokens_getsubtokensize_dsbased_arithmeticexpansion(string)

	# new command substitution

	} else if (string ~ /^\$\(/) {
		return compiler_gettokens_getsubtokensize_dsbased_commandsubstitution(string)

	# parameter expansion in braces

	} else if (string ~ /^\$\{/) {
		return compiler_gettokens_getsubtokensize_dsbased_parameterexpansion(string)

	# simple parameter expansions

	} else if (match(string, /^(\$[[:digit:]*@#?\-$!_]|\$[[:alnum:]_]+)/, temp)) {
		return temp[1, "length"]

	# just an ordinary dollar sign

	} else {
		return 1

	}
}

function compiler_gettokens_getsubtokensize_dsbased_arithmeticexpansion(string,   size, temp) {
	compiler_log_debug("compiler_gettokens_getsubtokensize_dsbased_arithmeticexpansion(\"" string "\")")

	size = 3
	string = substr(string, 4)

	while (length(string)) {
		# another inline dollar-sign based expansion or substitution

		if (string ~ /^\$/) {
			subsubtokensize = compiler_gettokens_getsubtokensize_dsbased(string)
			size = size + subsubtokensize
			string = substr(string, subsubtokensize + 1)
			continue
		}

		# old backquote command substitution

		if (match(string, /^(`(\\`|[^`])*`?)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[3]
			continue
		}

		# any non-enclosing pairs or characters

		if (match(string, /^((\\.?|[)]?[^$)])+)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[3]
			continue
		}

		# end of arithmetic expansion

		if (string ~ /^\)\)/)
			return size + 1

		# invalid

		compiler_log_failure("compiler_gettokens_getsubtokensize_dsbased_arithmeticexpansion: failed to parse string.  This is probably a bug in the parser or the current locale is just not compatible.  String failed to parse was \"" string "\".")
	}

	compiler_log_failure("compiler_gettokens_getsubtokensize_dsbased_arithmeticexpansion: unexpected end of string while looking for matching '))'",
			compiler_walk_current_file, compiler_walk_current_line_number,
			gensub(/^[[:blank:]]+/, "", 1, compiler_walk_current_line))
}

function compiler_gettokens_getsubtokensize_dsbased_commandsubstitution(string,   size, temp) {
	compiler_log_debug("compiler_gettokens_getsubtokensize_dsbased_commandsubstitution(\"" string "\")")

	string = substr(string, 3)

	# check if there's a comment

	if (match(string, /^([[:blank:]]*(#[^)]*\)|#[^)]*))/, temp))
		compiler_log_failure("compiler_gettokens_getsubtokensize_dsbased_commandsubstitution: cannot parse comments inside a command substitution enclosure.",
				compiler_walk_current_file, compiler_walk_current_line_number,
				gensub(/^[[:blank:]]+/, "", 1, compiler_walk_current_line))

	size = 2
	subtokensize = 0

	while (length(string)) {
		# end of enclosure

		if (string ~ /^\)/)
			return size + 1

		# comments

		if (match(string, /^[[:blank:]]+#/, temp)) {
			compiler_log_failure("compiler_gettokens_getsubtokensize_dsbased_commandsubstitution: cannot parse comments inside a command substitution enclosure.",
					compiler_walk_current_file, compiler_walk_current_line_number,
					gensub(/^[[:blank:]]+/, "", 1, compiler_walk_current_line))
		}

		# next token

		if (match(string, /^([[:blank:]]+)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[2]

			if (! length(string))
				break
		}

		# single quoted strings

		if (match(string, /^('[^']*'?)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[2]
			continue
		}

		# backquotes (old command substitution)

		if (match(string, /^(`(\\`|[^`])*`?)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[3]
			continue
		}

		# double quoted strings
		# dollar-sign based expansions or substitutions

		if (string ~ /^"/) {
			subtokensize = compiler_gettokens_getsubtokensize_doublequotes(string)
		} else if (string ~ /^\$/) {
			subtokensize = compiler_gettokens_getsubtokensize_dsbased(string)
		}

		if (subtokensize) {
			size = size + subtokensize
			string = substr(string, subtokensize + 1)
			subtokensize = 0
			continue
		}

		# redirections

		if (match(string, /^([[:digit:]]*[<>]&(-|[[:digit:]]+|[[:digit:]]+-)|[[:digit:]]*(<|>|<<|<>)|&>|<&|<<<|<<-?)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[4]
			continue
		}

		# digits not followed by redirections

		if (match(string, /^([[:digit:]]+)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[2]
			continue
		}

		# control characters or metacharacters

		if (match(string, /^(\|\||\|&|&&|&\||\||&|;;|;)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[2]
			continue
		}

		# all of the non-special characters or pairs

		if (match(string, /^(#?(\\.?|[^[:blank:][:digit:]"$&';<>|)])+)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[3]
			continue
		}

		# compiler bug; something was not parsed

		compiler_log_failure("compiler_gettokens_getsubtokensize_dsbased_commandsubstitution: failed to parse string.  This is probably a bug in the parser or the current locale is just not compatible.  String failed to parse was \"" string "\".")
	}

	compiler_log_failure("compiler_gettokens_getsubtokensize_dsbased_commandsubstitution: unexpected end of string while looking for matching ')'",
			compiler_walk_current_file, compiler_walk_current_line_number,
			gensub(/^[[:blank:]]+/, "", 1, compiler_walk_current_line))
}

function compiler_gettokens_getsubtokensize_dsbased_parameterexpansion(string,   size, temp) {
	compiler_log_debug("compiler_gettokens_getsubtokensize_dsbased_parameterexpansion(\"" string "\")")

	size = 2
	string = substr(string, 3)

	while (length(string)) {
		# inline single quoted strings

		if (match(string, /^('[^']+'?)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[2]
			continue
		}

		# old backquote command substitution

		if (match(string, /^(`(\\`|[^`])*`?)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[3]
			continue
		}

		# double quotes

		if (string ~ /^\"/) {
			subsubtokensize = compiler_gettokens_getsubtokensize_doublequotes(string)
			size = size + subsubtokensize
			string = substr(string, subsubtokensize + 1)
			continue
		}

		# another inline dollar-sign based expansion or substitution

		if (string ~ /^\$/) {
			subsubtokensize = compiler_gettokens_getsubtokensize_dsbased(string)
			size = size + subsubtokensize
			string = substr(string, subsubtokensize + 1)
			continue
		}

		# any non-enclosing pairs or characters

		if (match(string, /^((\\.?|[^"$'\\}])+)(.*)/, temp)) {
			size = size + temp[1, "length"]
			string = temp[3]
			continue
		}

		# end of parameter expansion

		if (string ~ /^\}/)
			return size + 1

		# invalid

		compiler_log_failure("compiler_gettokens_getsubtokensize_dsbased_parameterexpansion: failed to parse string.  This is probably a bug in the parser or the current locale is just not compatible.  String failed to parse was \"" string "\".")
	}

	compiler_log_failure("compiler_gettokens_getsubtokensize_dsbased_parameterexpansion: unexpected end of string while looking for matching '))'",
			compiler_walk_current_file, compiler_walk_current_line_number,
			gensub(/^[[:blank:]]+/, "", 1, compiler_walk_current_line))
}

function compiler_getwd(  cmd, wd) {
	compiler_log_debug("compiler_getwd()")

	cmd = "pwd"

	if ((cmd | getline wd) > 0) {
		close(cmd)
		return wd
	} else {
		close(cmd)
		return ""
	}
}

function compiler_log_debug(text) {
	if (compiler_debugmode)
		compiler_log_message(text)
}

function compiler_log_failure(text, file, lineno, context) {
	compiler_log_message("failure: " text, file, lineno, context)
	exit(1)
}

function compiler_log_message(text, file, lineno, context) {
	if (file) {
		if (context)
			text = context ":\n\t" text
		if (lineno)
			text = "line " lineno ": " text
		text = file ": " text
	}
	print "compiler: " text > "/dev/stderr"
}

function compiler_log_warning(text, file, lineno, context) {
	compiler_log_message("warning: " text, file, lineno, context)
}

function compiler_log_stderr(text) {
	print text >"/dev/stderr"
}

function compiler_makehash(string, hashlength,   randomizer, hash, hashstring, stringlength, sum, c, h, i, n, r, s) {
	if (!hashlength || hashlength <= 0)
		hashlength = compiler_makehash_defaulthashlength

	string = "hash" string
	stringlength = length(string)
	randomizer = 2.86
	numbermargin = 2 ^ 16

	sum = 0

	for (s = 1; s <= stringlength; s++) {
		c = substr(string, s, 1)
		sum = (sum + compiler_makehash_itable[c]) % numbermargin
	}

	n = sum
	h = 0

	for (s = 1; s <= stringlength; s++) {
		c = substr(string, s, 1)
		n = n + compiler_makehash_itable[c]

		for (i = 1; i <= hashlength; i++) {
			n = hash[h] + n
			r = (n * randomizer + randomizer) % (10 + 26)
			hash[h++] = r
			h = h % hashlength
			n = n - r
		}

		n = n % numbermargin
	}

	hashstring = ""

	for (h = 0; h < hashlength; h++) {
		n = int(hash[h])
		hashstring = hashstring compiler_makehash_ctable[n]
	}

	return hashstring
}

function compiler_makehash_initialize(uppercase, defaulthashlength,   c, i, j, l, h) {
	if (uppercase) {
		l = 65
		h = 92
	} else {
		l = 97
		h = 122
	}

	j = 0

	for (i = 0; i <= 255; i++) {
		c = sprintf("%c", i)

		compiler_makehash_itable[c] = i

		if ((i >= 48 && i <= 57) || (i >= l && i <= h)) {
			compiler_makehash_ctable[j++] = c
		}
	}

	compiler_makehash_defaulthashlength = defaulthashlength
}

function compiler_removefile(file) {
	compiler_log_message("removefile: " file)
	return (system("rm '" file "' >/dev/null 2>&1") == 0)
}

function compiler_removequotes(string,   temp) {
	if (match(string, /^'(.*)'$/, temp))
		return temp[1]

	if (match(string, /^"(.*)"$/, temp))
		string = temp[1]

	return gensub(/\\(.)/, "\\1", "g", string)
}

function compiler_test(op, file) {
	file = compiler_gendoublequotesform(file)
	return (system("test " op " " file " >/dev/null 2>&1") == 0)
}

function compiler_truncatefile(file) {
	compiler_log_message("truncate: " file)
	return (system(": > '" file "' >/dev/null 2>&1") == 0)
}

function compiler_writetocallsobj(text) {
	print text >> compiler_callsobjfile
}

function compiler_writetocallsobj_comment(text) {
	if (!compiler_noinfo) {
		sub(/^(  )?/, "#:", text)
		print text >> compiler_callsobjfile
	}
}

function compiler_writetomainobj(text) {
	print text >> compiler_mainobjfile
}

function compiler_writetomainobj_comment(text) {
	if (!compiler_noinfo) {
		sub(/^(  )?/, "#:", text)
		print text >> compiler_mainobjfile
	}
}


# Extensions

function EXTENSIONS(  i) {
	ARGS = "\"" gensub(/"/, "\\\"", "g", ARGV[1]) "\""

	for (i = 2; i < ARGC; i++)
		ARGS = ARGS gensub(/"/, "\\\"", "g", ARGV[i])
}


# Begin

BEGIN {
	GLOBALS()
	EXTENSIONS()
	compiler()
}
