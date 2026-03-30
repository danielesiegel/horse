# horse — BCI Factory

Production pipeline for brain-computer interfaces built on algebraic geometry (Stacks Project) and compositional category theory (LocalCharts).

## Factory Stages

```
 RAW SIGNAL        SHEAF ASSEMBLY       DESCENT/GLUING       DECODE
 ─────────────────────────────────────────────────────────────────────
 8ch EEG (Cyton)   presheaf over        local→global         motor intent
 fNIRS (HbO/HbR)   electrode sites      hemodynamic state    neurofeedback
 sEMG + haptic     sections of F        cohomology class     phenomenal field
 eye tracking       on U_i               H^1 obstruction      qualia valence
```

### Stage 1: Signal Acquisition → Sites
Electrode montages define a Grothendieck topology. Each channel is a section over an open set.

- `stacks-project/sites.tex` — topology on the montage
- `stacks-project/sheaves.tex` — signal presheaves F: Open(Brain)^op → Vect
- `stacks-project/modules.tex` — O_X-modules for multimodal sensor fusion

### Stage 2: Local Processing → Cohomology
Per-patch spectral analysis, Fisher-Rao distances, GF(3) trit encoding of fNIRS.

- `stacks-project/cohomology.tex` — obstructions to global brain state reconstruction
- `stacks-project/crystalline.tex` — GF(3) PD structure on fNIRS trits (HbO=+1, HbR=-1, baseline=0)
- `stacks-project/etale-cohomology.tex` — Fisher-Rao metric as etale sheaf
- `stacks-project/simplicial.tex` — persistent homology of neural point clouds

### Stage 3: Global Assembly → Descent
Gluing local patches into coherent whole-brain state. The factory's core theorem: effective descent = real-time BCI.

- `stacks-project/descent.tex` — gluing condition for hemodynamic patches
- `stacks-project/stacks.tex` — gauge symmetry of reference frames (re-referencing = stack morphism)
- `stacks-project/formal-defos.tex` — perturbation theory for neurofeedback protocols
- `stacks-project/derham.tex` — continuous neural dynamics ↔ discrete EEG comparison

### Stage 4: Decode → Categorical Semantics
Compositional interpretation of assembled brain states using category theory.

- `localcharts/forest/` — forester wiki for BCI categorical semantics
- `localcharts/cct-reading-group/` — compositional category theory foundations
- `stacks-project/categories.tex` — categorical infrastructure
- `stacks-project/functors.tex` — signal-to-intent functorial decode

## Device Stack

| Layer | Hardware | Rate | Math |
|---|---|---|---|
| EEG | OpenBCI Cyton 8ch | 250 Hz | presheaf sections |
| fNIRS | dual-wavelength | 10 Hz | GF(3) crystalline |
| Haptic | vibrotactile array | 50 Hz | feedback sheaf |
| sEMG | surface EMG | 1 kHz | motor intent descent |
| Eye | pupil + gaze | 120 Hz | attention functor |
| Braille | refreshable display | async | output sheaf |

## Critical Path

```
Signal → Sheaf Assembly → Descent → Decode
         1.2ms            1.8ms     1.0ms   = 4.0ms @ 50Hz
```

Bridge-9 implements this pipeline: 13 files, 9,500+ LOC, 4.0ms critical path.

## GF(3) Conservation

The factory's invariant: trit parity is conserved across all stages.

```
fNIRS input:  HbO(+1) + HbR(-1) + baseline(0) = 0
GF(3) tower:  GF(3) → GF(9) → GF(27)
ego-locale:   ordered locale with way-below relation
output:       valence gradient ∈ {-1, 0, +1}
sum:          always 0
```

## Layout

```
horse/
├── stacks-project/           # 119 .tex chapters — algebraic geometry substrate
│   ├── sites.tex             # Stage 1: montage topology
│   ├── sheaves.tex           # Stage 1: signal presheaves
│   ├── cohomology.tex        # Stage 2: obstruction classes
│   ├── crystalline.tex       # Stage 2: GF(3) fNIRS
│   ├── descent.tex           # Stage 3: patch gluing
│   ├── stacks.tex            # Stage 3: gauge symmetry
│   ├── formal-defos.tex      # Stage 3: neurofeedback perturbation
│   └── ...                   # 112 more chapters
├── localcharts/
│   ├── forest/               # categorical semantics wiki
│   ├── cct-reading-group/    # compositional CT foundations
│   ├── silviculture/         # forest tooling
│   └── alg-geo-podcast/      # algebraic geometry media
└── README.md
```
