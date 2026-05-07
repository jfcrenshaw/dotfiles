---
name: ccl
description: Guide to CCL (pyccl), the DESC Core Cosmology Library for theoretical cosmological calculations. Use this skill whenever the user imports pyccl, works with Cosmology objects, computes angular power spectra (angular_cl), uses tracers (WeakLensingTracer, NumberCountsTracer, CMBLensingTracer), computes 3D power spectra (linear_matter_power, nonlin_matter_power), uses Pk2D, calls scalar functions like sigma8/growth_factor/comoving_radial_distance, configures halo model components, or asks about CCL cosmological calculations, units conventions, or parameter naming in any DESC pipeline context.
---

# CCL — Core Cosmology Library (pyccl)

You're helping a user write code with CCL (pyccl), DESC's Core Cosmology Library for standardized theoretical predictions.
CCL is TXPipe's cosmological backbone: every TXPipe theory or simulation stage reads a `FiducialCosmology` YAML file and converts it to a `ccl.Cosmology` via `FiducialCosmology.to_ccl()`.

## Overview

### Cosmology construction

```python
import pyccl as ccl
import numpy as np

# Use sigma8 OR A_s, not both; Omega_* are dimensionless (NOT h²-scaled)
cosmo = ccl.Cosmology(
    Omega_c=0.27, Omega_b=0.045, h=0.67,
    sigma8=0.8, n_s=0.96,
    Omega_k=0.0, w0=-1.0, wa=0.0, Neff=3.046,
    matter_power_spectrum="halofit",   # or "linear", "emu"
    transfer_function="bbks",          # or "boltzmann_camb", "eisenstein_hu"
)
# From YAML (TXPipe's FiducialCosmology.to_ccl() does this internally)
cosmo = ccl.Cosmology.read_yaml("fiducial_cosmology.yml")
```

**Key gotchas**: Distances return **Mpc** (not Mpc/h).
Set exactly one of `sigma8` / `A_s`; pass `None` for the other.
For w0waCDM just set `w0`/`wa` in the same constructor.

### Distances and growth

```python
a = 1.0 / (1 + z)           # CCL uses scale factor a, not redshift z
chi = ccl.comoving_radial_distance(cosmo, a)   # Mpc
D = ccl.growth_factor(cosmo, a)                # normalized to 1 at a=1
f = ccl.growth_rate(cosmo, a)
s8 = ccl.sigma8(cosmo)
```

### Angular power spectra

```python
z = np.linspace(0, 3, 300)
nz = np.exp(-0.5 * ((z - 0.5) / 0.1)**2)

# Tracers
wl = ccl.WeakLensingTracer(cosmo, dndz=(z, nz))
nc = ccl.NumberCountsTracer(cosmo, dndz=(z, nz),
                             has_rsd=False, bias=(z, np.ones_like(z)))
cmb = ccl.CMBLensingTracer(cosmo, z_source=1100.0)

ell = np.arange(2, 2000)
cl_shear   = ccl.angular_cl(cosmo, wl, wl, ell)    # C_ell (dimensionless)
cl_ggl     = ccl.angular_cl(cosmo, nc, wl, ell)
cl_density = ccl.angular_cl(cosmo, nc, nc, ell)
```

`angular_cl` returns the standard lensing/clustering angular power spectrum without any ell prefactor.

### 3D power spectra and Pk2D

```python
k = np.logspace(-4, 2, 200)   # h/Mpc
pk_lin  = ccl.linear_matter_power(cosmo, k, a=1.0)    # (Mpc)^3
pk_nl   = ccl.nonlin_matter_power(cosmo, k, a=1.0)

# Custom power spectrum
pk2d = ccl.Pk2D.from_function(pkfunc=lambda k, a: pk_lin,
                                is_logp=False)
```

See [`references/api.md`](references/api.md) for full parameter tables, halo model components, and units details.

## TXPipe usage

Every TXPipe theory or simulation stage reads a `FiducialCosmology` YAML and converts it to `ccl.Cosmology` via `FiducialCosmology.to_ccl()`.
See [`references/txpipe.md`](references/txpipe.md) for the stage table and utility functions.

## Reference

| Topic | Reference |
|---|---|
| Full API reference (parameters, tracers, Pk2D, halo model, units, gotchas) | [`references/api.md`](references/api.md) |
| TXPipe stage table and utilities | [`references/txpipe.md`](references/txpipe.md) |
