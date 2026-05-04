---
name: audit-config
description: Audits the global Claude Code configuration in ~/.dotfiles/claude/ against established best practices. Covers CLAUDE.md length and content fitness, skill naming and description quality, SKILL.md structure and progressive disclosure, settings.json permissions, and directory hygiene. Use whenever asked to audit, review, or suggest improvements to Claude's own config; also use when creating a new skill, adding content to CLAUDE.md or settings.json, or modifying existing skills — ensures new additions follow best practices from the start.
---

# Auditing Claude's global config

Config lives at `~/.dotfiles/claude/` (symlinked to `~/.claude/{CLAUDE.md,settings.json,skills/}`).

Copy this checklist and track progress through each section:

```
Audit progress:
- [ ] Step 1: Inventory the current state
- [ ] Step 2: CLAUDE.md audit
- [ ] Step 3: Skills audit
- [ ] Step 4: settings.json audit
- [ ] Step 5: Structure and hygiene audit
- [ ] Step 6: Write up findings and proposed changes
```

---

## Principles (the "why" behind every check)

**CLAUDE.md** is loaded in full at the start of *every* session — every line costs context every time.
Target ≤200 lines.
Only include what would cause a mistake if removed.

**Skills** are loaded on demand when relevant — they are the right place for domain knowledge, setup docs, and reference material that is only sometimes needed.
A lean CLAUDE.md + rich skills is the correct trade-off.

**settings.json** controls what Claude can do without prompting.
Pre-approve all safe read-only operations; use hooks for truly deterministic behaviors.

---

## Step 1: Inventory

```bash
find ~/.dotfiles/claude -type f | sort
wc -l ~/.dotfiles/claude/CLAUDE.md
wc -l ~/.dotfiles/claude/skills/*/SKILL.md
ls -la ~/.dotfiles/claude/skills/
```

Note the line count of CLAUDE.md and each SKILL.md before proceeding.

---

## Step 2: CLAUDE.md audit

For **each section**, apply this filter:

| Question | If NO → action |
|---|---|
| Must this be loaded in every session? | Candidate for extraction to a skill |
| Would removing it cause Claude to make a mistake? | Safe to remove or condense |
| Is this duplicated in a skill that already triggers when relevant? | Remove from CLAUDE.md |
| Is this setup/installation/maintenance doc? | Move to a dedicated skill |

**What belongs in CLAUDE.md** (universal, session-critical):
- Identity and environment (user, system, groups, scheduler)
- Personal filesystem paths and quota rules
- Formatting and style preferences (docstrings, markdown conventions)
- Working norms (how to handle disagreement, clarification, durable knowledge)
- Token-efficiency behavioral rules
- Short reference tables Claude needs instantly (repos/accounts, filesystem layout)
- Tool gotchas that occur in normal sessions (e.g. qmd negation parser)
- Dotfiles management rules (where to put new files)

**What does NOT belong in CLAUDE.md**:
- Installation guides or setup scripts for any tool
- Anything only needed when onboarding a new machine
- Long command blocks for rarely-used maintenance operations
- Full paths and masks for every indexed collection (a list of names suffices)
- MCP server architecture explanations
- Anything Claude can infer from reading the code or project files
- Standard language/framework conventions Claude already knows

---

## Step 3: Skills audit

For **each skill** in `skills/`:

**Naming** — `name` field in frontmatter:
- [ ] Lowercase letters, numbers, hyphens only (no spaces, no uppercase)
- [ ] ≤64 characters
- [ ] Gerund form preferred (`auditing-config`, `processing-pdfs`) or action-oriented (`audit-config`, `process-pdfs`); avoid vague nouns (`helper`, `utils`)

**Description** — `description` field in frontmatter:
- [ ] Written in **third person** (not "I can..." or "You can use this to...")
- [ ] States *what* the skill does AND *when* to trigger it (include specific keywords/contexts)
- [ ] ≤1024 characters
- [ ] Specific enough to distinguish from other skills (avoid "helps with documents")

