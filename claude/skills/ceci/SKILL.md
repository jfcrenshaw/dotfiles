---
name: ceci
description: How to write DESC pipeline stages and pipelines with ceci. Covers PipelineStage subclassing, inputs/outputs declarations, config_options, HDFFile/FitsFile/etc. I/O, parallel iteration helpers, MPI patterns, pipeline YAML structure (modules/launcher/site/stages/inputs), aliasing, CLI usage, and NERSC deployment. Use this skill whenever the user imports ceci, subclasses PipelineStage, writes a pipeline YAML, or asks about ceci file types or parallel execution.
---

# ceci — DESC pipeline framework

You're helping a user write code with ceci, the DESC pipeline framework.
Most DESC analysis packages (TXPipe, RAIL, etc.) are built on ceci.
For NERSC job submission and cluster conventions, see the `nersc` skill.

## Overview

A **stage** subclasses `PipelineStage`, declares `inputs`/`outputs` as lists of `(tag, FileType)` tuples, sets `config_options`, and implements `run()`.
A **pipeline** is a YAML file: `modules`, `launcher`, `site`, `stages`, `inputs`, `output_dir`, `log_dir`, `config`.
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

## Reference

| Topic | Reference |
|---|---|
| Stage definition, file types, MPI, pipeline YAML, CLI, gotchas | [`references/stages-and-pipelines.md`](references/stages-and-pipelines.md) |
| NERSC launchers, parsl site config, interactive vs batch, per-stage resources, parsl gotchas | [`references/nersc-parsl.md`](references/nersc-parsl.md) |
