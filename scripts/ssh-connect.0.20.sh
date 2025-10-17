#!/bin/bash

# ==============================================================================
# Script: ssh-connect.sh
# Description: Facilitates SSH connections using a predefined list of hosts.
# Repository: https://github.com/thatguyinoz/ssh_connect
# Author: peter@hctech.com.au
# License: MIT
# ==============================================================================

# --- Script Metadata and Versioning ---
SCRIPT_NAME=$(basename "$0")
VERSION="0.20"

# --- Changelog ---
# Version 0.20:
#   - Added -v/--version argument to display the script version.
#   - Added GitHub repository link to the script header.
#   - Condensed the detailed changelog for versions 0.01-0.15 into a summary.
#
# Version 0.19:
#   - Refactored the TERMINAL_CMD logic for better cross-terminal compatibility.
#     The execution flag ('--' for gnome-terminal, '-e' for others) is now
#     part of the TERMINAL_CMD variable itself, simplifying the execution command.
#   - Implemented a more robust, user-provided method for EdgeOS key
#     installation.
#   - The script now creates and manipulates a persistent authorized_keys file
#     in /config/auth and uses sudo to copy it into place to keep the file secure,
#     the user can run "configure|loadkey <user> /config/auth/<user>-authorised_keys|exit"
#     to add the keys to the saved config if desired.
#
# Version 0.18:
#   - Implemented a simplified, fully automated key installation for EdgeOS.
#   - The script now attempts to directly run the 'loadkey' command non-interactively,
#     removing the need for a manual, user-guided session. This is a more
#     reliable and efficient method based on new testing.
#
# Version 0.17:
#   - Added intelligent, device-aware SSH key installation.
#   - The script now detects the 'EdgeOS' banner on connection.
#   - If an EdgeOS device is detected, it automatically uses the required
#     specialized installation process (scp + loadkey command).
#   - Standard hosts continue to use the robust 'ssh-copy-id' method.
#
# Version 0.16:
#   - Implemented a two-stage connection fallback for maximum reliability.
#   - The script now retries with password-only authentication if the initial
#     connection attempt fails, successfully handling servers that disconnect
#     after a failed public key authentication.
#
# Versions 0.01 - 0.15:
#   - Initial development of the core features, including the interactive
#     host selection menu, SSH connection multiplexing, direct connection
#     handling, and robust error handling and connection testing.
#   - Numerous bug fixes and reliability improvements.
#
# Version 0.00:
#   - Initial commit with basic TODO list.
# ==============================================================================

# --- Configuration ---
# The HOSTS_FILE variable points to the list of hosts.
# For development, this is a local file. In production, it should be ~/.config/mysshhosts.conf.
#HOSTS_FILE="~/.config/myhosts.conf"
HOSTS_FILE="auth/my_hosts.conf"
# Optional: Define a terminal to open new SSH sessions in.
# If blank or the command is not found, the session will open in the current terminal.
# TERMINAL_CMD="xterm -e"
# TERMINAL_CMD="konsole -e"
TERMINAL_CMD="gnome-terminal --" #<-- change this to your preferred terminal with the argument "-e" or "--" as needed to allow passing of further arguments.

# ==============================================================================
# --- Core Functions ---
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: usage()
# Description: Displays the script's usage instructions.
# ------------------------------------------------------------------------------
usage() {
    cat << EOF
A utility to simplify SSH connections.

USAGE:
    ${SCRIPT_NAME} [options]
    ${SCRIPT_NAME} [user@]hostname [-p port]

DESCRIPTION:
    This script provides an interactive menu to manage and connect to SSH hosts.
    It can also be used as a wrapper for ssh to automatically save new
    connections for future use.
    It uses SSH connection multiplexing to establish a persistent background
    connection, allowing for instant subsequent connections.

    On the first successful connection to a host, it will offer to install a
    public SSH key to enable passwordless login for future sessions. Hosts that
    are already configured with a key are marked with a 🔑 icon.

OPTIONS:
    -h, --help    Show this help message.
    -v, --version Show the script version.

CONFIGURATION:
    Host File:
        The script uses a host configuration file located at:
        ${HOSTS_FILE}

        Each line in this file represents one host and must be in the following
        comma-separated (CSV) format:

        Friendly Name,Username,Hostname,Port,Timestamp,KeyInstalled

        - Friendly Name: The name displayed in the selection menu.
        - Username:        The user to connect as.
        - Hostname:        The hostname or IP address of the server.
        - Port:            The SSH port on the server.
        - Timestamp:       A Unix epoch timestamp of the last connection (0 for new).
        - KeyInstalled:    Set to 1 if an SSH key is installed, otherwise 0.

    Terminal Command:
        The script can open the SSH session in a new terminal window. if no terminal
        is set, then the current erminal is used.
        Current Terminal: ${TERMINAL_CMD:-"Not set (will use current terminal)"}

        This can be changed by editing the TERMINAL_CMD variable in the script.
EOF
}

