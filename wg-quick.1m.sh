#!/usr/local/bin/bash  # Replace with /opt/homebrew/bin/bash for Apple Silicon Macs
export PATH="/usr/local/bin:$PATH"  # Replace with /opt/homebrew/bin for Apple Silicon Macs

################################################################################
# CONFIGURATION
################################################################################

# Directory containing WireGuard configuration files (*.conf)
WG_CONF_DIR="/usr/local/etc/wireguard"   # Update this path if your configs are elsewhere

# Paths to WireGuard utilities
WG_CMD="$(which wg)"
WG_QUICK_CMD="$(which wg-quick)"

# Log file path
LOG_FILE="$HOME/wg-quick-xbar.log"       # Logs are stored here

# Define the full path to the current script dynamically
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# Base64 encoded icons for the xbar menu (replace with your own icons if desired)
ICON_MAIN_BASE64="iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFC..."
ICON_UP_BASE64="iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFC..."   
ICON_DOWN_BASE64="iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFC..."

################################################################################
# DEBUGGING CONFIGURATION
################################################################################

DEBUG='NO'  # Set to 'YES' to enable detailed logging for debugging

################################################################################
# HELPER FUNCTIONS
################################################################################

# Function to log error messages (always active)
log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

# Function to log debug messages (active only when DEBUG='YES')
log_debug() {
  if [ "$DEBUG" = "YES" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $1" >> "$LOG_FILE"
  fi
}

# Function to derive the public key from a private key
get_public_key_from_private() {
  local priv="$1"
  # Use wg pubkey to generate the public key from the private key
  echo "$priv" | $WG_CMD pubkey 2>/dev/null
}

# Function to display WireGuard interface statistics as a submenu
print_wg_show_interface_stats() {
  local iface="$1"
  local show_output
  # Retrieve interface details using wg show
  show_output="$(sudo $WG_CMD show "$iface" 2>/dev/null)"
  [ -z "$show_output" ] && return

  echo "--$iface info:"
  # Iterate through each line of the wg show output and display it
  while IFS= read -r line; do
    echo "---$line"
  done < <(echo "$show_output")
}

################################################################################
# PARSE ARGUMENTS (up/down)
################################################################################

# Log the Bash version and the arguments with which the script was invoked
log_debug "Using Bash version: $BASH_VERSION"
log_debug "Script invoked with args: $@"

# Check if at least two arguments are passed (action and config file)
if [ $# -ge 2 ]; then
  action="$1"       # 'up' or 'down'
  conf_file="$2"    # Configuration file name (e.g., 'wg0.conf')

  case "$action" in
    up)
      log_debug "ACTION: UP $conf_file"
      log_debug "Executing: sudo $WG_QUICK_CMD up $WG_CONF_DIR/$conf_file"
      # Execute 'wg-quick up' and log the output
      sudo "$WG_QUICK_CMD" up "$WG_CONF_DIR/$conf_file" 2>&1 | while IFS= read -r l; do log_debug "[UP:$conf_file] $l"; done
      log_debug "Finished ACTION: UP $conf_file"
      exit 0
      ;;
    down)
      log_debug "ACTION: DOWN $conf_file"
      log_debug "Executing: sudo $WG_QUICK_CMD down $WG_CONF_DIR/$conf_file"
      # Execute 'wg-quick down' and log the output
      sudo "$WG_QUICK_CMD" down "$WG_CONF_DIR/$conf_file" 2>&1 | while IFS= read -r l; do log_debug "[DOWN:$conf_file] $l"; done
      log_debug "Finished ACTION: DOWN $conf_file"
      exit 0
      ;;
    *)
      log_error "Unknown action: $action"
      ;;
  esac
fi

################################################################################
# MAIN SCRIPT
################################################################################

log_debug "---- Starting xbar script run ----"

# Attempt to retrieve the list of WireGuard interfaces using 'wg show'
WG_SHOW_OUTPUT="$(sudo $WG_CMD show 2>&1)"
WG_SHOW_EXIT_CODE=$?

if [ $WG_SHOW_EXIT_CODE -ne 0 ]; then
  log_error "sudo wg show failed with exit code $WG_SHOW_EXIT_CODE: $WG_SHOW_OUTPUT"
else
  log_debug "wg show succeeded."
fi

log_debug "wg show exit code: $WG_SHOW_EXIT_CODE"
log_debug "wg show output:"
log_debug "$WG_SHOW_OUTPUT"

# Parse the output of 'wg show' to map interfaces to their public keys
declare -A IFACE_TO_PUBKEY
current_iface=""
while IFS= read -r line; do
  log_debug "Parsing line: '$line'"
  if [[ "$line" =~ ^interface:\ (.+)$ ]]; then
    current_iface="${BASH_REMATCH[1]}"
    log_debug "Found interface: $current_iface"
    continue
  fi
  # Match lines that contain the public key
  if [[ "$line" =~ ^[[:space:]]+public\ key:\ (.+)$ ]]; then
    IFACE_TO_PUBKEY["$current_iface"]="${BASH_REMATCH[1]}"
    log_debug "  -> public key: ${BASH_REMATCH[1]}"
  else
    log_debug "  -> No match for public key in line: '$line'"
  fi
done < <(echo "$WG_SHOW_OUTPUT")

