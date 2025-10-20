# ssh-connect Utility

## 1. Project Overview

*   **Project Name:** ssh-connect
*   **High-Level Summary:** A shell script to simplify and manage SSH connections by providing an interactive menu of predefined hosts.
*   **Core Features:**
    *   Connect to frequently used hosts via a simple selection menu.
    *   Uses SSH connection multiplexing (`ControlMaster`) for instant subsequent connections.
    *   Opens sessions in a new terminal window or the current one.
    *   Offers to install a public SSH key for passwordless login.
    *   Visually indicates hosts with keys (🔑) and those behind a jumphost (↪️).
    *   **Jumphost Support:** Connect through a bastion host by linking hosts by name.
    *   Updates a timestamp in the host file only after a successful connection.
    *   Stores host configurations in an external, easy-to-edit file.
*   **Technology Stack:** Bash

---

## 2. Installation

There are a couple of ways to download the script.

### Method 1: Git Clone (Recommended)

If you have `git` installed, you can clone the entire repository:

```bash
git clone https://github.com/thatguyinoz/ssh-connect.git
cd ssh-connect
```

This will download all the files, including the latest version of the script, `ssh-connect.sh`.

### Method 2: Download the script directly

You can download the script directly using `curl` or `wget`.

Using `curl`:
```bash
curl -o ssh-connect.sh https://raw.githubusercontent.com/thatguyinoz/ssh_connect/master/scripts/ssh-connect.0.19.sh
```

Using `wget`:
```bash
wget -O ssh-connect.sh https://raw.githubusercontent.com/thatguyinoz/ssh_connect/master/scripts/ssh-connect.0.19.sh
```

### Making the script executable

After downloading, you need to make the script executable:

```bash
chmod +x ssh-connect.sh
```

### (Optional) Move to a directory in your PATH

To run the script from anywhere, move it to a directory in your system's `PATH`.

```bash
sudo mv ssh-connect.sh /usr/local/bin/ssh-connect
```

Now you can run the script by simply typing `ssh-connect` in your terminal.

---

## 3. Usage

To use the script, simply execute it from your terminal:

```bash
./ssh-connect.sh
```

The script will display a numbered list of available hosts, sorted by the most recently connected. Hosts that are already configured for passwordless login will be marked with a key icon (🔑). Hosts that connect through a jumphost will have a jump icon at the end of the line (↪️).

Enter the number corresponding to the host you wish to connect to and press Enter.

If it's your first time connecting to a host, the script will offer to install one of your local public SSH keys (`~/.ssh/*.pub`) onto the remote server, enabling passwordless login for future sessions.

---

## 3. Configuration

### Host File

The script uses a configuration file to store the list of SSH hosts. By default, it looks for `auth/my_hosts.conf` inside the script's directory.

The file uses a flexible, 8-column comma-separated value (CSV) format that allows for both direct and proxied (jumphost) connections.

**Format:**
`Friendly Name,User,Hostname,Port,Timestamp,Key,JumpHostName,IsJumphost`

*   **`Friendly Name`**: A unique name for the host (e.g., "Web Server").
*   **`Username`**: The user to connect as.
*   **`Hostname`**: The hostname or IP address.
*   **`Port`**: The SSH port.
*   **`Timestamp`**: Unix timestamp of the last connection (managed by the script).
*   **`KeyInstalled`**: `1` if an SSH key is installed, otherwise `0`.
*   **`JumpHostName`**: The `Friendly Name` of another host to use as a proxy. Set to `0` for a direct connection.
*   **`IsJumphost`**: `1` if this host can be used as a jumphost for others, otherwise `0`.

**Example `auth/my_hosts.conf`:**
```
# 1. A host that is a jumphost and can also be connected to directly.
Main-Bastion,jumpadmin,bastion.example.com,22,0,1,0,1

# 2. A private server that can only be reached through "Main-Bastion".
Private-DB,dbuser,10.0.1.50,22,0,0,Main-Bastion,0

# 3. A standard, direct-connect server.
Web-Server,webadmin,192.168.1.100,22,0,0,0,0
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
