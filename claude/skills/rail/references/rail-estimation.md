# rail.estimation — photo-z base classes and algorithms

## Contents

- [Base class hierarchy](#base-class-hierarchy)
- [Implementing a new algorithm](#implementing-a-new-algorithm)
- [Shared config options (from SharedParams)](#shared-config-options-from-sharedparams)
- [Available algorithms](#available-algorithms)
- [Gotchas](#gotchas)

---

## Base class hierarchy

All estimation classes are `RailStage` subclasses.
The five base classes cover distinct roles in the photo-z workflow:

| Class | Input(s) | Output | Entrypoint | Role |
|---|---|---|---|---|
| `CatInformer` | `TableHandle` (training catalog) | `ModelHandle` | `inform(training_data)` | Train/prepare a model |
| `CatEstimator` | `ModelHandle` + `TableHandle` (test catalog) | `QPHandle` (per-galaxy PDFs) | `estimate(input_data)` | Run photo-z on catalog |
| `CatSummarizer` | `TableHandle` (catalog) | `QPHandle` (ensemble n(z)) | `summarize(input_data)` | Catalog → n(z) directly |
| `PZSummarizer` | `ModelHandle` + `QPHandle` (per-galaxy PDFs) | `QPHandle` (ensemble n(z)) | `summarize(input_data)` | Per-galaxy PDFs → n(z) |
| `SZPZSummarizer` | `TableHandle` (photo) + `TableHandle` (spec) + `ModelHandle` | `QPHandle` (ensemble n(z)) | `summarize(input_data, spec_data)` | SOM-based: needs spec-z catalog |

Additional: `CatClassifier` / `PZClassifier` for tomographic binning.

---

## Implementing a new algorithm

### Informer

```python
from ceci.config import StageParameter
from rail.estimation.informer import CatInformer

class MyInformer(CatInformer):
    name = "MyInformer"
    config_options = CatInformer.config_options.copy()
    config_options.update(
        n_neighbors=StageParameter(int, 5, msg="number of neighbors"),
    )

    def run(self):
        training_data = self.get_data("input")
        # ... train model ...
        self.add_data("model", trained_model)  # ModelHandle wraps any picklable object
```

### Estimator — must implement `_process_chunk`, NOT `run`

`CatEstimator.run()` iterates over the input in chunks and calls `_process_chunk` for each.

```python
from rail.estimation.estimator import CatEstimator

class MyEstimator(CatEstimator):
    name = "MyEstimator"
    config_options = CatEstimator.config_options.copy()

    def _process_chunk(self, start, end, data, first):
        self.open_model(**self.config)   # loads self.model from ModelHandle
        locs = self.model.predict(data["mag_r_lsst"])
        sigs = np.ones(len(locs)) * 0.1
        qp_dist = qp.Ensemble(qp.stats.norm,
                              data=dict(loc=locs.reshape(-1,1),
                                        scale=sigs.reshape(-1,1)))
        self._do_chunk_output(qp_dist, start, end, first)
```

---

## Shared config options (from `SharedParams`)

Most estimation classes inherit these via `CatEstimator.config_options`:

| Key | Default | Notes |
|---|---|---|
| `hdf5_groupname` | `"photometry"` | HDF5 group containing the input table; set `""` for flat HDF5 |
| `chunk_size` | `10_000` | Rows per chunk in `CatEstimator.run()` |
| `zmin` | `0.0` | Minimum redshift for output grid |
| `zmax` | `3.0` | Maximum redshift for output grid |
| `nzbins` | `301` | Number of redshift bins |
| `id_col` | `"id"` | Column name for object IDs |
| `redshift_col` | `"redshift"` | Column name for true redshifts (used in evaluation) |

---

## Available algorithms

Load all registered algorithms at once: `import rail.stages; rail.stages.import_and_attach_all()`

### In rail_base (no extra dependencies)

| Informer / Estimator or Summarizer | Algorithm | Notes |
|---|---|---|
| `RandomGaussInformer` / `RandomGaussEstimator` | Random Gaussian | Unit-test placeholder only |
| `TrainZInformer` / `TrainZEstimator` | Train-Z | Assigns every object the training N(z) |
| `KNearNeighInformer` / `KNearNeighEstimator` | K-nearest neighbour | Color-space kNN |
| `NZDirInformer` / `NZDirEstimator` | NZ-DIR | Nearest-neighbour weighting (TXPipe DIR method) |
| `CMNNInformer` / `CMNNEstimator` | CMNN | Color-matched nearest neighbours |
| `BPZliteInformer` / `BPZliteEstimator` | BPZ-lite | Template-fitting (port of BPZ; templates bundled) |
| `GPzInformer` / `GPzEstimator` | GPz | Gaussian process photo-z |
| `NaiveStackInformer` / `NaiveStackSummarizer` | Naive stack | Histogram sum of per-galaxy PDFs |
| `PointEstHistInformer` / `PointEstHistSummarizer` | Point-estimate histogram | Histogram of point estimates |
| `VarInfStackInformer` / `VarInfStackSummarizer` | Variational inference stack | VI-based N(z) stacking |
| `UniformBinningClassifier` | Uniform-width tomography | Classifier only (no Informer) |
| `EqualCountClassifier` | Equal-count tomography | Classifier only (no Informer) |
| `TrueNZHistogrammer` | True-N(z) histogram | Validation/testing — needs true redshifts |

### Needs sklearn (usually pre-installed)

| Informer / Estimator | Algorithm | Notes |
|---|---|---|
| `SklNeurNetInformer` / `SklNeurNetEstimator` | sklearn neural network | MLP regressor, magnitude/color inputs |
| `DNFInformer` / `DNFEstimator` | DNF | Directional Neighbourhood Fitting |
| `RandomForestInformer` / `RandomForestClassifier` | Random forest | Tomographic classifier; base method in TXPipe |

### Needs external package

| Informer / Estimator or Summarizer | External dep | Algorithm |
|---|---|---|
| `FlexZBoostInformer` / `FlexZBoostEstimator` | `flexcode`, `qp_flexzboost` | FlexZBoost conditional density estimation |
| `PZFlowInformer` / `PZFlowEstimator` | `pzflow` | Normalizing-flow photo-z |
| `LephareInformer` / `LephareEstimator` | `lephare` | LePhare template-fitting SED code |
| `MiniSOMInformer` / `MiniSOMSummarizer` | `minisom` (`rail_som`) | Self-organising map (MiniSom backend) |
| `SomocluSOMInformer` / `SomocluSOMSummarizer` | `somoclu` (`rail_som`) | Self-organising map (Somoclu backend) |
| SOMPZ summarizer classes | `rail_sompz` | 3-SOM N(z) method; class names not in qmd index — check package docs |
| YAW stages (`YawCacheCreate`, …) | `yaw` (`rail_yaw`) | Clustering-redshift cross-correlation |

---

## Gotchas

1. **`CatEstimator`: implement `_process_chunk`, not `run`.** `run()` handles chunk iteration internally; overriding it breaks chunking.

2. **`PZSummarizer` takes `QPHandle` input, not `TableHandle`.** Input is the per-galaxy PDF ensemble from an Estimator output. Use `CatSummarizer` if you start from a catalog directly.

3. **`SZPZSummarizer` needs two catalog inputs.** `("input", TableHandle)` is the photometry-only sample; `("spec_input", TableHandle)` is the spectroscopic sample with known redshifts. Used by SOM-based methods (`rail_som`, `rail_sompz`).

4. **`hdf5_groupname` must match your file.** Default is `"photometry"`. Flat HDF5 files (no group) need `hdf5_groupname=""`. Mismatch raises a confusing KeyError at read time.

5. **`ModelHandle` wraps any picklable object.** There is no common model interface; each Informer/Estimator pair must be used together.

6. **`open_model(**self.config)` call.** Call this inside `_process_chunk` (or `run` for summarizers) before accessing `self.model`. It loads the model from the handle on first call; subsequent calls are no-ops.

7. **Point estimates.** `CatEstimator` includes `PointEstimationMixin`: set `point_estimates: [mode, mean, median]` in config to compute and save point estimates alongside the PDF output.
