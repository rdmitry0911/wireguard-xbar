# wireguard-xbar
A bash script for xbar that manages your WireGuard tunnels. This script has been tested only on macOS 12 with wirguard-tools installed with homebrew. It is a replacement for official wireguard client for macOS which doesn't support activation of several tunnels at once.
## Explanation of the Script
### Shebang and PATH Configuration:
- The script starts with a shebang pointing to the new version of Bash installed via Homebrew. Ensure you replace /usr/local/bin/bash with /opt/homebrew/bin/bash if you're using an Apple Silicon Mac.
- The PATH environment variable is updated to prioritize directories where the new Bash and WireGuard utilities are located.
### Configuration Section:
- WG_CONF_DIR: Directory where your WireGuard .conf files are stored. Update this path if your configurations are in a different location.
- WG_CMD and WG_QUICK_CMD: Paths to the wg and wg-quick utilities.
- LOG_FILE: Path to the log file where the script will record its operations.
- SCRIPT_PATH: Dynamically determines the full path to the current script, ensuring that menu items can call the script without hardcoding its location.
- ICON_MAIN_BASE64, ICON_UP_BASE64, ICON_DOWN_BASE64: Base64 encoded icons for the xbar menu. Replace these with your own icons if desired.
### Debugging Configuration:
- DEBUG: A variable to control logging verbosity. Set to 'YES' to enable detailed logging for debugging purposes. By default, it's set to 'NO', meaning only errors will be logged.
### Helper Functions:
- log_error: Logs error messages to the log file. This is always active, regardless of the DEBUG setting.
- log_debug: Logs detailed debug messages to the log file only if DEBUG is set to 'YES'.
- get_public_key_from_private: Derives the public key from a given private key using wg pubkey.
- print_wg_show_interface_stats: Retrieves and displays statistics for a given WireGuard interface as a submenu in xbar.
### Argument Parsing (up/down):
- The script checks if it's invoked with at least two arguments: an action (up or down) and a configuration file name.
- Depending on the action, it executes wg-quick up <conf_file> or wg-quick down <conf_file>, logging the operations accordingly.
- After performing the action, the script exits to prevent executing the main menu rendering logic.
### Main Script Logic:
- Logs the start of a new run.
- Executes wg show to retrieve active WireGuard interfaces and their public keys.
- Parses the output of wg show to map interfaces to their public keys.
- Iterates through each WireGuard configuration file in WG_CONF_DIR, extracts the private key, derives the public key, and maps it to any active interfaces.
- Logs the final mapping of configuration files to interfaces.
### Drawing the xbar Menu:
- Displays a main WireGuard icon in the menu bar.
- Iterates through each configuration file and displays its status:
  - UP: Shows the configuration as active with a green color and provides a Down option to deactivate it.
  - DOWN: Shows the configuration as inactive with a red color and provides an Up option to activate it.
- Each action (Up or Down) calls the script itself (SCRIPT_PATH) with appropriate arguments (up/down and the configuration file name).
- Provides links to the log file and a manual refresh option.
## How to Use
### Save the Script:
- Save the above script as wg-quick.1m.sh in your xbar plugins directory, typically located at ~/Library/Application Support/xbar/plugins/.
### Make the Script Executable:
```
chmod +x "$HOME/Library/Application Support/xbar/plugins/wg-quick.1m.sh"
```
### Configure WireGuard Directory:
- Ensure that WG_CONF_DIR points to the directory where your WireGuard .conf files are located. Update the path in the script if necessary.
### Set Permissions:
- Ensure that your user has the necessary permissions to execute wg and wg-quick without being prompted for a password. You can configure this in your sudoers file using visudo: `sudo visudo`
- Add the following line (replace your_username with your actual username):
```
your_username ALL=(ALL) NOPASSWD: /usr/local/bin/wg, /usr/local/bin/wg-quick
```
- Warning: Be cautious when editing the sudoers file to avoid syntax errors that could lock you out of administrative privileges.
### Enable Debug Logging (Optional):
To enable detailed logging for debugging, edit the script and set `DEBUG='YES'`:
```
DEBUG='YES'
```
- Logs will be written to ~/wg-quick-xbar.log.
### Run the Script:
- Launch xbar or refresh the plugins. You should see the WireGuard icon in your menu bar.
- Click on the icon to view the status of your WireGuard tunnels and use the Up and Down options to manage them.
### Check Logs:
- Review the log file at ~/wg-quick-xbar.log to monitor the script's operations and troubleshoot any issues.
## Additional Notes
- Icons: Replace the ICON_MAIN_BASE64, ICON_UP_BASE64, and ICON_DOWN_BASE64 variables with your own Base64 encoded images to customize the appearance of the menu items.
- Script Path: The SCRIPT_PATH variable dynamically determines the script's location, ensuring that the Up and Down actions correctly reference the script regardless of where it's moved.
- Permissions: Ensure that your WireGuard configuration files have appropriate permissions to prevent unauthorized access:
```
chmod 600 /usr/local/etc/wireguard/*.conf
sudo chown your_username:staff /usr/local/etc/wireguard/*.conf
```
- Auto-Refresh: The refresh=true parameter in the menu items ensures that the xbar menu refreshes automatically after executing an action, reflecting the updated status of your tunnels.


  
