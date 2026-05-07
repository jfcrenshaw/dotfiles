# RAIL — Redshift Assessment Infrastructure Layers

RAIL is the DESC photo-z framework built on ceci.
It extends ceci's `PipelineStage` with a `DataStore`/`DataHandle` pattern and organises the full photo-z lifecycle into three modules: `rail.creation` (simulation), `rail.estimation` (photo-z algorithms), `rail.evaluation` (metrics).

Paper: RAIL Team et al. 2025, arXiv:2505.02928
Docs: <https://rail-hub.readthedocs.io/en/latest/>
Umbrella repo: <https://github.com/LSSTDESC/rail>
Sub-packages: rail_base, rail_astro_tools, rail_pipelines, rail_projects, rail_som, rail_sompz, rail_yaw, rail_lephare, rail_fsps, rail_dsps, …

**Source indexed in qmd** — search `collection:"rail"` for stage class definitions, DataHandle subclasses, config options, and algorithm implementations before consulting docs or training data.

---

## Contents

- [Namespace architecture](#namespace-architecture)
- [Three main modules](#three-main-modules)
- [RailStage — how it extends PipelineStage](#railstage--how-it-extends-pipelinestage)
- [DataHandle types](#datahandle-types)
- [Base class hierarchy (creation module)](#base-class-hierarchy-creation-module)
- [Estimation module (brief)](#estimation-module-brief)
- [Building a ceci pipeline with RAIL stages](#building-a-ceci-pipeline-with-rail-stages)
- [Important packages](#important-packages)
- [Common gotchas](#common-gotchas)

---

## Namespace architecture

RAIL is distributed across many repos that all contribute to the `rail.*` namespace via setuptools entry-points.
Installing `rail` (the umbrella package) pulls in the core; additional algorithm packages (e.g. `rail_bpz`, `rail_flexzboost`) register themselves into `rail.estimation.algos` on install.
You never import from `rail_base` directly — always use the `rail.*` path:

```python
from rail.creation.degraders.photometric_errors import LSSTErrorModel
from rail.creation.degraders.quantity_cuts import QuantityCut
from rail.creation.degraders.observing_condition_degrader import ObsCondition
from rail.creation.degraders.desi_selector_phy import SpecSelection_DESI_Phy
from rail.estimation.estimator import CatEstimator
from rail.core.data import TableHandle, PqHandle, Hdf5Handle, QPHandle, ModelHandle
```

In pipeline YAML, list whichever packages supply the stages you use:
```yaml
modules:
  - rail.creation
  - rail.estimation
  - rail_astro_tools   # for SpecSelection_DESI_Phy, ObsCondition
```

---

## Three main modules

| Module | Purpose | Key classes |
|---|---|---|
| `rail.creation` | Simulate catalogs, degrade photometry | Degrader, Noisifier, Selector, Creator |
| `rail.estimation` | Train and run photo-z algorithms | CatInformer, CatEstimator, CatSummarizer |
| `rail.evaluation` | Compute photo-z quality metrics | Evaluator, PointToPointEvaluator, etc. |
| `rail.core` | Infrastructure | RailStage, DataStore, DataHandle subclasses |

---

## RailStage — how it extends PipelineStage

`RailStage` inherits from `ceci.PipelineStage` and adds:

| Feature | ceci PipelineStage | RailStage |
|---|---|---|
| Data access | `self.open_input(tag)` / `self.open_output(tag)` | + `self.get_data(tag)`, `self.set_data(tag, data)`, `self.add_data(tag, data)` |
| Tag aliasing | Not supported | Full aliasing for multi-instance pipelines |
| Data routing | File tags only | File tags + in-memory DataStore |
| Iteration | `self.iterate_hdf()` etc. | + `self.input_iterator(tag)` |

In practice, most RAIL stages use `self.get_data()` / `self.add_data()` instead of `self.open_input()` / `self.open_output()`, but the ceci-level file tag system still applies in pipeline YAML.

**Config options — use `StageParameter`, not plain dict:**

```python
from ceci.config import StageParameter

class MyStage(RailStage):
    config_options = RailStage.config_options.copy()   # inherit base params (required)
    config_options.update(dict(
        my_float=StageParameter(float, 1.0, msg="human-readable description"),
        my_list=StageParameter(list, [1, 2, 3], msg="..."),
        my_dict=StageParameter(dict, {}, msg="..."),
    ))
```

- Omitting `.copy()` silently drops base-class params (e.g. `output_path`, `aliases`).
- Access values via **dot notation**: `self.config.my_float` (not `self.config["my_float"]`).

**Getting output path for external tools:**

```python
out_path = self.get_output("output_catalog", final_name=True)
# returns str — the resolved permanent filesystem path
# use this when passing the path to an external function instead of self.add_data()
```

**Source stages (no upstream ceci dependency):**

Declare `inputs = []` for stages that read directly from the filesystem.
Ceci handles an empty inputs list correctly with no special treatment.

**Minimal custom stage skeleton:**
```python
from rail.core.stage import RailStage
from rail.core.data import PqHandle

class MyStage(RailStage):
    name = "MyStage"
    inputs  = [("input",  PqHandle)]
    outputs = [("output", PqHandle)]
    config_options = {"my_param": float, "seed": 42}

    def run(self):
        data = self.get_data("input")      # returns pandas DataFrame
        # ... transform ...
        self.add_data("output", result)    # result is a DataFrame
```

---

## DataHandle types

All RAIL I/O is mediated by DataHandle subclasses that wrap format-specific read/write:

| Class | File format | Typical use |
|---|---|---|
| `PqHandle` | Parquet | Catalog tables (preferred for large catalogs) |
| `Hdf5Handle` | HDF5 | Catalog tables with groups (default group: `photometry`) |
| `FitsHandle` | FITS | Legacy astronomical tables |
| `TableHandle` | Any tabular | Generic; dispatches to the above |
| `QPHandle` | qp.Ensemble | Per-galaxy photo-z PDFs and n(z) ensembles |
| `QPDictHandle` | dict of qp.Ensemble | Multiple ensembles (e.g. per-bin n(z)) |
| `ModelHandle` | Pickle | Trained ML models |

Use `PqHandle` or `Hdf5Handle` for all catalog stages — avoid `FitsHandle` for large tables.

---

## Base class hierarchy (creation module)

```
RailStage  (extends ceci.PipelineStage)
└── Degrader          (one isolated degradation effect)
    ├── Noisifier     (adds noise; output size = input size)
    │   └── PhotoErrorModel → LSSTErrorModel, EuclidErrorModel, RomanErrorModel
    └── Selector      (removes rows; output size ≤ input size)
        ├── QuantityCut
        ├── SpecSelection → SpecSelection_DESI_Phy, SpecSelection_DESI_LRG, …
        ├── GridSelection
        └── SOMSpecSelector
```

Design rule: each Degrader models **one** effect. Chain them in series for a full simulation pipeline.

---

## Estimation module (brief)

Typical estimation pipeline: Informer (train) → Estimator (predict per-galaxy PDFs) → Summarizer (stack to n(z))

| Class | Input | Output | Method |
|---|---|---|---|
| `CatInformer` | `TableHandle` (training catalog) | `ModelHandle` | `inform()` |
| `CatEstimator` | `TableHandle` (test catalog) + `ModelHandle` | `QPHandle` | `estimate()` |
| `CatSummarizer` | `QPHandle` + `ModelHandle` | `QPHandle` (n(z)) | `summarize()` |
| `PZSummarizer` | `QPHandle` (per-galaxy PDFs) | `QPHandle` (ensemble n(z)) | `summarize()` |
| `SZPZSummarizer` | `TableHandle` (spec) + `QPHandle` (photo) | `QPHandle` | — |

Key shared config: `zmin`, `zmax`, `nzbins`, `chunk_size` (default 10 000), `calculated_point_estimates` (list of `"mean"`, `"mode"`, `"median"`).

TXPipe expects the summarizer output (`QPNOfZFile` / `QPHandle`) as input to `PZRailSummarizeLens/Source` and downstream 2pt stages.

---

## Building a ceci pipeline with RAIL stages

RAIL stages work in a standard ceci pipeline YAML. The only differences from a TXPipe pipeline are:
- `modules:` must import the rail packages that provide the stages
- Stage `name` must match the class-level `name` attribute exactly
- Per-stage config goes in a separate `config.yml` keyed by stage name

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
  - name: QuantityCut             # column pre-selection
  - name: ObsCondition            # SFD reddening + depth
  - name: LSSTErrorModel          # photometric errors
  - name: SpecSelection_DESI_Phy  # physics-based DESI spec selection

inputs:
  input: /path/to/catalog.pq
```

```yaml
# config.yml
QuantityCut:
  cuts:
    redshift: 3.5
    mag_i_lsst: 26.0

ObsCondition:
  nside: 128
  map_dict:
    EBV: /path/to/ebv_map.fits
    # add m5, nVisYr, etc. for depth variation

LSSTErrorModel:
  bands: [u, g, r, i, z, y]
  err_bands: [mag_err_u_lsst, mag_err_g_lsst, mag_err_r_lsst, mag_err_i_lsst, mag_err_z_lsst, mag_err_y_lsst]
  seed: 42

SpecSelection_DESI_Phy:
  desi_type: lrg
  threshold_col: log_peak_sub_halo_mass
  redshift_col: redshift
  threshold_table: /path/to/thresholds.pq
```

---

## Important packages

| Package | What it adds to the `rail.*` namespace |
|---|---|
| `rail_base` | Core infrastructure: RailStage, DataHandle, DataStore, all base classes |
| `rail_astro_tools` | `ObsCondition`, `SpecSelection_DESI_Phy`, `IGMExtinctionModel` |
| `rail_pipelines` | Pre-built pipeline YAML templates (good for reference) |
| `rail_projects` | Project-level pipeline management (CLI tools; user unlikely to use directly) |
| `rail_som` / `rail_sompz` | SOM-based photo-z estimation and n(z) calibration |
| `rail_yaw` | Yet-Another-Wizard: angular cross-correlation n(z) calibration |
| `rail_lephare` | LePHARE SED template photo-z estimator |
| `rail_fsps` / `rail_dsps` | SED-based catalog generation from galaxy physical properties |

---

## Common gotchas

1. **`self.add_data()` not `self.open_output()`.** RailStage stages use `self.add_data(tag, df)` to register outputs, not the ceci `open_output` context manager. Mixing the two in the same stage breaks the DataStore.

2. **HDF5 group name matters.** `Hdf5Handle` defaults to reading/writing the `photometry` group. If your HDF5 file uses a different group, pass `groupname=` in the config or the stage will silently read an empty table.

3. **`modules:` must include every package that supplies a stage.** If a stage class can't be found, ceci gives a `StageNotFound` error rather than an import error. Add the relevant `rail_*` package to `modules:`.

4. **qp.Ensemble ≠ pandas DataFrame.** `QPHandle` stores a `qp.Ensemble` object, not a table. You cannot pass it to a stage expecting `PqHandle`/`Hdf5Handle`. The conversion is explicit (`ensemble.to_tables()` / `qp.from_tables()`).

5. **`nside` in `ObsCondition` must match your EBV map resolution.** Mismatched nside causes incorrect extinction values with no error message.

6. **SharedParams define the global redshift grid.** `rail.core.common_params.RAILBIRD_SHARED_PARAMS` (or `SharedParams`) controls `zmin`, `zmax`, `nzbins` used by default across stages. Override per-stage in config if you need non-default grids.

7. **`self.config["key"]` raises KeyError — use dot access.** RailStage config values must be accessed as `self.config.key`, not `self.config["key"]`. The latter is ceci `PipelineStage` syntax and does not work on the `RailStage` config object.
