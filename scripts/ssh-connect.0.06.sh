#!/bin/bash

# ==============================================================================
# Script: ssh-connect.sh
# Description: Facilitates SSH connections using a predefined list of hosts.
# Author: Gemini
# License: MIT
# ==============================================================================

# --- Script Metadata and Versioning ---
SCRIPT_NAME=$(basename "$0")
VERSION="0.06"

# --- Changelog ---
# Version 0.06:
#   - Added SSH key installation feature.
#   - Host file format updated to track key installation status.
#   - Host list now displays a key icon (🔑) for configured hosts.
#   - Script now offers to install a public key for passwordless login
#     using the existing authenticated connection.
#
# Version 0.05:
#   - Fixed bug in 'ssh -O check' by adding the missing ControlPath option.
#     This allows the script to correctly reuse existing connections.
#
# Version 0.04:
#   - Reworked connection logic to prevent orphaned sessions.
#   - Switched to ControlPersist=10s for automatic cleanup.
#   - Added robust connection check with 'ssh -O check'.
#   - Script now hands off control to ssh session with 'exec' and exits.
#
# Version 0.03:
#   - Modified connect_to_host() to fall back to the current terminal
#     if TERMINAL_CMD is not set or the command is not found.
#   - Updated comments to reflect that TERMINAL_CMD is optional.
#
# Version 0.02:
#   - Implemented the missing create_sample_config() function.
#   - Added command-line argument parsing for -h and --help.
#   - Added a check to verify that the TERMINAL_CMD exists before use.
#
# Version 0.01:
#   - Initial refactor to align with project style guide.
#   - Added standard header, main() function, and section structure.
#   - Renamed help_text() to usage().
#   - Moved TODO items to TODO.md.
#
# Version 0.00:
#   - Initial commit with basic TODO list.
# ==============================================================================

# --- Configuration ---
# Define global constants and configuration variables here.
# The HOSTS_FILE variable points to the list of hosts.
# For development, this is a local file. In production, it will be ~/.config/mysshhosts.conf.
HOSTS_FILE="auth/my_hosts.conf"
# Optional: Define a terminal to open new SSH sessions in.
# If blank or the command is not found, the session will open in the current terminal.
TERMINAL_CMD="gnome-terminal" #<-- change this to your preferred terminal (e.g., xterm, konsole)

# ==============================================================================
# --- Core Functions ---
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: usage()
# Description: Displays the script's usage instructions.
# ------------------------------------------------------------------------------
usage() {
    echo "Usage: ${SCRIPT_NAME} [options]"
    echo "A utility to simplify SSH connections."
    echo
    echo "Options:"
    echo "  -h, --help    Show this help message."
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
    
    # Create the directory for control sockets if it doesn't exist
    mkdir -p "${socket_dir}"
    
    # If a socket already exists, it might be stale. We'll check and reuse if it's live.
    if ! ssh -o ControlPath="${socket_file}" -O check "${user}@${hostname}" -p "${port}" &>/dev/null; then
        echo "Establishing connection to ${friendly_name}..."
        # Start a new master connection in the background.
        # ControlPersist=10s: Keep master alive for 10s after the last client disconnects.
        ssh -fNM -o ControlPersist=10s -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}"
        
        # Wait a moment for the connection to establish
        sleep 1
        
        # Check if the master connection was successful.
        if ! ssh -o ControlPath="${socket_file}" -O check "${user}@${hostname}" -p "${port}" &>/dev/null; then
            echo "Connection to ${friendly_name} failed."
            # Clean up the failed socket
            rm -f "${socket_file}"
            return 1
        fi
    else
        echo "Reusing existing connection to ${friendly_name}."
    fi

    # --- Connection Successful ---
    echo "Connection successful. Updating timestamp."
    update_timestamp "$1"

    # If a key is not yet installed, offer to install one.
    if [[ "${key_installed}" -ne 1 ]]; then
        offer_to_install_key "$1"
    fi

    # Hand off to the interactive session
    if [[ -n "${TERMINAL_CMD}" && -x "$(command -v ${TERMINAL_CMD})" ]]; then
        echo "Opening new terminal with '${TERMINAL_CMD}'..."
        ${TERMINAL_CMD} -e "ssh -o ControlPath='${socket_file}' '${user}@${hostname}' -p '${port}'" &
        # The script will now exit.
    else
        echo "Spawning session in current terminal..."
        # Replace the script's process with the ssh process.
        exec ssh -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}"
    fi
}

# ------------------------------------------------------------------------------
# Function: offer_to_install_key()
# Description: Finds public SSH keys and offers to install one on the remote host.
# ------------------------------------------------------------------------------
offer_to_install_key() {
    local host_details="$1"
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

    # Use the existing control socket to avoid a password prompt.
    if ssh-copy-id -i "${selected_key}" -o "ControlPath='${socket_file}'" "${user}@${hostname}" -p "${port}"; then
        echo "Key installed successfully."
        update_key_status "${host_details}"
    else
        echo "Failed to install SSH key."
    fi
}

# ------------------------------------------------------------------------------
# Function: update_key_status()
# Description: Updates the KeyInstalled flag for a host to 1.
# ------------------------------------------------------------------------------
update_key_status() {
    local selected_host_line="$1"
    
    # Create the new line with the updated key status
    local new_host_line
    new_host_line=$(echo "${selected_host_line}" | awk -F, -v OFS=',' '{$6=1; print}')
    
    # Use sed to replace the old line with the new one in the file
    sed "s|${selected_host_line}|${new_host_line}|" "${HOSTS_FILE}" > "${HOSTS_FILE}.tmp" && mv "${HOSTS_FILE}.tmp" "${HOSTS_FILE}"
}

# ------------------------------------------------------------------------------
# Function: update_timestamp()
# Description: Updates the last connected timestamp for the selected host.
# ------------------------------------------------------------------------------
update_timestamp() {
    local selected_host_line="$1"
    local new_timestamp
    new_timestamp=$(date +%s)
    
    # Create the new line with the updated timestamp
    local new_host_line
    new_host_line=$(echo "${selected_host_line}" | awk -F, -v OFS=',' -v ts="${new_timestamp}" '{$5=ts; print}')
    
    # Use sed to replace the old line with the new one in the file
    # Note: Using a temporary file for portability with sed
    sed "s|${selected_host_line}|${new_host_line}|" "${HOSTS_FILE}" > "${HOSTS_FILE}.tmp" && mv "${HOSTS_FILE}.tmp" "${HOSTS_FILE}"
}


# ==============================================================================
# --- Main Execution Logic ---
# ==============================================================================
main() {
    # --- Argument Parsing ---
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        return 0
    fi

    if ! check_config_file; then
        return 1
    fi

    load_hosts
    
    if (( ${#hosts[@]} == 0 )); then
        echo "No hosts found in the configuration file."
        return 1
    fi
    
    select_host
}

# --- Script Entry Point ---
# Call the main function with all command-line arguments.
main "$@"
