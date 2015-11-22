#!/bin/bash -e
#Note only int, no 1.30.3.. etc or leters for script version
SCRIPT_VERSION=2
# NOTICE: Uncomment if your script depends on bashisms.
#if [ -z "$BASH_VERSION" ]; then bash $0 $@ ; exit $? ; fi

# Install KiCad from source onto either:
#  -> a Ubuntu/Debian/Mint or
#  -> a Red Hat
# compatible linux system.
#
# The "install_prerequisites" step is the only "distro dependent" one.  That step could be modified
# for other linux distros.
#
# There are 3 package groups in a KiCad install:
# 1) Compiled source code in the form of executable programs.
# 2) User manuals and other documentation typically as *.pdf files.
# 3) a) Schematic parts, b) layout footprints, and c) 3D models for footprints.
#
# To achieve 1) source is checked out from its repo and compiled by this script then executables
#  are installed using CMake.
# To achieve 2) documentation is checked out from its repo and installed using CMake.
# TO achieve 3a) and 3c) they are checked out from their repos and installed using CMake.
# To achieve 3b) a global fp-lib-table is put into your home directory which points to
#  http://github.com/KiCad.  No actual footprints are installed locally, internet access is used
#  during program operation to fetch footprints from github as if it was a remote drive in the cloud.
#  If you want to install those same KiCad footprints locally, you may run a separate script
#  named library-repos-install.sh found in this same directory.  That script requires that "git" be on
#  your system whereas this script does not.  The footprints require some means to download them and
#  bzr-git seems not up to the task.  wget or curl would also work.

# set number of cpus for make, if you have them use them !
CPUCOUNT=4 

# Since bash is invoked with -e by the first line of this script, all the steps in this script
# must succeed otherwise bash will abort at the first non-zero error code.  Therefore any script
# functions must be crafted to anticipate numerous conditions, such that no command fails unless it
# is a serious situation.
CONFIG_FILE=~/".$0.conf"
KICAD_BUILD_CONFIG_TAG="KICAD_BUILD_CONFIG*"
WEB_MASTER_KICAD_BUILD_SCRIPT_URL=www.lunchpad.com
SCRIPT_NAME=kicad-install.sh
#set this to your sytem or peruser tmp dirctory
SYSTEM_TMP_DIR="/tmp/"


languages="-DSINGLE_LANGUAGE=en"   #en,fr,it,ja,nl,pl
docformats="-DBUILD_FORMATS=pdf"   #html;pdf;epub
docpdfgenrator="-DPDF_GENERATOR=DBLATEX"  #FOP or DBLATEX  pad generator

# Set where the 3 source trees will go, use a full path
#WORKING_TREES=/public/kicad_sources
working_trees="~/buildkicad"

#STABLE=5054             # a sensible mix of features and stability
#TESTING=last:1          # the most recent

# Set this to STABLE or TESTING or other known revision number:
REVISION=$TESTING

# For info on revision syntax:
# $ bzr help revisionspec


# CMake Options No gdb debug
OPTS="-DBUILD_GITHUB_PLUGIN=ON"  # needed by $STABLE revision
OPTS_INSTALL_PREFIX="-DCMAKE_INSTALL_PREFIX="
INSTALL_DIR="/usr/local"

# Debug option
OPTS_DEBUG="-DCMAKE_BUILD_TYPE=Debug"
CMAKE_BUILD_TYPE="-DCMAKE_BUILD_TYPE=Release"
#OPTS_DEBUG=""

# Python scripting, uncomment only one to enable:
# Basic python scripting: gives access to wizards like footprint wizards (recommended)
# be sure you have python 2.7 installed
BASIC_PYTHON="$OPTS -DKICAD_SCRIPTING=ON"

# More advanced python scripting: gives access to wizards like footprint wizards and creates a python module
# to edit board files (.kicad_pcb files) outside kicad, by python scripts
MED_PYTHON="$OPTS -DKICAD_SCRIPTING=ON -DKICAD_SCRIPTING_MODULES=ON"

# Most advanced python scripting: you can execute python scripts inside Pcbnew to edit the current loaded board
# mainly for advanced users
MAX_PYTHON="$OPTS -DKICAD_SCRIPTING=ON -DKICAD_SCRIPTING_MODULES=ON -DKICAD_SCRIPTING_WXPYTHON=ON"
# Default no pyhon build
PYTHON=""

# Use https under bazaar to retrieve repos because this does not require a
# launchpad.net account.  Whereas lp:<something> requires a launchpad account.
# https results in read only access.
REPOS=https://code.launchpad.net

# This branch is a bzr/launchpad import of the Git repository
# at https://github.com/KiCad/kicad-library.git.
# It has schematic parts and 3D models in it.
LIBS_REPO=$REPOS/~kicad-product-committers/kicad/library

SRCS_REPO=$REPOS/~kicad-product-committers/kicad/product
DOCS_REPO=$REPOS/~kicad-developers/kicad/doc


#WEB_MASTER_KICAD_BUILD_SCRIPT_URL="http://bazaar.launchpad.net/~kicad-product-committers/kicad/product/view/head:/scripts"
WEB_MASTER_KICAD_BUILD_SCRIPT_URL="https://raw.githubusercontent.com/lachlanA/kicad-install/master/kicad-install.sh"
WEB_MASTER_KICAD_BUILD_SCRIPT_VERSION_URL="http://cosmosc.com/kicad"
WEB_MASTER_KICAD_BUILD_SCRIPT_SHA512SUM_URL="http://cosmosc.com/kicad"
###

SCRIPT_NAME=$(basename "$0")
SCRIPT_NAME_VERSION=$(basename "$0").version
SCRIPT_NAME_SHA512SUM=$(basename "$0").sha512
SYSTEM_TMP_DIR="/tmp"

