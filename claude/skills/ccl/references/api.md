# CCL API Reference

**Contents:** Cosmology constructor · Key scalar functions · Tracers · angular_cl · Pk2D · Halo model · Units and conventions · Common gotchas

## Cosmology constructor parameters

| Parameter | Type | Description | Units/Notes |
|---|---|---|---|
| `Omega_c` | float | Cold dark matter density | Dimensionless (NOT h²-scaled) |
| `Omega_b` | float | Baryon density | Dimensionless |
| `h` | float | Hubble parameter | H₀ / (100 km/s/Mpc) |
| `sigma8` | float or None | RMS matter fluctuations in 8 Mpc/h sphere | Mutually exclusive with `A_s` |
| `A_s` | float or None | Primordial scalar amplitude | Mutually exclusive with `sigma8` |
| `n_s` | float | Scalar spectral index | Dimensionless |
| `Omega_k` | float | Curvature density | Default 0 (flat) |
| `Omega_g` | float or None | Photon density | Default None (computed from T_CMB) |
| `w0` | float | Dark energy EOS today | Default -1 |
| `wa` | float | Dark energy EOS time derivative | Default 0 |
| `m_nu` | float or list | Neutrino masses | eV; pass list for 3-flavor split |
| `m_nu_type` | str | How m_nu is interpreted | `"normal"`, `"inverted"`, `"equal"`, `"list"` |
| `Neff` | float | Effective number of neutrino species | Default 3.046 |
| `transfer_function` | str | Boltzmann code / fitting formula | `"bbks"`, `"eisenstein_hu"`, `"boltzmann_camb"`, `"boltzmann_class"` |
| `matter_power_spectrum` | str | Non-linear prescription | `"linear"`, `"halofit"`, `"emu"` (Mira-Titan), `"camb"` |
| `baryons_power_spectrum` | str | Baryon feedback | `"nobaryons"` (default), `"bcm"` |
| `bcm_log10Mc` | float | BCM baryon model param | Default 14.079 |
| `mu_0`, `sigma_0` | float | Modified gravity params | Default 0 (GR) |

## Key scalar functions

All take `cosmo` as first arg; distances take scale factor `a = 1/(1+z)`, not redshift.

```python
# Distances — all return Mpc (not Mpc/h)
ccl.comoving_radial_distance(cosmo, a)      # χ(z) in Mpc
ccl.angular_diameter_distance(cosmo, a)     # D_A in Mpc
ccl.luminosity_distance(cosmo, a)           # D_L in Mpc
ccl.h_over_h0(cosmo, a)                     # E(z) = H(z)/H0

# Growth
ccl.growth_factor(cosmo, a)                 # D(a), normalized to 1 at a=1
ccl.growth_rate(cosmo, a)                   # f = d ln D / d ln a
ccl.sigma8(cosmo)                           # σ₈

# Power spectra — k in h/Mpc, output in (Mpc)^3
ccl.linear_matter_power(cosmo, k, a)
ccl.nonlin_matter_power(cosmo, k, a)
```

## Tracers

### WeakLensingTracer
```python
ccl.WeakLensingTracer(
    cosmo,
    dndz=(z_arr, nz_arr),    # n(z) normalized arbitrarily
    has_shear=True,           # include cosmic shear kernel
    ia_bias=None,             # intrinsic alignment: (z, A_IA) tuple or None
    use_A_ia=True,            # if True, ia_bias interpreted as A_IA amplitude
)
```

### NumberCountsTracer
```python
ccl.NumberCountsTracer(
    cosmo,
    dndz=(z_arr, nz_arr),
    bias=(z_arr, b_arr),      # linear galaxy bias b(z)
    has_rsd=False,            # redshift-space distortions
    mag_bias=None,            # magnification bias s(z), or None
)
```

### CMBLensingTracer
```python
ccl.CMBLensingTracer(cosmo, z_source=1100.0)
```

