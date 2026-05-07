# TXPipe — pipeline configuration and file types

Reference for TXPipe's data file types, pipeline YAML structure, example pipelines, and common gotchas.
For the full stage catalog see [`txpipe-stages.md`](txpipe-stages.md).

Docs: <https://txpipe.readthedocs.io/en/latest/>
Repo: <https://github.com/LSSTDESC/TXPipe>
Examples: <https://github.com/LSSTDESC/TXPipe/tree/master/examples>

---

## Contents

- [Key file types (data_types.py)](#key-file-types-datatypespy)
- [Pipeline YAML structure](#pipeline-yaml-structure)
- [Example pipelines](#example-pipelines)
- [Common gotchas](#common-gotchas)

---

## Key file types (data_types.py)

| Type | Tag convention | Format | Contents |
|---|---|---|---|
| `ShearCatalog` | `shear_catalog` | HDF5 | Raw per-object shear measurements; format-specific column names |
| `PhotometryCatalog` | `photometry_catalog` | HDF5 | Magnitudes, colours, RA/Dec |
| `BinnedCatalog` | `binned_shear_catalog`, `binned_lens_catalog` | HDF5 | Shear/lens after selection + tomography |
| `RandomsCatalog` | `randoms_catalog`, `binned_randoms_catalog` | HDF5 | Random points; must have `ra`, `dec` |
| `MapsFile` | `source_maps`, `lens_maps`, `density_maps`, `auxiliary_*_maps`, `masks` | HDF5 / HealSparse | HEALPix maps, configurable nside |
| `LensingNoiseMaps` | `source_noise_maps` | HDF5 | Shape noise realisations (realization × bin) |
| `ClusteringNoiseMaps` | `lens_noise_maps` | HDF5 | Density noise realisations |
| `QPNOfZFile` | `source_photo_z`, `lens_photo_z` | HDF5 (QP) | Stacked n(z) ensemble per tomographic bin |
| `SACCFile` | `twopoint_data_real_raw`, `twopoint_data_fourier` | SACC | 2pt functions + covariance + tracers |
| `FiducialCosmology` | `fiducial_cosmology` | YAML | CCL parameter dict |
| `TomographyCatalog` | *(implicit in selectors)* | HDF5 | Photo-z bin edges |
| `HDFFile` | `tracer_metadata` | HDF5 + YAML | Per-bin n_eff, sigma_e, response |

### FiducialCosmology YAML format

The `fiducial_cosmology` input is a YAML file read by `ccl_read_yaml()` in `utils/theory.py`.
All keys below are required; set exactly one of `sigma8` / `A_s` and write `nan` for the other:

```yaml
Omega_c: 0.27
Omega_b: 0.045
h: 0.67
n_s: 0.96
sigma8: 0.8
A_s: nan        # use "nan" (string) when specifying sigma8 instead
Omega_k: 0.0
Neff: 3.046
w0: -1.0
wa: 0.0
bcm_log10Mc: 14.079
bcm_etab: 0.5
bcm_ks: 55.0
mu_0: 0.0
sigma_0: 0.0
```

Optional keys: `m_nu` (list of neutrino masses in eV), `z_mg`/`df_mg` (modified gravity z-dependent growth).

---

## Pipeline YAML structure

```yaml
modules:
  - txpipe
  - rail.estimation
  - rail.summarization

launcher:
  name: mini
  interval: 1.0

site:
  name: local       # or nersc-interactive / nersc-batch
  max_threads: 4

output_dir: data/outputs
log_dir:    data/logs
resume: true        # skip stages with existing outputs during reruns

config: examples/metadetect/config.yml   # per-stage config

stages:
  - name: TXSourceSelectorMetadetect
  - name: TXShearCalibration
  - name: TXSourceTomography
  - name: TXTracerMetadata
  - name: TXAuxiliarySourceMaps
  - name: TXSimpleMask
  - name: TXSourceMaps
  - name: TXLensMaps
  - name: TXSourceNoiseMaps
  - name: TXLensNoiseMaps
  - name: TXJackknifeCenters
  - name: TXTwoPoint
    nprocess: 4
  - name: TXTwoPointFourier
    nprocess: 8
    threads_per_process: 16
  - name: TXFourierNamasterCovariance
    nprocess: 8
  - name: TXTwoPointTheoryReal
  - name: TXBlinding

inputs:
  shear_catalog:      data/shear.hdf5
  photometry_catalog: data/photometry.hdf5
  fiducial_cosmology: data/cosmology.yml
```

The per-stage config file (`config.yml`) is a YAML dict keyed by stage name — each stage has its own sub-dict:

```yaml
TXSourceSelectorMetadetect:  # stage name as key
  snr_cut: 10.0
  T_cut: 0.3

TXSourceMaps:
  pixelization: healpix
  nside: 512               # must match mask nside everywhere

# Gotcha-prone config keys for TXTwoPoint / TXTwoPointFourier:
# see txpipe-stages.md §8 for full config_options
```

---

## Example pipelines

| Example | Data source | Shear type | Notes |
|---|---|---|---|
| `metadetect/` | LSST DP0.2 sim | MetaDetect | Full 56-stage pipeline; reference for a complete 3×2pt run |
| `cosmodc2/` | CosmoDC2 mock | Metacal | True photo-z available; NERSC resource config included |
| `desy1/` | DES Y1 | Metacal | Real data; many optional stages disabled |
| `desy3/` | DES Y3 | Metacal | Deeper than Y1 |
| `metacal/` | Simulated | Metacal | Minimal: demonstrates Metacal selector |
| `lensfit/` | Simulated | Lensfit | Demonstrates Lensfit selector |
| `lognormal/` | GLASS lognormal | Simple | Fast mocks for testing |
| `buzzard/` | Buzzard sims | Metacal | Mock data pipeline |
| `gaussian_sims/` | Gaussian random fields | Simple | Minimal diagnostic pipeline |
| `redmagic/` | DES REDMAGIC | — | Cluster magnification |

The `metadetect` example is the canonical reference; when in doubt, compare against it.

---

## Common gotchas

1. **Use the right stage for your data source.** Both ingesters and selectors are source-specific and fail silently with wrong data:
   - *Ingesters*: `TXIngestDataPreview02` ≠ `TXIngestDataPreview1`; Butler schema changes between LSST Data Previews; the wrong ingester fails at column-access time with opaque messages.
   - *Selectors*: `TXSourceSelectorMetadetect` vs `TXSourceSelectorMetacal` read different column names and apply different response matrix logic; the wrong one silently corrupts the shear catalog.

2. **Calibration must precede tomography and maps.** `TXShearCalibration` → `TXSourceTomography` → `TXSourceMaps`. Reversing this drops the calibration corrections.

3. **Tomographic bin edges must be consistent across source and lens.** Source (`TXSourceTomography`) and lens (`TXMeanLensSelector`) bins are set independently. If they disagree in number or edges, `TXTwoPoint` / `TXTwoPointFourier` will produce shape mismatches.

4. **Photo-z must be summarised (stacked) before reaching 2pt stages.** Raw PDFs are not valid input to `TXTwoPoint` or `TXTwoPointFourier`. You need `QPNOfZFile` output from a `PZRailSummarize*` stage or `TXTruePhotozStack`.

5. **Map nside must match mask nside everywhere.** `TXSourceMaps`, `TXLensMaps`, `TXSimpleMask`, and the covariance stages all use the same nside. A mismatch causes a silent shape error or a Fourier-space noise floor.

6. **All declared outputs must be written every run** (ceci rule). Don't conditionally skip writing an output file — this will crash the rename step.

7. **`resume: true` skips stages with existing outputs.** When you change a stage's config and rerun, you must delete its outputs or set `resume: false`, or the old outputs will be used silently.

8. **`TXTracerMetadata` is not optional.** Theory (`TXTwoPointTheory*`) and blinding stages read per-bin metadata from it. Disabling it breaks downstream.

9. **The blinding seed must stay secret.** `TXBlinding` produces a deterministic shift from the seed — publishing the seed retroactively reveals the blind. Store it only in an untracked secrets file.

10. **NaMaster covariance is expensive.** Allocate adequate MPI ranks and wall-time (`nprocess: 8+`, `nodes: 2+` on NERSC). For quick tests use `TXFourierGaussianCovariance` instead.

11. **Noise map realisations feed covariance, not just diagnostics.** Without `TXSourceNoiseMaps` / `TXLensNoiseMaps`, the covariance stages will either fail or underestimate variance (cosmic-variance-only). Always include them.

12. **`txpipe` must be listed under `modules:` in the pipeline YAML and be importable.** If TXPipe is not in the environment, ceci raises a stage-not-found error rather than an import error. Always activate the DESC conda env before running.

13. **Kaiser–Squires (`TXConvergenceMaps`) requires calibrated g1/g2.** Passing uncalibrated or mis-formatted shear produces a convergence map that looks reasonable but is quantitatively wrong. Run after `TXShearCalibration`.

14. **PSF diagnostic columns are catalog-type-specific.** Metacal uses `psf_T_mean`; MetaDetect uses `T_model`; Lensfit uses different conventions. `TXPSFDiagnostics` and `TXRoweStatistics` must be configured for the right catalog type or will silently produce empty/wrong plots.

15. **`flip_g2` defaults differ between TXTwoPoint and TXTwoPointFourier.** `TXTwoPoint` (TreeCorr) defaults to `flip_g2: true`; `TXTwoPointFourier` (NaMaster) defaults to `flip_g2: false`. If you run both without explicitly setting `flip_g2` in both, real-space and Fourier-space shear-position correlations will use opposite g2 sign conventions, making cross-checks between the two meaningless. Always set `flip_g2` explicitly and consistently in both stages.

16. **Extensions are not auto-imported.** The `txpipe` module only imports core stages. Extension stages (CMB lensing: `TXIngestQuaia`, `TXIngestPlanckLensingMaps`, `TXTwoPointFourierCMBLensingCrossDensity`) live under `txpipe/extensions/` and must be explicitly added to `modules:` in the pipeline YAML. Check the extension's `__init__.py` for the exact importable module path (the directory name uses hyphens, so it is not directly importable as `txpipe.extensions.cmb-lensing`). Omitting the import causes a stage-not-found error at runtime.
