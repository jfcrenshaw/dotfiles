---
name: txpipe
description: How to work with TXPipe, the DESC 3×2pt weak-lensing pipeline. Covers all pipeline phases (ingestion → photo-z → selection → calibration → masks → maps → noise maps → 2pt → covariance → theory → diagnostics), key stage names, file tags, pipeline YAML structure, and critical gotchas. Use this skill whenever the user imports txpipe, works with TXPipe stages, writes a TXPipe pipeline YAML, or asks about catalog processing, map generation, two-point measurements, or covariance estimation.
---

# TXPipe — DESC 3×2pt weak-lensing pipeline

You're helping a user work with TXPipe, the main DESC analysis workhorse.
TXPipe processes shear and photometric catalogs through sample selection, map generation, two-point measurements (real and Fourier space), covariance estimation, theory comparison, and diagnostics.
All stages are ceci `PipelineStage` subclasses; for ceci conventions see the `ceci` skill.
For NERSC job submission, see the `nersc` skill.

## Pipeline phases (in order)

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

## Reference

| Topic | Reference |
|---|---|
| All 15 pipeline phases and stage names | [`references/txpipe-stages.md`](references/txpipe-stages.md) |
| Key file types, pipeline YAML structure, example pipelines, gotchas | [`references/txpipe-pipeline.md`](references/txpipe-pipeline.md) |