WGET_OP="--wait=10 --no-proxy -q"
#WGET_OP="--wait=10 --no-proxy"
CMD=""
DEBUG=0
DISABLE_DOCS=0
BUILD_TYPE=0

usage()
{
    echo ""
    echo " Version $SCRIPT_VERSION kicad-install.sh script for linux"
    echo ""
    echo " Note: parameters in <> Are required, while parameters in [] are optional, | = OR, IE one in list"
    echo " IE: Build Python add on, needs -p MIN  for minimum version of python."
    echo " Note: This script can self update, using SHA512SUM verification, To over ride Version Check use -V"
    echo " and -S to disable SHA512SUM check. Also a backup copy of the current script will be made in both."
    echo " the script working directory and target working directory format will be script name + date"
    echo " This script must be mark as exectuable by: chmode a+rx $SCRIPT_NAME"
    echo " If target SOURCE'S director is not set, default will be be = $working_trees"
    echo " If Install DIRECTOR is not set, default will be = $INSTALL_DIR"
    echo ""
    echo "  ./kicad-install.sh <cmd> [Options...]"
    echo "  where <cmd> can be one of.."
    echo ""
    echo "   --setup-update-build-install    ( Full/New install which also updates current install KiCad )"
    echo "   --setup-update-build-tools      ( Install/Update build tools only)"
    echo "   --update-build-install          ( Update source then build and install KiCad )"
    echo "   --build-install                 ( Build source and install KiCad.)"
    echo "   --install                       ( Install KiCad )"
    echo "   --remove-sources                ( Removes source trees for another attempt )"
    echo "   --uninstall-libraries           ( Removes KiCad supplied libraries )"
    echo "   --uninstall-kicad               ( Uninstalls all of KiCad but leaves source trees. )"
    echo "   --script-server-version-check   ( Check version of script $0 on server )"
    echo "   --script-server-install         ( Update version of $SCRIPT_NAME script from server,"
    echo "                                      only update's if newer Note: Use -V to force update )"
    echo "   --diff-server-local-script      ( Show the difference between current and server scripts"
    echo "                                      $SCRIPT_NAME, using diff, Note: With NO! SHA512SUM verification )"
    echo "   --make-script-sha512            ( Makes 2 files, one with a SHA512SUM in $working_trees/$SCRIPT_NAME_SHA512SUM other"
    echo "                                      With SCRIP_VERSION in file $working_trees/$SCRIPT_NAME_VERSION )"
    echo "   --clean                         ( Clean build files IE: Frees disk space )"    
    echo "   --delete-build-dir              ( Delete the SOURCE'S/build directory, you may need to do this if"
    echo "                                      build is not working as exepcted )"    
    echo "   --version                       ( Prints script version )"
    echo "   --help                          ( This help Docs )"
    echo ""    
    echo "  Where Options can be any number of--"
    echo "  Options Are"
    echo "      [-t SOURCEDIR]         ( Set Target directory for source's/build )"
    echo "      [-n INSTALLBINDIR]     ( Set Install directory for bin NOTE: if you change the install director )"
    echo "      [-d ]                  ( Build GDB debug version )"
    echo "      [-D ]                  ( Disable Documents Build )"
    echo "      [-r ]                  ( Build version, Set this to STABLE or TESTING or other known revision number 5054 etc )"
    echo "      [-S ]                  ( Disable SHA512SUM verification )"
    echo "      [-V ]                  ( Disable version check )"
    echo "      [-p MIN | MED | MAX ]  ( Build python MIN=For footprint wizards, MED=creates a python module, )"
    echo "                                MAX=Pcbnew can edit the current loaded board)"
    echo "      [-x ProcessCount ]     ( Set's the number of Build process's for Make -j ProcessCount )"    
    echo ""
    echo " Example: $0 --setup-update-build-install -t /home/fred/src/kicad -n /usr/ -d -D -x 8" 
    echo ""
    echo " Will Install source's at: /home/fred/src/kicad, and Binaries install tree at: /usr "
    echo " and build with Debug Enabled, Documents Disabled, make j8 (8 build process's) "
    echo ""
}



#return's
# 0 web same as local version,
# 1 web newer then local version
# 2 web older than local version
# 3 no version file on web
# 4 ssha512sum check failed it's bad/or hacked
# 5 ssha512sum file not found
# 6 No scripting file on server to check
check_version()
{
    OLD_VERSION=$SCRIPT_VERSION
    
    if [ "$DISABLE_VERSION_CHECK" != 1 ]; then
	set +e
	# check for script version file first
	wget $WGET_OP "$WEB_MASTER_KICAD_BUILD_SCRIPT_VERSION_URL/$SCRIPT_NAME_VERSION" -O "$SYSTEM_TMP_DIR/$SCRIPT_NAME_VERSION.$$"
	RESULT=$?
	set -e
	if [ "$RESULT" != 0 ]; then
	    return 3;
	fi
    fi
    
# check for script SHA512SUM file
    if [ "$DISABLE_SHA512SUM" != 1 ]; then
	set +e
	wget $WGET_OP "$WEB_MASTER_KICAD_BUILD_SCRIPT_SHA512SUM_URL/$SCRIPT_NAME_SHA512SUM" -O "$SYSTEM_TMP_DIR/$SCRIPT_NAME_SHA512SUM.$$"
	RESULT=$?
	set -e


	if [ "$RESULT" == 0 ]; then  #Ok found hash so now download script
	    set +e
	    wget $WGET_OP "$WEB_MASTER_KICAD_BUILD_SCRIPT_URL/$SCRIPT_NAME" -O "$SYSTEM_TMP_DIR/$SCRIPT_NAME.$$"
	    RESULT=$?
	    set -e
	    if [ "$RESULT" == 0 ]; then #good ?
		set +e  #so hash check
		sha512sum --status -c "$SYSTEM_TMP_DIR/$SCRIPT_NAME_SHA512SUM.$$" <"$SYSTEM_TMP_DIR/$SCRIPT_NAME.$$" 
		RESULT=$?
		set -e
		if [ "$RESULT" != 0 ]; then
		    return 4
		fi
	    else
		return 6; # could not find scripting file to check
	    fi
	    
	else
	    return 5 # Ok no version file, so return with error
	fi
    fi

    if [ "$DISABLE_VERSION_CHECK" == 1 ]; then #disable version check ?
	return 1;  # Yes just return good then, and say version on server is newer.
    fi

    #	grep -e "^SCRIPT_VERSION=" $SYSTEM_TMP_DIR/$SCRIPT_NAME.$$ >$SYSTEM_TMP_DIR/$SCRIPT_NAME.$$
    source "$SYSTEM_TMP_DIR/$SCRIPT_NAME_VERSION.$$" #Read the version 
    if [ "$SCRIPT_VERSION" == "$OLD_VERSION" ]; then
	return 0 #same version
    else
	if [ "$SCRIPT_VERSION" -gt "$OLD_VERSION" ]; then
	    return 1 #Web is newer
	else
	    return 2 #Web is older
	fi
    fi
}

