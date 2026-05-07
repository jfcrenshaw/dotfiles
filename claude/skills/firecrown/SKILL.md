---
name: firecrown
description: Guide to Firecrown, the DESC likelihood framework for cosmological parameter inference. Covers the Likelihood/Statistic/Systematic/ModelingTools architecture, two-point statistics (angular power spectra and correlation functions), systematic effects (intrinsic alignment, photo-z shifts, multiplicative shear bias, galaxy bias), sacc as the data container interface, and connectors to CosmoSIS, NumCosmo, and Cobaya. Also covers the TXPipe→Firecrown data flow via sacc files. Use this skill whenever the user imports firecrown, works with likelihood objects, builds a Firecrown analysis, connects to CosmoSIS or NumCosmo, reads or writes sacc files for inference, asks about DESC likelihood inference, or calls `load_likelihood` / `build_likelihood`.
---

# Firecrown — DESC likelihood and parameter inference framework

You're helping a user write code with Firecrown, DESC's framework for implementing and running cosmological likelihoods.
Firecrown sits downstream of TXPipe (which produces sacc files) and upstream of samplers (CosmoSIS, NumCosmo, Cobaya); it uses pyccl for all theory predictions.

## Overview

**Package layout:**
- `firecrown.likelihood` — `Likelihood`, `Statistic`, `Source`, `GaussFamily`, `ConstGaussian`, `TwoPoint`, `WeakLensing`, `NumberCounts`, and all systematics
- `firecrown.modeling_tools` — `ModelingTools` (wraps `pyccl.Cosmology`) and `CCLFactory`
- `firecrown.parameters` — `ParamsMap`, `RequiredParameters`, `UpdatableCollection`
- `firecrown.connector` — `cosmosis`, `numcosmo`, `cobaya` sub-packages

**Lifecycle every call:** `update(params)` → `tools.prepare(cosmo)` → `compute_theory_vector(tools)` → `compute_loglike(tools)`

**Systematics are applied sequentially:** each systematic in a source's list receives the current source state and returns a modified version — order matters.

**Entry point — every Firecrown likelihood file must define:**
```python
def build_likelihood(build_parameters: dict) -> tuple[Likelihood, ModelingTools]:
    ...
    return lk, tools
```
The samplers and TXPipe both call `load_likelihood_from_script(path, build_parameters)`.

**Minimal 3×2pt example** (real-space):
```python
import firecrown.likelihood.weak_lensing as wl
import firecrown.likelihood.number_counts as nc
from firecrown.likelihood.two_point import TwoPoint
from firecrown.likelihood.gaussian import ConstGaussian
from firecrown.modeling_tools import ModelingTools
import sacc

def build_likelihood(build_parameters):
    sacc_data = sacc.Sacc.load_fits(build_parameters["sacc_file"])

    sources = {}
    for name in sacc_data.tracers:
        if name.startswith("source"):
            sources[name] = wl.WeakLensing(sacc_tracer=name, systematics=[
                wl.PhotoZShift(sacc_tracer=name),
                wl.MultiplicativeShearBias(sacc_tracer=name),
            ])
        elif name.startswith("lens"):
            sources[name] = nc.NumberCounts(sacc_tracer=name, systematics=[
                nc.LinearBiasSystematic(sacc_tracer=name),
            ])

    stats = {}
    for dt in sacc_data.get_data_types():
        for t1, t2 in sacc_data.get_tracer_combinations(dt):
            stat = TwoPoint(source0=sources[t1], source1=sources[t2], sacc_data_type=dt)
            stats[f"{dt}_{t1}_{t2}"] = stat

    lk = ConstGaussian(statistics=list(stats.values()))
    lk.read(sacc_data)
    return lk, ModelingTools()
```

See [`references/api.md`](references/api.md) for systematic parameters, sacc data-type strings, and sampler connectors.

## TXPipe usage

TXPipe connects to Firecrown via sacc files; some internal stages also call `load_likelihood_from_script` directly for theory predictions.
See [`references/txpipe.md`](references/txpipe.md) for the full data flow, stage list, and tracer naming conventions.

## Reference

| Topic | Reference |
|---|---|
| Systematic classes, parameters, sampler connectors, gotchas | [`references/api.md`](references/api.md) |
| TXPipe data flow, stages, sacc tracer naming | [`references/txpipe.md`](references/txpipe.md) |
