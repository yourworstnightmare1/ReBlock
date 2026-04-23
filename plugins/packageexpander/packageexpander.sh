#!/bin/bash

# packageExpander — automates the manual pkg expand + Payload extract flow (macOS).

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ICON_REBLOCK_STYLE='
                                                                     
                                                                     
                                                                     
                =====================================                
            =============================================            
         ===================================================         
        =====================================================        
       =======================================================       
      ===========================-::===========================      
      =======================-.       .:=======================      
      ====================..             ..====================      
      ================-.                     .-================      
      =============:.                           .:=============      
      ==============:.                         ..==============      
      ===========.-====-.                   .-=====.===========      
      ===========.  .-===+=..           ..=+===-.   ===========      
      ===========.     .:===+=:.     .:=+===:.      ===========      
      ===========.         .====+-.-+====.          ===========      
      ===========.            .-=====-.             ===========      
      ===========.               ===                ==========+      
      ===========.               ===                ==========+      
      ++++++++++=.               =+=                =++++++++++      
      ++++++++++=.               =+=                =++++++++++      
      +++++++++++:               =+=               :+++++++++++      
      +++++++++++++:.            =+=            .:+++++++++++++      
      ++++++++++++++++=.         =+=         .-++++++++++++++++      
      ++++++++++++++++++++..     =+=     ..=+++++++++++++++++++      
      +++++++++++++++++++++++-.  =+=  .-+++++++++++++++++++++++      
      ++++++++++++++++++++++++++==+==++++++++++++++++++++++++++      
       +++++++++++++++++++++++++++++++++++++++++++++++++++++++       
        +++++++++++++++++++++++++++++++++++++++++++++++++++++        
         +++++++++++++++++++++++++++++++++++++++++++++++++++         
           +++++++++++++++++++++++++++++++++++++++++++++++           
                ++++++++++++++++++++++++++++++++++++++               
                                                                     
                                                                     
'

APP_VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

strip_wrapping_quotes() {
    local s="$1"
    s="${s%\"}"
    s="${s#\"}"
    s="${s%\'}"
    s="${s#\'}"
    echo "$s"
}

# read -r keeps backslashes; users often paste terminal-style "Install\ FL\ Studio.pkg".
normalize_path_input() {
    local s
    s="$(strip_wrapping_quotes "$1")"
    s="${s//\\ / }"
    echo "$s"
}

