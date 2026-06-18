#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'
# To apply colors use echo -e
# Make sure to remove colors with ${NC}

version=1.0
build=1

mainIcon='                                    
                                 ::                         
                          ---::::::::::  ---                
                     ::::::---::::::::::------              
                :::::::::::----:::::::----------:           
          :::::::::::::::::-----::::--------------:::       
     -----:::::::::::::::::------------------------:::::    
     =-----:::::::::::::::--=========---------------::::::: 
      =----::::::::::------=============------------::::::--
       =---::::------------==========----==---------::::--- 
        ===----------------=====----==========------:::-=   
     -----===-----------------===================---:---    
  -----------==------------=======================++=-      
+======--------===---------===================++++=====     
 +======----------==-------===============+++===========    
   ++====-----------==-----==========++==================   
     +====-------------+---=====++========================  
       +===--------------==++============================== 
         #*==-----------+**+==============================  
         ###*==-----+**#*****=====================+**=      
         #**##*++*####********+==============++*#####       
         #***#######***********+=========++**####****       
         #*****###*************#*+===++*#####********       
         ##*********************#***#####************       
           ##*********************###****************       
              #***********************************#         
                #****************************##             
                  ##*********************#                  
                    #*****************#                     
                      ##**********                          
                        #*****                              
'
clear
# Main menu
echo -e "${RED}$mainIcon${NC}"
echo -e "${RED}Welcome to packageExpander!${NC}"
echo -e "${YELLOW}v$version | Build $build${NC}"
echo -e "Created by yourworstnightmare1"
read -rp "Press any key to continue..."

clear
echo -e "To start, we need some info."
echo -e "\n${BOLD}Supported file types: pkg${NC}"
read -rp "Enter the directory of your package file: " pkgdir
read -rp "Enter the extraction location: " extractdir

echo -e "\nChoose the method you want to use:\n\n"
echo -e "${BOLD}[1] Payload Extraction (Recommended) (Default)${NC}"
echo -e "packageExpander will extract the package and then extract the payload file containing the main content of the installer. This is the default method for 95% of macOS applications and you will rarely need to use something different."
echo -e "${BOLD}[2] Package Extraction${NC}"
echo -e "packageExpander will only extract the package and then extract any .app files inside, as this type of installer doesn't use a payload. This is very rarely used."

read -rp "Choice: " method
case "${method:-1}" in
    1)
        # Method 1: Payload Extraction
        method=1
        ;;
    2)
        # Method 2: Package Extraction
        method=2
        ;;
    *)
        echo "Invalid choice"
        ;;
esac

echo -e "This is the info provided:"
echo -e "Package directory: $pkgdir"
echo -e "Extraction directory: $extractdir"
echo -e "Method: $method"
read -rp "Press any key to confirm and proceed..." -n1 -s

# packageExpander

clear
echo -e "${BOLD}Starting...${NC}"
echo -e "///////////////////////////////////"
echo -e "//////  packageExpander 1.0  //////"
echo -e "//////      Developed by     //////"
echo -e "//////  yourworstnightmare1  //////"
echo -e "///////////////////////////////////"

if [ -d "$pkgdir" ] && { [ -f "$pkgdir/Payload" ] || [ -f "$pkgdir/PackageInfo" ]; }; then
    tmpdir="$pkgdir"
    echo -e "${GREEN}Package is already expanded; using it directly.${NC}"
else
    tmpdir="$(dirname "$pkgdir")/$(basename "$pkgdir" .pkg)"
    echo -e "Extracting package..."
    pkgutil --expand "$pkgdir" "$tmpdir" || { echo -e "${RED}Failed to expand package. Try running with sudo.${NC}"; exit 1; }
    echo -e "${GREEN}Package extracted to temporary folder.${NC}"
fi

if [ "$method" -eq 1 ]; then
    echo -e "Extracting payload to $extractdir..."
    find "$tmpdir" -name "Payload" -exec sh -c 'tar -xf "$1" -C "$2"' _ {} "$extractdir" \;
    echo -e "${GREEN}Payload extracted.${NC}"
elif [ "$method" -eq 2 ]; then
    echo -e "Extracting .app files..."
    find "$tmpdir" -name "*.app" -exec cp -R "{}" "$extractdir" \;
    echo -e "${GREEN}.app files extracted.${NC}"
fi

echo -e "${GREEN}Done!${NC}"
if [ "$tmpdir" != "$pkgdir" ]; then
    echo -e "Cleaning up temporary files..."
    rm -rf "$tmpdir"
    echo -e "${GREEN}Temporary files removed.${NC}"
fi
echo -e "Successfully extracted to $extractdir. You should see a folder or app in the folder at that path."
read -rp "Press any key to exit..." -n1 -s