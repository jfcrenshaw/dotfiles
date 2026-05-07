---
name: desi
description: Covers the DESI spectroscopic survey — data products, environment variables, production releases (mountain names), data layout under $DESI_SPECTRO_REDUX, Python I/O with desispec, and DESI-specific compute conventions. Most DESI runtime tools (desimodules, desispec, redrock, $SPECPROD, $DESI_ROOT) require NERSC; combine with the nersc skill for job submission and cluster setup. Use this skill whenever working with DESI data or code, importing desispec/redrock/fiberassign, setting $SPECPROD, reading DESI catalogs or spectra, or asking about DESI survey data products.
---

# DESI spectroscopic survey

DESI is a DOE spectroscopic survey instrument at KPNO; the data and software infrastructure lives at NERSC.
**Runtime tools (`desimodules`, `desispec`, `redrock`, etc.) require NERSC** — for job submission and cluster setup invoke `/nersc`.
Conceptual questions, data layout, and Python I/O patterns work anywhere.

## Loading the software stack (NERSC only)

```bash
module load desimodules/master       # rolling, current pipeline tools
# or pin a release to match the SPECPROD you're analysing:
module load desimodules/24.4
```

`desimodules` sets up `desispec`, `desisim`, `redrock`, `fiberassign`, `desisurvey`, `specter`, `gpu_specter`, `simqso`, `speclite`, `prospect`, `desimeter`, plus all `DESI_*` env vars.

## Key environment variables

| Var | Value / meaning |
|---|---|
| `DESI_ROOT` | `/global/cfs/cdirs/desi` |
| `DESI_SPECTRO_DATA` | Raw nightly data, `NIGHT/EXPID/...` |
| `DESI_SPECTRO_REDUX` | One subdir per `SPECPROD` |
| `DESI_TARGET` | Targeting / fiberassign inputs |
| `DESI_SURVEYOPS` | Survey ops trunk |
| `SPECPROD` | Current production label — **set per task** |

```bash
export SPECPROD=matterhorn     # internal frontier (2026-04)
export SPECPROD=loa            # public DR2
```

## Productions ("mountain releases")

| Release | Public | Notes |
|---|---|---|
| `daily` | — | Rolling pipeline output, never frozen |
| `fuji` | EDR | Early Data Release |
| `guadalupe` | DR1 | |
| `himalayas` | (internal) | Frozen, never went public |
| `iron` | DR1 | |
| `jura` | (internal) | Frozen, never went public |
| `kibo` | DR2 | |
| `loa` | DR2 | |
| `matterhorn` | (current internal) | Active as of 2026-04 |

**Verify before citing** — releases get promoted and the frontier moves.
At NERSC: `scripts/desi_prods.sh` (bundled with this skill) identifies the current frontier from live symlinks.

## Data layout under `$DESI_SPECTRO_REDUX/<SPECPROD>/`

- `exposures/NIGHT/EXPID/` — frame, sframe, cframe, sky, fiberflat per exposure.
- `tiles/cumulative/TILEID/LASTNIGHT/` — coadded spectra and redshifts per tile (most commonly used).
- `tiles/pernight/TILEID/NIGHT/` — per-night summaries.
- `healpix/<survey>/<program>/<hp//100>/<hp>/` — healpix-coadded spectra; better for sample-level work crossing tile boundaries.
- `zcatalog/` — concatenated redshift catalogs across tiles/healpix.
- Top-level indices: `tilepix.fits`, `exposures-<SPECPROD>.fits`, `tiles-<SPECPROD>.fits`.

Authoritative HDU/column/bitmask reference: <https://desidatamodel.readthedocs.io/en/latest/>

## Reading DESI files in Python

```python
import desispec.io as dio

spectra = dio.read_spectra("coadd-TILEID-thru20240101.fits")
zbest   = dio.read_zbest("redrock-TILEID-thru20240101.fits")
frame   = dio.read_frame("frame-b0-00012345.fits")
```

`desispec.io` handles the multi-arm (B/R/Z) coadd structure, mask propagation, and resolution-matrix sparse storage.
For large zcatalog tables, prefer `fitsio` over `astropy.io.fits` — significantly faster on Lustre.

## Output conventions

- **Sims and intermediate I/O**: `$PSCRATCH/desi/<project>/...` — big budget, will be purged.
- **Outputs to keep**: `$DESI_ROOT/users/$USER/...` — persistent, group-writable; don't park TBs without coordinating with ops.
- **Collaboration catalogs**: use the formal VAC submission process.

## Compute repos and GPU tools (NERSC)

- `desi` — CPU jobs. `desi_g` — GPU jobs (required for `gpu_specter`, `redrock` GPU mode).
- `gpu_specter` replaces CPU `specter` for spectral extraction; activated automatically in production scripts on `-C gpu` nodes.
- `redrock` has a CUDA backend (~5–10× speedup). Use `desi_zproc --gpu`.

## Useful entry points

- `desi_proc_dashboard` — pipeline status across recent nights.
- `desi_zcatalog` — build/inspect concatenated zcatalogs.
- `desi_quicklook` — fast on-the-fly QA.
- `prospect_pages` — HTML viewers for Redrock fits.

## Deep reference

Full loading instructions, env vars, productions table, file layout details, Python I/O patterns, GPU pipeline, and output conventions: [`references/desi-at-nersc.md`](references/desi-at-nersc.md)

## Links

- Data model: <https://desidatamodel.readthedocs.io/en/latest/>
- Software repos: <https://github.com/desihub>
- Public data: <https://data.desi.lbl.gov/>
- Allocation hours: <https://iris.nersc.gov> (repos `desi` / `desi_g`)
