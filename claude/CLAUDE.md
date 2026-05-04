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

The following `~/.claude/` paths are symlinks into `~/.dotfiles/claude/`:
- `CLAUDE.md` (this file)
- `settings.json`
- `skills/`

When writing a new file under `~/.claude/`, decide:
- **Belongs in dotfiles** (new skill, persistent global preference): add it to
  `~/.dotfiles/claude/` and register a symlink entry in `dotbot_config.yaml`.
- **Does not belong** (credentials, cache, session data, project memory): leave
  it in `~/.claude/` as a regular file.

**`~/.claude.json` is NOT in dotfiles** — it's a volatile state file (session
caches, startup counts, per-project trust state).
It also holds the top-level `mcpServers` key where local MCP servers are
registered (see below).
Do not add it to dotfiles; re-run `claude mcp add` on each new machine instead.

## qmd — local search MCP server

**Always use qmd first when looking for code, config, or docs.**
Reach for `Read`, `grep`, or `find` only when qmd returns insufficient results or the target file is not yet indexed.

qmd is installed at `~/.local/bin/qmd` (v2.1.0 as of 2026-05).
Node.js is installed as a standalone tarball at `~/.local/node-v25.9.0-linux-x64/`
with `node`/`npm`/`npx` symlinked into `~/.local/bin/`.
The index lives at `~/.cache/qmd/index.sqlite` (local to each machine — not in dotfiles).

### How Claude Code MCP servers actually work

**Two completely separate config locations:**

| Server type | Where registered | Who writes it |
|---|---|---|
| Local stdio (e.g. qmd) | Top-level `mcpServers` key in `~/.claude.json` | `claude mcp add --scope user` |
| Remote claude.ai connectors (Google Drive, Slack, etc.) | Provisioned by claude.ai at login | claude.ai account sync |

**Critical gotcha:** `~/.claude/settings.json` does NOT register local MCP servers —
the `mcpServers` key there is ignored by Claude Code.
Local servers must be registered via `claude mcp add`, which writes to `~/.claude.json`.

**Verifying registration:** `claude mcp list` shows all registered servers and their
connection status.
If a local server shows as connected there but the `mcp__*` tools are still absent
from a running session, restart the session — tools are discovered at startup.

**Permissions** for MCP tool calls are still controlled by `permissions.allow` in
`~/.claude/settings.json` (that part works correctly).

### MCP tools (all auto-allowed in settings.json)

| Tool | Use |
|---|---|
| `mcp__qmd__query` | Hybrid BM25 + semantic search with reranking — best for most questions |
| `mcp__qmd__get` | Retrieve a single file by path (`qmd://collection/rel/path`) |
| `mcp__qmd__multi_get` | Batch fetch by glob or comma-separated paths |
| `mcp__qmd__status` | Show indexed collections and document counts |

### Collection management

```bash
# Add a new collection (--mask controls which files are indexed)
qmd collection add /path/to/dir --name myname --mask "**/*.{md,py,yml,yaml,sh}"

# Re-index after file changes
qmd update              # re-scans all collections
qmd embed               # regenerates vectors (downloads model on first run, ~334 MB)

# Add human-readable context so searches rank better
qmd context add qmd://myname/ "One-sentence description of what this collection contains."

# Inspect / remove
qmd collection list
qmd collection show myname
qmd collection remove myname
qmd status
```

**Important gotchas:**
- Default `--mask` is `**/*.md` only — always pass `--mask` for code repos.
- `qmd collection add <path>` (no `--name`) uses the directory basename as the collection name.
- After adding or updating files, run `qmd embed` to regenerate vectors; text search works immediately but vector/semantic search needs the embed step.
- The glob syntax uses `{a,b}` brace expansion, e.g. `**/*.{py,yml}`.
- `qmd embed` uses the GPU if CUDA is available (A100 on NERSC — fast).

### Adding qmd to a new machine

```bash
# 1. Install Node.js (standalone tarball — no module system needed on NERSC)
curl -fSL "https://nodejs.org/dist/v25.9.0/node-v25.9.0-linux-x64.tar.gz" -o /tmp/node.tar.gz
tar -xf /tmp/node.tar.gz -C ~/.local/
ln -sf ~/.local/node-v25.9.0-linux-x64/bin/{node,npm,npx} ~/.local/bin/
rm /tmp/node.tar.gz

# 2. Install qmd (use lbg-env Python for node-gyp to avoid Python 3.6 system default)
npm_config_python=/global/common/software/m1727/groups/WLSS/LBG/lbg-env/miniforge/envs/lbg-python-v1.0.0/bin/python3 \
  npm install -g --prefix="$HOME/.local" @tobilu/qmd

# 3. Register qmd as a Claude Code MCP server (writes to ~/.claude.json — NOT in dotfiles)
claude mcp add --scope user qmd -- /bin/sh -c 'exec "$HOME/.local/bin/qmd" mcp'

# 4. Re-add collections (index is not in dotfiles — must be rebuilt per machine)
qmd collection add /path/to/repo --name name --mask "**/*.{md,py,yml,yaml,sh}"
qmd context add qmd://name/ "Description."
qmd embed
```

On **Mac**: step 1 is not needed (homebrew node is fine); step 2 is just
`npm install -g --prefix="$HOME/.local" @tobilu/qmd` with no `npm_config_python` override.

### Adding other local MCP servers to a new machine

Any local stdio MCP server must be registered with `claude mcp add` — not by
editing `settings.json`.
The general pattern:

```bash
claude mcp add --scope user <name> -- <command> [args...]
# e.g. with env vars:
claude mcp add --scope user <name> -e KEY=value -- <command> [args...]
```

Use `--scope project` instead of `--scope user` to restrict the server to one repo.

### Currently indexed collections

| Collection | Path | Mask |
|---|---|---|
| `lbg-pipelines` | `/global/cfs/cdirs/desc-wl/LBG/users/jfc20/lbg-pipelines` | `**/*.{md,py,yml,yaml,sh}` |
| `claude` | `~/.dotfiles/claude` | `**/*.{md,json}` |
| `txpipe` | `/global/common/software/m1727/groups/WLSS/LBG/lbg-env/submodules/txpipe` | `**/*.{py,md}` |
| `ceci` | `/global/common/software/m1727/groups/WLSS/LBG/lbg-env/miniforge/envs/lbg-python-v1.0.0/lib/python3.12/site-packages/ceci` | `**/*.{py,md}` |
| `rail` | `/global/common/software/m1727/groups/WLSS/LBG/lbg-env/miniforge/envs/lbg-python-v1.0.0/lib/python3.12/site-packages/rail` | `**/*.{py,md}` |

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