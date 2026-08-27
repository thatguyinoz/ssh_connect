# ssh-connect TODO

This document tracks the development status of the `ssh-connect` utility.

---

### Incompleted Features 

*   *(None)*


### Completed Features ✔️

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

*   **Hybrid Port Forwarding Support:**
    *   Update the host file format to 9 columns to include a `ForwardingRules` field.
    *   This field will store persistent `-L` or `-R` flags for a host.
    *   Multiple rules can be stored, separated by semicolons (`;`).
    *   Modify the script to combine these persistent rules with any ad-hoc forwarding flags provided on the command line.
    *   Modify the script to display an icon if saved forwarding values are present. update metadata and readme to document these changes.

*   **Host Management Commands:**
    *   Add paging or display formatting for when the list if hosts is too long.
