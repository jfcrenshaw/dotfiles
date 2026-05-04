---
name: desc
description: How to write code for LSST DESC (Dark Energy Science Collaboration) science. Covers the DESC Python ecosystem — cosmology libraries, weak-lensing pipelines, photo-z codes, catalog I/O, and simulation tools — with idiomatic usage patterns, key gotchas, and pointers to official docs. Use this skill whenever the user is working on DESC science code, imports a DESC library, or asks about DESC pipelines, simulations, or catalogs. Tool references are in references/, added as each tool is introduced.
---

# LSST DESC Python ecosystem

You're helping a user write DESC science code.
DESC (Dark Energy Science Collaboration) is the primary LSST weak-lensing / large-scale-structure science collaboration.
Most work happens at NERSC (see the `nersc` skill for cluster conventions); this skill focuses on the DESC software stack itself.

Jump to the section for the tool you're using.
Per-tool deep-dives are in `references/`.

---

## Tools covered

| Tool | Purpose | Reference |
|---|---|---|
| `ceci` | Pipeline framework: stage definition, YAML pipelines, MPI, file I/O | [`references/ceci.md`](references/ceci.md) |
| `TXPipe` | Main DESC 3×2pt pipeline: selection → maps → 2pt → covariance → theory | [`references/txpipe.md`](references/txpipe.md) |
| `RAIL` | Photo-z framework (ceci-based): creation, estimation, evaluation modules | [`references/rail.md`](references/rail.md) |
| RAIL creation | Catalog simulation pipeline: column cuts, reddening, photo errors, spec selection | [`references/rail-creation.md`](references/rail-creation.md) |

---

## ceci (pipeline framework)

Most DESC analysis packages are built on ceci.
A **stage** subclasses `PipelineStage`, declares `inputs`/`outputs` as lists of `(tag, FileType)` tuples, sets `config_options`, and implements `run()`.
A **pipeline** is a YAML file: `module`, `launcher`, `site`, `stages`, `inputs`, `output_dir`, `log_dir`, `config`.
Ceci resolves execution order from the tag DAG automatically — YAML order is irrelevant.

```python
from ceci import PipelineStage
from ceci.file_types import HDFFile, TextFile

class MyStage(PipelineStage):
    name = "MyStage"
    inputs  = [("input_cat", HDFFile)]
    outputs = [("output_cat", HDFFile), ("summary", TextFile)]
    config_options = {"quality_cut": float, "n_bins": 10}

    def run(self):
        cut = self.config["quality_cut"]
        with self.open_input("input_cat", wrapper=True) as f:
            data = f.file["shear/g1"][:]
        with self.open_output("output_cat", wrapper=True) as out:
            out.file.create_dataset("result/g1", data=data[data > cut])
```

Key rules: `name` is required and globally unique; all declared outputs must be written on every run; `resume: true` in YAML skips stages with existing outputs; `nprocess: N` triggers MPI with N ranks.
Full detail: [`references/ceci.md`](references/ceci.md).

---

## TXPipe (3×2pt pipeline)

TXPipe is the main DESC analysis workhorse: it processes shear and photometric catalogs through sample selection, map generation, two-point measurements (real and Fourier space), covariance estimation, theory comparison, and diagnostics.
All stages are ceci `PipelineStage` subclasses; the pipeline YAML must include `modules: [txpipe, ...]`.

**Pipeline phases (in order):**
1. **Ingestion** — `TXIngestDataPreview02`, `TXCosmoDC2Mock`, etc. — source-specific; using the wrong ingester silently reads wrong columns
2. **Photo-z** — RAIL stages (`PZEstimatorLens/Source`, `PZRailSummarizeLens/Source`); must produce `QPNOfZFile` before 2pt
3. **Selection** — `TXSourceSelectorMetadetect/Metacal/Lensfit/HSC` + `TXSourceTomography`; `TXMeanLensSelector` for lenses
4. **Calibration** — `TXShearCalibration` then `TXTracerMetadata` (both required; calibration must precede tomography)
5. **Masks** — `TXSimpleMask` or `TXCustomMask`; nside must match map nside everywhere
6. **Maps** — `TXSourceMaps`, `TXLensMaps`, `TXAuxiliarySourceMaps/LensMaps`, `TXLSSWeights`
7. **Noise maps** — `TXSourceNoiseMaps` (~30 realisations), `TXLensNoiseMaps` (~5); required for covariance
8. **Two-point real** — `TXTwoPoint` (TreeCorr; ξ±, γ_t, w(θ)); uses `TXJackknifeCenters` for jackknife cov
9. **Two-point Fourier** — `TXTwoPointFourier` (NaMaster; C_ℓ for shear-shear, shear-pos, pos-pos)
10. **Covariance** — `TXFourierNamasterCovariance` / `TXRealNamasterCovariance` (expensive; use `TXFourierGaussianCovariance` for quick tests)
11. **Theory & blinding** — `TXTwoPointTheoryReal/Fourier` (CCL); `TXBlinding` (secret seed, deterministic)
12. **Diagnostics** — `TXPSFDiagnostics`, `TXRoweStatistics`, `TXTauStatistics`, `TXSourceDiagnosticPlots`, `TXTwoPointPlots`

