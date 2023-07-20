# Miter.jl

![lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange.svg)
[![build](https://github.com/tpapp/Miter.jl/workflows/CI/badge.svg)](https://github.com/tpapp/Miter.jl/actions?query=workflow%3ACI)
[![codecov.io](http://codecov.io/github/tpapp/Miter.jl/coverage.svg?branch=master)](http://codecov.io/github/tpapp/Miter.jl?branch=master)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://tpapp.github.io/Miter.jl/stable)
[![Documentation](https://img.shields.io/badge/docs-master-blue.svg)](https://tpapp.github.io/Miter.jl/dev)

A Julia plotting package using the PGF Basic Layer Core.

**Very experimental, each commit may break something, don't use in production code.**

# Overview

This is (yet another) plotting package for [Julia](https://julialang.org/). It produces plots using the *basic layer* of [pgf](https://github.com/pgf-tikz/pgf), and can also compile them via LaTeX. 

It can currently output plots as `pdf`, `svg`, `tex` (standalone file) and `tikz` (for embedding in LaTeX documents). The comparative advantage of this package lies in its close integration with LaTeX: you can use LaTeX expressions for text, eg various text labels, and the resulting plots blend seamlessly with your LaTeX document. Unless you need these, it may not make sense to use this package, as it is not particularly fast, and does not handle busy plots (with eg overplotting) very well.

A closely related package is [PGFPlotsX.jl](https://github.com/KristofferC/PGFPlotsX.jl). The table below compares them, planned features are in *italics*.

| PGFPlotsX.jl                                     | Miter.jl                                                                                               |
|--------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| uses `pgfplots`                                  | uses the basic layer primitives of `pgf`, doing calculations in Julia whenever possible, may be faster |
| options and syntax can match `pgfplots` closely  | not related to `pgfplots` in any way, uses only Julia syntax                                           |
| needs a local LaTeX installation, `pdf2svg`, etc | uses binaries from jlls (*planned: optionally uses local installation*)                                |
| strings passed through as is                     | special chars in strings (`#`, `$`, ...) escaped by default, use `math` or `latex`                     |

