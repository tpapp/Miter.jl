# Miter.jl

![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)
[![build](https://github.com/tpapp/Miter.jl/workflows/CI/badge.svg)](https://github.com/tpapp/Miter.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/github/tpapp/Miter.jl/branch/master/graph/badge.svg?token=7HeB2iNJz4)](https://codecov.io/github/tpapp/Miter.jl)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://tpapp.github.io/Miter.jl/stable)
[![Documentation](https://img.shields.io/badge/docs-master-blue.svg)](https://tpapp.github.io/Miter.jl/dev)

A Julia plotting package using LaTeX/PGF for text (including equations) and Cairo for everything else.

**Very experimental, each commit may break something, don't use in production code.**

# Overview

This is (yet another) plotting package for [Julia](https://julialang.org/). It produces plots by rendering vector graphics using [Cairo][cairo], then overlaying them with text (including equations) in LaTeX, using [PGF][pgf]. Compilation happens in a single pass for all text.

Check out the [gallery][gallery] for examples.

It can output plots as `pdf`, `svg`, `tex` (standalone file) and `tikz` (for embedding in LaTeX documents). The comparative advantage of this package lies in its close integration with LaTeX: you can use LaTeX expressions for text, eg various text labels, and the resulting plots blend seamlessly with your LaTeX document.

A closely related package is [PGFPlotsX.jl](https://github.com/KristofferC/PGFPlotsX.jl). The table below compares them.

| PGFPlotsX.jl                                             | Miter.jl                                                                                           |
|----------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| uses `pgfplots`                                          | uses Cairo (for vector graphics) + PGF (for text/equations)                                        |
| options and syntax can match `pgfplots` closely          | not related to `pgfplots` in any way, uses only Julia syntax                                       |
| units passed as text strings                             | uses units like [`mm`, `inch`, `pt` defined in this package][lengths]                              |
| colors need to be expanded to text strings in some cases | uses [ColorTypes.jl](https://github.com/JuliaGraphics/ColorTypes.jl) for colors                    |
| needs a local LaTeX installation, `pdf2svg`, etc         | uses [Tectonic][tectonic] and [Cairo][cairo] binaries from `jll`s                                  |
| strings passed through as is                             | special chars in strings (`#`, `$`, ...) escaped automatically, use [`lx"..."`][strings] for LaTeX |

[gallery]: https://tpapp.github.io/Miter.jl/stable/gallery.html
[strings]: https://tpapp.github.io/Miter.jl/stable/building_blocks.html#Strings-and-LaTeX
[tectonic]: https://tectonic-typesetting.github.io/en-US/
[cairo]: https://www.cairographics.org
[lengths]: https://tpapp.github.io/Miter.jl/stable/building_blocks.html#Length-units
[pgf]: https://tikz.dev/
