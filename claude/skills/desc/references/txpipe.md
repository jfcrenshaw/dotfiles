# TXPipe — DESC catalog-to-statistics pipeline

TXPipe is the main DESC analysis pipeline: catalog → sample selection → maps → 2pt statistics → covariance → theory comparison.
It implements the full 3×2pt analysis (cosmic shear ξ±, galaxy–galaxy lensing γ_t, galaxy clustering w(θ) and C_ℓ), plus all associated diagnostics, systematics corrections, and null tests.
All stages are ceci `PipelineStage` subclasses. See [`ceci.md`](ceci.md) for the framework basics.

Docs: <https://txpipe.readthedocs.io/en/latest/>
Repo: <https://github.com/LSSTDESC/TXPipe>
Examples: <https://github.com/LSSTDESC/TXPipe/tree/master/examples>

**Source indexed in qmd** — search `collection:"txpipe"` for stage class definitions, inputs/outputs, and config options before consulting docs or training data.

---

## Pipeline phases and stage names

### 1. Ingestion

Read raw external data into the TXPipe HDF5 schema. One ingester per data source — using the wrong one silently reads the wrong columns.

| Stage | Source |
|---|---|
| `TXIngestDataPreview02` | LSST DP0.2 (Butler) |
| `TXIngestDataPreview1` | LSST DP1 (Butler) |
| `TXCosmoDC2Mock` | CosmoDC2 mock catalogs |
| `TXGaussianSimsMock` | Gaussian sim mocks |
| `TXMetacalGCRInput` | Metacal via GCR |
| `TXIngestStars` | Stellar catalogs |
| `TXIngestRedmagic` | REDMAGIC cluster sample |
| `TXIngestDESY3Gold` | DES Y3 Gold |
| `TXParquetToHDF` | Parquet → HDF5 format conversion |
| `FlowCreator` | Simulated catalog via normalizing flow |

### 2. Photo-z estimation (RAIL-based)