# ------------------------------------------------------------------------------
# Function: check_config_file()
# Description: Checks if the hosts config file exists and prompts to create it
#              if it is missing.
# Returns:
#   0 if the file exists or was created successfully.
#   1 if the file does not exist and the user chose not to create it.
# ------------------------------------------------------------------------------
check_config_file() {
    if [[ ! -f "${HOSTS_FILE}" ]]; then
        read -p "Host configuration file not found at '${HOSTS_FILE}'. Create a sample file? (y/n): " choice
        case "$choice" in
            y|Y )
                if create_sample_config; then
                    echo "Sample config created at '${HOSTS_FILE}'. Please edit it with your host details."
                    return 0
                else
                    return 1
                fi
                ;;
            * )
                echo "Cannot proceed without a host file."
                return 1
                ;;
        esac
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Function: create_sample_config()
# Description: Creates a sample host configuration file.
# Returns:
#   0 on successful creation.
#   1 on failure.
# ------------------------------------------------------------------------------
create_sample_config() {
    # Ensure the directory exists
    mkdir -p "$(dirname "${HOSTS_FILE}")"
    
    # Create the sample file with instructional content
    if ! tee "${HOSTS_FILE}" > /dev/null << EOF
# ==============================================================================
# Host Configuration File for ssh-connect.sh
# ==============================================================================
#
# Instructions:
# - Each line represents a single host.
# - The format is a comma-separated list:
#   Friendly Name,Username,Hostname or IP,Port,LastConnectedTimestamp,KeyInstalled
#
# - 'KeyInstalled' should be 1 if you have installed an SSH key, otherwise 0.
#   The script will offer to install a key for you if this is 0.
#
# ==============================================================================
#
# --- Example Entry (uncomment and edit to use) ---
# My Web Server,webadmin,192.168.1.100,22,0,0

EOF
    then
        echo "Error: Could not write to '${HOSTS_FILE}'."
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Function: load_hosts()
# Description: Loads hosts from the config file into an array and displays them.
#              The hosts are sorted by the last connected timestamp.
# ------------------------------------------------------------------------------
load_hosts() {
    echo "Available hosts:"
    mapfile -t hosts < <(grep -vE '^\s*#|^\s*$' "${HOSTS_FILE}" | sort -t, -k5 -nr)
    
    for i in "${!hosts[@]}"; do
        IFS=',' read -r friendly_name _ _ _ _ key_installed <<< "${hosts[$i]}"
        
        local display_name="${friendly_name}"
        if [[ "${key_installed}" -eq 1 ]]; then
            display_name="🔑 ${friendly_name}"
        fi
        
        printf "%2d. %s\n" "$((i+1))" "${display_name}"
    done
}

# ------------------------------------------------------------------------------
# Function: select_host()
# Description: Prompts the user to select a host and validates the input.
# ------------------------------------------------------------------------------
select_host() {
    read -p "Enter the number of the host to connect to: " selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || (( selection < 1 || selection > ${#hosts[@]} )); then
        echo "Invalid selection. Please enter a number between 1 and ${#hosts[@]}."
        return 1
    fi
    
    # Adjust for 0-based array index
    connect_to_host "${hosts[$((selection-1))]}"
}

# ------------------------------------------------------------------------------
# Function: connect_to_host()
# Description: Establishes a persistent background SSH connection and opens
#              an interactive session in a new terminal.
# ------------------------------------------------------------------------------
connect_to_host() {
    IFS=',' read -r friendly_name user hostname port timestamp key_installed <<< "$1"
    
    local socket_dir="${HOME}/.ssh/controlmasters"
    local socket_file="${socket_dir}/${user}@${hostname}:${port}"
    local is_edgerouter=false
    
    mkdir -p "${socket_dir}"
    
    if ssh -o ControlPath="${socket_file}" -O check "${user}@${hostname}" -p "${port}" &>/dev/null; then
        echo "Reusing existing connection to ${friendly_name}."
    else
        echo "Establishing connection to ${friendly_name}..."
        
        local banner_file
        banner_file=$(mktemp)
        
        # Attempt 1: Standard interactive connection.
        if ! ssh -M -o ControlPersist=10s -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}" "exit" &> "${banner_file}"; then
            # Attempt 2: Password-only fallback.
            echo "Initial connection failed. Retrying with password-only authentication..."
            if ! ssh -M -o ControlPersist=10s -o ControlPath="${socket_file}" -o PreferredAuthentications=password "${user}@${hostname}" -p "${port}" "exit" &> "${banner_file}"; then
                echo "Connection to ${friendly_name} failed."
                cat "${banner_file}" # Show the user the error
                rm -f "${socket_file}" "${banner_file}"
                return 1
            fi
        fi
        
        # Check for EdgeOS banner
        if grep -q "EdgeOS" "${banner_file}"; then
            is_edgerouter=true
        fi
        rm -f "${banner_file}"
    fi

    # --- Connection Successful ---
    echo "Connection successful. Updating timestamp."
    update_timestamp "$1"

    # If a key is not yet installed, offer to install one.
    if [[ "${key_installed}" -ne 1 ]]; then
        offer_to_install_key "$1" "${is_edgerouter}"
    fi

    # Hand off to the final interactive session
    if [[ -n "${TERMINAL_CMD}" && -x "$(command -v ${TERMINAL_CMD})" ]]; then
        echo "Opening new terminal with '${TERMINAL_CMD}'..."
        ${TERMINAL_CMD} ssh -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}" &
    else
        echo "Spawning session in current terminal..."
        exec ssh -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}"
    fi
}

# ------------------------------------------------------------------------------
# Function: offer_to_install_key()
# Description: Finds public SSH keys and offers to install one on the remote host.
# ------------------------------------------------------------------------------
offer_to_install_key() {
    local host_details="$1"
    local is_edgerouter="$2"
    IFS=',' read -r friendly_name user hostname port _ _ <<< "${host_details}"
    local socket_dir="${HOME}/.ssh/controlmasters"
    local socket_file="${socket_dir}/${user}@${hostname}:${port}"

    mapfile -t public_keys < <(find "${HOME}/.ssh" -type f -name "*.pub")

    if [[ ${#public_keys[@]} -eq 0 ]]; then
        echo "No public SSH keys found in ~/.ssh/. Skipping key installation."
        return
    fi

    read -p "Would you like to install an SSH key for passwordless login? (y/n): " choice
    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        return
    fi

    echo "Available public keys:"
    for i in "${!public_keys[@]}"; do
        printf "%2d. %s\n" "$((i+1))" "$(basename "${public_keys[$i]}")"
    done

    read -p "Enter the number of the key to install (or any other key to cancel): " selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || (( selection < 1 || selection > ${#public_keys[@]} )); then
        echo "Invalid selection. Cancelling key installation."
        return
    fi

    local selected_key="${public_keys[$((selection-1))]}"
    echo "Installing key '${selected_key}'..."

    if [[ "${is_edgerouter}" == "true" ]]; then
        # --- EdgeOS Specific Logic (Simplified & Automated) ---
        echo "EdgeOS device detected. Using simplified installation method."
        local remote_tmp_key="/tmp/ssh_connect_key.pub"

        # Step 1: SCP the key to the device
        echo "Uploading public key..."
        if ! scp -o ControlPath="${socket_file}" "${selected_key}" "${user}@${hostname}:${remote_tmp_key}"; then
            echo "Error: Failed to copy key to the EdgeRouter."
            return 1
        fi

        # Step 2: append the key from /tmp/<keyfile> to /config/auth/<user>_authorized_keys then sudo copy it back.
        echo "Running loadkey command..."
        if ! ssh -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}" "cat /home/$user/.ssh/authorized_keys > /config/auth/$user-authorized_keys;cat ${remote_tmp_key} >>/config/auth/$user-authorized_keys;sudo cp /config/auth/$user-authorized_keys /home/$user/.ssh/authorized_keys"; then
            echo "Error: Failed to run loadkey command on the EdgeRouter."
            # Still try to clean up
            ssh -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}" "rm ${remote_tmp_key}"
            return 1
        fi
        # Step 3: Clean up the temporary key
        echo "Cleaning up..."
        ssh -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}" "rm ${remote_tmp_key}"
        
        echo "Key installed successfully on EdgeOS device."
        update_key_status "${host_details}"

    else
        # --- Standard ssh-copy-id Logic ---
        if ssh-copy-id -i "${selected_key}" -p "${port}" -o "ControlPath=${socket_file}" "${user}@${hostname}"; then
            echo "Key installed successfully."
            update_key_status "${host_details}"
        else
            echo "Failed to install SSH key."
        fi
    fi
}

# ------------------------------------------------------------------------------
# Function: update_key_status()
# Description: Updates the KeyInstalled flag for a host to 1.
#              Identifies the host by user, hostname, and port.
# ------------------------------------------------------------------------------
update_key_status() {
    local host_details="$1"
    IFS=',' read -r _ user hostname port _ _ <<< "${host_details}"

    awk -F, -v OFS=',' -v u="${user}" -v h="${hostname}" -v p="${port}" \
        '{ if ($2 == u && $3 == h && $4 == p) $6 = 1; print }' \
        "${HOSTS_FILE}" > "${HOSTS_FILE}.tmp" && mv "${HOSTS_FILE}.tmp" "${HOSTS_FILE}"
}

# ------------------------------------------------------------------------------
# Function: update_timestamp()
# Description: Updates the last connected timestamp for the selected host.
#              Identifies the host by user, hostname, and port.
# ------------------------------------------------------------------------------
update_timestamp() {
    local host_details="$1"
    IFS=',' read -r _ user hostname port _ _ <<< "${host_details}"
    local new_timestamp
    new_timestamp=$(date +%s)

    awk -F, -v OFS=',' -v u="${user}" -v h="${hostname}" -v p="${port}" -v ts="${new_timestamp}" \
        '{ if ($2 == u && $3 == h && $4 == p) $5 = ts; print }' \
        "${HOSTS_FILE}" > "${HOSTS_FILE}.tmp" && mv "${HOSTS_FILE}.tmp" "${HOSTS_FILE}"
}


# ==============================================================================
# --- Direct Connection Logic ---
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: handle_direct_connection()
# Description: Handles a direct connection request, saving the new host if successful.
# ------------------------------------------------------------------------------
handle_direct_connection() {
    local user_host
    local port=22 # Default SSH port
    local key_installed=0

    # --- Parse Arguments ---
    # A robust parser that handles arguments in any order.
    local remaining_args=()
    while (( "$#" )); do
        case "$1" in
            -p)
                if [[ -n "$2" && "$2" != -* ]]; then
                    port="$2"
                    shift 2
                else
                    echo "Error: Argument for -p is missing" >&2
                    return 1
                fi
                ;;
            -p*)
                port="${1#-p}"
                shift
                ;;
            *)
                remaining_args+=("$1")
                shift
                ;;
        esac
    done

    # Find the user@host string from the remaining arguments
    for arg in "${remaining_args[@]}"; do
        if [[ "${arg}" =~ @ ]]; then
            user_host="${arg}"
            break
        fi
    done

    if [[ -z "${user_host}" ]]; then
        echo "Error: Invalid connection string. Format: user@hostname" >&2
        return 1
    fi

    local user="${user_host%@*}"
    local hostname="${user_host#*@}"

    # --- Check if Host Exists ---
    while IFS= read -r line; do
        IFS=',' read -r _ u h p _ _ <<< "${line}"
        if [[ "${u}" == "${user}" && "${h}" == "${hostname}" && "${p}" == "${port}" ]]; then
            echo "Existing host found. Connecting..."
            connect_to_host "${line}"
            return 0
        fi
    done < "${HOSTS_FILE}"

    # --- New Host: Test Connection ---
    echo "New host detected. Testing for key-based authentication..."
    # Stage 1: Try with public keys only, in batch mode to prevent prompts.
    if ssh -v -o BatchMode=yes -o ConnectTimeout=5 "${user}@${hostname}" -p "${port}" "exit" &> /dev/null; then
        echo "Connection successful with SSH key."
        key_installed=1
        read -p "Enter a friendly name to save this host: " friendly_name
    else
        # Stage 2: If keys fail, assume password is required and proceed to interactive login.
        echo "Key-based authentication failed. Will attempt interactive login."
        key_installed=0
        read -p "Enter a friendly name to save this host: " friendly_name
    fi
    # --- Save New Host ---
    if [[ -z "${friendly_name}" ]]; then
        friendly_name="${user_host}" # Default to user@host if no name is given
    fi

    local new_host_line="${friendly_name},${user},${hostname},${port},0,${key_installed}"
    echo "${new_host_line}" >> "${HOSTS_FILE}"
    echo "Host '${friendly_name}' saved."

    # --- Proceed to Connect ---
    connect_to_host "${new_host_line}"
}


# ==============================================================================
# --- Main Execution Logic ---
# ==============================================================================
main() {
    # --- Argument Parsing ---
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        return 0
    elif [[ "$1" == "-v" || "$1" == "--version" ]]; then
        echo "${VERSION}"
        return 0
    fi

    if ! check_config_file; then
        return 1
    fi

    # If arguments are provided, handle as a direct connection.
    # Otherwise, show the interactive menu.
    if [[ $# -gt 0 ]]; then
        handle_direct_connection "$@"
    else
        load_hosts
        
        if (( ${#hosts[@]} == 0 )); then
            echo "No hosts found in the configuration file."
            return 1
        fi
        
        select_host
    fi
}

# --- Script Entry Point ---
# Call the main function with all command-line arguments.
main "$@"