**Body**:
- [ ] SKILL.md body under 500 lines; split into reference files if approaching the limit
- [ ] Uses progressive disclosure: summary/overview in SKILL.md, details in `references/` files
- [ ] Reference files are linked directly from SKILL.md — no chains (SKILL.md → A → B is too deep)
- [ ] Reference files have a table of contents if > 100 lines
- [ ] Consistent terminology throughout (pick one term and use it everywhere)
- [ ] No time-sensitive information ("before August 2025, use the old API…")
- [ ] Complex workflows broken into numbered steps with a copyable checklist
- [ ] Scripts and templates referenced explicitly from SKILL.md

**Directory hygiene**:
- [ ] No empty subdirectories
- [ ] No web-artifact files (`robots.txt`, `.htaccess`, etc.)
- [ ] All file paths use forward slashes
- [ ] File names are descriptive (`form_validation_rules.md`, not `doc2.md`)

---

## Step 4: settings.json audit

```bash
cat ~/.dotfiles/claude/settings.json
```

- [ ] All commonly-used read-only Bash tools are in `permissions.allow` (ls, find, grep, cat, head, tail, wc, stat, etc.)
- [ ] All MCP tools the user uses are in `permissions.allow`
- [ ] No destructive operations (rm, git reset --hard, force push) are pre-approved
- [ ] Git read-only operations (log, status, diff, show, blame) are pre-approved
- [ ] If any "must-always-happen" behaviors exist (linting after edits, blocking writes to certain dirs), they are hooks — not just instructions in CLAUDE.md

---

## Step 5: Structure and hygiene audit

```bash
ls -la ~/.claude/                # check what's a symlink vs real file
ls ~/.dotfiles/claude/skills/    # confirm skill dirs
```

- [ ] `~/.claude/CLAUDE.md` → symlink to dotfiles ✓
- [ ] `~/.claude/settings.json` → symlink to dotfiles ✓
- [ ] `~/.claude/skills/` → symlink to dotfiles ✓
- [ ] `~/.claude.json` is NOT in dotfiles (it's volatile session state) ✓
- [ ] Credentials, cache, session data are in `~/.claude/` as regular files, not dotfiles ✓
- [ ] Any new skill directories created since last audit are symlinked or are inside the `skills/` symlink ✓

---

## Step 6: Write up findings

Organize findings into:

1. **Critical** — CLAUDE.md bloat, broken skill descriptions, missing permissions
2. **Moderate** — skill naming issues, description quality, long SKILL.md files
3. **Minor** — empty dirs, stray files, inconsistent terminology

For each proposed change, state:
- What to change and why (which principle it violates)
- Specific files affected
- Estimated line impact on CLAUDE.md (if applicable)

For extraction proposals (moving content from CLAUDE.md to a skill), always propose the new skill's `name` and `description` fields.

---

## Common anti-patterns

| Anti-pattern | Principle violated | Fix |
|---|---|---|
| CLAUDE.md > 200 lines | Every line costs context every session | Extract setup/reference docs to skills |
| Installation guides in CLAUDE.md | Only needed on new machine setup, not every session | Create a dedicated skill |
| Vague skill description ("helps with documents") | Claude can't distinguish skills by description | Rewrite: third-person, specific, include trigger terms |
| First-person skill description ("I can help you...") | Breaks discovery; description is injected into system prompt | Rewrite in third person |
| Empty directories in skill dirs | Clutter | Delete |
| Web-artifact files (robots.txt) in skill dirs | Not applicable to local filesystem skills | Delete |
| References nested > 1 level deep | Claude may partially read nested files | Restructure to link directly from SKILL.md |
| Duplicate content in CLAUDE.md and a skill | Wastes context; risks divergence | Remove from CLAUDE.md, keep in skill |
| Style/convention rules Claude already knows | Bloats CLAUDE.md with no benefit | Delete |
| Time-sensitive dates in skill content | Will become wrong | Use "old patterns" / "legacy" framing instead |
