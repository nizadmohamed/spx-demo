# Claude Code setup for this project (portable)

What travels with the repository:
- `CLAUDE.md` (repo root): project instructions Claude Code loads automatically (standing rules, do-nots, tooling notes).
- `.claude/memory/`: copy of Claude's saved project memory (resume context, the "always confirm before org changes" rule).
- `docs/SPX_Session_Resume_Context.md`: full dated state log; read it first on resume.
- `docs/SPX_Oral_Prep_Guide.md` and `.docx`: architecture and Q&A.

What does NOT travel (set up on the new machine):
- Org authorisations. Run `sf org login web --alias <alias> --instance-url <url>` for each org. Never commit auth URLs or tokens.
- Claude Code login, Salesforce CLI, Node, Git, GitHub CLI or credentials.
- Conversation transcripts (not included on purpose; they contain org URLs and usernames).

## Restore on a new machine
1. Install: Git, Node 18+, Salesforce CLI (`sf`), Claude Code. Optional: `gh`.
2. `git clone <repo-url>` and `cd` into it.
3. Restore memory: `.\scripts\restore_claude_memory.ps1`
4. Authorise the org: `sf org login web --alias spx-new --set-default`
5. Start Claude Code in the repo folder. It reads `CLAUDE.md` automatically; ask it to read `docs/SPX_Session_Resume_Context.md` and `docs/SPX_New_Sandbox_Deployment_Plan.md`.

Org-specific references that will differ in a new org: the org alias `spx-demo` and usernames ending `@accenture.com.spx.demo`, record IDs quoted in docs, the instance URL, and any record Ids inside scripts under `docs/scripts` and `data-load`.
