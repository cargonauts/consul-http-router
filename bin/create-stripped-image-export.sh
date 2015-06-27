#!/bin/bash

# NAME
#	strip-image - strips the bare essentials from an image and exports them
#
# SYNOPSIS
#	strip-image [-d export-dir ] [-p package | -f file] [-x] 
#			
#
# OPTIONS
#	-d export-directory	to copy content to, defaults to /export.
#	-p package		package to include from image, multiple -p allowed.
#	-f file			file to include from image, multiple -f allowed.
#	-x			debug
#
# DESCRIPTION
#   	this script copies all the files from an installed package and copies them
#	to an export directory. Additional files can be added. When an executable
#	is copied, all dynamic libraries required by the executed are included too.
#
# EXAMPLE
#	The following example strips the nginx installation from the default NGiNX docker image, 
#	and allows the files in ./export to be added to a scratch image.
#
#        docker run -v $PWD/export/:/export \
#		   -v $PWD/bin:/mybin nginx \
#		/mybin/strip-image.sh \
#			-p nginx  \
#			-f /etc/passwd \
#			-f /etc/group \
#			-f '/lib/*/libnss*' \
#			-f /bin/ls \
#			-f /bin/cat \
#			-f /bin/sh \
#			-f /bin/mkdir \
#			-f /bin/ps \
#			-f /var/run \
#			-f /var/log/nginx \
#			-d /export
#
export EXPORT_DIR=/export

function usage() {
	echo "usage: $(basename $0) [-d export-dir ] [-p package] [-f file]" >&2
	echo "	$@" >&2
}

function parse_commandline() {

	while getopts "xp:f:d:" OPT; do
	    case "$OPT" in
		x)
		    DEBUG=1
		    ;;
		p)
		    PACKAGES="$PACKAGES $OPTARG"
		    ;;
		f)
		    FILES="$FILES $OPTARG"
		    ;;
		d)
		    EXPORT_DIR="$OPTARG"
		    ;;
		*)
		    usage
		    exit 1
		    ;;
	    esac
	done
	shift $((OPTIND-1))

	if [ -z "$PACKAGES" -a -z "$FILES" ] ; then
		usage "Missing -p or -f options"
		exit 1
	fi
	if [ ! -d $EXPORT_DIR ] ; then
		usage "$EXPORT_DIR is not a directory."
		exit 1
	fi
}

function print_file() {
		if [ -e "$1" ] ; then
			echo "$1"
		else
			test -n "$DEBUG" && echo "DEBUG: ignoring not existent file '$1'" >&2
		fi

		if [ -s "$1" ] ; then
			TARGET=$(readlink "$1")
			if  [ -n "$TARGET" ] ; then
				if expr "$TARGET" : '^/' >/dev/null 2>&1 ; then
					list_dependencies "$TARGET"
				else
					list_dependencies $(dirname "$1")/"$TARGET"
				fi
			fi
		fi
}

function list_dependencies() {
	for FILE in $@ ; do
		if [ -e "$FILE" ] ; then
			print_file "$FILE"
			if /usr/bin/ldd "$FILE" >/dev/null 2>&1 ; then
				/usr/bin/ldd "$FILE" | \
				awk '/statically/{next;} /=>/ { print $3; next; } { print $1 }' | \
				while read LINE ; do
					test -n "$DEBUG" && echo "DEBUG: including $LINE" >&2
					print_file "$LINE"
				done
			fi
		else
			test -n "$DEBUG" && echo "DEBUG: ignoring not existent file $FILE" >&2
		fi
	done
}

function list_packages() {
        /usr/bin/dpkg -L $1 | while read FILE ; do
		if [ ! -d "$FILE" ] ; then
			list_dependencies "$FILE"
		fi
        done
}

function list_all_packages() {	
	for i in "$@" ; do
		list_packages "$i"
	done 
}

parse_commandline "$@"


tar czf - $(

	(
	list_all_packages $PACKAGES
	list_dependencies $FILES
	)  | sort -u

) | ( cd $EXPORT_DIR ; tar -xzhvf - )
