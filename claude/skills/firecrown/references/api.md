# Firecrown API Reference

**Contents:** Systematic classes · sacc data-type strings · Sampler connectors · ModelingTools and CCL · Loading a likelihood · Common gotchas

## Systematic classes and their updatable parameters

### Weak lensing (`firecrown.likelihood.weak_lensing`)

| Class | Constructor args | Updatable parameters |
|---|---|---|
| `WeakLensing` | `sacc_tracer`, `scale=1.0`, `systematics=[]` | — (host source) |
| `PhotoZShift` | `sacc_tracer`, `active=True` | `{tracer}_delta_z` |
| `MultiplicativeShearBias` | `sacc_tracer` | `{tracer}_mult_bias` |
| `LinearAlignmentSystematic` | `sacc_tracer=None`, `alphag=1.0` | `ia_bias`, `alphaz`, `alphag`, `z_piv` |
| `TattAlignmentSystematic` | `sacc_tracer=None`, `include_z_dependence=False` | `ia_a_1/2/d`, `ia_zpiv_1/2/d`, `ia_alphaz_1/2/d` |

### Number counts (`firecrown.likelihood.number_counts`)

| Class | Constructor args | Updatable parameters |
|---|---|---|
| `NumberCounts` | `sacc_tracer`, `has_rsd=False`, `scale=1.0`, `systematics=[]` | — |
| `LinearBiasSystematic` | `sacc_tracer` | `{tracer}_bias`, `{tracer}_alphaz`, `{tracer}_alphag`, `{tracer}_z_piv` |
| `PTNonLinearBiasSystematic` | `sacc_tracer` | `b_2`, `b_s` |
| `MagnificationBiasSystematic` | `sacc_tracer` | `r_lim`, `sig_c`, `eta`, `z_c`, `z_m` |

**Parameter naming:** parameter names are automatically prefixed with `{sacc_tracer}_` for per-tracer systematics (e.g., `source_0_delta_z`, `lens_1_bias`).

---

## sacc data-type strings

| Measurement | Data type string |
|---|---|
| Shear-shear EE (Fourier) | `galaxy_shear_cl_ee` |
| Shear-shear ξ+ (real) | `galaxy_shear_xi_plus` |
| Shear-shear ξ− (real) | `galaxy_shear_xi_minus` |
| Galaxy-galaxy lensing (Fourier) | `galaxy_shearDensity_cl_e` |
| Galaxy-galaxy lensing γ_t (real) | `galaxy_shearDensity_xi_t` |
| Galaxy density (Fourier) | `galaxy_density_cl` |
| Galaxy density w(θ) (real) | `galaxy_density_xi` |

**Ordering rule:** tracer order in `(t1, t2)` must match the order implied by the data-type string. Firecrown enforces CMB < Clusters < Galaxies hierarchy. Use `firecrown sacc view data.sacc --check` to validate.

---

## Sampler connectors

### CosmoSIS
```ini
[firecrown]
module = firecrown.connector.cosmosis.likelihood
likelihood_source = /path/to/likelihood.py
```
Requires the `consistency` module and a Boltzmann code (CAMB or CLASS) in the pipeline.
Firecrown uses pyccl in "calculator mode" — the Boltzmann code supplies distances/growth, not CCL.

### NumCosmo (standalone, no Boltzmann sampler)
```python
from firecrown.connector.numcosmo.numcosmo import MappingNumCosmo, NumCosmoFactory
factory = NumCosmoFactory("likelihood.py", build_parameters, MappingNumCosmo(...))
```
Supports best-fit, Fisher matrix, and Fisher bias calculations; see NumCosmo cookbook in the docs.

### Cobaya
```yaml
likelihood:
  firecrown.connector.cobaya.likelihood.FirecrownLikelihood:
    likelihood_source: /path/to/likelihood.py
```
Requires a Boltzmann theory block (CAMB or CLASS).

---

## ModelingTools and CCL

```python
from firecrown.modeling_tools import ModelingTools
tools = ModelingTools()          # wraps pyccl.Cosmology
tools.update(ParamsMap({...}))   # push cosmological parameters
tools.prepare(cosmo)             # build PT/HM calculators; cosmo is pyccl.Cosmology
tools.ccl_cosmo                  # access the wrapped CCL cosmology
tools.add_pk("my_pk", pk2d)      # register a custom Pk2D object
```

In TXPipe's theory-prediction path, `cosmo` is a `pyccl.Cosmology` read from a YAML file and `tools.prepare(cosmo)` is called explicitly before `compute_theory_vector(tools)`.

---

## Loading a likelihood

```python
from firecrown.likelihood.likelihood import load_likelihood_from_script
from firecrown.parameters import ParamsMap

lk, tools = load_likelihood_from_script("likelihood.py", build_parameters)
lk.update(ParamsMap({"Omega_c": 0.27, "source_0_delta_z": 0.01}))
tools.update(ParamsMap({"Omega_c": 0.27}))
tools.prepare(cosmo)
theory_vec = lk.compute_theory_vector(tools)
loglike = lk.compute_loglike(tools)
```

---

## Common gotchas

- **B modes / unsupported data types:** `TwoPoint` raises `ValueError: ... is not supported` for BB, EB modes. Catch and skip; TXPipe sets those indices to zero in the theory sacc.
- **Dummy covariance:** sacc files from TXPipe may have non-positive-definite shot-noise covariance. Add `sacc_data.add_covariance(np.ones(len(sacc_data)), overwrite=True)` when only computing theory vectors.
- **`lk.read()` required:** must call `lk.read(sacc_data)` after building the `ConstGaussian` to populate the data vector and covariance.
- **Parameter prefix:** per-tracer systematic parameters are named `{sacc_tracer}_{param}`, e.g., `lens_0_bias` not `bias_0`.
- **`LinearBiasSystematic` extra params:** also requires `{tracer}_alphaz`, `{tracer}_alphag`, `{tracer}_z_piv`; set `alphag=0.0` for constant bias.
- **CCL calculator mode:** when using CosmoSIS/Cobaya, Firecrown does not call CCL to compute power spectra internally — the Boltzmann code must supply all background quantities. Standalone use (NumCosmo or theory-prediction) calls CCL directly.
- **Legacy import paths:** older TXPipe code may use `firecrown.likelihood.gauss_family.statistic.source.*`; current paths are `firecrown.likelihood.weak_lensing` and `firecrown.likelihood.number_counts`.