TXPipe delegates photo-z to [RAIL](https://lsstdescrail.readthedocs.io/en/stable/) stages imported alongside TXPipe stages.

```yaml
modules:
  - txpipe
  - rail.estimation
  - rail.summarization
```

| Stage | Purpose |
|---|---|
| `PZPrepareEstimatorLens` | Configure RAIL estimator for lens sample |
| `PZEstimatorLens` | Run estimator → per-object photo-z PDFs |
| `NZDirInformerLens` | Prior from training data (DIR method) |
| `PZRailSummarizeLens` | Summarize PDFs → stacked n(z) per bin |
| `PZPrepareEstimatorSource` | Same pipeline for source sample |
| `PZEstimatorSource` | |
| `NZDirInformerSource` | |
| `PZRailSummarizeSource` | |
| `TXTruePhotozStack` | Ground-truth n(z) from true redshifts (sims only) |
| `TXPhotozPlot` | n(z) visualisation |
| `PZRealizationsPlot` | Plot multiple n(z) realisations |

Output type: `QPNOfZFile` — ensemble n(z) per tomographic bin. This is required input for all 2pt stages.

### 3. Sample selection & tomographic binning

**Source shear samples** — one selector per catalog type; picks the correct column names and response format:

| Stage | Catalog type |
|---|---|
| `TXSourceSelectorMetadetect` | MetaDetect |
| `TXSourceSelectorMetacal` | Metacal |
| `TXSourceSelectorLensfit` | Lensfit |
| `TXSourceSelectorHSC` | HSC |
| `TXSourceSelectorSimple` | Generic / simulations |

After selection, bin by photo-z:
- `TXSourceTomography` — assigns sources to tomographic bins; outputs `binned_shear_catalog`

**Lens galaxy samples:**
- `TXMeanLensSelector` — applies photometric cuts, assigns lens tomographic bins; outputs `binned_lens_catalog`

**Random catalogs:**
- `TXRandomCat` — generates uniform randoms over the footprint
- `TXSubsampleRandoms` — thins existing randoms

### 4. Shear calibration & metadata

- `TXShearCalibration` — applies multiplicative response corrections and additive PSF corrections; must run *after* ingestion and *before* maps
- `TXTracerMetadata` — collates per-bin metadata (effective number densities, mean ellipticities, response matrices) into a YAML + HDF5 file; required by theory and blinding stages

### 5. Masking

| Stage | What it does |
|---|---|
| `TXSimpleMask` | Binary mask from depth cut + bright object count |
| `TXSimpleMaskSource` | Same using lensing weights |
| `TXSimpleMaskFrac` | Fractional mask using high-resolution ancillary maps |
| `TXCustomMask` | Mask with user-defined cuts on auxiliary map columns |

All masks are HEALPix maps at a configurable `nside`. Mask `nside` must match the map `nside` used downstream.

### 6. Auxiliary maps & systematic weights

**Auxiliary maps** (survey property maps fed to systematics stages):

| Stage | Outputs |
|---|---|
| `TXAuxiliarySourceMaps` | PSF g1/g2/T, object counts, lensing weights, flag maps |
| `TXAuxiliaryLensMaps` | Bright-object count map, depth from S/N |
| `TXAuxiliarySSIMaps` | SSI depth: measured, true, detection probability |

**LSS systematic weights** (regression-based corrections for survey non-uniformity):

| Stage | Method |
|---|---|
| `TXLSSWeights` | Wavelet-based regression |
| `TXLSSWeightsLinBinned` | Linear regression on binned correlations |
| `TXLSSWeightsLinPix` | Pixel-level linear regression |
| `TXLSSWeightsUnit` | No weights (unit weights) |

### 7. Map generation

**Signal maps** (HEALPix or gnomonic pixelisation):

| Stage | Output tag | Contents |
|---|---|---|
| `TXSourceMaps` | `source_maps` | g1, g2, count, weight, variance per source bin |
| `TXLensMaps` | `lens_maps` | count, weighted-count per lens bin |
| `TXDensityMaps` | `density_maps` | overdensity δ = (n − n̄)/n̄ per lens bin |

**Noise realisations** (used in covariance estimation):

| Stage | Output tag | Method |
|---|---|---|
| `TXSourceNoiseMaps` | `source_noise_maps` | ~30 random shear rotations per source bin |
| `TXLensNoiseMaps` | `lens_noise_maps` | ~5 random catalog splits per lens bin |
| `TXNoiseMapsJax` | both | GPU-accelerated version (combined source+lens) |

**Convergence:**
- `TXConvergenceMaps` — Kaiser–Squires E/B-mode reconstruction from source maps; requires true g1/g2

**Map visualisation:**
- `TXMapPlots`, `TXMapPlotsSSI`, `TXConvergenceMapPlots`
- `TXMapCorrelations` — correlate maps with survey property maps (auxiliary maps) in angular bins

### 8. Two-point measurements

#### Real space (TreeCorr)

**`TXTwoPoint`** — measures all three 2pt functions in real space:
- ξ+(θ), ξ−(θ) — cosmic shear
- γ_t(θ) — galaxy–galaxy lensing
- w(θ) — galaxy clustering

Key config:
```yaml
TXTwoPoint:
  min_sep: 2.5        # arcmin
  max_sep: 250.0      # arcmin
  n_theta_bins: 20
  sep_units: arcmin
  jackknife: true
  use_randoms: true
```

Outputs: `twopoint_data_real_raw` (SACC), `twopoint_gamma_x` (SACC; B-mode)

#### Fourier space (NaMaster)

**`TXTwoPointFourier`** — measures C_ℓ for all cross-correlations using NaMaster:
- C_ℓ^{EE}, C_ℓ^{BB} — shear power spectra
- C_ℓ^{κg} — galaxy–galaxy lensing power spectra
- C_ℓ^{gg} — galaxy clustering power spectra

Key config:
```yaml
TXTwoPointFourier:
  min_ell: 20
  max_ell: 2000
  n_ell_bins: 20
  compute_shear_shear: true
  compute_shear_pos: true
  compute_pos_pos: true
  deprojection_modes: 5   # # systematic modes to project out
```

Output: `twopoint_data_fourier` (SACC)

#### Null tests

| Stage | Tests |
|---|---|
| `TXGammaTFieldCenters` | Tangential shear around exposure field centres |
| `TXGammaTStars` | Tangential shear around bright/dim stars |
| `TXGammaTRandoms` | Tangential shear around random points (should be zero) |
| `TXApertureMass` | Aperture mass M_ap and M_× statistics |

### 9. Jackknife patches

- `TXJackknifeCenters` — compute patch centres from randoms; `npatch` (typical: 10–50)
- `TXJackknifeCentersSource` — patch centres from shear catalog

Pass `patch_centers` tag to `TXTwoPoint` to enable jackknife covariance.

### 10. Covariance estimation

| Stage | Method | Space |
|---|---|---|
| `TXFourierGaussianCovariance` | Gaussian analytic | Fourier |
| `TXRealGaussianCovariance` | Wigner transform of Gaussian | Real |
| `TXFourierNamasterCovariance` | Hybrid NaMaster + TJPCov | Fourier |
| `TXRealNamasterCovariance` | Wigner transform of NaMaster | Real |

NaMaster covariance uses linear binning (ℓ = 1…500) then log binning; distributes blocks over MPI. It is compute-intensive — allocate adequate resources.
Covariance is attached directly to the output SACC file.

### 11. Theory predictions

- `TXTwoPointTheoryReal` — CCL-based theory predictions for real-space data vector
- `TXTwoPointTheoryFourier` — CCL-based theory predictions for C_ℓ

Both support: fiducial cosmology input, configurable galaxy bias (unit / global / per-bin), optional n(z) smoothing.
Requires `fiducial_cosmology` input (a YAML file of CCL parameters) and `tracer_metadata`.

### 12. Blinding

- `TXBlinding` — shifts data vector by a random cosmology offset (Muir et al. method); controlled by a secret seed
- `TXNullBlinding` — pass-through; use for simulations or after unblinding

**Never share the blinding seed.** The same seed always produces the same shift, so publishing it retroactively breaks the blind.

### 13. PSF diagnostics

| Stage | What it measures |
|---|---|
| `TXPSFDiagnostics` | Mean PSF residuals Δe1, Δe2, ΔT by star type |
| `TXRoweStatistics` | Six Rowe statistics (PSF spatial auto/cross-correlations) |
| `TXPSFMomentCorr` | 10 PSF moment correlations |
| `TXTauStatistics` | τ statistics — shear × PSF correlations (Gatti et al. 2023) |
| `TXGalaxyStarShear` | Galaxy shear × star PSF shape cross-correlations |
| `TXGalaxyStarDensity` | Galaxy density × star PSF density cross-correlations |
| `TXBrighterFatterPlot` | Magnitude-dependent PSF size residuals |
| `TXFocalPlanePlot` | Mean e1/e2 as function of focal plane position |

### 14. Source/lens diagnostics

- `TXSourceDiagnosticPlots` — PSF-shear correlations, e1/e2 histograms, S/N, magnitude (per catalog type)
- `TXLensDiagnosticPlots` — S/N and magnitude histograms for lens sample
- `TXDiagnosticQuantiles` — Distogram-based quantile diagnostics

### 15. Two-point visualisation

- `TXTwoPointPlots` — ξ±, γ_t, w(θ) vs theory
- `TXTwoPointPlotsFourier` — C_ℓ and data/theory ratios
- `TXTwoPointPlotsTheory` — data + theory + residuals

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
  - name: TXSourceTomography
  - name: TXShearCalibration
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

The per-stage config file (`config.yml`) contains a YAML dict keyed by stage name:

```yaml
TXSourceSelectorMetadetect:
  snr_cut: 10.0
  size_cut: 0.5
  T_cut: 0.3

TXSourceTomography:
  n_z: 5
  zbin_edges: [0.0, 0.3, 0.5, 0.7, 0.9, 1.2]

TXSimpleMask:
  depth_cut: 24.5
  bright_obj_cut: 10

TXSourceMaps:
  pixelization: healpix
  nside: 512
  sparse: false

TXTwoPoint:
  min_sep: 2.5
  max_sep: 250.0
  n_theta_bins: 20
  sep_units: arcmin
  jackknife: true

TXTwoPointFourier:
  min_ell: 20
  max_ell: 2000
  n_ell_bins: 20
  deprojection_modes: 5

TXJackknifeCenters:
  npatch: 20
  every_nth: 100
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

1. **Use the right selector for your catalog type.** `TXSourceSelectorMetadetect` vs `TXSourceSelectorMetacal` read different column names and apply different response matrix logic. Using the wrong one gives a silently corrupted shear catalog.

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

12. **`module: txpipe` in pipeline YAML must be importable.** If TXPipe is not in the environment, ceci raises a stage-not-found error rather than an import error. Always activate the DESC conda env before running.

13. **LSST DP versions have dedicated ingesters.** `TXIngestDataPreview02` ≠ `TXIngestDataPreview1`. Butler schema changes between Data Previews; the wrong ingester fails at column-access time with opaque messages.

14. **Kaiser–Squires (`TXConvergenceMaps`) requires calibrated g1/g2.** Passing uncalibrated or mis-formatted shear produces a convergence map that looks reasonable but is quantitatively wrong. Run after `TXShearCalibration`.

15. **PSF diagnostic columns are catalog-type-specific.** Metacal uses `psf_T_mean`; MetaDetect uses `T_model`; Lensfit uses different conventions. `TXPSFDiagnostics` and `TXRoweStatistics` must be configured for the right catalog type or will silently produce empty/wrong plots.
