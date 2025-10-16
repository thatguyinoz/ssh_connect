### `ssh-connect` TODO List:

*   **Host Management:**
    *   Maintain a list of commonly used hosts.
    *   Store hosts in an external file (e.g., `~/.config/mysshhosts.conf`).
    *   The host file should support fields for: friendly name, user, hostname/IP, port, and `last_connected_timestamp` (in epoch format).

*   **User Interaction:**
    *   On launch, offer to reconnect to the most recently used host (based on timestamp).
    *   Display a numbered list of hosts from the config file for selection, sorted by `last_connected_timestamp`.
    *   Prompt to create the configuration file (`~/.config/mysshhosts.conf`) if it doesn't exist.

*   **Configuration:**
    *   Use an INI file for script settings (e.g., `~/.config/ssh-connect.ini`).

*   **Future Features (Scope Creep):**
    *   Add an option to push a public key to the selected host using `ssh-copy-id`.
    *   allow the script to be available for repeated use, perhaps call the secomd connection from a forked process?
