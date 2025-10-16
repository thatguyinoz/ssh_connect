#!/bin/bash

# ==============================================================================
# Script: ssh-connect.sh
# Description: Facilitates SSH connections using a predefined list of hosts.
# Author: Gemini
# License: MIT
# ==============================================================================

# --- Script Metadata and Versioning ---
SCRIPT_NAME=$(basename "$0")
VERSION="0.01"

# --- Changelog ---
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
                create_sample_config
                return 0
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
# Function: display_host_list()
# Description: Reads and displays the list of hosts from the config file.
# ------------------------------------------------------------------------------
display_host_list() {
    echo "Available hosts:"
    # Read the file, ignore comments and empty lines, and format for display.
    grep -vE '^\s*#|^\s*$' "${HOSTS_FILE}" | nl -w2 -s'. '
}


# ==============================================================================
# --- Main Execution Logic ---
# ==============================================================================
main() {
    # Check for the configuration file first.
    if ! check_config_file; then
        # Exit if the config file check fails (e.g., user opts not to create it).
        return 1
    fi

    # If the config file exists, display the list of hosts.
    display_host_list
}

# --- Script Entry Point ---
# Call the main function with all command-line arguments.
main "$@"
