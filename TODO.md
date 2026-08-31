# ssh-connect TODO

This document tracks the development status of the `ssh-connect` utility.

---

### Incompleted Features 

*   *(None)*


### Completed Features ✔️

*   **Hybrid Port Forwarding & Advanced SSH Options (Version 0.32):**
    *   ✅ Update `auth/my_hosts.conf` and `auth/my_hosts.conf.ref` schema to 9 columns, adding an `SSHOptions` field for literal command-line flags.
    *   ✅ Enhance `connect_to_host` to read the `SSHOptions` field and parse it safely into an array of persistent flags using space-splitting.
    *   ✅ Combine parsed persistent options with any ad-hoc forwarding/SSH flags from the CLI.
    *   ✅ Support saving active ad-hoc forwarding/SSH flags as persistent options when interactively saving a new direct host connection.
    *   ✅ Display a custom icon (`🔗`) in the interactive host selection menu when a host has saved custom SSH options/forwarding rules.
    *   ✅ Update script header, version metadata, and `README.md` to document the new 9-column schema and literal `SSHOptions` field.
    *   ✅ Add a debug command that will display the full ssh command used to make the connection.

*   **Documentation:**
    *   ✅ Update README.md with forwarding features and explicit examples.

*   **Host Management:**
    *   ✅ Maintain a list of hosts in an external CSV file (`auth/my_hosts.conf`).
    *   ✅ Host file supports: friendly name, user, host, port, last connected timestamp, and key installation status.
    *   ✅ Automatically prompts to create a sample host file if one is not found.

*   **Connection Handling:**
    *   ✅ Display a numbered list of hosts, sorted by the most recently used.
    *   ✅ Use SSH `ControlMaster` and `ControlPersist` for robust, reusable connections, preventing orphaned sessions.
    *   ✅ Implement a direct connection mode (`./ssh-connect.sh user@host`).
    *   ✅ Implement a robust, two-stage connection process to handle servers with strict security and verbose banners.
    *   ✅ **Jumphost Support:**
        *   Connect to hosts via a jumphost (bastion) by linking to another host entry by its friendly name.
        *   Visually indicate hosts that use a jumphost (↪️).
        *   Interactively prompts to assign a jumphost when adding a new host.

*   **Key Installation:**
    *   ✅ Offer to install a public SSH key on the first successful connection.
    *   ✅ Visually indicate hosts with installed keys (🔑).
    *   ✅ **Intelligent, Device-Aware Installation:**
        *   Automatically detects Ubiquiti EdgeOS devices from their SSH banner.
        *   Uses a specialized, reliable method to install keys on EdgeOS devices.
        *   Uses the standard `ssh-copy-id` for all other hosts.

*   **Auto-Update:**
    *   ✅ Periodically checks GitHub for new versions.
    *   ✅ Prompts the user to download and apply updates.
    *   ✅ Intelligently uses `sudo` if required to update script in protected directories.

---

### Future Enhancements 🚀

*   *(None)*
