# Firecrown in TXPipe

TXPipe and Firecrown connect **purely through sacc files** for the sampling use case — no TXPipe stage calls Firecrown's sampler connectors directly.

## Data flow

```
TXTwoPoint / TXTwoPointFourier
    → twopoint_data_real_raw / twopoint_data_fourier  (SACCFile)
    → [TXBlinding, TXCovariance*]
    → twopoint_data_real / twopoint_data_fourier  (final SACCFile)
    → [hand off to CosmoSIS/NumCosmo/Cobaya with Firecrown connector]
```

## Internal theory usage

TXPipe **does** call Firecrown internally for theory predictions via `txpipe/utils/theory.py::theory_3x2pt()`, which calls `load_likelihood_from_script` using `txpipe/utils/theory_model.py` as the likelihood script.
This powers `TXTwoPointTheoryReal` and `TXTwoPointTheoryFourier` (theory-prediction-only stages, not samplers).
`TXBlinding` also imports firecrown to compute cosmology-shift theory vectors.

## Tracer naming conventions

TXPipe sacc files use: `source_0`, `source_1`, … (weak lensing) and `lens_0`, `lens_1`, … (number counts).
These names feed directly into `sacc_tracer=` arguments in Firecrown source constructors.
