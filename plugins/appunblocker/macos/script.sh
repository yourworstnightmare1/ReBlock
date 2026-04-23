#!/usr/bin/env bash
# appUnblocker macOS flow: wrap bundle in a new {name}.app folder, then open the inner bundle.
# GitHub: https://github.com/yourworstnightmare1/appunblocker

set -euo pipefail

# --- equivalent to $ErrorActionPreference = 'Stop' (strict mode above) ---

# Terminal window title (ANSI OSC 0) when stdout is a TTY
if [[ -t 1 ]]; then
  printf '\033]0;%s\007' 'script.sh - appUnblocker for macOS by yourworstnightmare1'
fi

# --- banner / icon (same art as script.ps1) ---
print_banner() {
  cat <<'EOF'
          ==============================
       ====================================
      ======================================
     ========================================
    ===================-::-===================
    ================:....... :================
    =============:...:======:...:=============
    ===========.  .============.  .-==========
    =========- .-================-. :=========
    =========- .-================-. :=========
    ==========-.. :============:...-==========
    ============-.  .:======-.. .-============
    +=========-.. :-: ........-: ..-=========+
    +++++++++: .-+++++=:..:-+++++-. -+++++++++
    +++++++++: .-=++++++++++++++=-. -+++++++++
    ++++++++++=...:=++++++++++=.. .=++++++++++
    ++++++++++++=:. .-=++++=:...:=++++++++++++
    +++++++++++++++=: ...... :=+++++++++++++++
    ++++++++++++++++++=-::-=++++++++++++++++++
     ++++++++++++++++++++++++++++++++++++++++
      ++++++++++++++++++++++++++++++++++++++
       ++++++++++++++++++++++++++++++++++++
          ++++++++++++++++++++++++++++++
EOF
}

print_icon_error() {
  cat <<'EOF'
    ####*                        *####
  +#######-                    =#######+
 ###########.                .###########.
  ############              ############
    ############          ############
     .############      ############
       =###########*  *###########-
         ########################
           ####################
             ################
              -############:
             ################
           ####################
         =######################=
       .############  ############.
      ############      ############
    ############          ############
  ############.            .############
 ###########=                =###########.
  ########+                    *########
    #####                        #####
EOF
}

RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
NC=$'\033[0m'

show_critical_error() {
  local detail="$1"
  clear
  printf '%s' "${RED}"
  print_icon_error
  printf '%s\n' "${NC}"
  printf '%s\n' "${RED}A critical error has occurred.${NC}"
  printf '%s\n' "${RED}______________________________${NC}"
  printf '%s\n' "${YELLOW}${detail}${NC}"
  printf '%s\n' "${YELLOW}Consider reinstalling your application.${NC}"
  printf '%s\n' "${YELLOW}Press Enter to exit appUnblocker.${NC}"
  read -r
  exit 1
}

clear
printf '%s' "${RED}"
print_banner
printf '%s\n' "${NC}"
printf '%s\n' "${RED}______________________________________________${NC}"
printf '%s\n' "${RED}Before we begin, we need to know some things in order to continue.${NC}"
printf '%s\n' ""
printf '%s\n' "${RED}Please type the path to your application (.app), or drag the file into this window.${NC}"
printf '%s\n' "${RED}If the path has spaces, wrap it in quotes (example: \"/Applications/MyApp.app\").${NC}"
printf '%s\n' ""

# --- remainder: prompt + open (macOS; no Windows __COMPAT_LAYER) ---
application=""
read -r -p "Application path: " application || true
# trim surrounding whitespace and quotes (rough equivalent to PowerShell Trim)
application="${application#"${application%%[![:space:]]*}"}"
application="${application%"${application##*[![:space:]]}"}"
application="${application#\"}"
application="${application%\"}"
application="${application#\'}"
application="${application%\'}"

if [[ -z "${application}" ]]; then
  show_critical_error "No path was entered."
fi

if [[ ! -e "${application}" ]]; then
  show_critical_error "Path not found: ${application}"
fi

# Resolve to absolute path (parent directory must be real for mktemp + mv)
parent_dir="$(cd "$(dirname "${application}")" && pwd)" || show_critical_error "Could not resolve parent directory for: ${application}"
src_abs="${parent_dir}/$(basename "${application}")"

if [[ ! -e "${src_abs}" ]]; then
  show_critical_error "Path not found after resolve: ${src_abs}"
fi

base="$(basename "${src_abs}")"
base="${base%/}"

# Folder name = filename without trailing ".app", then add ".app" (e.g. MyGame -> MyGame.app)
if [[ "${base}" == *.app ]]; then
  stem="${base%.app}"
else
  stem="${base}"
fi

if [[ -z "${stem}" ]]; then
  show_critical_error "Could not derive a name from: ${base}"
fi

target_root="${parent_dir}/${stem}.app"

# Allow in-place re-wrap when the user selected the bundle that will become the inner path
if [[ -e "${target_root}" && "${src_abs}" != "${target_root}" ]]; then
  show_critical_error "Target folder already exists: ${target_root}"
fi

stamp="$(date '+%H:%M:%S')"
printf '%s\n' "${YELLOW}[${stamp} | INFO] Creating wrapper folder and moving app...${NC}"

tmp="$(mktemp -d "${parent_dir}/.appunblocker.XXXXXX")" || show_critical_error "Could not create temporary folder in: ${parent_dir}"

if ! mv "${src_abs}" "${tmp}/"; then
  rmdir "${tmp}" 2>/dev/null || true
  show_critical_error "Failed to move application into temporary folder."
fi

if ! mv "${tmp}" "${target_root}"; then
  show_critical_error "Failed to rename wrapper folder to: ${target_root} (your app may still be inside: ${tmp})"
fi

inner_path="${target_root}/${base}"
if [[ ! -e "${inner_path}" ]]; then
  show_critical_error "Unexpected layout after move (missing inner path): ${inner_path}"
fi

stamp="$(date '+%H:%M:%S')"
printf '%s\n' "${YELLOW}[${stamp} | INFO] Launching app from: ${inner_path}${NC}"

if ! open "${inner_path}"; then
  show_critical_error "Failed to open application with path: ${inner_path}"
fi

stamp="$(date '+%H:%M:%S')"
printf '%s\n' "${GREEN}[${stamp} | SUCCESS] Wrapped app at ${target_root} and launched successfully!${NC}"
