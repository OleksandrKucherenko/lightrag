---
description: Help the developer generate a new LightRAG configuration check script through the template system.
---

The user input to you can be provided directly by the agent or as a command argument - you **MUST** consider it before proceeding with the prompt (if not empty).

User input:

$ARGUMENTS

1. Treat the user input as the natural language description for the desired check. If it is empty, ask the user to describe the check goal (including GIVEN/WHEN/THEN) before proceeding.
2. Extract or confirm the GIVEN, WHEN, and THEN sections. If any are missing, ask concise follow-up questions to collect them. The generator cannot proceed without all three sections.
3. Determine the default metadata:
   - Group → infer from keywords (`security`, `storage`, `communication`, `environment`, `monitoring`, `performance`, `wsl2`). Ask if unsure.
   - Script type → default to `bash` unless the user explicitly requests PowerShell (`powershell`, `ps1`, `windows`) or CMD (`cmd`, `bat`).
   - Service/test name → derive from the description; confirm with the user when ambiguous.
4. When the user wants to preview the template output without creating a file, append `--dry-run` to the generator command.
5. Run the generator from repo root using the orchestrator entry point:
   ```bash
   ./tests/verify.configuration.v3.sh /check "$DESCRIPTION" --group $GROUP --service $SERVICE --test $TEST --script-type $SCRIPT_TYPE
   ```
   - Replace `$DESCRIPTION` with the finalized GIVEN/WHEN/THEN text.
   - Include optional flags such as `--template-id`, `--output-dir`, `--force`, `--json`, or `--metadata` only if the user requested them.
6. Inspect the command output:
   - On success, capture the generated file path and summarize next steps (e.g., replace placeholder logic, run orchestrator).
   - On validation errors (missing sections, duplicate files, unsupported group), explain the issue and guide the user to correct it before retrying.
7. Show the contents of the generated check to the user so they can start implementing real assertions. Highlight where GIVEN/WHEN/THEN placeholders appear.
8. Remind the user to update the placeholder command/message and to run `./tests/verify.configuration.v3.sh` (or targeted checks) once implementation is complete.

Reference commands:
- `./tests/verify.configuration.v3.sh --list-templates` to show available templates.
- `./tests/verify.configuration.v3.sh --validate-templates` to ensure registry integrity when templates change.