### Other tracers
`tSZTracer`, `CIBTracer`, `ISWTracer` — same pattern, see CCL docs.

## angular_cl

```python
ell = np.arange(2, 3000)
cl = ccl.angular_cl(cosmo, tracer1, tracer2, ell)
# or equivalently:
cl = cosmo.angular_cl(tracer1, tracer2, ell)
```

Output is C_ℓ (dimensionless, no ℓ prefactor).
CCL uses the Limber approximation by default for ℓ ≥ 2 (configurable).

## Pk2D — custom power spectra

```python
import numpy as np

# From arrays
k_arr = np.logspace(-4, 2, 100)
a_arr = np.linspace(0.1, 1.0, 20)
pk_arr = np.outer(a_arr**(-1), linear_pk(k_arr))   # shape (na, nk)

pk2d = ccl.Pk2D(
    pkfunc=None,
    a_arr=a_arr,
    lk_arr=np.log(k_arr),
    pk_arr=np.log(pk_arr),  # log-space interpolation
    is_logp=True,
)

# From function
def my_pk(k, a):
    return ccl.linear_matter_power(cosmo, k, a) * my_boost(k, a)

pk2d = ccl.Pk2D.from_function(pkfunc=my_pk, is_logp=False)

# Use in angular_cl
cl = ccl.angular_cl(cosmo, tracer1, tracer2, ell, p_of_k_a=pk2d)
```

## Halo model

```python
# Mass function + halo bias
mdef = ccl.halos.MassDef200m
hmf  = ccl.halos.MassFuncTinker08(mass_def=mdef)
hbf  = ccl.halos.HaloBiasTinker10(mass_def=mdef)

hmc  = ccl.halos.HMCalculator(
    mass_function=hmf,
    halo_bias=hbf,
    mass_def=mdef,
)

# Halo profiles
nfw  = ccl.halos.HaloProfileNFW(mass_def=mdef, concentration=ccl.halos.ConcentrationDuffy08())

# 2-halo + 1-halo power spectrum
pk_hm = ccl.halos.halomod_Pk2D(cosmo, hmc, nfw)

# Use with angular_cl
cl = ccl.angular_cl(cosmo, tracer1, tracer2, ell, p_of_k_a=pk_hm)
```

## Units and conventions

| Quantity | Units |
|---|---|
| Distances (chi, D_A, D_L) | **Mpc** (not Mpc/h) |
| Wavenumber k in P(k) functions | **h/Mpc** |
| P(k) output | **(Mpc)³** (not (Mpc/h)³) |
| C_ℓ output | Dimensionless |
| n(z) normalization | Arbitrary (CCL normalizes internally) |
| Scale factor | a = 1 at z=0; a = 1/(1+z) |

## Common gotchas

- **`sigma8` vs `A_s`**: pass exactly one; the other must be `None` (or omit it).
  TXPipe's `FiducialCosmology.to_ccl()` explicitly sets the unused one to `None`.
- **Scale factor vs redshift**: nearly all CCL functions take `a`, not `z`.
  Convert: `a = 1.0 / (1.0 + z)`.
- **k units**: P(k) inputs/outputs use h/Mpc and (Mpc)³ — not Mpc⁻¹ and Mpc³.
- **`compute_nonlin_power()`**: Call before passing `cosmo` to Firecrown
  (`theory_3x2pt()` does this explicitly).
- **CCL v2 vs v3**: TXPipe's `FiducialCosmology.to_ccl()` branches on `ccl.__version__[0] == "2"`
  to conditionally pass `bcm_log10Mc`, `mu_0`, `sigma_0` — these moved between versions.
- **YAML serialization**: `ccl.Cosmology.read_yaml()` exists but TXPipe rolls its own
  `ccl_read_yaml()` in `utils/theory.py` because the native YAML format has extra fields.
- **`matter_power_spectrum="halofit"`**: Must be set at construction time; TXPipe theory stages
  always override this via `.to_ccl(matter_power_spectrum="halofit", Neff=3.046)`.
