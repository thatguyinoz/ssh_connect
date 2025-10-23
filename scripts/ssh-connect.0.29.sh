#!/bin/bash

# ==============================================================================
# Script: ssh-connect.sh
# Description: Facilitates SSH connections using a predefined list of hosts.
# Repository: https://github.com/thatguyinoz/ssh_connect
# Author: thatguy@hctech.com.au
# License: MIT
# ==============================================================================

# --- Script Metadata and Versioning ---
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_NAME=$(basename "$0")
VERSION="0.29"

# --- Changelog ---
# Version 0.29:
#   - The auto-update feature now intelligently detects if administrator
#     privileges are required to write to the script's directory and will
#     use `sudo` automatically, prompting the user.
#
# Version 0.28:
#   - Improved argument parser to handle attached values (e.g., `-p2222` or
#     `-L8080:localhost:80`) for the `-p`, `-L`, and `-R` flags, increasing
#     compatibility with standard SSH syntax.
#
# Version 0.27:
#   - Fixed a regression where custom ports for direct connections (e.g.,
#     `user@host -p 2222`) were ignored.
#   - Implemented a more robust command-line argument parser to properly
#     distinguish the connection port (`-p`) from forwarding flags (`-L`, `-R`).
#
# Version 0.26:
#   - Added 'Help' and 'Quit' options to the interactive host selection menu.
#
# Version 0.25:
#   - Added support for ad-hoc port forwarding. The script now accepts
#     multiple `-L` and `-R` flags and passes them to the SSH command.
#
# Version 0.24:
#   - The automatic update prompt now displays the direct download URL for
#     the new version, improving transparency.
#
# Version 0.23:
#   - Added an auto-update feature. When a new version is detected, the
#     script now offers to download and apply the update automatically.
#
# Version 0.22:
#   - Added an automatic, periodic check for new script versions on GitHub.
#     - The check runs once per user session or once every 7 days.
#     - Notifies user if a new version is available to download.
#     - Prompts user to push local changes if their version is newer.
#
# Version 0.21:
#   - Implemented flexible jumphost (bastion) support.
#     - Hosts can be linked by friendly name in a unified host file.
#     - Visual indicator (↪️) for hosts connecting via a jumphost.
#     - Interactive prompts for assigning jumphosts when adding new hosts.
#   - Added an automatic, periodic check for new script versions on GitHub.
#     - The check runs once per user session or once every 7 days.
#     - Notifies user if a new version is available to download.
#     - Prompts user to push local changes if their version is newer.
#   - Fixed a persistent bug with the host list sorting logic.
#
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

# --- Version Check Configuration ---
# The interval in seconds to wait before checking for a new version (7 days).
VERSION_CHECK_INTERVAL=604800
# A lock file to track when the last version check was performed.
# Uses the user's runtime directory, which is cleared on logout/reboot.
LOCK_FILE="/run/user/$(id -u)/ssh-connect_last_check"


# ==============================================================================
# --- Core Functions ---
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: check_for_updates_if_needed()
# Description: Checks if enough time has passed since the last version check
#              and triggers a new check if necessary.
# ------------------------------------------------------------------------------
check_for_updates_if_needed() {
    # Ensure the runtime directory exists
    mkdir -p "$(dirname "${LOCK_FILE}")"

    # If the lock file doesn't exist, or if it's older than the interval,
    # run the check.
    if [[ ! -f "${LOCK_FILE}" ]] || \
       (( $(date +%s) - $(date -r "${LOCK_FILE}" +%s) > VERSION_CHECK_INTERVAL )); then
        
        # Run the check in the foreground to ensure the message appears before
        # the host list. The check function has its own timeout.
        check_for_updates
        # Update the lock file's timestamp
        touch "${LOCK_FILE}"
    fi
}

