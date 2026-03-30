#!/usr/bin/env python3
"""Convert Stacks Project LaTeX chapters to forester trees."""

import os
import re
import glob

STACKS_DIR = "stacks-project"
OUT_DIR = "stacks-trees"
STACKS_URL = "https://stacks.math.columbia.edu"

# Chapter ordering from chapters.tex
CHAPTERS = [
    ("introduction", "Introduction"),
    ("conventions", "Conventions"),
    ("sets", "Set Theory"),
    ("categories", "Categories"),
    ("topology", "Topology"),
    ("sheaves", "Sheaves on Spaces"),
    ("sites", "Sites and Sheaves"),
    ("stacks", "Stacks"),
    ("fields", "Fields"),
    ("algebra", "Commutative Algebra"),
    ("brauer", "Brauer Groups"),
    ("homology", "Homological Algebra"),
    ("derived", "Derived Categories"),
    ("simplicial", "Simplicial Methods"),
    ("more-algebra", "More on Algebra"),
    ("smoothing", "Smoothing Ring Maps"),
    ("modules", "Sheaves of Modules"),
    ("sites-modules", "Modules on Sites"),
    ("injectives", "Injectives"),
    ("cohomology", "Cohomology of Sheaves"),
    ("sites-cohomology", "Cohomology on Sites"),
    ("dga", "Differential Graded Algebra"),
    ("dpa", "Divided Power Algebra"),
    ("sdga", "Differential Graded Sheaves"),
    ("hypercovering", "Hypercoverings"),
    ("schemes", "Schemes"),
    ("constructions", "Constructions of Schemes"),
    ("properties", "Properties of Schemes"),
    ("morphisms", "Morphisms of Schemes"),
    ("coherent", "Cohomology of Schemes"),
    ("divisors", "Divisors"),
    ("limits", "Limits of Schemes"),
    ("varieties", "Varieties"),
    ("topologies", "Topologies on Schemes"),
    ("descent", "Descent"),
    ("perfect", "Derived Categories of Schemes"),
    ("more-morphisms", "More on Morphisms"),
    ("flat", "More on Flatness"),
    ("groupoids", "Groupoid Schemes"),
    ("more-groupoids", "More on Groupoid Schemes"),
    ("etale", "Etale Morphisms of Schemes"),
    ("chow", "Chow Homology"),
    ("intersection", "Intersection Theory"),
    ("pic", "Picard Schemes of Curves"),
    ("weil", "Weil Cohomology Theories"),
    ("adequate", "Adequate Modules"),
    ("dualizing", "Dualizing Complexes"),
    ("duality", "Duality for Schemes"),
    ("discriminant", "Discriminants and Differents"),
    ("derham", "de Rham Cohomology"),
    ("local-cohomology", "Local Cohomology"),
    ("algebraization", "Algebraic and Formal Geometry"),
    ("curves", "Algebraic Curves"),
    ("resolve", "Resolution of Surfaces"),
    ("models", "Semistable Reduction"),
    ("functors", "Functors and Morphisms"),
    ("equiv", "Derived Categories of Varieties"),
    ("pione", "Fundamental Groups of Schemes"),
    ("etale-cohomology", "Etale Cohomology"),
    ("crystalline", "Crystalline Cohomology"),
    ("proetale", "Pro-etale Cohomology"),
    ("relative-cycles", "Relative Cycles"),
    ("more-etale", "More Etale Cohomology"),
    ("trace", "The Trace Formula"),
    ("spaces", "Algebraic Spaces"),
    ("spaces-properties", "Properties of Algebraic Spaces"),
    ("spaces-morphisms", "Morphisms of Algebraic Spaces"),
    ("decent-spaces", "Decent Algebraic Spaces"),
    ("spaces-cohomology", "Cohomology of Algebraic Spaces"),
    ("spaces-limits", "Limits of Algebraic Spaces"),
    ("spaces-divisors", "Divisors on Algebraic Spaces"),
    ("spaces-over-fields", "Algebraic Spaces over Fields"),
    ("spaces-topologies", "Topologies on Algebraic Spaces"),
    ("spaces-descent", "Descent and Algebraic Spaces"),
    ("spaces-perfect", "Derived Categories of Spaces"),
    ("spaces-more-morphisms", "More on Morphisms of Spaces"),
    ("spaces-flat", "Flatness on Algebraic Spaces"),
    ("spaces-groupoids", "Groupoids in Algebraic Spaces"),
    ("spaces-more-groupoids", "More on Groupoids in Spaces"),
    ("bootstrap", "Bootstrap"),
    ("spaces-pushouts", "Pushouts of Algebraic Spaces"),
    ("spaces-chow", "Chow Groups of Spaces"),
    ("groupoids-quotients", "Quotients of Groupoids"),
    ("spaces-more-cohomology", "More on Cohomology of Spaces"),
    ("spaces-simplicial", "Simplicial Spaces"),
    ("spaces-duality", "Duality for Spaces"),
    ("formal-spaces", "Formal Algebraic Spaces"),
    ("restricted", "Algebraization of Formal Spaces"),
    ("spaces-resolve", "Resolution of Surfaces Revisited"),
    ("formal-defos", "Formal Deformation Theory"),
    ("defos", "Deformation Theory"),
    ("cotangent", "The Cotangent Complex"),
    ("examples-defos", "Deformation Problems"),
    ("algebraic", "Algebraic Stacks"),
    ("examples-stacks", "Examples of Stacks"),
    ("stacks-sheaves", "Sheaves on Algebraic Stacks"),
    ("criteria", "Criteria for Representability"),
    ("artin", "Artin's Axioms"),
    ("quot", "Quot and Hilbert Spaces"),
    ("stacks-properties", "Properties of Algebraic Stacks"),
    ("stacks-morphisms", "Morphisms of Algebraic Stacks"),
    ("stacks-limits", "Limits of Algebraic Stacks"),
    ("stacks-cohomology", "Cohomology of Algebraic Stacks"),
    ("stacks-perfect", "Derived Categories of Stacks"),
    ("stacks-introduction", "Introducing Algebraic Stacks"),
    ("stacks-more-morphisms", "More on Morphisms of Stacks"),
    ("stacks-geometry", "The Geometry of Stacks"),
    ("moduli", "Moduli Stacks"),
    ("moduli-curves", "Moduli of Curves"),
    ("examples", "Examples"),
    ("exercises", "Exercises"),
    ("guide", "Guide to Literature"),
    ("desirables", "Desirables"),
    ("coding", "Coding Style"),
]


