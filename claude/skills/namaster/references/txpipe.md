# TXPipe NaMaster Stage Reference

**Contents:** TXTwoPointFourier · TXTwoPointFourierCatalog · TXFourierNamasterCovariance · TXTwoPointFourierCMBLensingCrossDensity

## TXTwoPointFourier

**File:** `txpipe/txpipe/twopoint-fourier.py`
**Output:** `twopoint_data_fourier` (SACCFile)

### Field construction (`load_maps`)

```python
import pymaster as nmt

# Spin-0 density fields — one map per lens tomographic bin
# Optional: template deprojection of systematics maps
density_fields = [
    nmt.NmtField(clustering_weight, [d], templates=s_maps, n_iter=0, lmax=lmax1)
    for d in d_maps
]

# Spin-2 lensing fields — [g1, g2] per source bin
# lmax = ell_max - 1  (off-by-one in namaster v2)
lensing_fields = [
    nmt.NmtField(lw, [g1, g2], n_iter=0, lmax=lmax1)
    for (lw, g1, g2) in zip(lensing_weights, g1_maps, g2_maps)
]
```

### Workspace management (`make_workspaces`)

TXPipe uses a `WorkspaceCache` (in `txpipe/utils/nmt_utils.py`) to persist MCMs to disk and avoid redundant computation.
A hash of the mask array combined with the ell binning hash is used as the cache key.

```python
w = nmt.NmtWorkspace.from_fields(f1, f2, ell_bins)
w.write_to(str(path))   # cached on disk as workspace_{key}.dat
```

### Power spectrum computation (`compute_power_spectra`)

TXPipe calls `compute_coupled_cell` + `decouple_cell` (not `compute_full_master`) so it can handle noise subtraction separately:

```python
pcl = nmt.compute_coupled_cell(field_i, field_j)
c   = workspace.decouple_cell(pcl)        # decoupled bandpowers
c   -= noise_bandpowers                   # subtract noise estimate

# Deprojection bias (if templates used)
cl_guess = nmt.compute_coupled_cell(field_i, field_j) / np.mean(mask**2)
pclb = nmt.deprojection_bias(field_i, field_j, cl_guess)
c   -= workspace.decouple_cell(pclb)
```

### Output spectra and SACC types

| Correlation | Indices into output | SACC type |
|---|---|---|
| shear × shear | 0: EE, 1: EB, 2: BE, 3: BB | `galaxy_shear_cl_ee`, `_eb`, `_be`, `_bb` |
| shear × density | 0: E, 1: B | `galaxy_shearDensity_cl_e`, `_b` |
| density × density | 0 | `galaxy_density_cl` |

### Noise estimation

Two methods controlled by `analytic_noise` config option:
- **Simulation-based** (default): half-maps from `source_noise_maps`/`lens_noise_maps`, analyzed with `nmt.NmtField` + `compute_coupled_cell`.
- **Analytic**: computed from variance maps (`var_e_i`) or mean galaxy counts.

### Key config options

| Option | Default | Meaning |
|---|---|---|
| `nside` | — | HEALPix resolution |
| `ell_min` / `ell_max` / `n_ell` | 100 / 1500 / 20 | Bandpower binning |
| `ell_spacing` | `"log"` | `"log"` or `"linear"` |
| `flip_g2` | False | Negate g2 before NmtField |
| `deproject_syst_clustering` | False | Template deprojection for density |
| `analytic_noise` | False | Use analytic vs simulated noise |
| `cache_dir` | `"./cache/twopoint_fourier"` | Workspace cache location |

---

## TXTwoPointFourierCatalog

**File:** `txpipe/txpipe/twopoint-fourier.py`
**Subclass of:** `TXTwoPointFourier`
**Output:** `twopoint_data_fourier_cat`

Uses catalog-based NaMaster fields instead of maps:

```python
# Shear field from catalog
field = nmt.NmtFieldCatalog(
    positions,    # shape (2, ngal): [ra, dec] in degrees if lonlat=True
    weight,       # per-galaxy weight
    shear,        # [g1, g2] arrays, or None for mask-only
    lmax=lmax, lmax_mask=lmax, spin=2, lonlat=True
)

# Density field with optional randoms
field = nmt.NmtFieldCatalogClustering(
    positions, weight,
    positions_rand=pos_rand, weights_rand=weight_rand,
    lmax=lmax, mask=mask_gc, lmax_mask=lmax,
    templates=templates, lmax_deproj=lmax_deproj,
    lonlat=True,
    calculate_noise_dp_bias=True,
)
```

Noise is automatically subtracted analytically for catalog-based fields; access `field.Nf` for the shot noise level.

---

## TXFourierNamasterCovariance

**File:** `txpipe/txpipe/covariance-nmt.py`
**Output:** `summary_statistics_fourier` (SACCFile with covariance)

### Field and workspace setup

```python
f0 = nmt.NmtField(msk, [msk], n_iter=0)         # spin-0
f2 = nmt.NmtField(msk, [msk, msk], n_iter=2)    # spin-2
b  = nmt.NmtBin.from_nside_linear(nside, 48)

# 3 mode-coupling workspaces
w00 = nmt.NmtWorkspace(); w00.compute_coupling_matrix(f0, f0, b)
w20 = nmt.NmtWorkspace(); w20.compute_coupling_matrix(f2, f0, b)
w22 = nmt.NmtWorkspace(); w22.compute_coupling_matrix(f2, f2, b)

# 6 covariance workspaces (all unique spin-quad combinations)
# (0,0,0,0), (0,0,2,0), (0,0,2,2), (2,0,2,0), (2,0,2,2), (2,2,2,2)
cw = nmt.NmtCovarianceWorkspace()
cw.compute_coupling_coefficients(f_a, f_b, f_c, f_d)
```

Workspaces are written to `scratch_dir/w{s1}{s2}.fits` and `cw{s1}{s2}{s3}{s4}.fits` and read back; MPI-parallel computation is supported.

### Gaussian covariance call

```python
nmt_cov = nmt.gaussian_covariance(
    cw,
    int(s1), int(s2), int(s3), int(s4),
    cl13,  # [C_ell + N_ell] for tracers (1,3); length depends on spins
    cl14,
    cl23,
    cl24,
    wa=w1,           # workspace for pair (1,2)
    wb=w2,           # workspace for pair (3,4)
    coupled=True,
)
```

The result is in coupled space; TXPipe rescales and normalizes it using `f_sky` and `ell` before combining with a TJPCov estimate at high ell.

### TXRealNamasterCovariance

Subclass with `do_xi = True`; projects the covariance to real space using a Wigner transform from `tjpcov`.

---

## TXTwoPointFourierCMBLensingCrossDensity

**File:** `txpipe/txpipe/extensions/cmb-lensing/twopoint-fourier-cross.py`

Spin-0 × spin-0 cross-spectra between CMB κ and galaxy density.
Uses `NmtWorkspace.from_fields` and `NmtCovarianceWorkspace.from_fields`.
Applies a Monte Carlo transfer function correction after decoupling.
Mask apodization: `nmt.mask_apodization(mask, aposize=0.2, apotype="C1")`.