# ------------------------------------------------------------------------------
# Function: check_for_updates()
# Description: Fetches the latest version from GitHub and notifies the user
#              if there is an update or if their local version is newer.
# ------------------------------------------------------------------------------
check_for_updates() {
    local repo_url="https://api.github.com/repos/thatguyinoz/ssh_connect/contents/scripts"
    
    # Fetch, parse, and sort to find the latest version number online.
    # Use a 2-second timeout to prevent the script from hanging.
    latest_version=$(curl --max-time 2 -sL "${repo_url}" | \
        grep -o 'ssh-connect\.[0-9]\+\.[0-9][0-9]\?\.sh' | \
        sed 's/ssh-connect\.\(.*\)\.sh/\1/' | \
        sort -V | \
        tail -n 1)

    # Silently exit if we failed to retrieve a version number.
    if [[ -z "${latest_version}" ]]; then
        return
    fi

    highest_version=$(printf '%s\n' "${latest_version}" "${VERSION}" | sort -V | tail -n 1)

    # Compare the highest version to our current version to determine the state.
    if [[ "${highest_version}" == "${VERSION}" ]]; then
        if [[ "${latest_version}" != "${VERSION}" ]]; then
            # This means the local version is newer.
            echo -e "\n---"
            echo "💡 Your local version (${VERSION}) is newer than the remote version (${latest_version})."
            echo "   Please consider pushing your changes to the repository."
            echo -e "---\n"
        fi
    else
        # This means the remote version is newer.
        local download_url="https://raw.githubusercontent.com/thatguyinoz/ssh_connect/master/scripts/ssh-connect.${latest_version}.sh"
        echo -e "\n---"
        echo "✨ A new version of ssh-connect (${latest_version}) is available!"
        echo "   Source: ${download_url}"
        read -p "   Would you like to download and apply this update now? [y/N]: " choice
        if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
            perform_update "${latest_version}"
        else
            echo "   Update skipped. You can update later by re-running the script."
        fi
        echo -e "---\n"
    fi
}