# work out assute path
function abspath() {
    # generate absolute path from relative path
    # $1     : relative filename
    # return : absolute path
    if [ -d "$1" ]; then
	# dir
	(cd "$1"; pwd)
    elif [ -f "$1" ]; then
	# file
	if [[ $1 == */* ]]; then
	    echo "got here1"
	    newpath="$(cd "${1%/*}"; pwd)/${1##*/}"
	else
	    echo "got here2"
	    newpath="$(pwd)/$1"
	fi
    fi
}

#
function getabspath {
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
	    [[ I -ne 0 ]] && newpath="/${T2[*]}/" || newpath=/
	    ;;
	*)
	    [[ I -ne 0 ]] && newpath="/${T2[*]}" || newpath=/.
	    ;;
    esac
}
#
parse_param()
{

    #    for i ; do echo - $i ; done
    # Code template for parsing command line parameters using only portable shell
    # code, while handling both long and short params, handling '-f file' and
    # '-f=file' style param data and also capturing non-parameters to be inserted
    # back into the shell positional parameters.
    
    while [ -n "$1" ]; do
        # Copy so we can modify it (can't modify $1)
        OPT="$1"
        # Detect argument termination
        if [ x"$OPT" = x"--" ]; then
            shift
            for OPT ; do
                REMAINS="$REMAINS \"$OPT\""
            done
            break
        fi
	
	# Parse current opt
        while [ x"$OPT" != x"-" ] ; do
            case "$OPT" in
                # Handle --flag=value opts like this
                --setup-update-build-install )
                    CMD=install-or-update
		    BUILD_TYPE=0 #Full Install Update and Build
                    ;;
                --setup-update-build-tools )
                    CMD=install-or-update-build-tools
                    ;; 
                --update-build-install )
                    CMD=update-source-and-build
		    BUILD_TYPE=1 # Update Build and install
                    ;;
                --build-install )
                    CMD=build-install
		    BUILD_TYPE=2 # Build and install
                    ;;
                --install )
                    CMD=install
		    BUILD_TYPE=3 # Install only
                    ;;
		--remove-sources )
                    CMD=remove-sources
                    ;;
                --uninstall-libraries )
                    CMD=uninstall-libraries
                    ;;
                --uninstall-kicad )
                    CMD=uninstall-kicad
                    ;;
		--script-server-version-check )
                    CMD=check-version
                    ;;
		--script-server-install )
                    CMD=update-version
                    ;;
		--diff-server-local-script )
                    CMD=diff-version
                    ;;
		--make-script-sha512 )
                    CMD=make-version-hash
                    ;;
		--clean ) 
                    CMD=clean
		    BUILD_TYPE=4 #Clean only
                    ;;
		--version ) 
                    CMD=version
                    ;;
		--delete-build-dir )  # remove the build directory
                    CMD=delete-build-dir
                    ;;
		-h | --help )
                    CMD=help
                    ;;
                # and --flag value opts like this
                -t  ) # Set the build directory
		    getabspath $2
		    working_trees=$newpath
                    shift
                    ;;
                -n  ) # set the install dirctory
		    getabspath $2
                    INSTALL_DIR=$newpath
                    shift
                    ;;
                -d  )
                    DEBUG=1
                    ;;
                -p  )
                    PYTHON="$2"
		    shift
                    ;;
                -D  ) # disable Docments build
                    DISABLE_DOCS=1
                    ;;
                -r  ) # Set version to build
                    REVISION=$2
		    shift
                    ;;
                -S  ) # disable SHA512SUM 
                    DISABLE_SHA512SUM=1
                    ;;
                -V  ) # disable version check 
                    DISABLE_VERSION_CHECK=1
                    ;;
                -x  )
                    CPUCOUNT="$2"
                    ;;
                # Anything unknown is recorded for later
                * )
                    REMAINS="$REMAINS \"$OPT\""
                    break
                    ;;
            esac
            # Check for multiple short options
            # NOTICE: be sure to update this pattern to match valid options
            NEXTOPT="${OPT#-[dSVD]}" # try removing single short opt
            if [ x"$OPT" != x"$NEXTOPT" ] ; then
                OPT="-$NEXTOPT"  # multiple short opts, keep going
            else
                break  # long form, exit inner loop
            fi
        done
        # Done with that param. move to next
        shift
    done
    # Set the non-parameters back into the positional parameters ($1 $2 ..)
    eval set -- "$REMAINS"

