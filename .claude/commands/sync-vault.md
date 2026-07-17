---
name: sync-vault
description: Synchronizes the repository state with the local Obsidian documentation vault.
---

# /sync-vault Command

When this command is invoked, execute the following steps precisely:
1. **Analyze Active Changes first**: Run `git status` and `git diff HEAD` to examine the active, uncommitted changes in your working tree. Also check the recent git log history (`git log -n 3 --oneline`) to orient your context.
2. Update the `docs/overview.md` milestone status matrices to match the features introduced by BOTH your active uncommitted changes and those recent commits.
3. Run the shell command `tree -I 'node_modules|dist|build|.git|venv|__pycache__|.obsidian' > docs/repo_map.md` to ensure your Obsidian file skeleton is up to date.
4. **Strict Boundary**: Do not read or parse any raw R source code files. Focus entirely on metadata, git status/diff outputs, and markdown files.
5. Close the session when done.