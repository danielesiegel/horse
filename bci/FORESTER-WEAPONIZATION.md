# Forester Weaponization for BCI Factory

Every forester tree in `localcharts/forest/` mapped to a BCI Factory stage.

## Stage 1: Signal → Sites (Theory of Composition)

### `theory-of-composition.tree` → Electrode Montage as SMD Category

A **theory of composition** is a symmetric monoidal double category. For BCI:

- **Objects (interfaces)** = electrode sites (Fp1, Fp2, C3, C4, O1, O2, ...)
- **Operations (compositions)** = montage derivations (bipolar, Laplacian, common average)
- **Tight maps** = physical repositioning of electrodes
- **2-cells** = interpolation between montage schemes

The montage **is** a symmetric monoidal double category. Parallel electrodes tensor; serial derivations compose.

### `equipment-of-sets.tree` → Raw Sample Space

Raw ADC samples live in **dblSet**: sets of voltage readings, functions between sample buffers (downsampling, windowing), spans as shared-reference re-montaging.

### `ocl-0002.tree` (Combinatorial Data Structures) → Electrode Graph

The electrode montage is a combinatorial data structure: electrodes reference each other through derivation chains. ACSets encode this directly — each electrode is a row, each derivation is a morphism.

---

## Stage 2: Local Processing → Cohomology (Theory of Systems)

### `theory-of-systems.tree` → Neural Signal System

A **theory of systems** over the montage composition theory:

- **Sys(A)** = category of neural signals at interface A (spectral decompositions, filtered bands)
- **Sys(h)** = profunctor of signal transformations under re-montaging
- **Sys(p)** = composition functor: how local spectral features compose into regional patterns

The BCI pipeline **is** a double algebra over the montage operad.

### `st-0002.tree` (Operads) → Wiring Diagrams for fNIRS

Spivak's wiring diagrams directly encode fNIRS optode placement:
- **Sources** = NIR emitters (760nm, 850nm)
- **Detectors** = photodiodes
- **Wires** = photon paths through cortex
- **Operations** = Beer-Lambert transform (ΔOD → ΔHbO/HbR)

The GF(3) encoding emerges naturally: HbO(+1), HbR(-1), baseline(0). The operad composition preserves trit parity because Beer-Lambert is linear.

### `kan-things.tree` → Signal Reconstruction via Kan Extensions

**Right Kan extension** = optimal signal reconstruction from sparse electrodes:
```
ran_H F(b,c) = ∫_{a:A} H(a,b) → F(a,c)
```
Where:
- A = full electrode set (ideal 256-channel)
- B = actual electrode set (8-channel Cyton)
- H = embedding profunctor (which channels we actually have)
- F = desired full-brain signal
- ran_H F = best reconstruction from 8 channels

**Left Kan lift** = minimum electrode set needed to detect a given neural pattern:
```
lift_K F(a,b) = ∫^{c:C} K(b,c) × F(a,c)
```
This is the **electrode optimization problem**: given target cognitive state K and desired discrimination F, what's the minimal montage?

### `double-operad.tree` → Hierarchical BCI Processing

Double T-operads give us:
- **Tight maps** = online processing (must be causal, ≤4ms)
- **Loose maps (operations)** = offline analysis (can look at full epoch)
- **2-cells** = calibration: relating online approximations to offline ground truth

---

## Stage 3: Global Assembly → Descent (Doctrines & Paradigms)

### `st-0003.tree` (Theories, Doctrines, Paradigms) → BCI Paradigm Selection

The three levels map directly:

| CST Level | BCI Level | Example |
|---|---|---|
| **Paradigm** | Measurement modality | EEG (set paradigm) vs fNIRS+EEG (category paradigm) |
| **Doctrine** | Processing framework | FFT-based, wavelet, Riemannian geometry |
| **Theory** | Specific BCI system | 8ch motor imagery, P300 speller, SSVEP |

The **equipment** E = dblCat for the category paradigm means systems are organized in categories (can be compared by morphisms = signal similarity metrics), not just sets.

**Key insight**: Most BCI systems operate in the **set paradigm** (systems compared only for equality — did the user intend left or right?). Moving to the **category paradigm** enables graded comparisons: "this signal is 0.7 similar to left-intent, with a cohomology obstruction class in H¹ indicating ambiguity localized to C3/C4."

### `concrete-object.tree` → The Brain as Concrete Object

The brain is the archetypal concrete object for BCI: it lives simultaneously in:
- **Top** (topological space of electrode sites)
- **Vect** (vector space of voltage readings)
- **Prob** (probability distributions for Bayesian decoding)
- **Cat** (category of cognitive states and transitions)
- **GF(3)-Mod** (trit-valued fNIRS encoding)

The more modalities we fuse, the more concrete the brain becomes. This is why multimodal BCI (EEG+fNIRS+sEMG+eye) outperforms unimodal.