log_debug "Parsed IFACE_TO_PUBKEY: ${!IFACE_TO_PUBKEY[@]}"

# Check if there are no active interfaces with public keys
if [ ${#IFACE_TO_PUBKEY[@]} -eq 0 ]; then
  log_error "No active interfaces with public keys found in wg show"
fi

# Map configuration files to their private and public keys and associated interfaces
declare -A CONF_TO_PRIVKEY
declare -A CONF_TO_PUBKEY
declare -A CONF_TO_INTERFACE  # Maps config files to their corresponding interfaces (e.g., utun3)

# Iterate through each WireGuard configuration file
for file in "$WG_CONF_DIR"/*.conf; do
  [ -f "$file" ] || continue  # Skip if not a regular file
  base="$(basename "$file")"
  log_debug "Processing config file: $base"

  # Extract the PrivateKey from the configuration file using awk
  priv_key="$(awk '
    BEGIN { flag=0 }
    /^\[Interface\]/ { flag=1; next }
    /^\[/ { flag=0 }
    flag && /^[[:space:]]*PrivateKey[[:space:]]*=/ {
      sub(/^[[:space:]]*PrivateKey[[:space:]]*=[[:space:]]*/, "")
      print
    }
  ' "$file" | tr -d '[:space:]')"

  # Log the extracted PrivateKey (first 10 characters for security)
  if [[ -n "$priv_key" ]]; then
    if [[ "$priv_key" =~ ^[A-Za-z0-9+/=]+$ ]]; then
      log_debug "Extracted PrivateKey for $base: '${priv_key:0:10}...'"
    else
      log_error "Failed to extract valid PrivateKey for $base. Extracted: '$priv_key'"
      priv_key=""
    fi
  else
    log_error "Failed to extract valid PrivateKey for $base. Extracted: '$priv_key'"
  fi

  # If a valid PrivateKey was extracted, derive the PublicKey
  if [ -n "$priv_key" ]; then
    pub_key="$(get_public_key_from_private "$priv_key")"
    if [ -n "$pub_key" ]; then
      log_debug "Derived PublicKey for $base: '$pub_key'"
      CONF_TO_PRIVKEY["$base"]="$priv_key"
      CONF_TO_PUBKEY["$base"]="$pub_key"

      # Check if the derived PublicKey matches any active interface
      matched_iface=""
      for iface in "${!IFACE_TO_PUBKEY[@]}"; do
        log_debug "Comparing PublicKey from config '$base' with interface '$iface': '$pub_key' == '${IFACE_TO_PUBKEY[$iface]}'"
        if [[ "${IFACE_TO_PUBKEY[$iface]}" == "$pub_key" ]]; then
          matched_iface="$iface"
          log_debug "  => Matched iface '$iface' with config '$base'"
          break
        fi
      done

      # If a matching interface is found, map it to the configuration file
      if [ -n "$matched_iface" ]; then
        CONF_TO_INTERFACE["$base"]="$matched_iface"
        log_debug "  => $base is up with interface $matched_iface"
      else
        log_debug "  => $base is not currently up"
      fi
    else
      log_error "Failed to derive PublicKey for $base from PrivateKey."
    fi
  else
    log_error "Config $base has no PrivateKey found."
  fi
done

log_debug "Final CONF_TO_INTERFACE mapping:"
for key in "${!CONF_TO_INTERFACE[@]}"; do
  log_debug "  $key => ${CONF_TO_INTERFACE[$key]}"
done

################################################################################
# 4) DRAW xbar MENU
################################################################################

# Display the main WireGuard icon in the menu bar
echo "WireGuard | templateImage=$ICON_MAIN_BASE64"
echo "---"  # Separator

# Initialize a flag to check if any configuration files are found
found_any_conf=false

# Iterate through each configuration file and display its status
for conf_file in "${!CONF_TO_PUBKEY[@]}"; do
  found_any_conf=true
  conf_name="${conf_file%.conf}"  # Remove the .conf extension for display
  pub_key="${CONF_TO_PUBKEY[$conf_file]}"
  iface="${CONF_TO_INTERFACE[$conf_file]}"

  if [ -n "$iface" ]; then
    # If the interface is up, display it with a green color and provide a 'Down' option
    echo "$conf_name (→ $iface) : UP | color=green image=$ICON_UP_BASE64"
    # The 'Down' option passes 'down' and the config file as arguments
    echo "--Down $conf_name | bash='$SCRIPT_PATH' param1=down param2='$conf_file' refresh=true terminal=false"
    # Optionally, display interface statistics as a submenu
    print_wg_show_interface_stats "$iface"
  else
    # If the interface is down, display it with a red color and provide an 'Up' option
    echo "$conf_name : DOWN | color=red image=$ICON_DOWN_BASE64"
    # The 'Up' option passes 'up' and the config file as arguments
    echo "--Up $conf_name | bash='$SCRIPT_PATH' param1=up param2='$conf_file' refresh=true terminal=false"
  fi
  echo "---"  # Separator between items
done

# If no configuration files are found, display a message
if [ "$found_any_conf" = false ]; then
  echo "No .conf files found in $WG_CONF_DIR"
  echo "---"
fi

# Display the log file path and a refresh option
echo "Log file: $LOG_FILE | color=gray"
echo "Refresh... | refresh=true"


