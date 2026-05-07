---
name: rail
description: How to work with RAIL (Redshift Assessment Infrastructure Layers), the DESC photo-z framework built on ceci. Covers RailStage/DataStore/DataHandle patterns, namespace architecture (rail.* entry-points), DataHandle types, three modules (creation/estimation/evaluation), pipeline YAML format, and the catalog simulation workflow (QuantityCut → Reddener → LSSTErrorModel → Dereddener → SpecSelection). Use this skill whenever the user imports rail, works with RailStage, does photo-z estimation, catalog degradation, or spectroscopic selection.
---

# RAIL — DESC photo-z framework

You're helping a user work with RAIL (Redshift Assessment Infrastructure Layers), the DESC photo-z framework.
RAIL extends ceci's `PipelineStage` with a `DataStore`/`DataHandle` pattern; for ceci base conventions see the `ceci` skill.
For NERSC job submission, see the `nersc` skill.

## Architecture

`RailStage` adds `self.get_data(tag)` / `self.add_data(tag, data)` on top of the ceci file-tag system.
The three modules are `rail.creation` (simulate catalogs), `rail.estimation` (run photo-z algorithms), `rail.evaluation` (quality metrics).
RAIL is distributed across many sub-packages (`rail_base`, `rail_astro_tools`, `rail_som`, …) that all populate the `rail.*` namespace via setuptools entry-points — always import from `rail.*`, never from `rail_base.*` directly.

**Key DataHandle types:** `PqHandle` (Parquet), `Hdf5Handle` (HDF5, default group `photometry`), `QPHandle` (qp.Ensemble PDFs), `ModelHandle` (trained models).

**Pipeline YAML:** same ceci format; `modules:` must list every sub-package that provides a stage (e.g. `rail.creation`, `rail_astro_tools`).

## RAIL creation pipeline (catalog simulation)

```
truth catalog (Parquet/HDF5)
  → QuantityCut              (pre-select columns/redshift range)
  → Reddener                 (SFD Galactic dust reddening, adds A_λ)
  → LSSTErrorModel           (photometric errors, non-detections → NaN)
  → Dereddener               (subtract A_λ = R_λ × EBV correction)
  → QuantityCut              (SNR / magnitude limit cuts on observed photometry)
  → SpecSelection_DESI_Phy   (physics-based DESI spec selection; in rail_astro_tools)
```

Key config notes:
- `Reddener` / `Dereddener`: both in `rail.tools.photometry_tools` (`rail_astro_tools`); `dustmap_dir` (required) points to downloaded SFD files; `band_a_env` maps column names to R_λ (SF11: u=4.145, g=3.237, r=2.273, i=1.684, z=1.323, y=1.088); `Reddener` adds A_λ×E(B-V), `Dereddener` subtracts it; they do NOT add an EBV column
- `LSSTErrorModel`: `bands: [u,g,r,i,z,y]`; magnitude columns named `mag_{b}_lsst`; NaN = non-detection
- `ObsCondition` is for spatially-varying depth/seeing, NOT for SFD reddening — use `Reddener`/`Dereddener` for dust
- `SpecSelection_DESI_Phy`: `desi_type` = "bgs"/"lrg"/"elg"; `threshold_col` = physical param (e.g. `log_peak_sub_halo_mass`); `threshold_table` = Parquet file with `z`, `thresh` columns
- Two `QuantityCut` instances in one pipeline require ceci aliasing (duplicate `name` raises `DuplicateStageName`)

## References

| Topic | Reference |
|---|---|
| RailStage, DataHandle types, base class hierarchy, gotchas | [`references/rail-core-concepts.md`](references/rail-core-concepts.md) |
| Full creation pipeline: all degradation stages, spec selectors, YAML skeleton, gotchas | [`references/rail-creation.md`](references/rail-creation.md) |
| Estimation base classes (CatInformer/Estimator/Summarizer), implementing algorithms, available algorithms, gotchas | [`references/rail-estimation.md`](references/rail-estimation.md) |
| RailPipeline pipeline-as-code, Stage.build() wiring, pre-built pipelines, CatalogTag | [`references/rail-pipelines.md`](references/rail-pipelines.md) |
| RailProject multi-flavor project management, YAML config, CLI, shared library, gotchas | [`references/rail-projects.md`](references/rail-projects.md) |