#    echo -e "After: \n configfile='$CONFIGFILE' \n force='$FORCE' \n retry='$RETRY' \n remains='$REMAINS'"
}
 
install_prerequisites()
{
    # Find a package manager, PM
    PM=$( command -v yum || command -v apt-get )

    # assume all these Debian, Mint, Ubuntu systems have same prerequisites
    if [ "$(expr match "$PM" '.*\(apt-get\)')" == "apt-get" ]; then
        #echo "debian compatible system"
        prerequisite_list="
            git
            make
            asciidoc
            pandoc
            gettext
            po4a
            dblatex
            texlive-xetex
            fonts-vlgothic
            source-highlight
            texlive-lang-english
            texlive-lang-french
            texlive-lang-italian
            texlive-lang-japanese
            texlive-lang-polish
            bzr
            bzrtools
            build-essential
            cmake
            cmake-curses-gui
            debhelper
            doxygen
            grep
            libbz2-dev
            libcairo2-dev
            libglew-dev
            libssl-dev
            libwxgtk3.0-dev
            wget
       "
#            texlive-lang-cjk 
#            texlive-lang-dutch not on debian 8
        for p in ${prerequisite_list}
        do
	set +e
            sudo apt-get install "$p" || exit 1
	set -e
        done

        # Only install the scripting prerequisites if required.
        if [ "$PYTHON" != "" ]; then
        #echo "KICAD_SCRIPTING=ON"
            scripting_prerequisites="
                python-dev
                python-wxgtk3.0-dev
                swig
            "
            for sp in ${scripting_prerequisites}
            do
		set +e
                sudo apt-get install "$sp" || exit 1
		set -e
            done
        fi

	#Option list, some package's name's change for deleted
        # So by naming all package's  we get at lest one, and miss the other, but thats ok
	# each version of debian is diffant.. !!
	scripting_prerequisites="
            texlive-lang-dutch
            texlive-lang-european
            "
        for sp in ${scripting_prerequisites}
        do
	    set +e
            sudo apt-get install "$sp"
	    set -e
        done

	
    # assume all yum systems have same prerequisites
    elif [ "$(expr match "$PM" '.*\(yum\)')" == "yum" ]; then
        #echo "red hat compatible system"
        # Note: if you find this list not to be accurate, please submit a patch:
        sudo yum groupinstall "Development Tools" || exit 1

        prerequisite_list="
            git
            bzr
            bzrtools
            bzip2-libs
            bzip2-devel
            cmake
            cmake-gui
            doxygen
            cairo-devel
            glew-devel
            grep
            openssl-devel
            wxGTK3-devel
            wget
        "

        for p in ${prerequisite_list}
        do
            sudo yum install "$p" || exit 1
        done

        echo "Checking wxGTK version. Maybe you have to symlink /usr/bin/wx-config-3.0 to /usr/bin/wx-config"
        V=`wx-config --version | cut -f 1 -d '.'` || echo "Error running wx-config."
        if [ "$V" -lt 3 ]
        then
        	echo "Error: wx-config is reporting version prior to 3"
        	exit
        else
        	echo "All ok"
        fi
        # Only install the scripting prerequisites if required.
        if [ "$(expr match "$OPTS" '.*\(-DKICAD_SCRIPTING=ON\)')" == "-DKICAD_SCRIPTING=ON" ]; then
        #echo "KICAD_SCRIPTING=ON"
            scripting_prerequisites="
                swig
                wxPython
            "

            for sp in ${scripting_prerequisites}
            do
                sudo yum install "$sp" || exit 1
            done
        fi
    else
        echo
        echo "Incompatible System. Neither 'yum' nor 'apt-get' found. Not possible to continue."
        echo
        exit 1
    fi

    # ensure bzr name and email are set.  No message since bzr prints an excellent diagnostic.
    bzr whoami || {
        echo "WARNING: You have not set bzr whoami, so I will set a dummy."
        export BZR_EMAIL="Kicad Build <nobody@foo>"
    }
}


rm_build_dir()
{
    local dir="$1"

    echo "removing directory $dir"

    if [ -e "$dir/install_manifest.txt" ]; then
        # this file is often created as root, so remove as root
        sudo rm "$dir/install_manifest.txt" 2> /dev/null
    fi

    if [ -d "$dir" ]; then
        sudo rm -rf "$dir"
    fi
}


cmake_uninstall()
{
    # assume caller set the CWD, and is only telling us about it in $1
    local dir="$1"

    cwd=`pwd`
    if [ "$cwd" != "$dir" ]; then
        echo "missing dir $dir"
    elif [ ! -e install_manifest.txt  ]; then
        echo
        echo "Missing file $dir/install_manifest.txt."
    else
        echo "uninstalling from $dir"
        sudo make uninstall
        sudo rm install_manifest.txt
    fi
}


# Function set_env_var
# sets an environment variable globally.
set_env_var()
{
    local var=$1
    local val=$2

    if [ -d /etc/profile.d ]; then
        if [ ! -e /etc/profile.d/kicad.sh ] || ! grep "$var" /etc/profile.d/kicad.sh >> /dev/null; then
            echo
            echo "Adding environment variable $var to file /etc/profile.d/kicad.sh"
            echo "Please logout and back in after this script completes for environment"
            echo "variable to get set into environment."
            sudo sh -c "echo export $var=$val >> /etc/profile.d/kicad.sh"
        fi

    elif [ -e /etc/environment ]; then
        if ! grep "$var" /etc/environment >> /dev/null; then
            echo
            echo "Adding environment variable $var to file /etc/environment"
            echo "Please reboot after this script completes for environment variable to get set into environment."
            sudo sh -c "echo $var=$val >> /etc/environment"
        fi
    fi
}

