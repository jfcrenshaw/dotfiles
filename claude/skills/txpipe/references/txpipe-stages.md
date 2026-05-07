# TXPipe — pipeline stages reference

All 15 pipeline phases with stage names, purposes, and key config.
For file types, pipeline YAML structure, and gotchas see [`txpipe-pipeline.md`](txpipe-pipeline.md).
All stages are ceci `PipelineStage` subclasses. See the `ceci` skill for the framework basics.

**Source indexed in qmd** — search `collection:"txpipe"` for stage class definitions, inputs/outputs, and config options before consulting docs or training data.

---

## Contents

- [1. Ingestion](#1-ingestion)
- [2. Photo-z estimation (RAIL-based)](#2-photo-z-estimation-rail-based)
- [3. Sample selection & tomographic binning](#3-sample-selection--tomographic-binning)
- [4. Shear calibration & metadata](#4-shear-calibration--metadata)
- [5. Masking](#5-masking)
- [6. Auxiliary maps & systematic weights](#6-auxiliary-maps--systematic-weights)
- [7. Map generation](#7-map-generation)
- [8. Two-point measurements](#8-two-point-measurements)
- [9. Jackknife patches](#9-jackknife-patches)
- [10. Covariance estimation](#10-covariance-estimation)
- [11. Theory predictions](#11-theory-predictions)
- [12. Blinding](#12-blinding)
- [13. PSF diagnostics](#13-psf-diagnostics)
- [14. Source/lens diagnostics](#14-sourcelens-diagnostics)
- [15. Two-point visualisation](#15-two-point-visualisation)

---

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
