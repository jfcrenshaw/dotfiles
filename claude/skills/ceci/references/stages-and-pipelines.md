# ceci — DESC pipeline framework

Ceci is the lightweight pipeline framework that underpins most DESC analysis packages (TXPipe, RAIL, etc.).
It separates *stage implementation* (Python subclasses) from *pipeline configuration* (YAML files), and handles execution order, file I/O, MPI, and provenance tracking automatically.

Docs: <https://ceci.readthedocs.io/en/latest/>
Repo: <https://github.com/LSSTDESC/ceci>
Template: `cookiecutter https://github.com/LSSTDESC/pipeline-package-template`

**Source indexed in qmd** — search `collection:"ceci"` for method signatures, class hierarchy, and config internals before consulting docs or training data.

---

## Contents

- [Core model](#core-model)
- [Defining a stage](#defining-a-stage)
- [File types](#file-types)
- [Parallel iteration helpers](#parallel-iteration-helpers)
- [MPI patterns](#mpi-patterns)
- [Pipeline YAML](#pipeline-yaml)
- [Aliasing (running a stage multiple times)](#aliasing-running-a-stage-multiple-times)
- [CLI patterns](#cli-patterns)
- [Launchers](#launchers)
- [Package structure](#package-structure)
- [Common gotchas](#common-gotchas)

---

## Core model

A **stage** is a Python class with declared inputs, outputs, config, and a `run()` method.
A **pipeline** is a YAML file that lists which stages to run, external inputs, output directories, and per-stage resource requests.
Ceci resolves execution order automatically from the tag dependency graph — stage order in the YAML does not matter.

---

## Defining a stage

```python
from ceci import PipelineStage
from ceci.file_types import HDFFile, FitsFile, YamlFile, TextFile

class MyStage(PipelineStage):
    name = "MyStage"  # must be unique across the pipeline

    inputs = [
        ("shear_catalog", HDFFile),
        ("config_data",   YamlFile),
    ]
    outputs = [
        ("result_catalog", HDFFile),
        ("summary",        TextFile),
    ]
    config_options = {
        "quality_cut":  float,      # required, no default
        "n_bins":       10,         # int default
        "zbin_edges":   [float],    # list of floats
        "label":        "",         # str default
    }

    def run(self):
        cut = self.config["quality_cut"]
        n   = self.config["n_bins"]

        # --- reading ---
        with self.open_input("shear_catalog", wrapper=True) as f:
            data = f.file["shear/g1"][:]        # h5py group access

        # --- or just get the path and open manually ---
        path = self.get_input("config_data")

        # --- writing ---
        with self.open_output("result_catalog", wrapper=True) as out:
            out.file.create_dataset("result/x", data=data)

        with self.open_output("summary") as f:
            f.write("done\n")
```

**Critical rules:**
- `name` class attribute is required and must be unique.
- `inputs` and `outputs` are **lists of (tag, FileType) tuples**, not dicts.
  (Some older code uses dicts; lists are the current convention.)
- Every declared output **must** be written on every execution — no conditional outputs.
- Config values are accessed via `self.config["key"]`.
  In `config_options`, a bare type (`float`) means required; a value (`10`) is the default.

**Automatic execution wrappers (don't call directly):**
- Output files are created as `inprogress_<name>` and atomically renamed on success.
- `self.execute()` handles profiling, memory monitoring, exception formatting, and cleanup.

---

## File types

| Class | Extension | Notes |
|---|---|---|
| `HDFFile` | `.hdf5` | h5py; parallel I/O under MPI; provenance in HDF5 group |
| `FitsFile` | `.fits` | fitsio; 'w' mode silently becomes 'rw' |
| `YamlFile` | `.yml` | load modes: "safe" (default), "full", "unsafe" |
| `TextFile` | `.txt` | plain text; no special features |
| `PNGFile` | `.png` | write-only; matplotlib |
| `PickleFile` | `.pkl` | binary Python objects |
| `ParquetFile` | `.parquet` | read-only; pyarrow |
| `Directory` | (dir) | directory-based storage; provenance.yml written alongside |
| `FileCollection` | `.list` | dynamic multi-file collections |

`open_input` / `open_output` return the raw file handle unless `wrapper=True`, in which case they return the `DataFile` wrapper object (exposes `.file`, `.path`, and provenance methods).

---

## Parallel iteration helpers

For chunked reads over large FITS or HDF5 files under MPI:

```python
# HDF5 — yields (start, end, {tag: chunk_dict})
for start, end, data in self.iterate_hdf("shear_catalog", "shear", ["g1","g2","w"], chunk_rows=10_000):
    process(data["g1"], data["g2"])

# FITS — yields (start, end, {tag: recarray})
for start, end, data in self.iterate_fits("shear_catalog", ["g1","g2"], chunk_rows=10_000):
    process(data["g1"])

# Combined — multiple files iterated together in lock-step
for start, end, data in self.combined_iterators(10_000,
        hdf_cols={"shear_catalog": ("shear", ["g1","g2"])},
        fits_cols={"lens_catalog": ["ra","dec"]}):
    ...
```

---

## MPI patterns

```python
class ParallelStage(PipelineStage):
    ...
    def run(self):
        rank, size = self.rank, self.size
        comm = self.comm

        # Round-robin task distribution
        my_tasks = self.split_tasks_by_rank(all_tasks)
        # Or contiguous block distribution
        my_tasks = self.map_tasks_by_rank(all_tasks)

        results = [compute(t) for t in my_tasks]

        comm.Barrier()

        # Gather to rank 0
        all_results = comm.gather(results, root=0)
        if self.rank == 0:
            flat = [x for sub in all_results for x in sub]
            with self.open_output("result_catalog", wrapper=True) as out:
                out.file.create_dataset("data", data=flat)
```

**MPI gotchas:**
- All ranks must reach `Barrier()` calls — never branch before a Barrier without ensuring all ranks take the same path.
- Only rank 0 should write outputs unless using parallel HDF5 collective I/O.
- Stage YAML must set `nprocess: N` for N > 1 MPI ranks.

---

## Pipeline YAML

```yaml
# pipeline.yml
modules: my_package   # space-separated list of Python packages to import; registers all stage classes

launcher:
  name: mini         # "mini" (lightweight) or "parsl" (full HPC)
  interval: 3        # seconds between completion checks (mini only)

site:
  name: local                  # "local" | "nersc-interactive" | "nersc-batch"
  max_threads: 4

# For nersc-batch:
# site:
#   name: nersc-batch
#   queue: regular             # debug | regular | premium
#   account: desc
#   max_jobs: 5
#   walltime: 1800             # seconds

stages:
  - name: MyStage
    nprocess: 1
    threads_per_process: 2
    nodes: 1

  - name: AnotherStage
    nprocess: 4               # 4 MPI ranks

inputs:
  shear_catalog: /path/to/shear.hdf5
  config_data:   ./config/params.yml

output_dir: ./outputs
log_dir:    ./logs
config:     ./config/pipeline_config.yml

resume: false   # true = skip stages whose outputs already exist
```

**Per-stage config** goes in the file referenced by `config:`:
```yaml
# pipeline_config.yml
MyStage:
  quality_cut: 0.3
  n_bins: 20
  zbin_edges: [0.0, 0.5, 1.0, 2.0]
AnotherStage:
  threshold: 5.0
```

---

## Aliasing (running a stage multiple times)

To run the same stage class on different data, give each instance a unique name via `classname:` and redirect its input/output tags via `aliases:`:

```yaml
stages:
  - name: PZEstimation_Sources      # unique DAG name
    classname: PZEstimation         # actual registered class
    aliases:
      photometry: source_photometry # this instance reads "source_photometry"
      pz_output:  source_pz

  - name: PZEstimation_Lenses
    classname: PZEstimation
    aliases:
      photometry: lens_photometry
      pz_output:  lens_pz
```

And in the config file, use the **DAG name** (not the class name) as the block key, and include a `name:` key matching the DAG name (see gotcha 12):

```yaml
PZEstimation_Sources:
  name: PZEstimation_Sources
  param: value

PZEstimation_Lenses:
  name: PZEstimation_Lenses
  param: other_value
```

---

## CLI patterns

```bash
# Run pipeline
ceci pipeline.yml

# Dry-run — print commands without executing
ceci --dry-run pipeline.yml

# Visualise dependency graph (implies --dry-run)
ceci --flow-chart pipeline.yml

# Jinja2 template substitution
ceci pipeline.yml -t specprod=iron -t nside=512

# Override config values on the command line
ceci pipeline.yml --MyStage.quality_cut=0.5
```

---

## Launchers

| Launcher | Use | Notes |
|---|---|---|
| `mini` | Local dev, interactive NERSC | No external deps; uses subprocess; cannot submit batch jobs itself |
| `parsl` | Production HPC, NERSC batch | Full workflow manager; integrates with SLURM |

On NERSC **interactive**: use `site: nersc-interactive` after `salloc`; ceci launches tasks via `srun` onto compute nodes.
On NERSC **batch**: use `site: nersc-batch` *or* call `ceci` from inside an `sbatch` script with the `mini` launcher — the mini launcher is not itself a batch submitter.

---

## Package structure

Created via cookiecutter template:

```
my_pipeline/
├── __init__.py       # from .stage1 import *; from .stage2 import *
├── __main__.py       # PipelineStage.main()
├── stage1.py
├── stage2.py
├── types.py          # custom DataFile subclasses if needed
├── pipeline.yml
└── config.yml
```

`__main__.py` must call `PipelineStage.main()` so individual stages can be run directly:
```bash
python -m my_pipeline MyStage --input shear_catalog=/path/... --output result_catalog=/path/... --config config.yml
```

---

## Common gotchas

1. **`inputs`/`outputs` are lists of tuples, not dicts.** `[("tag", FileType)]` is the correct form; dict syntax is deprecated and may break.
2. **All outputs must be written every run.** Undeclared-but-written files are ignored; declared-but-missing files cause a crash on rename.
3. **Tag names are global.** If two stages in the same pipeline use the same output tag, the pipeline fails at construction time — use aliasing.
4. **Stage order in YAML is irrelevant.** Ceci builds a DAG from tags. Never rely on YAML order.
5. **`resume: true` skips stages with existing outputs** — if you re-run after changing a stage, delete its outputs or set `resume: false`.
6. **Config file is required** even if empty (`config: ./empty.yml` with `{}`). Missing config raises a confusing error.
7. **`nprocess > 1` requires MPI to be available.** On login nodes this will either fail or silently run single-process. Always test in an allocation.
8. **FitsFile write mode 'w' → 'rw'.** fitsio limitation; don't rely on overwriting via mode 'w'.
9. **Memory monitor runs in a background thread.** Large in-memory operations may log false-alarm warnings; ignore unless it pages out.
10. **`modules:` in pipeline YAML must be importable.** If the package isn't installed or on `PYTHONPATH`, ceci fails silently with a stage-not-found error rather than an import error.
11. **`python_paths:` does NOT register stage classes — `modules:` does.** `python_paths:` only calls `sys.path.append()` for each entry. `modules:` calls `__import__()` on each name, which executes `__init__.py` and registers stage subclasses. Additionally, ceci automatically appends the current working directory to `sys.path` at startup, so `python_paths:` is never needed for local stages under the repo root. Symptom of the bug: `StageNotFound` even though the class exists — because `modules:` was omitted.
12. **When using `classname:`, you must add `name: <DAG-name>` to each config block.** Ceci's `instance_name` property resolves via `self._configs.get("name", self.name)`. If the `name` key is absent from the config block, it falls back to the class's `name` attribute (e.g., `SpecSelection_DESI_Phy`), which doesn't match any key in `stage_execution_config` → `KeyError` at pipeline startup. Fix: add `name: DESISelectionELG` (matching the YAML stage `name:`) to each config block.