def extract_sections(tex_path):
    """Extract section titles from a LaTeX file."""
    sections = []
    try:
        with open(tex_path, "r", errors="replace") as f:
            for line in f:
                m = re.match(r"\\section\{(.+?)\}", line)
                if m:
                    title = m.group(1).replace("\\", "").replace("'", "'")
                    sections.append(title)
    except FileNotFoundError:
        pass
    return sections


def extract_definitions(tex_path, limit=15):
    """Extract definition/theorem/lemma labels from LaTeX."""
    defs = []
    try:
        with open(tex_path, "r", errors="replace") as f:
            content = f.read()
        for env in ["definition", "theorem", "lemma", "proposition"]:
            pattern = rf"\\begin\{{{env}\}}\s*\\label\{{({env}-[^}}]+)\}}"
            for m in re.finditer(pattern, content):
                defs.append((env, m.group(1)))
                if len(defs) >= limit:
                    return defs
    except FileNotFoundError:
        pass
    return defs


def make_tree_id(idx):
    """Generate stk-XXXX id."""
    return f"stk-{idx:04d}"


def escape_forester(s):
    """Escape special chars for forester markup."""
    return s.replace("{", "\\{").replace("}", "\\}").replace("#", "\\#").replace("\\\\", "")


def generate_tree(idx, slug, title, sections, defs):
    """Generate a forester tree for a Stacks chapter."""
    tid = make_tree_id(idx)
    lines = []
    lines.append(f"\\title{{{escape_forester(title)}}}")
    lines.append(f"\\taxon{{reference}}")
    lines.append(f"\\author{{The Stacks Project Authors}}")
    lines.append(f"\\meta{{source}}{{Stacks Project}}")
    lines.append(f"\\meta{{url}}{{{STACKS_URL}/tag/0000}}")
    lines.append(f"\\meta{{slug}}{{{slug}}}")
    lines.append(f"\\tag{{stacks-project}}")
    lines.append(f"\\tag{{algebraic-geometry}}")
    lines.append("")
    lines.append(f"\\p{{Chapter from the \\strong{{Stacks Project}}, an open-source textbook and reference for algebraic geometry.}}")
    lines.append("")

    if sections:
        lines.append("\\subtree{")
        lines.append("\\title{Sections}")
        lines.append("\\ol{")
        for sec in sections:
            lines.append(f"  \\li{{{escape_forester(sec)}}}")
        lines.append("}")
        lines.append("}")
        lines.append("")

    if defs:
        lines.append("\\subtree{")
        lines.append("\\title{Key Definitions}")
        lines.append("\\ul{")
        for env, label in defs[:10]:
            nice = label.replace("-", " ").replace("_", " ")
            lines.append(f"  \\li{{\\code{{{label}}} ({env})}}")
        lines.append("}")
        lines.append("}")

    return tid, "\n".join(lines)


