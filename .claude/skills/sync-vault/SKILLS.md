---
name: sync-vault
description: Synchronizes the repository state with the local Obsidian documentation vault.
---

# Skill: Sync Obsidian Vault

When this skill is invoked, execute the following steps precisely:

1. **Check Git Progress**: Read the last git commit message (`git log -n 1`) to see what engineering tasks were just completed.
2. **Update Project Overview**: Open `docs/overview.md` and update any milestone progress checkboxes or status descriptions to match the latest commit.
3. **Regenerate Repo Map**: Run the local shell command `tree -I 'node_modules|dist|build|.git|venv|__pycache__|.obsidian' > docs/repo_map.md` to ensure your Obsidian file skeleton is perfectly up to date.
4. **Strict Boundary**: Do not read or parse any raw R source code files during this process. Focus entirely on metadata, git logs, and markdown files.
5. **Auto-Exit**: Once the updates are written to the `docs/` folder, notify the user that the vault is synced and terminate the session.