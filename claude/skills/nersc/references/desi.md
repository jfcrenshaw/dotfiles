# DESI at NERSC

DESI is a primary user community at NERSC; the `desi` and `desi_g` repos and the `/global/cfs/cdirs/desi` filesystem are dedicated to it. This file collects the conventions someone returning to DESI work after some time away will want.

## Loading the stack

```bash
module load desimodules/master       # rolling, current pipeline tools
# or pin a release:
module load desimodules/24.4         # example tag — match the SPECPROD you're analysing
```

`desimodules` sets up `desispec`, `desisim`, `redrock`, `fiberassign`, `desisurvey`, `specter`, `gpu_specter`, `simqso`, `speclite`, `prospect`, `desimeter`, plus all the `DESI_*` env vars. After loading, `which desi_quicklook` etc. should resolve.

## Authoritative env vars (set by desimodules)

| Var | Meaning |
|---|---|
| `DESI_ROOT` | `/global/cfs/cdirs/desi` |
| `DESI_SPECTRO_DATA` | Raw nightly data, `NIGHT/EXPID/...` |
| `DESI_SPECTRO_REDUX` | One subdir per `SPECPROD` |
| `DESI_SPECTRO_SIM` | Sim outputs |
| `DESI_TARGET` | Targeting / fiberassign inputs |
| `DESI_SURVEYOPS` | Survey ops trunk |
| `DESIMODEL` | Instrument model data |
| `RR_TEMPLATE_DIR` | Redrock template directory |
| `SPECPROD` | Current production label — set per task |

## Productions ("mountain releases")

DESI internal data releases are named after mountains in alphabetical order:

| Release | Public release | Notes |
|---|---|---|
| `daily` | — | Rolling pipeline output, never frozen |
| `fuji` | **EDR** | Early Data Release |
| `guadalupe` | **DR1** | |
| `himalayas` | (internal only) | Frozen, never went public |
| `iron` | **DR1** | |
| `jura` | (internal only) | Frozen, never went public |
| `kibo` | **DR2** | |
| `loa` | **DR2** | |
| `matterhorn` | (current internal) | Active reduction as of 2026-04 |

(Snapshot 2026-04. The map shifts as releases are promoted; `scripts/desi_prods.sh` is the live check — it identifies which mountain dirs are symlinks into `$DESI_ROOT/public/dr*` vs. live internal.)

Verify with `scripts/desi_prods.sh` before citing any of this — releases get promoted, and the "current" frontier moves.

Set `SPECPROD` per task rather than relying on shell defaults:

```bash
export SPECPROD=matterhorn
# or for analyzing public DR2:
export SPECPROD=loa
```

Public releases live under `$DESI_ROOT/public/<release>/` and are what you point external collaborators at.

## Layout under `$DESI_SPECTRO_REDUX/<SPECPROD>/`

- `exposures/NIGHT/EXPID/` — frame, sframe, cframe, sky, fiberflat per exposure.
- `tiles/cumulative/TILEID/LASTNIGHT/` — coadded spectra and redshifts per tile.
  - `coadd-{B,R,Z}-TILEID-thru<NIGHT>.fits` — per-arm coadds.
  - `coadd-TILEID-thru<NIGHT>.fits` — joined (multi-arm) coadds.
  - `redrock-TILEID-thru<NIGHT>.fits` — Redrock classifications + redshifts.
  - `rrdetails-...h5` — per-target chi² scans.
- `tiles/pernight/TILEID/NIGHT/` — per-night tile summaries (less commonly used than `cumulative`).
- `healpix/<survey>/<program>/<hp//100>/<hp>/` — healpix-coadded spectra. Better for sample-level work that crosses tile boundaries.
- `zcatalog/` — concatenated redshift catalogs across tiles/healpix.
- `tilepix.fits`, `exposures-<SPECPROD>.fits`, `tiles-<SPECPROD>.fits` — top-level indices.

The **DESI data model** at <https://desidatamodel.readthedocs.io/en/latest/> is the canonical reference for HDU/column names, units, and bitmasks. Use it before guessing.

## Reading DESI files in Python

```python
import desispec.io as dio
spectra = dio.read_spectra("coadd-TILEID-thru20240101.fits")
zbest   = dio.read_zbest("redrock-TILEID-thru20240101.fits")
frame   = dio.read_frame("frame-b0-00012345.fits")
```

`desispec.io` handles:
- The multi-arm (B/R/Z) coadd structure (separate wavelength grids).
- Mask propagation.
- Resolution-matrix sparse storage.

For raw FITS access prefer `fitsio` (already in the stack) over `astropy.io.fits` — significantly faster on big tables that are common in zcatalog work.

## Output conventions

- **Sims and intermediate I/O:** `$PSCRATCH/desi/<your-project>/...`. Big I/O budget, will be purged so don't park keepers here.
- **Outputs you want to keep:** `$DESI_ROOT/users/$USER/...`. Group-writable, persistent. Don't put TBs there without coordinating with the DESI ops team.
- **Catalogs you intend to share with the collaboration:** use the formal VAC submission process, not your user dir.

## Compute repos

- `desi` — CPU jobs against the DESI allocation.
- `desi_g` — GPU jobs (e.g. `gpu_specter`, `redrock` GPU mode). The `_g` suffix is required for GPU work.

Charge factors and remaining hours are at <https://iris.nersc.gov> under the `desi`/`desi_g` repos.

## GPU pipeline tools

- **`gpu_specter`** — GPU spectral extraction. Replaces CPU `specter` for the extraction step in the standard pipeline. Activated automatically by the production scripts when run on `-C gpu` nodes.
- **`redrock`** — has a CUDA backend for template-fitting. ~5–10× speedup typical. `desi_zproc --gpu` etc.

When running a pipeline step on GPU, request the standard 4-GPU node and let the tool decide concurrency:

```bash
salloc -N 1 -C gpu --gpus-per-node=4 -c 32 -t 2:00:00 -A desi_g -q gpu_interactive
```

## Useful entry points

- `desi_proc_dashboard` — pipeline status across recent nights.
- `desi_zcatalog` — build/inspect concatenated zcatalogs.
- `desi_quicklook` — fast on-the-fly QA.
- `prospect_pages` — generate HTML viewers for Redrock fits.

## DESI links

- Data model: <https://desidatamodel.readthedocs.io/en/latest/>
- DESI software (collab GitHub): <https://github.com/desihub>
- DESI public data: <https://data.desi.lbl.gov/>  (requires DESI account for non-public)
- Survey ops Slack and #desi-data: collaboration-internal
