# ssh-connect TODO

This document tracks the development status of the `ssh-connect` utility.

---

### Completed Features ✔️

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

---

### Future Enhancements 🚀

*   **Configuration:**
    *   Migrate script settings (like `TERMINAL_CMD` and `HOSTS_FILE` path) from hardcoded variables to an external INI configuration file (e.g., `~/.config/ssh-connect.ini`).

*   **User Experience:**
    *   On launch, directly offer to reconnect to the single most recently used host as a default, quick-connect option.

*   **Additional ssh arguments such as -R or -L**

*   **Host Management Commands:**
    *   Add paging or display formatting for when the list if hosts is too long.