expand_pkg_flow() {
    echo ""
    echo -e "${BOLD}Expand a .pkg installer${NC}"
    echo -e "${CYAN}Step 1 of 4:${NC} Path to your .pkg (e.g. ${YELLOW}~/Desktop/My App.pkg${NC}). Finder paths and terminal-style backslashes before spaces both work."
    read -r -p "Package path: " pkg_raw
    local pkg
    pkg="$(normalize_path_input "$pkg_raw")"
    pkg="${pkg/#\~/$HOME}"
    pkg="${pkg%/}"

    if [[ -z "$pkg" ]]; then
        echo -e "${RED}Error: Package path is required.${NC}"
        read -r -p "Press Enter to return to the menu..."
        return
    fi
    if [[ ! -f "$pkg" ]] && [[ ! -d "$pkg" ]]; then
        echo -e "${RED}Error: Not found: $pkg${NC}"
        read -r -p "Press Enter to return to the menu..."
        return
    fi

    echo ""
    echo -e "${CYAN}Step 2 of 4:${NC} Folder where the extracted payload should go (must be empty or new)."
    read -r -p "Output folder: " out_raw
    local outdir
    outdir="$(normalize_path_input "$out_raw")"
    outdir="${outdir/#\~/$HOME}"
    outdir="${outdir%/}"

    if [[ -z "$outdir" ]]; then
        echo -e "${RED}Error: Output folder is required.${NC}"
        read -r -p "Press Enter to return to the menu..."
        return
    fi
    if [[ -e "$outdir" ]] && [[ -n "$(ls -A "$outdir" 2>/dev/null)" ]]; then
        echo -e "${RED}Error: Output folder exists and is not empty. Choose an empty or new folder.${NC}"
        read -r -p "Press Enter to return to the menu..."
        return
    fi
    mkdir -p "$outdir" || {
        echo -e "${RED}Error: Could not create output folder.${NC}"
        read -r -p "Press Enter to return to the menu..."
        return
    }

    # pkgutil --expand requires DIR to not exist yet (it creates DIR).
    local expand_root="/tmp/packageexpander.${PPID}.${RANDOM}.${RANDOM}"
    while [[ -e "$expand_root" ]]; do
        expand_root="/tmp/packageexpander.${PPID}.${RANDOM}.${RANDOM}"
    done

    echo ""
    echo -e "${CYAN}Step 3 of 4:${NC} Running ${BOLD}pkgutil --expand${NC} (same as the manual guide)..."
    echo -e "${YELLOW}pkgutil --expand \"$pkg\" \"$expand_root\"${NC}"
    if ! pkgutil --expand "$pkg" "$expand_root"; then
        echo -e "${RED}Error: pkgutil --expand failed.${NC}"
        rm -rf "$expand_root"
        read -r -p "Press Enter to return to the menu..."
        return
    fi

    echo ""
    echo -e "${CYAN}Step 4 of 4:${NC} Locating ${BOLD}Payload${NC} inside the expanded package..."
    local payloads=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && payloads+=("$line")
    done < <(find "$expand_root" \( -name Payload -o -name payload \) -type f 2>/dev/null)

    if [[ ${#payloads[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No Payload file found after expand. This .pkg layout may need manual steps (option 2).${NC}"
        rm -rf "$expand_root"
        read -r -p "Press Enter to return to the menu..."
        return
    fi

    local chosen="${payloads[0]}"
    if [[ ${#payloads[@]} -gt 1 ]]; then
        echo -e "${YELLOW}Multiple Payload files found. Pick one:${NC}"
        local i
        for i in "${!payloads[@]}"; do
            echo "[$((i + 1))] ${payloads[$i]}"
        done
        echo "[X] Cancel"
        echo ""
        while true; do
            read -r -p "Choose Payload number: " pick
            if [[ "$pick" == [Xx] ]]; then
                rm -rf "$expand_root"
                echo "Cancelled."
                read -r -p "Press Enter to return to the menu..."
                return
            fi
            if [[ "$pick" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick <= ${#payloads[@]} )); then
                chosen="${payloads[$((pick - 1))]}"
                break
            fi
            echo -e "${RED}Invalid choice. Enter a valid number or X.${NC}"
        done
    fi

    echo -e "${YELLOW}tar -xvf \"$chosen\" -C \"$outdir\"${NC}"
    if tar -xvf "$chosen" -C "$outdir"; then
        echo ""
        echo -e "${GREEN}Done. Payload extracted to:${NC}"
        echo "  $outdir"
        echo -e "${GREEN}You can open the folder in Finder from the menu, or open your app from there.${NC}"
    else
        echo ""
        echo -e "${YELLOW}tar failed (some Apple payloads are gzip+cpio, not plain tar). Trying gzip | cpio...${NC}"
        if gzip -dc "$chosen" 2>/dev/null | (cd "$outdir" && cpio -idm 2>/dev/null); then
            echo -e "${GREEN}Extracted with gzip | cpio.${NC}"
            echo "  $outdir"
        else
            echo -e "${RED}Automatic extraction failed. Use option 2 for manual steps, or inspect:${NC}"
            echo "  $expand_root"
            rm -rf "$expand_root"
            read -r -p "Press Enter to return to the menu..."
            return
        fi
    fi

    rm -rf "$expand_root"
    echo ""
    read -r -p "Open output folder in Finder? [y/N]: " openf
    if [[ "$openf" == [yY] ]]; then
        open "$outdir"
    fi
    read -r -p "Press Enter to return to the menu..."
}

manual_instructions() {
    clear
    echo -e "${BOLD}packageExpander: the manual way${NC}"
    echo "This is how to do the same thing without this script."
    echo ""
    echo -e "${CYAN}Step 1:${NC} Get the path to your .pkg (Get Info → Where). Use form ${YELLOW}/path/to/Installer.pkg${NC} or ${YELLOW}~/Desktop/Installer.pkg${NC}."
    echo "Pick a ${BOLD}new empty folder${NC} path for the expand step — ${BOLD}delete the folder if it already exists${NC}, or pkgutil can fail."
    echo ""
    echo -e "${CYAN}Step 2:${NC} In Terminal:"
    echo -e "  ${YELLOW}pkgutil --expand /your/app.pkg /folder/for/expand${NC}"
    echo "The second path must ${BOLD}not${NC} exist yet (or remove it first)."
    echo ""
    echo -e "${CYAN}Step 3:${NC} Open the new folder. If you see another .pkg, use Show Package Contents and locate the file named ${BOLD}Payload${NC}. Note its full path."
    echo ""
    echo -e "${CYAN}Step 4:${NC} Create a folder where you want the app files, then:"
    echo -e "  ${YELLOW}tar -xvf /path/to/Payload -C /path/to/output/folder${NC}"
    echo "(If tar errors, the payload may be gzip+cpio — search for cpio extraction for your macOS version.)"
    echo ""
    echo -e "${CYAN}Step 5:${NC} Open the output folder; your app should be there."
    echo ""
    read -r -p "Press Enter to return to the menu..."
}

main_menu() {
    while true; do
        clear
        echo -e "${RED}${ICON_REBLOCK_STYLE}${NC}"
        echo -e "${RED}Welcome to packageExpander!${NC}"
        echo -e "${YELLOW}Version $APP_VERSION${NC}"
        echo "Created & Programmed by yourworstnightmare1"
        echo "___________________________________________"
        echo ""
        echo -e "${CYAN}Choose an option:${NC}"
        echo "[1] Expand a .pkg installer (automated)"
        echo "[2] View manual instructions"
        echo "[3] Exit"
        echo ""
        read -r -p "Enter 1-3: " choice
        case "$choice" in
            1)
                expand_pkg_flow
                ;;
            2)
                manual_instructions
                ;;
            3)
                echo -e "${YELLOW}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
                sleep 1
                ;;
        esac
    done
}

if ! command -v pkgutil >/dev/null 2>&1; then
    echo -e "${RED}packageExpander requires macOS pkgutil.${NC}"
    exit 1
fi

main_menu
