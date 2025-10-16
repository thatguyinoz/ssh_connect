# ssh-connect Utility

## 1. Project Overview

*   **Project Name:** ssh-connect
*   **High-Level Summary:** A shell script to simplify and manage SSH connections by providing an interactive menu of predefined hosts.
*   **Core Features:**
    *   Connect to frequently used hosts via a simple selection menu.
    *   Uses SSH connection multiplexing (`ControlMaster`) to establish a persistent background connection, allowing for instant subsequent connections.
    *   Opens interactive sessions in a new terminal window (if available), or in the current one.
    *   Offers to install a public SSH key for passwordless login on the first successful connection.
    *   Visually indicates (🔑) which hosts are already configured with an SSH key.
    *   Updates a timestamp in the host file only after a successful connection.
    *   Stores host configurations in an external, easy-to-edit file.
*   **Technology Stack:** Bash

---

## 2. Usage

To use the script, simply execute it from your terminal:

```bash
./ssh-connect.sh
```

The script will display a numbered list of available hosts, sorted by the most recently connected. Hosts that are already configured for passwordless login will be marked with a key icon (🔑).

Enter the number corresponding to the host you wish to connect to and press Enter.

If it's your first time connecting to a host, the script will offer to install one of your local public SSH keys (`~/.ssh/*.pub`) onto the remote server, enabling passwordless login for future sessions.

---

## 3. Configuration

### Host File

The script uses a configuration file to store the list of SSH hosts.

*   **Default Location:** `~/.config/mysshhosts.conf`
*   **Development Location:** `auth/my_hosts.conf`

The file uses a simple comma-separated value (CSV) format:

```
# Format: Friendly Name,User,Hostname/IP,Port,LastConnectedTimestamp,KeyInstalled
# KeyInstalled: 1 if an SSH key has been installed, 0 otherwise.
My Web Server,webadmin,192.168.1.100,22,1678886400,1
Corporate DNS,root,dns.corp.example.com,22,0,0
```

### Terminal Command

The script opens a new terminal window for the SSH session. You can configure which terminal to use by editing the `TERMINAL_CMD` variable at the top of the `ssh-connect.sh` script. If this variable is left blank or the command is not found, the session will open in the current terminal.

**Default:**
```bash
TERMINAL_CMD="gnome-terminal"
```

You can change this to your preferred terminal, for example: `xterm`, `konsole`, or `terminator`.

---

## 4. Advanced Usage

### Direct Connection

For quick, one-off connections, you can use the script as a wrapper for `ssh`. It will automatically test the connection and prompt you to save the new host for future use.

The arguments can be provided in any order:

```bash
# Connect using the default port 22
./ssh-connect.sh user@hostname

# Specify a custom port
./ssh-connect.sh -p 2222 user@hostname
./ssh-connect.sh user@hostname -p2222
```

### Intelligent Key Installation

The script makes enabling passwordless login easy and reliable. When you first connect to a host that requires a password, it will offer to install a public key.

The script is device-aware and will automatically use the correct method:

*   **Standard Hosts:** For most servers, it uses the robust, industry-standard `ssh-copy-id` utility.
*   **EdgeOS Devices:** The script automatically detects Ubiquiti EdgeRouters. For these devices, it uses a specialized, fully automated process that creates and manipulates the persistent key files in `/config/auth/<username>_authorized_keys`, copying it back to /home/<user>/.ssh/authorized_keys ensuring the key is installed reliably without any manual steps. the user can log in and use "configure|loadkey <username> /config/auth/<user>-authorized_keys|exit" to add the keys to saved config if desired.

This intelligent detection makes the key installation process seamless and reliable across different types of remote hosts.
