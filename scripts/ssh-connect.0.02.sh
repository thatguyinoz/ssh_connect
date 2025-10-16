#!/bin/bash

# ==============================================================================
# Script: ssh-connect.sh
# Description: Facilitates SSH connections using a predefined list of hosts.
# Author: Gemini
# License: MIT
# ==============================================================================

# --- Script Metadata and Versioning ---
SCRIPT_NAME=$(basename "$0")
VERSION="0.02"

# --- Changelog ---
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
#   Friendly Name,Username,Hostname or IP,Port,LastConnectedTimestamp
#
# - 'Friendly Name' is the alias you'll see in the selection menu.
# - 'LastConnectedTimestamp' is a Unix epoch timestamp used for sorting.
#   You can leave it as 0 for new entries.
#
# ==============================================================================
#
# --- Example Entry (uncomment and edit to use) ---
# My Web Server,webadmin,192.168.1.100,22,0

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
        # Extract friendly name for display
        friendly_name=$(echo "${hosts[$i]}" | cut -d, -f1)
        printf "%2d. %s\n" "$((i+1))" "${friendly_name}"
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
    IFS=',' read -r friendly_name user hostname port timestamp <<< "$1"
    
    local socket_dir="${HOME}/.ssh/controlmasters"
    local socket_file="${socket_dir}/${user}@${hostname}:${port}"
    
    # Create the directory for control sockets if it doesn't exist
    mkdir -p "${socket_dir}"
    
    echo "Establishing connection to ${friendly_name}..."
    
    # Step 1: Establish the master connection in the background.
    # -f: Go to background just before command execution.
    # -N: Do not execute a remote command.
    # -M: Puts the client into "master" mode for connection sharing.
    # ControlPersist=yes: Keep the master connection open indefinitely.
    ssh -fNM -o ControlPersist=yes -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}"
    
    # Step 2: Check if the master connection was successful.
    if [ $? -eq 0 ]; then
        echo "Connection successful. Updating timestamp."
        update_timestamp "$1"
        
        # Step 3: Verify the terminal command exists.
        if ! command -v "${TERMINAL_CMD}" &> /dev/null; then
            echo "Error: Terminal command '${TERMINAL_CMD}' not found."
            echo "Please install it or change the 'TERMINAL_CMD' variable in the script."
            return 1
        fi

        # Step 4: Open the interactive session in a new terminal.
        # This command attaches to the master connection's socket.
        ${TERMINAL_CMD} -e "ssh -o ControlPath='${socket_file}' '${user}@${hostname}' -p '${port}'" &
        
        echo "New terminal opened for your session."
    else
        echo "Connection to ${friendly_name} failed."
    fi
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