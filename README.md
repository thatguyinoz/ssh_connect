# ssh-connect Utility

## 1. Project Overview

*   **Project Name:** ssh-connect
*   **High-Level Summary:** A shell script to simplify and manage SSH connections by providing an interactive menu of predefined hosts.
*   **Core Features:**
    *   Connect to frequently used hosts via a simple selection menu.
    *   Stores host configurations in an external, easy-to-edit file.
    *   Automatically creates a sample configuration if one doesn't exist.
*   **Technology Stack:** Bash

---

## 2. Usage

To use the script, simply execute it from your terminal:

```bash
./ssh-connect.sh
```

The script will display a numbered list of available hosts. Enter the number corresponding to the host you wish to connect to and press Enter.

---

## 3. Configuration

The script uses a configuration file to store the list of SSH hosts.

*   **Default Location:** `~/.config/mysshhosts.conf`
*   **Development Location:** `auth/my_hosts.conf`

The file uses a simple comma-separated value (CSV) format:

```
# Format: Friendly Name,User,Hostname/IP,Port,LastConnectedTimestamp
My Web Server,webadmin,192.168.1.100,22,1678886400
Corporate DNS,root,dns.corp.example.com,22,0
```

If the configuration file is not found, the script will offer to create a sample file populated with default values.
