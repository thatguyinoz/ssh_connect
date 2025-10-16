# ssh-connect Utility

## 1. Project Overview

*   **Project Name:** ssh-connect
*   **High-Level Summary:** A shell script to simplify and manage SSH connections by providing an interactive menu of predefined hosts.
*   **Core Features:**
    *   Connect to frequently used hosts via a simple selection menu.
    *   Uses SSH connection multiplexing (`ControlMaster`) to establish a persistent background connection, allowing for instant subsequent connections.
    *   Opens interactive sessions in a new terminal window, leaving the original script free.
    *   Updates a timestamp in the host file only after a successful connection.
    *   Stores host configurations in an external, easy-to-edit file.
*   **Technology Stack:** Bash

---

## 2. Usage

To use the script, simply execute it from your terminal:

```bash
./ssh-connect.sh
```

The script will display a numbered list of available hosts, sorted by the most recently connected. Enter the number corresponding to the host you wish to connect to and press Enter.

A new terminal window will open with your SSH session. The original script will be ready to accept another command.

---

## 3. Configuration

### Host File

The script uses a configuration file to store the list of SSH hosts.

*   **Default Location:** `~/.config/mysshhosts.conf`
*   **Development Location:** `auth/my_hosts.conf`

The file uses a simple comma-separated value (CSV) format:

```
# Format: Friendly Name,User,Hostname/IP,Port,LastConnectedTimestamp
My Web Server,webadmin,192.168.1.100,22,1678886400
Corporate DNS,root,dns.corp.example.com,22,0
```

### Terminal Command

The script opens a new terminal window for the SSH session. You can configure which terminal to use by editing the `TERMINAL_CMD` variable at the top of the `ssh-connect.sh` script.

**Default:**
```bash
TERMINAL_CMD="gnome-terminal"
```

You can change this to your preferred terminal, for example: `xterm`, `konsole`, or `terminator`.