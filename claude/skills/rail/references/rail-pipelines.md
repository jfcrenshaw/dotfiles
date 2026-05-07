# rail_pipelines — pipeline-as-code with RailPipeline

## Contents

- [Overview](#overview)
- [Defining a pipeline](#defining-a-pipeline)
- [Saving to YAML](#saving-to-yaml)
- [Pre-built pipelines](#pre-built-pipelines)
- [CatalogTag and column name mapping](#catalogtag-and-column-name-mapping)
- [When to use RailPipeline vs YAML](#when-to-use-railpipeline-vs-yaml)
- [Gotchas](#gotchas)

---

## Overview

`rail_pipelines` provides two things:

1. **`RailPipeline`** (in `rail.core.stage`) — the base class for defining pipelines in Python code rather than YAML.
2. **Pre-built pipelines** (in `rail.pipelines.*`) — ready-to-use `RailPipeline` subclasses for common workflows.

`RailPipeline` is complementary to ceci YAML pipelines.
Use it when you need programmatic control — dynamic stage lists, parametric pipelines, or pipelines that are too complex to express statically in YAML.
The output of `RailPipeline` is a ceci-compatible YAML file.

---

## Defining a pipeline

Subclass `RailPipeline`.
In `__init__`, call `Stage.build(...)` for each stage and assign it to `self.<name>`.

```python
from rail.core.stage import RailPipeline, RailStage
from rail.estimation.algos.train_z import TrainZInformer, TrainZEstimator
from rail.evaluation.single_evaluator import SingleEvaluator

class TrainZPipeline(RailPipeline):
    default_input_dict: dict[str, str] = dict(
        input_train="dummy.in",
        input_test="dummy.in",
    )

    def __init__(self) -> None:
        RailPipeline.__init__(self)

        self.inform = TrainZInformer.build(
            aliases=dict(input="input_train"),
            hdf5_groupname="",
        )

        self.estimate = TrainZEstimator.build(
            aliases=dict(input="input_test"),
            connections=dict(model=self.inform.io.model),
            hdf5_groupname="",
        )

        self.evaluate = SingleEvaluator.build(
            aliases=dict(truth="input_test"),
            connections=dict(input=self.estimate.io.output),
            point_estimates=["mode"],
            truth_point_estimates=["redshift"],
            metrics=["all"],
            hdf5_groupname="",
        )
```

### `Stage.build()` arguments

| Argument | Type | Purpose |
|---|---|---|
| `aliases` | `dict[str, str]` | Map stage I/O tags to pipeline-level global tags (external inputs/outputs) |
| `connections` | `dict[str, handle]` | Wire outputs from other stages: `dict(input=other.io.output)` |
| `**config` | kwargs | Stage config options (same as `config_options` keys) |

### Wiring rules

- `connections=dict(tag=other_stage.io.tag)` — `other_stage.io.tag` is the output handle of another stage.
- `aliases=dict(tag="global_name")` — names an I/O endpoint at the pipeline level (appears in `default_input_dict` or as a pipeline output).
- An I/O tag must be covered by exactly one of `connections` or `aliases`.

### `default_input_dict`

Declares the pipeline's external inputs.
Values are placeholder paths (`"dummy.in"`) — they get replaced when the pipeline is run or serialized.

---

## Saving to YAML

```python
pipeline = TrainZPipeline()
pipeline.save("my_pipeline.yaml")
```

The YAML is ceci-compatible and can be run with `ceci my_pipeline.yaml`.
`RailProject.build_pipelines()` calls this internally for each flavor.

---

## Pre-built pipelines

### `rail.pipelines.estimation`

| Class | Module | Description |
|---|---|---|
| `TrainZPipeline` | `train_z_pipeline` | TrainZ inform → estimate → evaluate |
| `YawPipeline` | `build_pipeline` | Clustering redshift pipeline (rail_yaw) |

### `rail.pipelines.degradation`

| Class | Module | Description |
|---|---|---|
| `SpectroscopicSelectionPipeline` | `spectroscopic_selection_pipeline` | Runs all SpecSelection variants on one input; parametric over selector list |

### Parametric pipelines

Some pipelines accept constructor arguments to configure which stages are included:

```python
# Run only specific spec-selectors
pipeline = SpectroscopicSelectionPipeline(selectors={"DESI_LRG": SELECTORS["DESI_LRG"]})
pipeline.save("spec_sel_lrg.yaml")
```

---

## CatalogTag and column name mapping

`rail.utils.catalog_utils` provides a `CatalogTag` system that maps abstract column names (e.g., `mag_r`) to survey-specific names (e.g., `mag_r_lsst`).

```python
from rail.utils import catalog_utils
active_tag = catalog_utils.get_active_tag()
colnames = active_tag.band_name_dict()  # {'u': 'mag_u_lsst', 'g': 'mag_g_lsst', ...}
```

Pipelines in `rail.pipelines.degradation` use `get_active_tag()` to adapt column names at build time — they are not hardcoded.
Set the active tag before building: `catalog_utils.set_active_tag("lsst_dp0")`.

---

## When to use RailPipeline vs YAML

| Situation | Prefer |
|---|---|
| Static pipeline with known stages | YAML directly |
| Dynamic stage list (e.g., loop over algorithms) | `RailPipeline` subclass |
| Pipeline managed by `RailProject` | `RailPipeline` (project calls `.save()`) |
| Quick one-off run | YAML directly |
| Multi-flavor project with shared pipeline templates | `RailPipeline` via `RailProject` |

---

## Gotchas

1. **`self.stage_name` becomes the stage name.** The attribute name you assign (`self.inform`, `self.estimate`) is used as the ceci stage name in the serialized YAML. Choose descriptive names — they appear in log files and output paths.

2. **`connections` and `aliases` are mutually exclusive per tag.** A tag covered by both raises an error at build time.

3. **`default_input_dict` values are ignored at save time.** They're only placeholders; the real paths come from `aliases` and the pipeline run configuration.

4. **`rail.stages.import_and_attach_all()` must be called before building pipelines that use sub-package stages.** Otherwise `SomeSubpackageEstimator` won't be registered and `build()` will fail with a stage-not-found error.

5. **`pipeline.save()` requires an output directory to exist.** It does not create parent directories.
