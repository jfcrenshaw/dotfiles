# git and GitHub at NERSC

Cluster-side `git` is a high-leverage place to use Claude — many DESC/cosmology users only `git` on their laptops, but the cluster has the actual data, the actual environment, and far more compute. This file covers the setup and patterns.

## One-time setup

```bash
# GitHub CLI (may not be in default modules; install via conda if not):
gh --version || conda install -n base -c conda-forge gh

gh auth login                        # device-flow OAuth in browser
git config --global user.name  "Your Name"
git config --global user.email "you@..."
git config --global pull.rebase true
git config --global init.defaultBranch main

# SSH key for git push (the gh CLI handles HTTPS auth, but pushes go faster over SSH):
ssh-keygen -t ed25519 -C "nersc-$USER"
# paste ~/.ssh/id_ed25519.pub at https://github.com/settings/keys
ssh -T git@github.com
```

## Patterns that work well on the cluster

- **`gh pr checkout <N>`** — pull a teammate's branch and run it against real data. Closer to production than a laptop reproducer.
- **Long edit/test loops in tmux on a login node** survive SSH dropouts. (Note: tmux on login nodes is allowed; tmux on compute nodes is fine inside an `salloc` but dies with the allocation.)
- **`gh pr create --draft`** for in-progress work — keeps CI running and gives teammates something to look at.
- **`gh run watch`** to follow a CI run from the terminal instead of the GitHub UI.

## Compute-node networking

Compute nodes have **no outbound internet by default**. Implications:
- `git clone https://...` from inside a job will fail. Clone from the login node.
- `gh` API calls from a job will fail. Run them from the login node.
- A job that imports a package from PyPI on first run will fail. Pre-stage the env.

If you genuinely need network from compute, NERSC documents per-job proxies; in practice, pre-stage everything from login.

## Confirmations expected

These actions affect shared state and Claude should confirm before running, even when you're moving fast:

- `git push --force` / `--force-with-lease`
- `git push` to `main`/`master`/release branches
- `gh pr merge`, `gh pr close`
- `gh release create`
- Any `git reset --hard` in a non-throwaway worktree
- `git rebase -i` rewrites of published history

For ordinary commits, branch creates, fetches, and PR drafts: just go.


Mind the `PYTHONPATH` gotcha — the same prepend that helps you here will silently break unrelated envs later.
