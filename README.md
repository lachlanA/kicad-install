# kicad-install
  ***kicad-install.sh bash script script***  

    Version 2 kicad-install.sh script for linux
    
    Note: parameters in <> Are required, while parameters in [] are optional, | = OR, IE one in list  
     IE: Build Python add on, needs -p MIN  for minimum version of python.  
     Note: This script can self update, using SHA512SUM verification, To over ride Version Check use -V  
     and -S to disable SHA512SUM check. Also a backup copy of the current script will be made in both.  
     the script working directory and target working directory format will be script name + date  
     This script must be mark as exectuable by: chmode a+rx kicad-install.sh  
     If target SOURCE'S director is not set, default will be be = ~/buildkicad  
     If Install DIRECTOR is not set, default will be = /usr/local  
    
    ./kicad-install.sh <cmd> [Options...]  
    where <cmd> can be one of..  
  
        --setup-update-build-install    ( Full/New install which also updates current install KiCad )  
        --setup-update-build-tools      ( Install/Update build tools only)  
        --update-build-install          ( Update source then build and install KiCad )  
        --build-install                 ( Build source and install KiCad.)  
        --install                       ( Install KiCad )  
        --remove-sources                ( Removes source trees for another attempt )  
        --uninstall-libraries           ( Removes KiCad supplied libraries )  
        --uninstall-kicad               ( Uninstalls all of KiCad but leaves source trees. )  
        --script-server-version-check   ( Check version of script ./kicad-install.sh on server )  
        --script-server-install         ( Update version of kicad-install.sh script from server,  
                                          only update's if newer Note: Use -V to force update )  
        --diff-server-local-script      ( Show the difference between current and server scripts  
                                          kicad-install.sh, using diff, Note: With NO! SHA512SUM verification )  
        --make-script-sha512            ( Makes 2 files, one with a SHA512SUM in ~/buildkicad/kicad-install.sh.sha512 other  
                                          With SCRIP_VERSION in file ~/buildkicad/kicad-install.sh.version )  
        --clean                         ( Clean build files IE: Frees disk space )  
        --delete-build-dir              ( Delete the SOURCE'S/build directory, you may need to do this if  
                                          build is not working as exepcted )  
        --version                       ( Prints script version )  
        --help                          ( This help Docs )  
      
      Where Options can be any number of--  
      Options Are  
          [-t SOURCEDIR]         ( Set Target directory for source's/build )  
          [-n INSTALLBINDIR]     ( Set Install directory for bin NOTE: if you change the install director )  
          [-d ]                  ( Build GDB debug version )  
          [-D ]                  ( Disable Documents Build )  
          [-r ]                  ( Build version, Set this to STABLE or TESTING or other known revision number 5054 etc )  
          [-S ]                  ( Disable SHA512SUM verification )  
          [-V ]                  ( Disable version check )  
          [-p MIN | MED | MAX ]  ( Build python MIN=For footprint wizards, MED=creates a python module, )  
                                    MAX=Pcbnew can edit the current loaded board)  
          [-x ProcessCount ]     ( Set's the number of Build process's for Make -j ProcessCount )  
      
     Example: ./kicad-install.sh --setup-update-build-install -t /home/fred/src/kicad -n /usr/ -d -D -x 8  
      
     Will Install source's at: /home/fred/src/kicad, and Binaries install tree at: /usr   
     and build with Debug Enabled, Documents Disabled, make j8 (8 build process's)   
  


