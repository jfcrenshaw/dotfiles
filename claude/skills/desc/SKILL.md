---
name: desc
description: Ecosystem-level guide to the DESC (Dark Energy Science Collaboration) Python stack. Covers which tools exist, how they fit together, and general DESC coding conventions. For deep dives into specific packages, use the dedicated skills. Use this skill when orienting to DESC, choosing which tools to use, or asking about cross-package patterns and conventions.
---

# LSST DESC Python ecosystem

You're helping a user write DESC science code.
DESC (Dark Energy Science Collaboration) is the primary LSST weak-lensing / large-scale-structure science collaboration.
Most work happens at NERSC (see the `nersc` skill for cluster conventions); this skill focuses on the DESC software stack itself.

For package-specific work, invoke the dedicated skill.

---

## Package skills

| Package | Purpose | Skill |
|---|---|---|
| `ceci` | Pipeline framework: stage definition, YAML pipelines, MPI, file I/O | `/ceci` |
| `TXPipe` | Main DESC 3×2pt pipeline: selection → maps → 2pt → covariance → theory | `/txpipe` |
| `RAIL` | Photo-z framework: creation (catalog simulation), estimation, evaluation | `/rail` |

---

## How the packages fit together

TXPipe and RAIL are both built on top of ceci — all their stages are ceci `PipelineStage` subclasses.
RAIL extends ceci with a `DataStore`/`DataHandle` pattern for managing in-memory data across stages.
TXPipe uses RAIL stages for its photo-z steps (`PZEstimatorLens/Source`, `PZRailSummarizeLens/Source`).

A typical DESC analysis pipeline flows: truth simulation → RAIL creation (degrade photometry) → RAIL estimation (photo-z) → TXPipe (2pt statistics).

---

## General DESC coding conventions

- DESC packages are Python 3; most require Python ≥ 3.9.
- Prefer the official DESC I/O helpers over rolling your own FITS/HDF5 reads — they handle unit conventions and multi-file layouts correctly.
- When in doubt about units, check the package docs: DESC packages are not always consistent with each other on angular units (radians vs arcmin vs degrees).
- For catalog-scale work (millions of objects), use `numpy` / `fitsio` / `h5py` over `astropy` table reads — they're dramatically faster on NERSC Lustre.
- DESC repos live on GitHub under the `LSSTDESC` organization: <https://github.com/LSSTDESC>.