# ------------------------------------------------------------------------------
# Function: perform_update()
# Description: Downloads the latest version of the script and replaces the
#              current one.
# ------------------------------------------------------------------------------
perform_update() {
    local version_to_download=$1
    local download_url="https://raw.githubusercontent.com/thatguyinoz/ssh_connect/master/scripts/ssh-connect.${version_to_download}.sh"
    local temp_file="/tmp/ssh-connect.tmp"

    echo "Downloading version ${version_to_download}..."
    if ! curl -sL -o "${temp_file}" "${download_url}"; then
        echo "Error: Download failed. Please try again later."
        rm -f "${temp_file}"
        return 1
    fi

    # Verify that the downloaded file is not empty
    if [[ ! -s "${temp_file}" ]]; then
        echo "Error: Downloaded file is empty. Aborting update."
        rm -f "${temp_file}"
        return 1
    fi

    # Make the new script executable
    chmod +x "${temp_file}"

    # Replace the current script with the new one
    if mv "${temp_file}" "${SCRIPT_PATH}"; then
        echo "✅ Update complete. Please run the script again."
        exit 0
    else
        echo "Error: Failed to replace the script file. Please check permissions."
        rm -f "${temp_file}"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Function: usage()
# Description: Displays the script's usage instructions.
# ------------------------------------------------------------------------------
usage() {
    cat << EOF
A utility to simplify SSH connections.

USAGE:
    ${SCRIPT_NAME} [options]
    ${SCRIPT_NAME} <host_name> [-p <port>] [-L <forward_spec>] [-R <forward_spec>]

DESCRIPTION:
    This script provides an interactive menu to manage and connect to SSH hosts.
    When a <host_name> is provided, it will connect to that host. If the
    host is not in the config file, it will be treated as a direct connection
    string (e.g., user@hostname) and you will be prompted to save it.

    The script supports standard SSH arguments for port forwarding (-L and -R)
    and for specifying a connection port (-p). These flags support both
    space-separated (e.g., -p 2222) and attached (e.g., -p2222) values.

    On the first successful connection, it will offer to install a public SSH
    key for passwordless login. Hosts with keys are marked with 🔑.
    Hosts that connect via a jumphost are marked with ↪️.

OPTIONS:
    -h, --help    Show this help message.
    -v, --version Show the script version.

CONFIGURATION:
    Host File:
        The script uses a host configuration file located at:
        ${HOSTS_FILE}

        Each line in this file represents one host and must be in the following
        comma-separated (CSV) format:

        Friendly Name,User,Hostname,Port,Timestamp,Key,JumpHostName,IsJumphost

        - Friendly Name:  A unique name for the host (e.g., "Web Server").
        - Username:       The user to connect as.
        - Hostname:       The hostname or IP address.
        - Port:           The SSH port.
        - Timestamp:      Unix timestamp of the last connection (managed by script).
        - KeyInstalled:   1 if an SSH key is installed, otherwise 0.
        - JumpHostName:   Set to 0 for a direct connection, or the exact
                          'Friendly Name' of another host to use as a jumphost.
        - IsJumphost:     Set to 1 if this host can be used as a jumphost for
                          other hosts, otherwise 0.

    Terminal Command:
        If the TERMINAL_CMD variable is set to a valid command, the script
        will open the SSH session in a new terminal window. Otherwise, it
        will use the current terminal.
        Current: ${TERMINAL_CMD:-"Not set (will use current terminal)"}
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
# - The format is a comma-separated list (8 columns):
#   Friendly Name,User,Hostname,Port,LastConnTimestamp,KeyInstalled,JumpHostName,IsJumphost
#
# - JumpHostName: Use '0' for a direct connection, or the 'Friendly Name' of
#                 another host that has 'IsJumphost' set to 1.
# - IsJumphost:   Set to 1 to allow this host to be used as a jumphost.
#
# ==============================================================================
#
# --- Example Entries (uncomment and edit to use) ---
#
# 1. A host that can be used as a jumphost
#Main Bastion,jumpadmin,bastion.example.com,22,0,1,0,1
#
# 2. A private server that connects through "Main Bastion"
#Private DB,dbuser,10.0.1.50,22,0,0,Main Bastion,0
#
# 3. A standard, direct-connect server
#Web Server,webadmin,192.168.1.100,22,0,0,0,0

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
    
    # First, read all filtered and sorted hosts into the 'hosts' array.
    # This ensures the entire sort operation completes before we proceed.
    mapfile -t hosts < <(grep -vE '^\s*#|^\s*$' "${HOSTS_FILE}" | sort -t, -k5,5nr)
    
    # Now, iterate through the correctly sorted array to display the hosts.
    local i=0
    for host_line in "${hosts[@]}"; do
        i=$((i+1))
        IFS=',' read -r friendly_name _ _ _ _ key_installed jump_host_name _ <<< "${host_line}"
        
        local display_name="${friendly_name}"
        # Add a key icon if a key is installed
        if [[ "${key_installed}" -eq 1 ]]; then
            display_name="🔑 ${display_name}"
        fi
        # Add a jump icon to the end of the line if a jumphost is used
        if [[ -n "${jump_host_name}" && "${jump_host_name}" != "0" ]]; then
            display_name="${display_name} ↪️"
        fi
        
        printf "%2d. %s\n" "${i}" "${display_name}"
    done
}

# ------------------------------------------------------------------------------
# Function: select_host()
# Description: Prompts the user to select a host from the pre-loaded list
#              and initiates the connection. Also handles the 'help' command.
# ------------------------------------------------------------------------------
select_host() {
    local -n hosts_ref=$1 # Use a nameref to get the sorted hosts array
    shift 
    local forwarding_flags=("$@")

    while true; do
        read -p "Enter host number, 'h' for help, or 'q' to quit: " selection
        case "${selection}" in
            h|help)
                usage
                # After showing help, re-display the list and re-prompt.
                echo -e "\n---"
                load_hosts
                ;;
            q|quit)
                echo "Exiting."
                return 0
                ;;
            [0-9]*)
                if (( selection >= 1 && selection <= ${#hosts_ref[@]} )); then
                    # Valid number, proceed to connect
                    connect_to_host "${hosts_ref[$((selection-1))]}" "${forwarding_flags[@]}"
                    # Break the loop after a valid selection
                    break
                else
                    echo "Invalid selection. Please enter a number between 1 and ${#hosts_ref[@]}."
                fi
                ;;
            *)
                echo "Invalid input. Please enter a number, 'h' for help, or 'q' to quit."
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Function: connect_to_host()
# Description: Establishes a persistent background SSH connection and opens
#              an interactive session in a new terminal.
# ------------------------------------------------------------------------------
connect_to_host() {
    local host_details=$1
    shift # Shift away the host details
    local forwarding_flags=("$@") # The rest of the arguments are forwarding flags

    IFS=',' read -r friendly_name user hostname port timestamp key_installed jump_host_name is_jumphost <<< "${host_details}"
    
    local socket_dir="${HOME}/.ssh/controlmasters"
    local socket_file="${socket_dir}/${user}@${hostname}:${port}"
    local is_edgerouter=false
    local jump_flag=""

    # --- Jump Host Logic ---
    if [[ -n "${jump_host_name}" && "${jump_host_name}" != "0" ]]; then
        local jump_host_line
        jump_host_line=$(awk -F, -v name="${jump_host_name}" \
            '$1 == name && $8 == 1 {print; exit}' "${HOSTS_FILE}")

        if [[ -z "${jump_host_line}" ]]; then
            echo "Error: Jumphost '${jump_host_name}' not found or is not marked as a jumphost in ${HOSTS_FILE}."
            return 1
        fi

        IFS=',' read -r _ jump_user jump_hostname jump_port _ _ _ _ <<< "${jump_host_line}"
        jump_port=${jump_port:-22}
        jump_flag="-J ${jump_user}@${jump_hostname}:${jump_port}"
        echo "Using jumphost: ${jump_user}@${jump_hostname}"
    fi
    
    mkdir -p "${socket_dir}"
    
    # First, check for/establish the persistent connection *without* forwarding flags,
    # as they can interfere with the non-interactive 'exit' command.
    if ssh ${jump_flag} -o ControlPath="${socket_file}" -O check "${user}@${hostname}" -p "${port}" &>/dev/null; then
        echo "Reusing existing connection to ${friendly_name}."
    else
        echo "Establishing persistent connection to ${friendly_name}..."
        
        local banner_file
        banner_file=$(mktemp)
        
        # Attempt 1: Standard key-based authentication.
        if ! ssh ${jump_flag} -M -o ControlPersist=10s -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}" "exit" &> "${banner_file}"; then
            # Attempt 2: Password-only fallback if keys fail.
            echo "Initial connection failed. Retrying with password-only authentication..."
            if ! ssh ${jump_flag} -M -o ControlPersist=10s -o ControlPath="${socket_file}" -o PreferredAuthentications=password "${user}@${hostname}" -p "${port}" "exit" &> "${banner_file}"; then
                echo "Connection to ${friendly_name} failed."
                cat "${banner_file}"
                rm -f "${socket_file}" "${banner_file}"
                return 1
            fi
        fi
        
        if grep -q "EdgeOS" "${banner_file}"; then
            is_edgerouter=true
        fi
        rm -f "${banner_file}"
    fi

    # --- Connection Successful ---
    echo "Connection successful. Updating timestamp."
    update_timestamp "${host_details}"

    if [[ "${key_installed}" -ne 1 ]]; then
        offer_to_install_key "${host_details}" "${is_edgerouter}" "${jump_flag}"
    fi

    # Now, open the interactive session *with* the forwarding flags.
    if [[ -n "${TERMINAL_CMD}" && -x "$(command -v ${TERMINAL_CMD})" ]]; then
        echo "Opening new terminal with port forwarding..."
        ${TERMINAL_CMD} ssh "${forwarding_flags[@]}" ${jump_flag} -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}" &
    else
        echo "Spawning session in current terminal with port forwarding..."
        exec ssh "${forwarding_flags[@]}" ${jump_flag} -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}"
    fi
}

