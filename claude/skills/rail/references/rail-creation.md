# RAIL creation module — catalog simulation pipeline

The `rail.creation` module forward-models a realistic photometric catalog from a truth simulation.
The typical pipeline for the DESC weak-lensing use case is:

```
truth catalog (Parquet/HDF5)
  → column pre-selection      (QuantityCut)
  → Galactic reddening        (Reddener — SFD lookup via dustmaps)
  → photometric errors        (LSSTErrorModel  or  ObsCondition with m5/depth maps)
  → de-reddening              (Dereddener — same SFD lookup, subtracts instead of adds)
  → quality / SNR cuts        (QuantityCut)
  → spec-survey selection     (SpecSelection_DESI_Phy / SpecSelection_DESI_LRG / etc.)
  → photo-z estimation        (CatInformer → CatEstimator → CatSummarizer)
```

All stages are `RailStage` (ceci `PipelineStage`) subclasses. See [`rail-core-concepts.md`](rail-core-concepts.md) for the framework.

---

## Contents

- [Stage reference](#stage-reference)
  - [1. Column pre-selection — QuantityCut](#1-column-pre-selection--quantitycut)
  - [2. Galactic dust reddening — Reddener](#2-galactic-dust-reddening--reddener)
  - [3. Photometric errors](#3-photometric-errors)
  - [4. De-reddening — Dereddener](#4-de-reddening--dereddener)
  - [5. Quality / SNR cuts — QuantityCut (second pass)](#5-quality--snr-cuts--quantitycut-second-pass)
  - [6. Spectroscopic selection](#6-spectroscopic-selection)
- [Column naming conventions](#column-naming-conventions)
- [Other useful creation stages](#other-useful-creation-stages)
- [Full pipeline YAML skeleton](#full-pipeline-yaml-skeleton)
- [Gotchas](#gotchas)

---

## Stage reference

### 1. Column pre-selection — `QuantityCut`

**Module:** `rail.creation.degraders.quantity_cuts.QuantityCut`
**Base class:** `Selector` (removes rows; output ≤ input size)

Applies upper-bound magnitude/redshift cuts before degradation. Run this first to trim the truth catalog to the regime you care about.

```yaml
QuantityCut:
  cuts:
    redshift: 3.5        # keep redshift < 3.5
    mag_i_lsst: 26.5     # keep mag_i_lsst < 26.5
  seed: 42
  output_mode: default
```

`cuts` values are **upper bounds** (strict `<`). For a lower bound or a range you need a custom stage or two chained `QuantityCut` instances.
Required input columns: whatever keys appear in `cuts`.

---

### 2. Galactic dust reddening — `Reddener`

**Module:** `rail.tools.photometry_tools.Reddener`
**Package:** `rail_astro_tools`
**Base class:** `DustMapBase` → `RailStage`

Queries the SFD dust map at each galaxy's (ra, dec) using `dustmaps.sfd.SFDQuery`, then adds A_λ = `band_a_env[col]` × E(B-V) to each magnitude column.
Requires the SFD map files to be present on disk at `dustmap_dir` (download once via the `dustmaps` package).

```yaml
Reddener:
  ra_name: ra
  dec_name: dec
  dustmap_name: sfd
  dustmap_dir: /path/to/dustmaps    # required; directory containing SFD .fits files
  band_a_env:                        # Schlafly & Finkbeiner 2011 R_λ for LSST
    mag_u_lsst: 4.145
    mag_g_lsst: 3.237
    mag_r_lsst: 2.273
    mag_i_lsst: 1.684
    mag_z_lsst: 1.323
    mag_y_lsst: 1.088
  copy_all_cols: true               # pass all other columns through unchanged
```

`band_a_env` maps **magnitude column names** to their A_λ/E(B-V) ratio (R_λ).
The stage does not add an EBV column — it directly modifies the magnitude columns in place.

---

### 3. Photometric errors

Two complementary approaches; often both are useful:

#### 3a. `LSSTErrorModel` and friends (simple, non-spatial)

**Module:** `rail.creation.degraders.photometric_errors`
**Base class:** `PhotoErrorModel(Noisifier)` — thin wrapper around the `photerr` package

Applies magnitude-dependent Gaussian noise; does not vary spatially.
All models use identical config patterns — only the class name changes for the survey.

| Class | Survey / tier |
|---|---|
| `LSSTErrorModel` | LSST (Ivezić et al. 2019; Crenshaw et al. 2024) |
| `RomanErrorModel` | Roman (baseline) |
| `RomanWideErrorModel` | Roman wide tier |
| `RomanMediumErrorModel` | Roman medium tier |
| `RomanDeepErrorModel` | Roman deep tier |
| `RomanUltraDeepErrorModel` | Roman ultra-deep tier |
| `EuclidErrorModel` | Euclid (baseline) |
| `EuclidWideErrorModel` | Euclid wide tier |
| `EuclidDeepErrorModel` | Euclid deep tier |

Use `LSSTErrorModel` when you want fast, simple errors or when spatial variation is handled separately.

```yaml
LSSTErrorModel:
  bands: [u, g, r, i, z, y]
  err_bands:
    - mag_err_u_lsst
    - mag_err_g_lsst
    - mag_err_r_lsst
    - mag_err_i_lsst
    - mag_err_z_lsst
    - mag_err_y_lsst
  output_mode: default
  seed: 42
```

Objects fainter than the 5σ limiting magnitude are set to `NaN` (non-detection). Downstream `QuantityCut` stages must handle NaN before applying magnitude cuts.

#### 3b. `ObsCondition` — spatially varying depth (alternative / complement)

**Module:** `rail.creation.degraders.observing_condition_degrader.ObsCondition`
**Package:** `rail_astro_tools`

Applies spatially-varying survey conditions (depth, sky brightness, seeing) using HEALPix maps.
This is *not* the reddening stage — use `Reddener` for SFD dust.
Use `ObsCondition` when you need realistic spatial variation in photometric depth.

```yaml
ObsCondition:
  nside: 128
  map_dict:
    m5:     {u: /path/u_m5.fits, g: /path/g_m5.fits, r: /path/r_m5.fits,
             i: /path/i_m5.fits, z: /path/z_m5.fits, y: /path/y_m5.fits}
    nVisYr: {u: /path/u_nvis.fits, ...}   # visits per year per band
    gamma:  {u: /path/u_gamma.fits, ...}  # sky background parameter
    msky:   {u: /path/u_msky.fits, ...}
    theta:  {u: /path/u_theta.fits, ...}  # seeing FWHM
    km:     {u: /path/u_km.fits, ...}     # atmospheric extinction
    airmass: /path/airmass.fits
    tvis:    /path/tvis.fits
  seed: 42
```

---

### 4. De-reddening — `Dereddener`

**Module:** `rail.tools.photometry_tools.Dereddener`
**Package:** `rail_astro_tools`
**Base class:** `DustMapBase` → `RailStage`

Mirror image of `Reddener`: performs the same SFD lookup but *subtracts* A_λ × E(B-V) to recover intrinsic magnitudes (simulating the standard pipeline dust correction).
Config is identical to `Reddener`.

```yaml
Dereddener:
  ra_name: ra
  dec_name: dec
  dustmap_name: sfd
  dustmap_dir: /path/to/dustmaps    # same directory as used by Reddener
  band_a_env:
    mag_u_lsst: 4.145
    mag_g_lsst: 3.237
    mag_r_lsst: 2.273
    mag_i_lsst: 1.684
    mag_z_lsst: 1.323
    mag_y_lsst: 1.088
  copy_all_cols: true
```

**`Reddener` vs `Dereddener`:**

| | Formula | Use |
|---|---|---|
| `Reddener` | `mag += R_λ × E(B-V)` | Simulate what the telescope sees (forward model) |
| `Dereddener` | `mag -= R_λ × E(B-V)` | Simulate the pipeline dust correction (inverse) |

The two stages use independent SFD lookups — they do not share state. If you use the same `dustmap_dir` and the same `band_a_env`, the correction is exact (no residual). Real analyses introduce a small residual because the SFD correction uses E(B-V) rounded to the pixel centre rather than the exact per-galaxy value.

---

### 5. Quality / SNR cuts — `QuantityCut` (second pass)

Same stage as step 1. Apply after photometric errors to impose SNR-based or magnitude-limit cuts on the *observed* (noisy) catalog:

```yaml
QuantityCut:
  cuts:
    mag_i_lsst: 25.3       # standard LSST gold sample limit
  seed: 42
```

To cut on SNR (≥ 10) you need `mag_err_i_lsst < 0.1`. `QuantityCut` only does upper-bound cuts, so invert the logic by cutting on the error column:
```yaml
  cuts:
    mag_err_i_lsst: 0.1    # keeps mag_err < 0.1  (i.e. SNR > 10)
```

`QuantityCut` drops rows where the cut column is `NaN`, so it also functions as a non-detection filter.

---

### 6. Spectroscopic selection

Spectroscopic selection stages simulate which galaxies a given survey would have targeted and successfully measured a redshift for. They are `Selector` subclasses (remove rows).

#### `SpecSelection_DESI_Phy` ← **primary stage for this workflow**

**Module:** `rail.creation.degraders.desi_selector_phy.SpecSelection_DESI_Phy`
**Package:** `rail_astro_tools`

Physics-based DESI selection: compares a physical parameter column against redshift-interpolated thresholds read from a Parquet file. More physically motivated than the colour/magnitude-based selectors.

```yaml
SpecSelection_DESI_Phy:
  desi_type: lrg              # "bgs" | "lrg" | "elg"
  threshold_col: log_peak_sub_halo_mass   # bgs/lrg; use "log_sfr" for elg
  redshift_col: redshift
  threshold_table: /path/to/desi_lrg_thresholds.pq  # Parquet: columns "z" and "thresh"
  seed: 42
  output_mode: default
```

The stage retains objects where `threshold_col > thresh(z)`, with `thresh(z)` interpolated from `threshold_table`.

#### Observable-based DESI selectors (alternatives / cross-checks)

These use photometric colours and magnitudes rather than physical parameters:

| Stage | Module | Target class |
|---|---|---|
| `SpecSelection_DESI_LRG` | `rail.creation.degraders.spectroscopic_selections` | Luminous Red Galaxies |
| `SpecSelection_DESI_BGS` | same | Bright Galaxy Survey (r < 19.5) |
| `SpecSelection_DESI_ELG_LOP` | same | Emission Line Galaxies |

#### Other survey selectors

All in `rail.creation.degraders.spectroscopic_selections`:

| Stage | Survey |
|---|---|
| `SpecSelection_BOSS` | SDSS-III BOSS (~893k galaxies, 9 100 deg²) |
| `SpecSelection_DEEP2` | DEEP2 (uses LSST g, r, i as proxies) |
| `SpecSelection_DEEP2_LSST` | DEEP2 adapted for LSST bands |
| `SpecSelection_GAMA` | Galaxy And Mass Assembly survey |
| `SpecSelection_HSC` | Hyper Suprime-Cam |
| `SpecSelection_VVDSf02` | VIMOS VLT Deep Survey |
| `SpecSelection_zCOSMOS` | zCOSMOS |

Common config across all `SpecSelection_*`:
```yaml
  n_tot: 10000       # target number of selected galaxies
  seed: 42
  output_mode: default
```

Each selector encodes survey-specific colour/magnitude cuts and a realistic spectroscopic success-rate function. Objects are randomly sampled down to `n_tot` after the selection cuts.

---

## Column naming conventions

| Column | Meaning |
|---|---|
| `mag_{b}_lsst` | AB magnitude in band `b` (u/g/r/i/z/y) |
| `mag_err_{b}_lsst` | Magnitude error in band `b` |
| `redshift` | True redshift (standard name used by most RAIL stages) |
| `ra`, `dec` | Sky position in degrees (required by `Reddener`, `Dereddener`, `ObsCondition`) |

Use `NaN` for non-detections; do not use sentinel magnitudes like 99 or −9.
`Reddener` and `Dereddener` do not add an EBV column — they modify magnitude columns directly.

**Schlafly & Finkbeiner 2011 R_λ coefficients for LSST** (use these as `band_a_env` values):

| Column key | R_λ |
|---|---|
| `mag_u_lsst` | 4.145 |
| `mag_g_lsst` | 3.237 |
| `mag_r_lsst` | 2.273 |
| `mag_i_lsst` | 1.684 |
| `mag_z_lsst` | 1.323 |
| `mag_y_lsst` | 1.088 |

---

## Other useful creation stages

| Stage | Module | Purpose |
|---|---|---|
| `IGMExtinctionModel` | `rail.creation.degraders.lya_degrader` | IGM/Lyα absorption for z > 1.5 (degrades u/g bands) |
| `LineConfusion` | `rail.creation.degraders.spectroscopic_degraders` | Spectroscopic line misidentification (wavelength-swap model) |
| `InvRedshiftIncompleteness` | same | Redshift-dependent spectroscopic incompleteness |
| `GaussianSkewtScatterSelector` | `rail.creation.degraders.gaussian_skewt_scatter_selector` | Adds mock `photoz_mock` column with Gaussian core + skew-t tail scatter, parameterized by mag_i and z bins; does not remove rows |
| `UnrecBlModel` | `rail.creation.degraders.unrec_bl_model` | Unresolved blending effects (requires `FoFCatalogMatching`) |
| `AddColumnOfRandom` | `rail.creation.degraders.addRandom` | Add random noise column for testing |
| `GridSelection` | `rail.creation.degraders.grid_selection` | Spatially-structured subsample selection |
| `SOMSpecSelector` | `rail.creation.degraders.specz_som` | SOM-based spec sample selection |

---

## Full pipeline YAML skeleton

```yaml
# pipeline.yml
modules:
  - rail.creation
  - rail_astro_tools

launcher:
  name: mini
  interval: 1

site:
  name: local
  max_threads: 4

output_dir: ./outputs
log_dir:    ./logs
config:     ./config.yml
resume:     true

stages:
  - name: QuantityCut              # 1. pre-select truth catalog
  - name: Reddener                 # 2. SFD Galactic extinction (rail_astro_tools)
  - name: LSSTErrorModel           # 3. photometric errors
  - name: Dereddener               # 4. apply dust correction (rail_astro_tools)
  - name: QuantityCut              # 5. quality / SNR cuts  ← needs aliasing (duplicate name)
  - name: SpecSelection_DESI_Phy   # 6. physics-based DESI spec selection

inputs:
  input: /path/to/truth_catalog.pq
```

**Note on two `QuantityCut` instances:** ceci requires unique stage names. Use aliasing to run the same class twice:
```yaml
stages:
  - name: QuantityCut
    aliases:
      input:  input
      output: preselected
  - name: QuantityCut
    aliases:
      input:  preselected_after_errors
      output: quality_selected
```

---

## Gotchas

1. **`QuantityCut` cuts are strict upper bounds.** For lower-bound cuts, chain two stages or write a custom `Selector`.

2. **`LSSTErrorModel` sets non-detections to `NaN`, not 99.** Any downstream stage that does arithmetic on magnitude columns will propagate NaN silently. Run a `QuantityCut` (which drops NaN rows) before any magnitude-arithmetic stage.

3. **`Reddener` and `Dereddener` require `ra`/`dec` columns** for the SFD sky coordinate lookup. If your truth catalog lacks position columns both stages will fail.

4. **`Reddener` and `Dereddener` do not add an EBV column.** They directly modify magnitude columns in place. There is no intermediate EBV product to preserve — each stage does its own independent SFD lookup.

5. **`dustmap_dir` is required and the SFD files must be downloaded once.** Use `dustmaps` to fetch them: `python -c "import dustmaps.sfd; dustmaps.sfd.fetch()"` with `dustmaps.config.config['data_dir']` pointing at your target directory. On NERSC, store them on CFS, not `$HOME`.

6. **`Dereddener` does not perfectly invert `Reddener` in all implementations.** Both query E(B-V) at the pixel centre; a small residual can arise from HEALPix pixelisation if the two stages use different `nside` values (though in practice they should use the same map). Keep `dustmap_dir` and `band_a_env` identical between the two stages.

7. **`ObsCondition` is not for SFD reddening** — it handles spatially-varying depth/seeing. Use `Reddener`/`Dereddener` for Galactic dust. Using `ObsCondition` for extinction is incorrect.

8. **`SpecSelection_DESI_Phy` requires the physical parameter column in the catalog.** For CosmoDC2 LRGs use `log_peak_sub_halo_mass`; for ELGs use `log_sfr`. These columns come from the truth simulation — preserve them through all degradation steps by setting `copy_all_cols: true` in each preceding stage.

9. **`threshold_table` for `SpecSelection_DESI_Phy` must be a Parquet file with columns `z` and `thresh`.** Generate this from the DESI targeting paper's threshold functions or from an empirical calibration.

10. **Two `QuantityCut` stages in the same pipeline require ceci aliasing.** Without unique names, ceci raises `DuplicateStageName` at pipeline construction time.
