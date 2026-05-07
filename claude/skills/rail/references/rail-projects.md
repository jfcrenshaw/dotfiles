# rail_projects — multi-flavor project management

## Contents

- [Overview](#overview)
- [Core concepts](#core-concepts)
- [Primary workflow](#primary-workflow)
- [CLI interface](#cli-interface)
- [Project YAML structure](#project-yaml-structure)
- [Shared library YAML](#shared-library-yaml)
- [RailFlavor config options](#railflavor-config-options)
- [Gotchas](#gotchas)

---

## Overview

`rail_projects` provides `RailProject`: a top-level driver that manages a collection of related analyses differing by algorithm choice, input data, or configuration.
It handles file path bookkeeping, pipeline building, and running across multiple **Flavors** and **Selections**.

```python
from rail.projects import RailProject
```

---

## Core concepts

| Concept | Class | Description |
|---|---|---|
| **Project** | `RailProject` | Top-level config: which pipelines, flavors, and selections to use |
| **Flavor** | `RailFlavor` | One analysis variant — a name, a `catalog_tag`, pipelines to run, and optional config overrides |
| **Selection** | `RailSelection` | A data selection (e.g., magnitude cut, footprint mask) |
| **Pipeline** | `RailPipelineTemplate` | A reference to a `RailPipeline` class + its input/output catalog templates |
| **Catalog** | `RailProjectCatalogTemplate` | A templated file path (filled in from `IterationVars` and `CommonPaths`) |
| **Library** | `rail.projects.library` | Shared pool of algorithms, pipelines, catalogs — loaded from YAML `Includes` |

---

## Primary workflow

```python
from rail.projects import RailProject

# 1. Load project from YAML
project = RailProject.load_config("my_project.yaml")

# 2. Build ceci YAML pipeline files (one per flavor × pipeline combination)
project.build_pipelines(flavor="baseline")

# 3a. Run on a single file
project.run_pipeline_single(flavor="baseline", selection="gold")

# 3b. Run on all catalog files (iterates over IterationVars)
project.run_pipeline_catalog(flavor="baseline", selection="gold")

# Data preparation helpers
project.reduce_data(flavor="baseline", selection="gold")   # apply selection + trim columns
project.subsample_data(flavor="baseline", selection="gold") # subsample for train/test splits
project.split_data(flavor="baseline", selection="gold")     # train/test split from one file
```

---

## CLI interface

```bash
# Inspect project config
rail-project inspect my_project.yaml

# Build ceci pipeline YAML files
rail-project build my_project.yaml --flavor baseline

# Split into train/test
rail-project split my_project.yaml --flavor baseline --selection gold

# Subsample
rail-project subsample my_project.yaml --flavor baseline

# Run a pipeline
rail-project run pz my_project.yaml --flavor baseline --selection gold
```

---

## Project YAML structure

```yaml
Project:
  Name: my_analysis

  # Paths — must override root, scratch_root, project
  CommonPaths:
    root: /global/cfs/cdirs/desc-wl/users/<user>/data
    scratch_root: /pscratch/sd/<l>/<user>
    project: my_analysis
    # Derived defaults (can be overridden):
    # project_dir: {root}/projects/{project}
    # catalogs_dir: {root}/catalogs
    # pipelines_dir: {project_dir}/pipelines

  # Optional path template overrides
  PathTemplates:
    pipeline_path: "{pipelines_dir}/{pipeline}_{flavor}.yaml"
    ceci_output_dir: "{project_dir}/data/{selection}_{flavor}"

  # Include shared library files (algorithms, pipeline templates, catalogs)
  Includes:
    - /path/to/shared_library.yaml

  # Baseline flavor — always present; other flavors inherit from it
  Baseline:
    Flavor:
      name: baseline
      catalog_tag: lsst_dp0
      pipelines: [pz, shear]

  # Additional analysis variants
  Flavors:
    - Flavor:
        name: bpz_run
        pipeline_overrides:
          pz:
            PZAlgorithm: bpz

  # Iteration variables (e.g., healpix patch IDs for multi-file catalogs)
  IterationVars:
    patch: [0, 1, 2, 3]

  # Selections, subsamples, and algorithms are resolved from the shared library
  Selections: [gold, silver]
  PZAlgorithms: [fzboost, bpz]
  Summarizers: [naive_stack]
```

---

## Shared library YAML

`Includes` loads one or more YAML files that define reusable components.
These are registered in `rail.projects.library` and shared across projects.

```yaml
# shared_library.yaml
Pipelines:
  - PipelineTemplate:
      name: pz
      pipeline_class: rail.pipelines.estimation.pz_all.PzPipeline
      input_catalog_template: degraded
      output_catalog_template: pz_output
      kwargs:
        algorithms: [all]

PZAlgorithms:
  - Algorithm:
      name: fzboost
      Inform: FlexZBoostInformer
      Estimate: FlexZBoostEstimator
      Module: rail.estimation.algos.flexzboost
```

---

## RailFlavor config options

| Key | Default | Description |
|---|---|---|
| `name` | required | Flavor name; used in file path templates |
| `catalog_tag` | `None` | Identifies column name convention (sets `CatalogTag`) |
| `pipelines` | `["all"]` | Which pipeline templates to run in this flavor |
| `file_aliases` | `{}` | Override specific input file paths for this flavor |
| `pipeline_overrides` | `{}` | Per-pipeline config key overrides |

---

## Gotchas

1. **`load_config` is a classmethod and registers the project globally.** Subsequent calls with the same name update `RailProject.projects[name]`. Don't instantiate `RailProject` directly — always use `load_config`.

2. **`CommonPaths.root`, `scratch_root`, and `project` have no useful defaults.** The defaults are `"."` — always override them or all file paths will land in the current directory.

3. **`Includes` are cumulative across all projects in the Python session.** Library items loaded by one project are visible to all subsequent projects. Reload with `library.clear()` if you need isolation.

4. **`pipeline_overrides` changes config values, not the pipeline DAG.** You can change algorithm parameters for a flavor but you cannot add or remove stages this way.

5. **`IterationVars` drives multi-file catalogs.** If your catalog is split into healpix patches, define `IterationVars: {patch: [0, 1, 2, ...]}` — `run_pipeline_catalog` will iterate over all combinations.

6. **`build_pipelines` calls `pipeline.save()` internally.** The `pipelines_dir` must exist before calling it. `RailProject` does not create directories.

7. **`catalog_tag` must match a registered `CatalogTag`.** If it's not registered, `get_active_tag()` will fail inside pipeline stages. Register custom tags via `CatalogTag.register()` before loading the project.