### `software/decapodes.tree` → Decapodes for Hemodynamic PDEs

Decapodes.jl encodes the hemodynamic response function (HRF) as a discrete exterior calculus problem on the cortical mesh. Gluing local Decapodes solutions = descent in the Stacks sense.

---

## Stage 4: Decode → Categorical Semantics (OCapN + CRDT)

### `software/ocapn.tree` + `software/captp.tree` → BCI Capability Security

Decoded neural intents are **capabilities**: the user's brain issues capability tokens that authorize actions. OCapN/CapTP architecture:

- **Brain** = vat issuing capabilities
- **Decoded intent** = capability reference (unforgeable, attenuated)
- **Effector** = receiving vat (robotic arm, keyboard, smart home)
- **CapTP** = transport protocol ensuring intent → action fidelity

This is not metaphor. BCI outputs MUST be capability-secured: a misclassified "move arm" should not have unbounded authority. Object capabilities give us exactly the right attenuation model.

### `software/loro.tree` → CRDT for BCI State

Loro's CRDT primitives handle the key BCI challenge: multiple processing pipelines (EEG decoder, fNIRS decoder, sEMG decoder) producing concurrent state updates that must merge consistently. The brain state is a CRDT:

- **Text CRDT** → language model output from neural speech decoding
- **Structured CRDT** → hierarchical cognitive state (attention, valence, arousal)
- **Version control** → rollback misclassified intents

### `software/egg.tree` → E-graph Optimization of Decode Pipeline

E-graphs (equality saturation) optimize the decode DAG:
- Multiple equivalent decode paths exist (FFT→threshold vs wavelet→classifier)
- E-graph finds the Pareto-optimal path for latency × accuracy
- Rewrite rules encode domain knowledge (e.g., "Laplacian reference ≡ surface Laplacian for motor cortex")

### `topos-0003.tree` (Categories, Controls, Flows) → Poly for BCI I/O

Polynomial functors type the BCI I/O:
```
p_BCI = Σ_{s : BrainState} y^{Action(s)}
```
Each brain state s has a dependent type of available actions. Cospans of polynomials = undirected wiring between BCI subsystems. This is exactly the Poly framework from the Berkeley seminar.

---

## Cross-cutting: GF(3) Conservation

The forester content's equipment/operad/algebra tower preserves GF(3) conservation:

```
Stage 1: montage composition preserves trit count (linear combination)
Stage 2: Beer-Lambert is linear → trit parity conserved
Stage 3: descent gluing is a limit → preserves algebraic structure
Stage 4: capability attenuation maps GF(3) → GF(3) (trit → trit)
```

**Theorem (BCI Factory Invariant)**: If each stage's functor is GF(3)-linear, the composite pipeline Signal→Sites→Cohomology→Descent→Decode preserves trit parity. ∎

## File Map

| Forester tree | BCI Stage | Weaponization |
|---|---|---|
| `theory-of-composition.tree` | 1 | Montage = SMD category |
| `equipment-of-sets.tree` | 1 | Raw ADC samples |
| `ocl-0002.tree` | 1 | Electrode graph as ACSets |
| `theory-of-systems.tree` | 2 | Neural signals = double algebra |
| `st-0002.tree` | 2 | Wiring diagrams for fNIRS optodes |
| `kan-things.tree` | 2 | Signal reconstruction & electrode optimization |
| `double-operad.tree` | 2 | Online/offline processing hierarchy |
| `st-0003.tree` | 3 | BCI paradigm/doctrine/theory stack |
| `concrete-object.tree` | 3 | Brain as concrete object |
| `software/decapodes.tree` | 3 | Hemodynamic PDE on cortical mesh |
| `software/ocapn.tree` | 4 | Capability-secured intent |
| `software/captp.tree` | 4 | Intent transport protocol |
| `software/loro.tree` | 4 | CRDT for concurrent BCI state |
| `software/egg.tree` | 4 | E-graph decode optimization |
| `topos-0003.tree` | 4 | Poly for BCI I/O typing |

## Authors as BCI collaborators

| Author | Expertise | BCI application |
|---|---|---|
| Matteo Capucci | Systems theory, doctrines | Stage 2-3 architecture |
| Owen Lynch | ACSets, structured data | Stage 1 electrode data model |
| David Jaz Myers | Categorical systems theory | Full pipeline formalization |
| David Spivak | Poly, wiring diagrams | Stage 4 I/O typing |
| Sophie Libkind | Decapodes | Stage 3 hemodynamic PDE |
| Jules Hedges | Open games | Neurofeedback as open game |
| Evan Patterson | ACSets, AlgebraicJulia | Stage 1-2 implementation |
| Kris Brown | AlgebraicRewriting | Stage 3 descent as rewriting |