def generate_index(chapter_trees):
    """Generate the root stacks index tree."""
    lines = []
    lines.append("\\title{Stacks Project}")
    lines.append("\\taxon{forest}")
    lines.append("\\author{The Stacks Project Authors}")
    lines.append("\\meta{source}{Stacks Project}")
    lines.append(f"\\meta{{url}}{{{STACKS_URL}}}")
    lines.append("\\tag{stacks-project}")
    lines.append("\\tag{algebraic-geometry}")
    lines.append("")
    lines.append("\\p{The \\strong{Stacks Project} is an open-source textbook and reference work on algebraic geometry. It covers foundations from set theory and categories through schemes, algebraic spaces, algebraic stacks, and moduli theory.}")
    lines.append("")
    lines.append("\\p{These trees are chapter-level summaries. Full content at \\link{https://stacks.math.columbia.edu}.}")
    lines.append("")

    # Group by section
    groups = [
        ("Preliminaries", 0, 25),
        ("Schemes", 25, 41),
        ("Topics in Scheme Theory", 41, 64),
        ("Algebraic Spaces", 64, 82),
        ("Topics in Geometry", 82, 89),
        ("Deformation Theory", 89, 93),
        ("Algebraic Stacks", 93, 107),
        ("Topics in Moduli Theory", 107, 109),
    ]

    for group_name, start, end in groups:
        lines.append(f"\\subtree{{")
        lines.append(f"\\title{{{group_name}}}")
        for tid, title in chapter_trees[start:end]:
            lines.append(f"\\transclude{{{tid}}}")
        lines.append("}")
        lines.append("")

    return "stk-0000", "\n".join(lines)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    chapter_trees = []
    for idx, (slug, title) in enumerate(CHAPTERS, start=1):
        tex_path = os.path.join(STACKS_DIR, f"{slug}.tex")
        sections = extract_sections(tex_path)
        defs = extract_definitions(tex_path)
        tid, content = generate_tree(idx, slug, title, sections, defs)
        chapter_trees.append((tid, title))

        out_path = os.path.join(OUT_DIR, f"{tid}.tree")
        with open(out_path, "w") as f:
            f.write(content)
        print(f"  {tid} -> {title} ({len(sections)} sections, {len(defs)} defs)")

    # Write index
    idx_id, idx_content = generate_index(chapter_trees)
    with open(os.path.join(OUT_DIR, f"{idx_id}.tree"), "w") as f:
        f.write(idx_content)
    print(f"\n  {idx_id} -> Stacks Project Index ({len(chapter_trees)} chapters)")
    print(f"\nGenerated {len(chapter_trees) + 1} trees in {OUT_DIR}/")


if __name__ == "__main__":
    main()
