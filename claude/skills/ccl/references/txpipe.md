# CCL in TXPipe

TXPipe stores cosmology as a `FiducialCosmology` YAML file (tag `fiducial_cosmology`).
Call `self.open_input("fiducial_cosmology", wrapper=True).to_ccl(**kwargs)` to get a `ccl.Cosmology`; `**kwargs` can override parameters (e.g., `matter_power_spectrum="halofit"`, `Neff=3.046`).

## Stages that use CCL

| Stage | What it does with CCL |
|---|---|
| `TXTwoPointTheoryReal` / `TXTwoPointTheoryFourier` | Loads cosmology with `halofit`, passes to `theory_3x2pt()` via Firecrown |
| `TXFourierGaussianCovariance` | Loads cosmology for Gaussian covariance with TJPCov |
| `TXLogNormalGlass` | Uses `comoving_radial_distance()` for shell spacing; builds `NumberCountsTracer` per shell; calls `angular_cl()` for lognormal C(ℓ)s |
| `TXShearCalibration` | Calls `comoving_radial_distance()` to add comoving distance column |
| `TXRandomCat` | Loads cosmology to compute comoving distances for random points |
| `TXBaseLensSelector` | Imports pyccl for redshift-to-distance conversion |

## Key utilities

`utils/theory.py::theory_3x2pt()` calls `cosmo.compute_nonlin_power()` then delegates to Firecrown for full 3×2pt predictions.
`utils/theory.py::make_bias_parameters()` uses `ccl.growth_factor(cosmo, a_eff)` to compute scale-dependent galaxy bias.
