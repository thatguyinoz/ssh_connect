# Generic Project: Workflow and Style Guide

This document provides a generic template for project workflow, style, and versioning. It is designed to be adapted for new projects, particularly those involving shell scripting and a versioned release process.

---

## 1. Project Overview

*(This section should be filled out for each new project.)*

*   **Project Name:** [Enter Project Name]
*   **High-Level Summary:** [Provide a one or two-sentence summary of the project's purpose and goals.]
*   **Core Features:**
    *   [List the primary features or functionalities.]
    *   [Feature 2]
    *   [Feature 3]
*   **Technology Stack:** [List the key packages, or libraries required as prerequisites]

---

## 2. Development Workflow: Isolated Function Development

This workflow is recommended for adding new functions to a core script to ensure stability.

1.  **Create a Temporary Script**: For any new piece of functionality, create a temporary, standalone development script named `temp_<function_name>.sh` (e.g., `temp_database_connect.sh`). Make it executable with `chmod +x`.

2.  **Isolated Development**: Write and test the new function inside this temporary script. This allows you to develop and debug in isolation without impacting the main application.

3. **Requirements**: update the requirements.txt file with anyadditional packages or libraries that have been added to the system during development.

4.  **Integration**: Once the function is fully tested and working correctly, integrate it into the main project script (e.g., `[main_script_name].sh`).

5.  **Cleanup**: After successful integration, delete the temporary `temp_<function_name>.sh` script.

---

## 3. Script Style Guide (for Shell Scripts)

All shell scripts should adhere to the following conventions for readability and maintainability.

*   **Header**: Every script must begin with a header containing:
    *   Shebang: `#!/bin/bash`
    *   A brief description of the script's purpose.
    *   A versioned changelog.

*   **Variables**:
    *   Define global constants for `SCRIPT_NAME` and `VERSION` at the top of the script.
    *   Use uppercase for global variables (e.g., `CONFIG_DIR`).
    *   Use lowercase for local function variables.

*   **Functions**:
    *   Break down logic into modular, self-contained functions with a single purpose.
    *   Use descriptive, lowercase names (e.g., `connect_to_database()`).
    *   Include a comment above each function explaining its high-level goal.

*   **Structure**:
    *   Organize the script into logical sections using commented banners (e.g., `--- Core Functions ---`).
    *   The main execution logic should be contained within a `main()` function, which is called at the end of the script with `main "$@"`.

---

## 4. Versioning and Release Workflow (Symlink Method)

This workflow uses versioned files and a symbolic link to manage releases and prevent direct edits to the production script.

1.  **Never Edit the Main Script Directly**: The main script file (e.g., `[project_name].sh`) is a symbolic link and should **never** be edited directly.

2.  **Create a New Version**: To make changes, first copy the latest versioned file to a new one with an incremented version number. For example:
    ```bash
    cp [project_name]-v0.2.sh [project_name]-v0.3.sh
    ```

3.  **Update the New File**: Make all your changes in the new versioned file (e.g., `[project_name]-v0.3.sh`).

4.  **Update the Changelog**: In the header of the new file, add a detailed entry for the new version, describing the changes made.

5.  **Update the Symlink**: Once all changes are complete and tested, update the main symlink to point to the new version:
    ```bash
    ln -sf [project_name]-v0.3.sh [project_name].sh
    ```

6.  **Commit**: Stage the new versioned file and the updated symlink and commit them to the repository.

---

## 5. Git Workflow

Follow standard Git best practices for all projects.

1.  **Branching**: Create a new branch for each new feature or bug fix (`feature/add-login`, `fix/auth-bug`).
2.  **Committing**: Write clear, concise commit messages that explain the "why" behind the changes, not just the "what."
3.  **Merging**: Use pull requests or merge requests to merge completed branches back into the main branch.

---

## 6. Tooling Configuration

### File Visibility

To ensure all project files are visible during our interactions, especially documentation and configuration files that might be excluded by default, I will use the `respect_git_ignore=False` flag with my file listing and searching tools. This provides a complete and unfiltered view of the project directory.
