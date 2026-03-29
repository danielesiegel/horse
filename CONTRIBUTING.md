# Contributing to horse

## What is this

horse is a BCI Factory: algebraic geometry (Stacks Project) + compositional category theory (LocalCharts) applied to brain-computer interfaces. Contributions should advance one of the four factory stages.

## Factory Stages

| Stage | Directory | What to contribute |
|---|---|---|
| 1. Signal → Sites | `stacks-project/sites.tex`, `sheaves.tex` | Montage topologies, new sensor presheaves |
| 2. Local → Cohomology | `stacks-project/crystalline.tex`, `cohomology.tex` | GF(3) encodings, Fisher-Rao computations |
| 3. Global → Descent | `stacks-project/descent.tex`, `stacks.tex` | Gluing algorithms, reference frame transforms |
| 4. Decode → Semantics | `localcharts/` | Categorical interpretations, forester trees |

## How to contribute

### Adding a new BCI interpretation

1. Identify a Stacks Project chapter relevant to a BCI problem
2. Create a file in `bci/` mapping definitions to signal processing concepts
3. Reference specific tags from `stacks-project/tags/tags`

Example:
```
bci/
  sites-montage.md      # sites.tex → electrode montage
  crystalline-fnirs.md  # crystalline.tex → GF(3) trit encoding
  descent-gluing.md     # descent.tex → hemodynamic patch fusion
```

### Adding a LocalCharts bridge

1. Pick a topic from `localcharts/forest/` or `localcharts/cct-reading-group/`
2. Write a bridge document showing how it applies to decode (Stage 4)
3. Place in `bci/categorical/`

### Device integration

New device modalities go in `bci/devices/`. Each device file should specify:
- Sampling rate
- Data type (presheaf structure)
- Which factory stage it enters
- GF(3) encoding if applicable

## Conventions

- **GF(3) conservation**: every pipeline must preserve trit parity (sum = 0)
- **Critical path budget**: 4.0ms total at 50Hz — justify any added latency
- **Tags**: reference Stacks Project tags (e.g., `\label{0ABC}`) when citing theorems
- **Categorical**: use string diagrams or wiring diagrams for compositional claims

## Repo structure

```
horse/
├── stacks-project/     # upstream mirror — do not modify directly
├── localcharts/        # upstream mirror — do not modify directly
├── bci/                # BCI Factory interpretations (contribute here)
│   ├── devices/        # device modality specs
│   ├── categorical/    # LocalCharts → BCI bridges
│   └── stages/         # per-stage implementations
├── CONTRIBUTING.md
└── README.md
```

## Getting started

1. Clone: `gh repo clone plurigrid/horse`
2. Read `README.md` for the factory overview
3. Pick a stage, find an uninterpreted theorem, write the BCI bridge
4. PR with tag `[stage-N]` in the title
