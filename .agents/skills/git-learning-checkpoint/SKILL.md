---
name: git-learning-checkpoint
description: Evaluate completed work in this physics-learning repository and create a scoped Git commit when a reviewable checkpoint is ready. Use after a learning session is reviewed, a roadmap or state update is complete, a project artifact is verified, or the user asks to commit. Do not use for incomplete work, failed validation, pushing, or unrelated changes.
---

# Git Learning Checkpoint

Create one reviewable Git commit for one completed unit of work. The repository's `AGENTS.md` supplies the standing authorization and commit conditions; this skill supplies the execution workflow.

## Decide Whether to Commit

Commit only when all of these are true:

- The current task has a coherent, completed outcome.
- Relevant validation has passed, or the repository has no applicable automated check and that limitation is reported.
- The exact files belonging to the task can be identified.
- The staged result contains no secrets, credentials, unintended large files, caches, or unrelated edits.

Do not commit incomplete learning sessions in `planned` or `submitted` state. Do not commit when validation fails, task ownership is unclear, or the intended change would need to be mixed with unrelated work.

If the repository has no existing commit, a complete and verified project baseline may be committed once as an initialization checkpoint. Confirm every included file belongs in that baseline.

## Prepare the Checkpoint

1. Inspect `git status --short --branch`, unstaged changes, staged changes, and untracked files.
2. Identify the current task's exact file set. Preserve all other worktree changes.
3. Run the checks required by `AGENTS.md` and the changed file types. For Markdown, verify local links and required structure. For code, use the repository's existing lint, typecheck, test, or targeted execution commands.
4. Inspect candidate files for credentials, private data, generated caches, and unexpectedly large binaries.
5. Stage only explicit task paths with `git add -- <paths>`. Never use a broad staging command when unrelated changes exist.
6. Review `git diff --cached --name-status`, `git diff --cached`, and `git diff --cached --check`. Stop if the staged diff is empty or contains anything outside the task.

## Write the Commit Message

Use Conventional Commit format:

```text
<type>(<scope>): <concise Chinese summary>
```

Choose the narrowest suitable type and scope:

- `docs(session)`: reviewed learning-session content.
- `docs(roadmap)`: learning-route changes.
- `docs(state)`: learner profile or current-state changes.
- `feat(project)`: a new runnable physics project or capability.
- `fix(project)`: a correction to a project model or result.
- `chore(repo)`: repository configuration or an initial baseline.

Keep one logical purpose per commit. Add a body only when the motivation, verification, or compatibility impact is not clear from the subject.

## Commit and Report

1. Run `git commit` with the reviewed message.
2. Verify the result with `git status --short --branch` and `git show --stat --oneline HEAD`.
3. Report the commit hash, exact message, validation performed, and any remaining uncommitted paths.

Never run `git push` under this skill.