# save config
save_to_configfile()
{
    set | grep "$KICAD_BUILD_CONFIG_TAG" >~/"$CONFIG_FILE"
}

# Install build update
install_or_update()
{
    shopt -s nocasematch

    if [ "$DEBUG" == "1" ]; then
	OPTS="$OPTS $OPTS_DEBUG"
    else
	OPTS="$OPTS $CMAKE_BUILD_TYPE"
    fi
    if [ "$PYTHON" == "MIN" ]; then
	OPTS="$OPTS $BASIC_PYTHON"
    fi
    if [ "$PYTHON" == "MED" ]; then
	OPTS="$OPTS $MED_PYTHON"
    fi
    if [ "$PYTHON" == "MAX" ]; then
	OPTS="$OPTS $MAX_PYTHON"
    fi

    OPTS="$OPTS $OPTS_INSTALL_PREFIX$INSTALL_DIR"

	
    
#    echo "$OPTS"
    shopt -u nocasematch

#    if [ $# -gt 0 ]; then
#	BUILD_TYPE=$1	
#    fi
    
    if [ "$BUILD_TYPE" == "0" ]; then
	echo "step 1) installing pre-requisites"
	install_prerequisites

	echo "step 2) make $working_trees if it does not exist"
	if [ ! -d "$working_trees" ]; then
            sudo mkdir -p "$working_trees"
            echo " mark $working_trees as owned by me"
            sudo chown -R `whoami` "$working_trees"
	fi
    fi

    if [ ! -d "$working_trees" ]; then # is build there ?
	set +e
	echo "step 2) make $working_trees if it does not exist"
        sudo mkdir -p "$working_trees"
        echo " mark $working_trees as owned by me"
        sudo chown -R `whoami` "$working_trees"
	set -e
    fi
    
    shopt -s nocasematch    
    if [ "$REVISION" == "TESTING" ]; then
	REVISION="last:1"
    fi
    if [ "$REVISION" == "STABLE" ]; then
	REVISION="5054"
    fi
    shopt -u nocasematch    
    
    if [ "$BUILD_TYPE" == "0" -o "$BUILD_TYPE" == "1" ]; then
	echo "step 3) checking out the source code from launchpad repo..."
	if [ -d "$working_trees/kicad.bzr" ]; then # is build there ?
	    if [ -d "$working_trees/kicad.bzr/build" ]; then # is build there ?
		if [[ ! -s "$working_trees/kicad.bzr/build/CMakeCache.txt"  ]]; then # Yes, what about CMakeCache.txt
		    echo -ne "\n\tFound partly installed, or existing install which is\n\tDamage or CMake has not been run on, you have 3 option\n"
		    echo -ne "\tX Exit this script(IE do nothing)\n"
		    echo -ne "\tC Check the sounce tree, (this will take some time!)-\n"
		    echo -ne "\t  if good, continue, if bad delete, and download new one.\n"
		    echo -ne "\tD Delete the source tree, and download and install new one-\n"
		    echo -ne "\t  it may be slow dependingg on your internet and server load\n\n"
		    echo -ne "Select one of.. C,D,X :"
		    read asser
		    while true; do
			case $asser in
			    X | x )
				echo -ne "\n\nExiting script with no changes!\n\n"
				exit 0
				;;
			    C | c )
				echo -ne "\n\nChecking and will continue if good, abort and delete old tree if bad!\n\n"
				bzr check kicad.bzr
				if [[ $? != 0 ]]; then 
				    echo -ne "\n\nSource tree Bad so deleteing old tree, and downlading new one!\n\n"
				    sudo rm -rf "$working_trees/kicad.bzr"
				    bzr checkout -r "$REVISION" "$SRCS_REPO" "$working_trees/kicad.bzr"
				    sudo chown -R `whoami` "$working_trees"		
				else
				    echo "Existing install good, so updating."
				    cd "$working_trees/kicad.bzr"
				    bzr up -r "$REVISION"
				    cd ../
				    break
				fi
				;;
			    D | d )
				echo -ne "\n\nDelete existing working tree "$working_trees/*.*" and over write with new source tree!\n\n"
				sudo rm -rf "$working_trees/kicad.bzr"
				bzr checkout -r "$REVISION" "$SRCS_REPO" "$working_trees/kicad.bzr"
				sudo chown -R `whoami` "$working_trees"		
				echo "woof woof"
				break
				;;
			    *)
				echo -ne "\n\nTry again input can only one of X,C,D!\n\n"
				;;
			esac
		    done
		else # Ok we have CMakeCache.txt so must be hanging round from last build
		    cd "$working_trees/kicad.bzr/"
		    bzr up -r "$REVISION"
		    echo " local source working tree updated."
		    cd ../
		fi
	    else # No build directory,  so check sournce's to see if there usable.. 
		if [ -d "$working_trees/kicad.bzr/pcbnew/plugin.cpp" ]; then # is build there ?
		    echo -ne "\n\nChecking and will continue if good, abort and delete old tree if bad!\n\n"
		    bzr check "$working_trees/kicad.bzr"
		    if [[ $? != 0 ]]; then 
			echo -ne "\n\nSource tree Bad so deleteing old tree, and downlading new one!\n\n"
			sudo rm -rf "$working_trees/kicad.bzr"
			bzr checkout -r "$REVISION" "$SRCS_REPO" "$working_trees/kicad.bzr"
			sudo chown -R `whoami` "$working_trees"		
		    else
			echo "Existing install good, so updating."
			cd "$working_trees/kicad.bzr"
			bzr up -r "$REVISION"
			cd ../
			break
		    fi
		else
		    echo -ne "\n\nSource tree Not install/or bad so install new one!\n\n"
		    sudo rm -rf "$working_trees/kicad.bzr"
		    if [ ! -d "$working_trees/kicad.bzr" ]; then
	     		mkdir "$working_trees/kicad.bzr"
		    fi
		    if [ ! -d "$working_trees/kicad.bzr/build" ]; then
	     		mkdir "$working_trees/kicad.bzr/build"
		    fi
		    bzr checkout -r "$REVISION" "$SRCS_REPO" "$working_trees/kicad.bzr"
		    sudo chown -R `whoami` "$working_trees"		
		fi
	    fi
	else # No kicad.bzr
	    cd "$working_trees/"
	    if [ ! -d "$working_trees/kicad.bzr" ]; then
	     	mkdir "$working_trees/kicad.bzr"
	    fi
	    if [ ! -d "$working_trees/kicad.bzr/build" ]; then
	     	mkdir "$working_trees/kicad.bzr/build"
	    fi
	    bzr checkout -r "$REVISION" "$SRCS_REPO" "$working_trees/kicad.bzr"
	    sudo chown -R `whoami` "$working_trees"		
	fi

	echo "step 4) checking out the schematic parts and 3D library repo."
	if [ ! -d "$working_trees/kicad-lib.bzr" ]; then
            bzr checkout "$LIBS_REPO" "$working_trees/kicad-lib.bzr"
	    sudo chown -R `whoami` "$working_trees"		
            echo ' kicad-lib checked out.'
	else
            cd "$working_trees/kicad-lib.bzr"
            bzr up
            echo ' kicad-lib repo updated.'
            cd ../
	fi

	if [ "$DISABLE_DOCS" == "0" ]; then
	    echo "step 5) checking out the documentation from launchpad repo..."
	    if [ ! -d "$working_trees/kicad-doc.git" ]; then
		mkdir "$working_trees/kicad-doc.git"
		sudo chown -R `whoami` "$working_trees"		
		cd "$working_trees/kicad-doc.git"
		git clone https://github.com/KiCad/kicad-doc.git
		mkdir "$working_trees/kicad-doc.git/kicad-doc/build"
		cd "$working_trees/kicad-doc.git/kicad-doc/build"
		cmake "$OPTS $languages $docformats $docpdfgenrator" ..
		echo " docs checked out."
	    else
		cd "$working_trees/kicad-doc.git/kicad-doc"
		git pull origin master
		echo " docs working tree updated."
		cd ../
	    fi
	fi
    fi

    if [ "$BUILD_TYPE" == "0" -o "$BUILD_TYPE" == "1" -o "$BUILD_TYPE" == "2" ]; then
	echo "step 6) compiling source code..."
	# cd kicad.bzr
	# if [ ! -s "build/CMakeCache.txt" ]; then     # Is Build dir & CMakeCache.txt aready build ?
        #     cd build   # No so set it up
        #     cmake ../ $OPTS  || exit 1
	#     echo "$OPTS" >"CMakeCache.txt.OPTS.last"
	#     cd ..
	# fi
	local cmake_opts
	if [ -s "$working_trees/kicad.bzr/build/CMakeCache.txt.OPTS.last" ]; then     # We have a old build CMake history ?
	    cmake_opts=$(<"$working_trees/kicad.bzr/build/CMakeCache.txt.OPTS.last")    # Yes read it then
	else
	    cmake_opts=""  # No history so force clean and CMake build then
	fi
#	echo "cmake_opts=$cmake_opts.  OPTS=$OPTS."
	if [ "$cmake_opts" != "$OPTS" ]; then
	    cd "$working_trees/kicad.bzr/build"
	    cmake $OPTS .. || exit 1
	    echo "$OPTS" >"$working_trees/kicad.bzr/build/CMakeCache.txt.OPTS.last"
	    make clean
	    cd ..
	fi
	cd "$working_trees/kicad.bzr/build"
	make -j"$CPUCOUNT" || exit 1
	echo " kicad compiled."
	cd ..
    fi


    if [ "$BUILD_TYPE" == "0" -o "$BUILD_TYPE" == "1" -o "$BUILD_TYPE" == "2" -o "$BUILD_TYPE" == "3" ]; then
	cd "$working_trees/kicad.bzr/build"
	echo "step 7) installing KiCad program files..."
	sudo make install
	echo " kicad program files installed."
	cd ../
    fi

    if [ $CMD == "clean" ]; then
	cd "$working_trees/kicad.bzr/build"
#	echo "Got  here $?"
	sudo make clean
	echo ""
	echo "Clean compelete"
	echo ""
	return
    fi 

    echo "step 8) installing libraries..."
    cd "$working_trees/kicad-lib.bzr"
    rm_build_dir build
    mkdir build && cd build
    cmake ..
    sudo make install
    echo " kicad-lib.bzr installed."


    echo "step 9) as non-root, install global fp-lib-table if none already installed..."
    # install ~/fp-lib-table
    if [ ! -e ~/fp-lib-table ]; then
        make  install_github_fp-lib-table
        echo " global fp-lib-table installed."
    fi

    if [ "$DISABLE_DOCS" == "0" ]; then
	echo "step 10) installing documentation..."
	cd "$working_trees/kicad-doc.git/kicad-doc/build/"
	sudo make install
	echo " kicad-doc.git installed."
    fi
    
    echo "step 11) check for environment variables..."
    if [ -z "${KIGITHUB}" ]; then
        set_env_var KIGITHUB https://github.com/KiCad
    fi

    echo
    echo "KiCad $CMD step(s) completed"
    echo
}

##
lowercase(){
    echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

#------------------------------------------------------------------------------
#
lowercase(){
    echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}
# work out the OS you have
OS=`lowercase \`uname\``
KERNEL=`uname -r`
MACH=`uname -m`

if [ "{$OS}" == "windowsnt" ]; then
    OS=windows
elif [ "{$OS}" == "darwin" ]; then
    OS=mac
else
    OS=`uname`
    if [ "${OS}" = "SunOS" ] ; then
        OS=Solaris
        ARCH=`uname -p`
        OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
    elif [ "${OS}" = "AIX" ] ; then
        OSSTR="${OS} `oslevel` (`oslevel -r`)"
    elif [ "${OS}" = "Linux" ] ; then
        if [ -f /etc/redhat-release ] ; then
            DistroBasedOn='RedHat'
            DIST=`cat /etc/redhat-release |sed s/\ release.*//`
            PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/SuSE-release ] ; then
            DistroBasedOn='SuSe'
            PSUEDONAME=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
            REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
        elif [ -f /etc/mandrake-release ] ; then
            DistroBasedOn='Mandrake'
            PSUEDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/debian_version ] ; then
            DistroBasedOn='Debian'
	    REV=`hostnamectl | grep -i "operating system"`
        fi
        if [ -f /etc/UnitedLinux-release ] ; then
            DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
        fi
        OS=`lowercase $OS`
        DistroBasedOn=`lowercase $DistroBasedOn`
        readonly OS
        readonly DIST
        readonly DistroBasedOn
        readonly PSUEDONAME
        readonly REV
        readonly KERNEL
        readonly MACH
    fi
fi
#
echo ""
echo "Running on $OS $REV $DIST $KERNEL $MACH"
echo ""
parse_param $@

if [ "$CMD" == "" -o "$CMD" == "help" ]; then
    usage
    exit 0
fi

if [ "$CMD" == "version" ]; then
    echo ""
    echo " $SCRIPT_NAME File SCRIPT_VERSION=$SCRIPT_VERSION"
    echo ""
    exit 0
fi

# Read config file
if [ -r "$CONFIG_FILE" -a -s "$CONFIG_FILE"  ]; then
    echo "Config file found"
    source "$CONFIG_FILE" # Read it
fi

# Build scrip hash and verson files for server
if [ "$CMD" == "make-version-hash" ]; then
    echo "SCRIPT_VERSION=$SCRIPT_VERSION" >"$working_trees/$SCRIPT_NAME_VERSION"
    sudo echo "" >>"$working_trees/$SCRIPT_NAME_VERSION"
    sudo sha512sum <"$0" >"$working_trees/$SCRIPT_NAME_SHA512SUM"
    echo ""
    echo "New SHA512 Hash file for $SCRIPT_NAME is at $working_trees/$SCRIPT_NAME_SHA512SUM"
    echo "New Version file for $SCRIPT_NAME is at $working_trees/$SCRIPT_NAME_VERSION"
    echo ""
    exit 0
fi

# Show diff from server to local
if [ "$CMD" == 'diff-version' ]; then #show diff of web and local
    set +e
    # check for script version file first
    wget $WGET_OP "$WEB_MASTER_KICAD_BUILD_SCRIPT_VERSION_URL/$SCRIPT_NAME" -O "$SYSTEM_TMP_DIR/$SCRIPT_NAME.$$"
    RESULT=$?
    set -e
    if [ $RESULT == 0 ]; then
	diff -s "$0" "$SYSTEM_TMP_DIR/$SCRIPT_NAME.$$" | less
    else
	echo ""
	echo "********************************************************************************"
	echo "Could not Read $SCRIPT_NAME from server $WEB_MASTER_KICAD_BUILD_SCRIPT_VERSION_URL/$SCRIPT_NAME"
	echo "********************************************************************************"
	echo ""
	echo ""	
	exit 0
    fi
fi

# --update-version
if [ "$CMD" == "update-version" ]; then #update current to version on server if latter than current on
    # check for script version file first
    set +e
    check_version && true
    vrs=$?
    set -e

    case "$vrs" in
        0)       #Same no update
	    if [ "$DISABLE_VERSION_CHECK" != 1 ]; then
		echo ""
		echo "Server and yours version is same so No update were committed, script version = $SCRIPT_VERSION"
		echo ""
		exit 0
	    else
		echo ""
		echo "Server version is same as this version But you have requested over writing your version.  Version = $SCRIPT_VERSION!"
		echo ""
	    fi
	    ;;
        1)       #Web version is newer so update
	    echo ""
	    echo "Server version=$SCRIPT_VERSION is Newer than your version=$OLD_VERSION"
	    echo ""
            ;;
        2)
	    if [ "$DISABLE_VERSION_CHECK" != 1 ]; then
		echo ""
		echo "Server version is older than yours version so No update were committed, Version = $SCRIPT_VERSION"
		echo ""
		exit 0
	    else
		echo ""
		echo "Server version is older than yours version, But you have requested over writing your version.  Version = $SCRIPT_VERSION!"
		echo ""
	    fi
            ;;
        3)
	    echo ""
            echo "There is no version file on server to check with your version!"
	    echo ""
	    exit 1;
            ;;
        4)
	    echo ""
            echo "Server script file=$SCRIPT_NAME failed sha512sum check, so is bad/damage, or hacked!"
	    echo ""
	    exit 1;
            ;;
        5) # check file not server
	    echo ""
	    echo "********************************************************************************"	    
            echo "Server SHA512 check file $SCRIPT_NAME_SHA512SUM not on server!"
	    echo "********************************************************************************"
	    echo ""
	    exit 1;
            ;;
        *)
    esac

  
    if [ "$DISABLE_SHA512SUM" == 1 ]; then #We dont have the version so download it
	set +e       
	wget $WGET_OP "$WEB_MASTER_KICAD_BUILD_SCRIPT_VERSION_URL/$SCRIPT_NAME" -O "$SYSTEM_TMP_DIR/$SCRIPT_NAME.$$"
	local rs=$?
	set -e
	if [ "$rs" != 0 ]; then
	    echo ""
	    echo ""	    
	    echo "********************************************************************************"
	    echo "Could not Read $SCRIPT_NAME from server $WEB_MASTER_KICAD_BUILD_SCRIPT_VERSION_URL/$SCRIPT_NAME"
	    echo "********************************************************************************"
	    echo ""
	    echo ""	
	    exit 1
	fi
    else
	RESULT=0 # Ok  download it already mark as good.
    fi

    if [ "$RESULT" == 0 ]; then
	cp "$0" "$0.backup.$(date +y%Ym%md%dh%Hm%Ms%S)" && true
	cp "$0" "$working_trees/$WORKING$0.backup.$(date +y%Ym%md%dh%Hm%Ms%S)" && true
	RESULT=$?
	if [ "$RESULT" != 0 ]; then
	    echo "Could not back up old script $0 before overwriting with new version of script, update aborted!"
	    exit 1
	fi
    fi

    cp "$SYSTEM_TMP_DIR/$SCRIPT_NAME.$$" "$0" && true
    RESULT=$?
    if [ "$RESULT" != 0 ]; then
	echo "Could not copy new script over old script!"
	exit 1
    fi

    echo "********************************************************************************"
    echo "Local script $SCRIPT_NAME updated to server version at $WEB_MASTER_KICAD_BUILD_SCRIPT_VERSION_URL/$SCRIPT_NAME"
    echo "********************************************************************************"
    echo ""
    exit 0
fi


# --check-version
if [ "$CMD" == "check-version" ]; then #update current to version on server if latter than current on
    # check for script version file first
    set +e
    check_version && true
    RESULT=$?
    set -e
    
    case "$RESULT" in
        0)       #Same no update
	    echo ""
	    echo "Server version is same as this version=" $SCRIPT_VERSION
	    ;;
        1)       #Web version is newer so update
	    echo ""
	    echo "Server version is newer=$SCRIPT_VERSION than current version=$OLD_VERSION"
            ;;
        2)       #Web is older
	    echo ""
	    echo "Server version=$SCRIPT_VERSION is older than our version=$OLD_VERSION"
            ;;
        3)       #Could not read version info from server.
	    echo ""
	    echo "********************************************************************************"
	    echo "Could not Read script version information from $WEB_MASTER_KICAD_BUILD_SCRIPT_VERSION_URL"         
	    echo "********************************************************************************"
            ;;
        4)       #Check sum failed
	    echo ""
	    echo "********************************************************************************"
            echo "Server script file=$SCRIPT_NAME failed sha512sum check, so is bad/damage, or hacked!"
	    echo "********************************************************************************"
            ;;
        5)       #No server SHA512 check file not server
	    echo ""
	    echo "********************************************************************************"
            echo "Server SHA512 check file $SCRIPT_NAME_SHA512SUM not on server!"
	    echo "********************************************************************************"
            ;;
        *)
    esac
    echo ""
    exit 1
fi



# Install build tools
if [ "$CMD" == "install-or-update-build-tools" ]; then
    install_prerequisites
    echo ""
    echo "install-or-update-build-tools compelete"
    echo ""
    exit 0
fi
	   
#remove sounces
if [ "$CMD" == "remove-sources" ]; then
    echo "deleting $working_trees"
    rm_build_dir "$working_trees/kicad.bzr/build"
    rm_build_dir "$working_trees/kicad-lib.bzr/build"
    if [ -d "$working_trees/kicad-doc.bzr/build" ]; then # check for installed doc's first
	rm_build_dir "$working_trees/kicad-doc.bzr/build"
    fi
    sudo rm -rf "$working_trees"
    echo ""
    echo "remove-sources compelete"
    echo ""
    exit 0
fi

#update source's and build
if [ "$CMD" == "update-source-and-build" ]; then
    install_or_update
    exit 0
fi

#install every thing
if [ "$CMD" == "install-or-update" -o "$CMD" == "update-source-and-build" -o "$CMD" == "build-install"  ]; then
    install_or_update
    exit 0
fi


#uninstall libraries
if [ "$CMD" == "uninstall-libraries" ]; then
    cd "$working_trees/kicad-lib.bzr/build"
    cmake_uninstall "$working_trees/kicad-lib.bzr/build"
    exit 0
fi


#uninstall all
if [ "$CMD" == "uninstall-kicad" ]; then
    cd "$working_trees/kicad.bzr/build"
    cmake_uninstall "$working_trees/kicad.bzr/build" 

    cd "$working_trees/kicad-lib.bzr/build"
    cmake_uninstall "$working_trees/kicad-lib.bzr/build"

    # this may fail since "uninstall" support is a recent feature of this repo:
    if [ -d "$working_trees/kicad-doc.bzr/build" ]; then # check for installed doc's first
	cd "$working_trees/kicad-doc.bzr/build"
	cmake_uninstall "$working_trees/kicad-doc.bzr/build"
    fi
    exit 0
fi

if [ $CMD == "clean" ]; then
    install_or_update
    exit 0
fi 

if [ $CMD == "install" ]; then
    install_or_update
    exit 0
fi 

# remove build directory
if [ $CMD == "delete-build-dir" ]; then
    rm_build_dir "$working_trees/kicad.bzr/build"
    exit 0
fi 



#command not mount so just output ussage
usage
