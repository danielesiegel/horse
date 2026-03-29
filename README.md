# plurigrid/blue — Stacks Project × BCI

The [Stacks Project](https://stacks.math.columbia.edu/) as substrate for
brain-computer interface mathematics.

## Why Stacks for BCI?

| Stacks concept | BCI application |
|---|---|
| **Sheaves** (`sites.tex`, `cohomology.tex`) | Neural signal fields over electrode sites; presheaf of EEG channels |
| **Descent** (`descent.tex`) | Gluing local fNIRS patches into global hemodynamic state |
| **Cohomology** (`etale-cohomology.tex`) | Fisher-Rao metric on probability distributions over phenomenal fields |
| **Stacks/Gerbes** (`algebraic.tex`, `stacks-*.tex`) | Gauge symmetry of BCI reference frames (re-referencing as stack morphism) |
| **Formal deformation** (`defos.tex`) | Perturbation theory for neurofeedback protocols |
| **Crystalline cohomology** (`crystalline.tex`) | GF(3) trit lattice on fNIRS (HbO/HbR/baseline) as PD structure |
| **de Rham** (`derham.tex`) | Continuous neural dynamics ↔ discrete EEG via comparison theorems |

## Key chapters for BCI phenomenology

1. `sites.tex` — Grothendieck topologies → electrode montage topologies
2. `cohomology.tex` — sheaf cohomology → obstructions to global brain state reconstruction
3. `simplicial.tex` — simplicial methods → persistent homology of neural point clouds
4. `formal-defos.tex` — deformation theory → neurofeedback perturbation
5. `crystalline.tex` — GF(3) lifts → trit-valued fNIRS signals

## Structure

```
stacks-project/     # Full mirror of stacks/stacks-project (119 .tex files)
```

## Related

- `~/i/bridge-9/` — 50Hz BCI pipeline (4.0ms critical path)
- `~/i/ego-locale.jl` — GF(3)→GF(9)→GF(27) tower, ordered locale as ego
- BCI device ecosystem: Cyton + fNIRS + haptic + sEMG + eye tracking
