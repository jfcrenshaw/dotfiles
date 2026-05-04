---
name: qmd
description: How to install, configure, and manage the qmd local search MCP server. Covers Node.js installation, npm install of @tobilu/qmd, registering with claude mcp add, adding and re-indexing collections with qmd collection add / qmd update / qmd embed, and diagnosing MCP server registration issues. Use this skill whenever setting up qmd on a new machine, adding a new qmd collection, re-indexing after file changes, or debugging why qmd tools are not appearing in a session.
---

# qmd — local search MCP server

qmd is installed at `~/.local/bin/qmd` (v2.1.0 as of 2026-05).
Node.js is installed as a standalone tarball at `~/.local/node-v25.9.0-linux-x64/`
with `node`/`npm`/`npx` symlinked into `~/.local/bin/`.
The index lives at `~/.cache/qmd/index.sqlite` (local to each machine — not in dotfiles).

## How Claude Code MCP servers actually work

Two completely separate config locations:

| Server type | Where registered | Who writes it |
|---|---|---|
| Local stdio (e.g. qmd) | Top-level `mcpServers` key in `~/.claude.json` | `claude mcp add --scope user` |
| Remote claude.ai connectors (Google Drive, Slack, etc.) | Provisioned by claude.ai at login | claude.ai account sync |

**Critical gotcha:** `~/.claude/settings.json` does NOT register local MCP servers —
the `mcpServers` key there is ignored by Claude Code.
Local servers must be registered via `claude mcp add`, which writes to `~/.claude.json`.

**Verifying registration:** `claude mcp list` shows all registered servers and their connection status.
If a local server shows as connected there but the `mcp__*` tools are still absent from a running session, restart the session — tools are discovered at startup.

**Permissions** for MCP tool calls are controlled by `permissions.allow` in `~/.claude/settings.json` (that part works correctly).

## MCP tools

| Tool | Use |
|---|---|
| `mcp__qmd__query` | Hybrid BM25 + semantic search with reranking — best for most questions |
| `mcp__qmd__get` | Retrieve a single file by path (`qmd://collection/rel/path`) |
| `mcp__qmd__multi_get` | Batch fetch by glob or comma-separated paths |
| `mcp__qmd__status` | Show indexed collections and document counts |

## Collection management

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

## Currently indexed collections

| Collection | Path | Mask |
|---|---|---|
| `lbg-pipelines` | `/global/cfs/cdirs/desc-wl/LBG/users/jfc20/lbg-pipelines` | `**/*.{md,py,yml,yaml,sh}` |
| `claude` | `~/.dotfiles/claude` | `**/*.{md,json}` |
| `txpipe` | `/global/common/software/m1727/groups/WLSS/LBG/lbg-env/submodules/txpipe` | `**/*.{py,md}` |
| `ceci` | `/global/common/software/m1727/groups/WLSS/LBG/lbg-env/miniforge/envs/lbg-python-v1.0.0/lib/python3.12/site-packages/ceci` | `**/*.{py,md}` |
| `rail` | `/global/common/software/m1727/groups/WLSS/LBG/lbg-env/miniforge/envs/lbg-python-v1.0.0/lib/python3.12/site-packages/rail` | `**/*.{py,md}` |

## Adding qmd to a new machine

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

## Adding other local MCP servers to a new machine

Any local stdio MCP server must be registered with `claude mcp add` — not by editing `settings.json`.
The general pattern:

```bash
claude mcp add --scope user <name> -- <command> [args...]
# e.g. with env vars:
claude mcp add --scope user <name> -e KEY=value -- <command> [args...]
```

Use `--scope project` instead of `--scope user` to restrict the server to one repo.

## Dotfiles-managed configuration

The following `~/.claude/` paths are symlinks into `~/.dotfiles/claude/`:
- `CLAUDE.md`
- `settings.json`
- `skills/`

When writing a new file under `~/.claude/`, decide:
- **Belongs in dotfiles** (new skill, persistent global preference): add it to `~/.dotfiles/claude/` and register a symlink entry in `dotbot_config.yaml`.
- **Does not belong** (credentials, cache, session data, project memory): leave it in `~/.claude/` as a regular file.

**`~/.claude.json` is NOT in dotfiles** — it's a volatile state file (session caches, startup counts, per-project trust state).
It also holds the top-level `mcpServers` key where local MCP servers are registered.
Do not add it to dotfiles; re-run `claude mcp add` on each new machine instead.
