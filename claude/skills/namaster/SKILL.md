---
name: namaster
description: Guide to NaMaster (pymaster), the DESC pseudo-Cl angular power spectrum estimator. Use this skill whenever the user imports pymaster, works with NmtField or NmtBin objects, computes pseudo-Cl power spectra, handles masks or mode-coupling matrices, asks about NaMaster, writes TXPipe Fourier-space stages, or needs Gaussian covariance estimates with NmtCovarianceWorkspace.
---

# NaMaster — pseudo-Cl power spectra for masked fields

You're helping a user write code with NaMaster (pymaster), DESC's pseudo-Cl angular power spectrum estimator (Alonso et al. 2019).
NaMaster is the Fourier-space workhorse of TXPipe: `TXTwoPointFourier` and its subclasses use it for all 3×2pt Cl measurements, and `TXFourierNamasterCovariance` uses it for Gaussian covariance estimation.

## Overview

**Four core objects** (import as `import pymaster as nmt`):

| Object | Role |
|---|---|
| `NmtField` | Wraps maps + mask + optional beam/templates |
| `NmtBin` | Defines ell bandpower binning |
| `NmtWorkspace` | Stores mode-coupling matrix; used to decouple pseudo-Cls |
| `NmtCovarianceWorkspace` | Stores coupling coefficients for Gaussian covariance |

**Minimal workflow:**
```python
import pymaster as nmt
import healpy as hp

nside = 512
mask = hp.read_map("mask.fits")
mask = nmt.mask_apodization(mask, aposize=1.0, apotype="Smooth")

# Spin-0 (density/convergence): one map
f0 = nmt.NmtField(mask, [delta_map], n_iter=0)

# Spin-2 (shear): two maps [g1, g2]
f2 = nmt.NmtField(mask, [g1, g2], n_iter=0, lmax=lmax)

# Binning
b = nmt.NmtBin.from_nside_linear(nside, nlb=40)   # linear, width-40 bands
# OR: b = nmt.NmtBin.from_edges(ell_lo, ell_hi)

# Compute coupling matrix once, reuse across tomographic bins
w = nmt.NmtWorkspace.from_fields(f0, f0, b)  # or w.compute_coupling_matrix(f0, f0, b)
w.write_to("workspace.fits")   # persist to disk

# Two equivalent approaches:
# (A) all-in-one (recomputes MCM internally — slow if reusing)
cl = nmt.compute_full_master(f0, f0, b)

# (B) decouple manually (fast when workspace is precomputed)
pcl = nmt.compute_coupled_cell(f0, f0)
cl  = w.decouple_cell(pcl)
```

**Spin-2 output ordering** — cross-correlating two spin-2 fields returns 4 spectra: `[EE, EB, BE, BB]` at indices 0–3.
Shear×density returns `[E, B]`.

See [`references/api.md`](references/api.md) for detailed parameter tables and gotchas.

## TXPipe usage

NaMaster is TXPipe's Fourier-space workhorse: `TXTwoPointFourier`, `TXTwoPointFourierCatalog`, `TXFourierNamasterCovariance`, and the CMB lensing cross-spectrum stage all use it.
See [`references/txpipe.md`](references/txpipe.md) for stage details, workspace management, noise estimation, the `choose_ell_bins` helper, and the `flip_g2` sign convention.

## Reference

| Topic | Reference |
|---|---|
| API details, gotchas, covariance | [`references/api.md`](references/api.md) |
| TXPipe stage details | [`references/txpipe.md`](references/txpipe.md) |