The `examples/metadetect/` pipeline is the canonical full-pipeline reference.
Full stage list, file tags, config keys, and gotchas: [`references/txpipe.md`](references/txpipe.md).

---

## RAIL (photo-z framework)

RAIL extends ceci's `PipelineStage` with a `DataStore`/`DataHandle` pattern.
`RailStage` adds `self.get_data(tag)` / `self.add_data(tag, data)` on top of the ceci file-tag system.
The three modules are `rail.creation` (simulate catalogs), `rail.estimation` (run photo-z algorithms), `rail.evaluation` (quality metrics).
RAIL is distributed across many sub-packages (`rail_base`, `rail_astro_tools`, `rail_som`, …) that all populate the `rail.*` namespace via setuptools entry-points — always import from `rail.*`, never from `rail_base.*` directly.

**Key DataHandle types:** `PqHandle` (Parquet), `Hdf5Handle` (HDF5, default group `photometry`), `QPHandle` (qp.Ensemble PDFs), `ModelHandle` (trained models).

**Pipeline YAML:** same ceci format; `modules:` must list every sub-package that provides a stage (e.g. `rail.creation`, `rail_astro_tools`).

Architecture and base classes: [`references/rail.md`](references/rail.md).

### RAIL creation pipeline (the main use case)

Simulates a realistic photometric catalog from a truth simulation:

```
truth catalog (Parquet/HDF5)
  → QuantityCut              (pre-select columns/redshift range)
  → ObsCondition             (SFD Galactic reddening via EBV HEALPix map)
  → LSSTErrorModel           (photometric errors, non-detections → NaN)
  → DereddenLSST             (apply A_λ = R_λ × EBV correction; write custom RailStage)
  → QuantityCut              (SNR / magnitude limit cuts on observed photometry)
  → SpecSelection_DESI_Phy   (physics-based DESI spec selection; in rail_astro_tools)
```

Key config notes:
- `Reddener` / `Dereddener`: both in `rail.tools.photometry_tools` (`rail_astro_tools`); both do an SFD lookup at `ra`/`dec`; `dustmap_dir` (required) points to downloaded SFD files; `band_a_env` maps column names to R_λ (SF11: u=4.145, g=3.237, r=2.273, i=1.684, z=1.323, y=1.088); `Reddener` adds A_λ×E(B-V), `Dereddener` subtracts it; they do NOT add an EBV column
- `LSSTErrorModel`: `bands: [u,g,r,i,z,y]`; magnitude columns named `mag_{b}_lsst`; NaN = non-detection
- `ObsCondition` is for spatially-varying depth/seeing, NOT for SFD reddening — use `Reddener`/`Dereddener` for dust
- `SpecSelection_DESI_Phy`: `desi_type` = "bgs"/"lrg"/"elg"; `threshold_col` = physical param (e.g. `log_peak_sub_halo_mass`); `threshold_table` = Parquet file with `z`, `thresh` columns
- Two `QuantityCut` instances in one pipeline require ceci aliasing (duplicate `name` raises `DuplicateStageName`)

Full stage reference, YAML skeleton, gotchas: [`references/rail-creation.md`](references/rail-creation.md).

---

## General DESC coding conventions

- DESC packages are Python 3; most require Python ≥ 3.9.
- Prefer the official DESC I/O helpers over rolling your own FITS/HDF5 reads — they handle unit conventions and multi-file layouts correctly.
- When in doubt about units, check the package docs: DESC packages are not always consistent with each other on angular units (radians vs arcmin vs degrees).
- For catalog-scale work (millions of objects), use `numpy` / `fitsio` / `h5py` over `astropy` table reads — they're dramatically faster on NERSC Lustre.
- DESC repos live on GitHub under the `LSSTDESC` organization: <https://github.com/LSSTDESC>.
