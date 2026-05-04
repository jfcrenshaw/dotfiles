# User-level Claude Code guidance for `jfc20` at NERSC

## Environment
- **User**: jfc20 — postdoctoral fellow at Stanford University and SLAC National Lab.
  Groups: `m1727`, `lsst`.
- **System**: NERSC Perlmutter (`$NERSC_HOST=perlmutter`). Login nodes are
  `login*`; compute nodes are `nidNNNNNN`. Claude sessions can run on either.
- **How to tell**: `hostname` (`*login*` = login node) and `$SLURM_JOB_ID`
  (set → inside an allocation). The skill ships `where_am_i.sh`.
- **Scheduler**: Slurm. Don't run compute on login nodes; `salloc`/`sbatch`.
- **Software**: Cray modules (`module avail`, `module load X`).
- **Docs**: <https://docs.nersc.gov> · IRIS: <https://iris.nersc.gov> ·
  JupyterHub: <https://jupyter.nersc.gov> · Status:
  <https://www.nersc.gov/live-status/motd/>

## Repos / accounts

| Repo  | For | Default? |
|---|---|---|
| `m1727`   | CPU jobs                    | yes |
| `m1727_g` | GPU jobs                    | (must pass `-A`) |

## Filesystems — your personal layout

| Path | Var | Use |
|---|---|---|
| `/global/homes/<l>/jfc20` | `$HOME` | Code, dotfiles, venvs (40 GB / 1M inodes) |
| `/pscratch/sd/<l>/jfc20`  | `$PSCRATCH` / `$SCRATCH` | Big I/O, intermediates. Purged on inactivity (~8 wk) |
| `/global/cfs/cdirs/<<PROJECT>>/users/jfc20` | — | Persistent project-shared output area |
| `/global/common/software/<<PROJECT>>/envs/<<NAME>>` | — | Shared conda/venv envs (fast import) |
| `$TMPDIR` (per-job) | `$TMPDIR` | Per-node ephemeral |

Rule of thumb: **inputs from CFS, big I/O on `$PSCRATCH`, code in `$HOME`,
keepers in `$DESI_ROOT/users/$USER` or `$CFS/<project>/users/$USER`.**

## Conventions / preferences

- **Python docstrings**: always use NumPy style.
- **Markdown and LaTeX**: one sentence per line — never wrap a sentence across
  multiple lines, and never put two sentences on the same line.

## Job-script defaults

```bash
#SBATCH -A <<REPO_CPU>>
#SBATCH -C cpu
#SBATCH -q regular
#SBATCH -t 4:00:00
#SBATCH -N 1
#SBATCH -c 128
#SBATCH --mem=0
#SBATCH -o logs/slurm-%j.out
#SBATCH -e logs/slurm-%j.err
#SBATCH --open-mode=append
```

## Working norms

- **Durable knowledge**: when I learn repo-specific workflow or preference
  information, add it to that repo's `AGENTS.md`. If a preference likely
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
  Fall back to `Read`, `Bash(grep*)`, or `Bash(ls/find)` only when qmd returns insufficient results or the file is not yet indexed.
- **When in doubt, ask.** One clarifying turn can save many context-heavy ones.

## Dotfiles-managed configuration

Symlinks: `~/.claude/{CLAUDE.md,settings.json,skills/}` → `~/.dotfiles/claude/`.
New files under `~/.claude/`: put in dotfiles if it's a skill or persistent preference; leave in `~/.claude/` for credentials, cache, and session data.
`~/.claude.json` is NOT in dotfiles — volatile state; re-run `claude mcp add` on each new machine.

## qmd — local search MCP server

**Always use qmd first** — before Read, grep, or ls/find.
Fall back only when qmd returns insufficient results or the file isn't indexed.

| Tool | Use |
|---|---|
| `mcp__qmd__query` | Hybrid BM25 + semantic search — best for most questions |
| `mcp__qmd__get` | Single file by path (`qmd://collection/rel/path`) |
| `mcp__qmd__multi_get` | Batch fetch by glob or comma-separated paths |
| `mcp__qmd__status` | Show indexed collections and doc counts |

Indexed collections: `lbg-pipelines`, `claude`, `txpipe`, `ceci`, `rail`.
For installation, collection management, and MCP registration details: invoke `/qmd`.

## Gotchas I keep stepping in

### qmd: hyphens in `vec`/`hyde` queries trigger negation parser

The qmd `vec` and `hyde` search types use a query parser that interprets `-word`
as "exclude this term."
Any hyphenated word (e.g. `lbg-pipelines`, `mock-desi`) in a `vec` or `hyde`
query will be rejected with:

> Structured search (vec): Negation (-term) is not supported in vec/hyde queries.

Fixes:
- **`vec`/`hyde`**: rephrase without the hyphen (e.g. "photo redshift" instead of
  "photo-z"). Semantic search preserves meaning so the exact term isn't needed.
- **`lex`**: wrap the hyphenated term in quotes (`"photo-z"`, `"lbg-pipelines"`)
  so the parser treats it as an exact phrase rather than negation.

Negation (`-term`) is only valid in `lex` queries, and only outside quotes.