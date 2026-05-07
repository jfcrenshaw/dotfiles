# NaMaster API Reference

**Contents:** NmtField · NmtBin · NmtWorkspace · NmtCovarianceWorkspace · Key free functions · Gotchas

## NmtField

```python
nmt.NmtField(
    mask,              # 1D array (HEALPix) or 2D (CAR); float weights, 0=masked
    maps,              # list of arrays: [m] for spin-0, [m1, m2] for spin-2
    spin=None,         # inferred from len(maps) if omitted (0 or 2)
    templates=None,    # shape [ntemp, nmap, npix]; triggers mode deprojection
    beam=None,         # 1D array B_ell (SHT of beam); deconvolved automatically
    purify_e=False,    # E-mode purification (reduces E→B leakage)
    purify_b=False,    # B-mode purification
    n_iter=3,          # SHT iteration count; use 0 for speed if mask is smooth
    lmax=None,         # cap at lmax; saves memory for large nside
    masked_on_input=False,  # set True if maps already multiplied by mask
    lite=False,        # skip storing alms (can't do deprojection bias later)
    lonlat=False,      # for NmtFieldCatalog: coords are (lon, lat) not (theta, phi)
)
```

**Spin conventions:**
- Spin-0: `[delta]`, `[kappa]` — one map.
- Spin-2: `[g1, g2]` — HEALPix convention (NOT IAU).
  For DESC catalogs: typically need `flip_g2=True` (negate g2 before passing).
- `purify_b=True` reduces leakage of E-modes into B but increases noise near mask edges; rarely used for main science.

**Template deprojection:**
Pass `templates` as an array of shape `[ntemp, nmap, npix]`.
NaMaster will project these modes out of the field before computing pseudo-Cls.
Use `nmt.deprojection_bias(f1, f2, cl_guess)` to subtract the resulting bias.

**Catalog-based fields (NaMaster v2+):**
- `nmt.NmtFieldCatalog(positions, weight, shear, lmax=..., spin=2, lonlat=True)` — shear from catalog.
- `nmt.NmtFieldCatalogClustering(positions, weight, positions_rand=..., mask=..., lmax=...)` — density from catalog, with optional randoms for mask.

## NmtBin

```python
# Option 1: linear bands of fixed width starting at ell=2
b = nmt.NmtBin.from_nside_linear(nside, nlb=40)

# Option 2: explicit bin edges
b = nmt.NmtBin.from_edges(ells_lo, ells_hi)  # 1D arrays of lower and upper edges

# Useful methods
b.get_effective_ells()   # array of bandpower centres
b.get_n_bands()          # number of bandpowers
b.get_ell_min(iband)     # minimum ell in band iband
b.get_ell_max(iband)     # maximum ell in band iband
```

## NmtWorkspace

```python
# Create + compute MCM in one call (preferred)
w = nmt.NmtWorkspace.from_fields(f1, f2, b)

# Or two-step (legacy)
w = nmt.NmtWorkspace()
w.compute_coupling_matrix(f1, f2, b)

# Persist to/from disk (FITS)
w.write_to("workspace.fits")
w.read_from("workspace.fits")

# Decouple pseudo-Cls
cl = w.decouple_cell(pcl)               # pcl from compute_coupled_cell
cl = w.decouple_cell(pcl, cl_bias=pclb) # subtract deprojection bias before decoupling

# Get bandpower window functions for theory comparison
# shape: (n_cls, n_bpws, n_cls, lmax+1)
windows = w.get_bandpower_windows()
```

**When to reuse vs recompute:** The MCM depends only on the masks and binning, not on the map values.
Reuse the same workspace for all tomographic bin pairs that share the same mask.
Use a hash of the mask array to detect when the MCM needs recomputing (TXPipe uses `array_hash` from `txpipe.utils`).

## NmtCovarianceWorkspace

```python
# Create from four fields (two pairs being correlated)
cw = nmt.NmtCovarianceWorkspace.from_fields(f1, f2, f3, f4)

# Or two-step
cw = nmt.NmtCovarianceWorkspace()
cw.compute_coupling_coefficients(f1, f2, f3, f4)

cw.write_to("cw.fits")
cw.read_from("cw.fits")
```

## Key free functions

```python
# All-in-one (slow if reusing workspace)
cl = nmt.compute_full_master(f1, f2, b)

# Fast manual pipeline
pcl = nmt.compute_coupled_cell(f1, f2)   # pseudo-Cl (coupled, not decoupled)
cl  = w.decouple_cell(pcl)

# Deprojection bias (only needed if templates passed to NmtField)
pclb = nmt.deprojection_bias(f1, f2, cl_guess)  # cl_guess shape: [ncls, lmax+1]
cl  = w.decouple_cell(pcl, cl_bias=pclb)

# Gaussian covariance
cov = nmt.gaussian_covariance(
    cw, s1, s2, s3, s4,
    cl13, cl14, cl23, cl24,  # each shape [n_cls_ij, lmax+1]; theory + noise
    wa=workspace_12,
    wb=workspace_34,
    coupled=True,            # return in coupled (ell-by-ell) space; decouple after
)

# Mask apodization (important: always apodize before passing to NmtField)
mask_apo = nmt.mask_apodization(mask, aposize=1.0, apotype="Smooth")
# apotype options: "C1", "C2", "Smooth"
```

## Gotchas

**Mask apodization is mandatory.**
A hard-edged mask causes severe ringing in the pseudo-Cls.
Always apodize with `nmt.mask_apodization` before creating `NmtField` objects.
Typical `aposize` = 0.2–1.0 degrees; `"C1"` or `"Smooth"` are common choices.

**HEALPix ring ordering required.**
Maps must be in RING ordering (the default in healpy).
Pass `nest=False` (default) to all `hp.read_map` calls.

**Pixel window correction.**
NaMaster does NOT automatically correct for the HEALPix pixel window function.
Divide your beam by `hp.pixwin(nside)` before passing to `NmtField`, or apply manually:
`beam_with_pixwin = beam * hp.pixwin(nside, pol=False)`.

**lmax off-by-one (NaMaster v2).**
The effective `lmax` is `3*nside - 1`.
When setting `lmax` in `NmtField`, pass `ell_max - 1` (TXPipe comment: "off-by-one bug or ambiguity in namaster v2").

**n_iter and accuracy.**
`n_iter=3` (default) iterates the SHT for accuracy near mask edges.
Use `n_iter=0` only when speed matters and the mask is smooth.

**Memory for large nside.**
Mode-coupling matrices scale as O(lmax³).
At nside=4096 the MCM is very large; use `Toeplitz` approximation or reduce `lmax` if memory is an issue.

**Spin-2 output shape.**
`compute_coupled_cell(f2, f2)` returns shape `(4, lmax+1)` — [EE, EB, BE, BB].
`compute_coupled_cell(f0, f0)` returns shape `(1, lmax+1)`.
`compute_coupled_cell(f2, f0)` returns shape `(2, lmax+1)` — [E, B].

**Beam deconvolution timing.**
The beam passed to `NmtField` is deconvolved during the MCM step.
If you want to apply a pixel window, include it in the beam array.
TXPipe currently leaves beam correction commented out due to an unresolved issue.

**gaussian_covariance input Cls.**
The `cl13`, `cl14`, `cl23`, `cl24` arguments expect theory power spectra in *coupled* space (not bandpower-binned) if `coupled=True`.
These must include shot/shape noise: pass `C_ell_signal + N_ell`.
The number of Cl arrays per argument depends on the spins: 1 for spin-0×spin-0, 2 for spin-0×spin-2, 4 for spin-2×spin-2.
