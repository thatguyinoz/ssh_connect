# Workflow for Adding New Functions to enswitch_manager.sh

This document outlines the standard procedure for developing, integrating, and documenting new functionality within the `enswitch_manager.sh` script. Following this workflow ensures that all changes are consistent, tested, and adhere to project conventions.

---

### Phase 1: Research and Discovery

Before writing any code, thoroughly understand the API endpoints required for the new feature.

1.  **Consult API Documentation**: Use the `enswitch_api_retrieval_guide.md` to fetch and review the official Enswitch API documentation for all relevant endpoints. Save the OpenAPI specifications to the `api/` directory.
2.  **Manual API Calls**: Use `curl` commands to manually interact with the API. This helps to confirm the correct parameters, data formats, and authentication requirements before scripting begins.
3.  **Identify a Template**: Find an existing, well-configured customer in the system to serve as a "template." Use the `get` or `list` commands to retrieve their configuration data. This provides a clear, real-world example of the data structure you need to work with.

---

### Phase 2: Isolated Development and Testing

Develop the new functionality in a temporary, standalone script to avoid impacting the main `enswitch_manager.sh` script during development.

1.  **Create a Temporary Script**: Create a new script for your feature (e.g., `temp_new_feature.sh`). Make it executable with `chmod +x`.
2.  **Build the Core Function**: Write the new function inside this temporary script.
3.  **Parameterize and Generalize**: Do not hardcode values. The function should accept parameters (like a customer ID) and dynamically look up any other required information (e.g., hunt group IDs, mailbox numbers) by making API calls.
4.  **Test Thoroughly**: Run the standalone script against multiple customers (including newly created ones) to ensure the function is robust, handles edge cases, and fails gracefully with clear error messages.

---

### Phase 3: Integration into `enswitch_manager.sh`

Once the function is complete and tested, integrate it into the main script.

1.  **Create New Version**: Copy the latest version of the main script to a new, incremented version file (e.g., `cp enswitch_manager-v1.26.sh enswitch_manager-v1.27.sh`).
2.  **Copy the Function**: Copy the finalized, tested function from your temporary script and paste it into the `--- Core API Functions ---` section of the new `enswitch_manager-vX.XX.sh` file.
3.  **Determine Integration Points**:
    *   If the new function should be part of the automated setup, add a call to it within the `setup_customer` function. Ensure it is in the correct logical order.
    *   If the function should be available as a standalone command, proceed to the next phase.

---

### Phase 4: Documentation and Finalization

Update all user-facing documentation and finalize the release.

1.  **Update Changelog**: In the header of the new `enswitch_manager-vX.XX.sh` file, add a new entry describing the changes for the new version.
2.  **Update Usage Information**:
    *   If you added a new standalone command, add it to the `usage()` function.
    *   Update the main `case` statement in the `--- Main Argument Parsing ---` section to handle the new command and its arguments.
3.  **Update `README.md`**: Add the new command to the command reference table in the main `README.md` file.
4.  **Update Symlink**: Update the main `enswitch_manager.sh` symlink to point to the new version file (`ln -sf enswitch_manager-vX.XX.sh enswitch_manager.sh`).
5.  **Commit and Push**: Use `git add` to stage the new version file, the updated symlink, and the `README.md`. Commit the changes with a clear, descriptive message and push to the remote repository.