# ------------------------------------------------------------------------------
# Function: offer_to_install_key()
# Description: Finds public SSH keys and offers to install one on the remote host.
# ------------------------------------------------------------------------------
offer_to_install_key() {
    local host_details="$1"
    local is_edgerouter="$2"
    local jump_flag="$3" # Accept the jump flag as an argument
    IFS=',' read -r friendly_name user hostname port _ _ _ _ <<< "${host_details}"
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
        if ! scp ${jump_flag} -o ControlPath="${socket_file}" "${selected_key}" "${user}@${hostname}:${remote_tmp_key}"; then
            echo "Error: Failed to copy key to the EdgeRouter."
            return 1
        fi

        # Step 2: append the key from /tmp/<keyfile> to /config/auth/<user>_authorized_keys then sudo copy it back.
        echo "Running loadkey command..."
        if ! ssh ${jump_flag} -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}" "cat /home/$user/.ssh/authorized_keys > /config/auth/$user-authorized_keys;cat ${remote_tmp_key} >>/config/auth/$user-authorized_keys;sudo cp /config/auth/$user-authorized_keys /home/$user/.ssh/authorized_keys"; then
            echo "Error: Failed to run loadkey command on the EdgeRouter."
            # Still try to clean up
            ssh ${jump_flag} -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}" "rm ${remote_tmp_key}"
            return 1
        fi
        # Step 3: Clean up the temporary key
        echo "Cleaning up..."
        ssh ${jump_flag} -o ControlPath="${socket_file}" "${user}@${hostname}" -p "${port}" "rm ${remote_tmp_key}"
        
        echo "Key installed successfully on EdgeOS device."
        update_key_status "${host_details}"

    else
        # --- Standard ssh-copy-id Logic ---
        local ssh_copy_id_options=""
        if [[ -n "${jump_flag}" ]]; then
            # ssh-copy-id doesn't support -J, so we must pass the ProxyJump
            # command as a generic option using -o.
            local proxy_jump_value=${jump_flag#"-J "}
            ssh_copy_id_options="-o ProxyJump=${proxy_jump_value}"
        fi

        if ssh-copy-id ${ssh_copy_id_options} -i "${selected_key}" -p "${port}" "${user}@${hostname}"; then
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
#              Identifies the host by its unique friendly name.
# ------------------------------------------------------------------------------
update_key_status() {
    local host_details="$1"
    IFS=',' read -r friendly_name _ _ _ _ _ _ _ <<< "${host_details}"

    awk -F, -v OFS=',' -v name="${friendly_name}" \
        '{ if ($1 == name) $6 = 1; print }' \
        "${HOSTS_FILE}" > "${HOSTS_FILE}.tmp" && mv "${HOSTS_FILE}.tmp" "${HOSTS_FILE}"
}

# ------------------------------------------------------------------------------
# Function: update_timestamp()
# Description: Updates the last connected timestamp for the selected host.
#              Identifies the host by its unique friendly name.
# ------------------------------------------------------------------------------
update_timestamp() {
    local host_details="$1"
    IFS=',' read -r friendly_name _ _ _ _ _ _ _ <<< "${host_details}"
    local new_timestamp
    new_timestamp=$(date +%s)

    awk -F, -v OFS=',' -v name="${friendly_name}" -v ts="${new_timestamp}" \
        '{ if ($1 == name) $5 = ts; print }' \
        "${HOSTS_FILE}" > "${HOSTS_FILE}.tmp" && mv "${HOSTS_FILE}.tmp" "${HOSTS_FILE}"
}


# ==============================================================================
# --- Direct Connection Logic ---
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: handle_direct_connection()
# Description: Handles a direct connection for a host not in the config file.
# ------------------------------------------------------------------------------
handle_direct_connection() {
    local direct_connection_string=$1
    local connection_port=$2
    shift 2
    local forwarding_flags=("$@")

    # Basic validation for the user@host format
    if ! [[ "${direct_connection_string}" =~ @ ]]; then
        echo "Error: Invalid connection string '${direct_connection_string}'. Format must be user@hostname." >&2
        usage
        return 1
    fi

    local user="${direct_connection_string%@*}"
    local hostname="${direct_connection_string#*@}"
    # Use the provided port, or default to 22 if it's empty.
    local port=${connection_port:-22}

    # --- Check if Host Exists ---
    # Note: This check is simple and may not catch all cases if port differs.
    while IFS= read -r line; do
        IFS=',' read -r _ u h p _ _ _ _ <<< "${line}"
        if [[ "${u}" == "${user}" && "${h}" == "${hostname}" && "${p}" == "${port}" ]]; then
            echo "Existing host found. Connecting..."
            connect_to_host "${line}" "${forwarding_flags[@]}"
            return 0
        fi
    done < <(grep -vE '^\s*#|^\s*$' "${HOSTS_FILE}")

    # --- New Host: Test Connection ---
    echo "New host detected. Testing for key-based authentication on port ${port}..."
    local key_installed=0
    if ssh -v -o BatchMode=yes -o ConnectTimeout=5 "${user}@${hostname}" -p "${port}" "exit" &> /dev/null; then
        echo "Connection successful with SSH key."
        key_installed=1
    else
        echo "Key-based authentication failed. Will attempt interactive login."
    fi
    
    # --- Get Host Details from User ---
    read -p "Enter a friendly name to save this host: " friendly_name
    if [[ -z "${friendly_name}" ]]; then
        friendly_name="${direct_connection_string}"
    fi

    local is_jumphost=0
    local jump_host_name="0"
    read -p "Is this host a jumphost/bastion? [y/N]: " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        is_jumphost=1
    else
        mapfile -t jump_hosts < <(awk -F, '!/^\s*($|#)/ && $8 == 1 {print $1}' "${HOSTS_FILE}")
        if [[ ${#jump_hosts[@]} -gt 0 ]]; then
            echo "Available jumphosts:"
            for i in "${!jump_hosts[@]}"; do
                printf "%2d. %s\n" "$((i+1))" "${jump_hosts[$i]}"
            done
            read -p "Assign a jumphost? (Enter number or any other key for none): " jump_selection
            if [[ "${jump_selection}" =~ ^[0-9]+$ ]] && (( jump_selection >= 1 && jump_selection <= ${#jump_hosts[@]} )); then
                jump_host_name="${jump_hosts[$((jump_selection-1))]}"
            fi
        fi
    fi

    # --- Save New Host ---
    local new_host_line="${friendly_name},${user},${hostname},${port},0,${key_installed},${jump_host_name},${is_jumphost}"
    echo "${new_host_line}" >> "${HOSTS_FILE}"
    echo "Host '${friendly_name}' saved."

    # --- Proceed to Connect ---
    connect_to_host "${new_host_line}" "${forwarding_flags[@]}"
}


# ==============================================================================
# --- Main Execution Logic ---
# ==============================================================================
main() {
    # Periodically check for new versions in the background.
    check_for_updates_if_needed

    # Handle -h and -v flags first, as they don't require a host.
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

    # --- Argument Parsing ---
    local friendly_name="$1"
    shift # The host is always the first argument

    local connection_port=""
    local forwarding_flags=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p*)
                # Handles both -p 2222 and -p2222
                val="${1#-p}"
                if [[ -z "${val}" ]]; then
                    # Value is the next argument
                    if [[ -z "$2" || "$2" =~ ^- ]]; then
                        echo "Error: -p option requires a port number." >&2; return 1
                    fi
                    connection_port="$2"
                    shift 2
                else
                    # Value is attached
                    connection_port="${val}"
                    shift
                fi
                ;;
            -L*|-R*)
                # Handles both -L spec and -Lspec (and -R)
                local flag="${1:0:2}" # Extracts -L or -R
                local val="${1:2}"   # Extracts the rest of the string

                if [[ -z "${val}" ]]; then
                    # Value is the next argument
                    if [[ -z "$2" || "$2" =~ ^- ]]; then
                        echo "Error: ${flag} option requires an argument." >&2; return 1
                    fi
                    forwarding_flags+=("${flag}" "$2")
                    shift 2
                else
                    # Value is attached, pass the whole flag+value as one arg
                    forwarding_flags+=("$1")
                    shift
                fi
                ;;
            *)
                echo "Error: Unknown or invalid option '$1'" >&2
                usage
                return 1
                ;;
        esac
    done

    if [[ -z "${friendly_name}" ]]; then
        # If no host argument is provided, show the interactive menu.
        load_hosts
        if (( ${#hosts[@]} == 0 )); then
            echo "No hosts found in the configuration file."
            return 1
        fi
        select_host hosts "${forwarding_flags[@]}" # Pass forwarding flags to menu
        return
    fi

    # Check if the friendly name exists in the host file.
    local host_line
    host_line=$(awk -F, -v name="${friendly_name}" '$1 == name {print; exit}' "${HOSTS_FILE}")

    if [[ -n "${host_line}" ]]; then
        # If it exists, connect using the stored details.
        # Note: connection_port from CLI is ignored if host is in config.
        connect_to_host "${host_line}" "${forwarding_flags[@]}"
    else
        # If it doesn't exist, treat it as a direct connection string.
        handle_direct_connection "${friendly_name}" "${connection_port}" "${forwarding_flags[@]}"
    fi
}

# --- Script Entry Point ---
# Call the main function with all command-line arguments.
main "$@"

