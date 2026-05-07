# Claude Code guidance for `jfc20`

## Identity

- **User**: jfc20 — postdoctoral researcher at Stanford University and SLAC National Lab.
  NERSC groups: `m1727` (CPU), `m1727_g` (GPU). LSST group: `lsst`.
- **Development systems**: primarily NERSC Perlmutter (HPC, Slurm, `$NERSC_HOST=perlmutter`), also personal Mac laptop.
  For anything cluster-related invoke `/nersc` — it covers job submission, filesystems, personal paths, accounts, and gotchas.

## Conventions / preferences

- **Python docstrings**: always use NumPy style.
- **Markdown and LaTeX**: one sentence per line — never wrap a sentence across
  multiple lines, and never put two sentences on the same line.


## Working norms

- **Durable knowledge**: when I learn repo-specific workflow or preference
  information, add it to that repo's `CLAUDE.md`. If a preference likely
  applies across repos, explicitly flag it as a candidate for global custom
  instructions (this file).
- **Blocked by missing tooling**: if a missing tool, package, or environment
  setup is slowing me down or blocking useful work, say exactly what to install
  and why — don't silently work around it.
- **Disagreement**: if I think the user is mistaken about the code, the
  requirements, or the likely fix, say so directly with a technical reason
  instead of implementing a change I believe is wrong.
- **Upfront clarification**: at the start of a new task, ask about
  uncertainties that materially affect correctness, interfaces, edge cases, or
  design direction. Don't stop for minor uncertainties — make reasonable
  assumptions, state them briefly, and proceed.

## Token-efficient operation

- **Size before reading.** Use `wc -c`, `ls -la`, or `wc -l` before pulling a
  large file. Take a slice (`head`, `tail`, `grep`, `jq`, Python projection)
  unless the full body is genuinely needed.
- **Don't relay content through context.** When the user wants to *see*
  something, reference the file path. When I need to *reason* about it, pull
  only what I need. Don't print long content to stdout — it burns context.
- **Trust writes.** After `Write` or `Edit` reports success, don't re-read
  the file to verify. Use `grep` to confirm a specific change landed if
  necessary.
- **Batch shell calls.** One `bash` call with `&&` and pipes beats N separate
  calls — every round-trip carries overhead on top of its output.
- **Silence noisy tools.** Prefer `pip --quiet`, `npm --silent`, `git -q`,
  `curl -sS`. Suppress progress bars and install chatter. Use `2>/dev/null`
  selectively, not as a blanket default — stderr often carries real errors.
- **Query, don't dump.** `grep -c` instead of `grep`. `wc -l` instead of
  `cat`. `jq '.field'` instead of pretty-printed JSON. Full `cat` / `Read`
  is a last resort.
- **Don't regenerate what exists.** `cp` or reference existing files. Never
  retype a known file into a `Write` body or heredoc.
- **One search, not five.** Don't re-query when the first result suffices.
  Paraphrase results instead of re-quoting them.
- **Search with qmd first.**
  Before reading any file, grepping for code, or exploring directories (`ls`, `find`), use the `qmd` MCP tools:
  `query` for semantic or multi-concept questions,
  `get` for retrieving a specific file by path,
  `multi_get` for batch retrieval by glob.
  Indexed collections: `lbg-pipelines`, `claude`, `txpipe`, `ceci`, `rail`.
  Fall back to `Read`, `Bash(grep*)`, or `Bash(ls/find)` only when qmd returns insufficient results or the file isn't indexed.
  For installation, collection management, and MCP registration: invoke `/qmd`.

## Dotfiles-managed configuration

Symlinks: `~/.claude/{CLAUDE.md,settings.json,skills/}` → `~/.dotfiles/claude/`.
New files under `~/.claude/`: put in dotfiles if it's a skill or persistent preference; leave in `~/.claude/` for credentials, cache, and session data.
`~/.claude.json` is NOT in dotfiles — volatile state; re-run `claude mcp add` on each new machine.

## Gotchas I keep stepping in

### qmd: hyphens in `vec`/`hyde` queries trigger negation parser

Any hyphenated word in a `vec`/`hyde` query is rejected — the parser reads `-word` as "exclude term."
Fix: rephrase without hyphens for `vec`/`hyde` (`"photo z"` not `"photo-z"`); for `lex`, wrap in quotes (`"photo-z"`).
