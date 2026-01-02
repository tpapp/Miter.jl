# Overview

!!! note
    At the moment, this package is work in progress. The API may change without notice, and a lot of the functionality is undocumented. More importantly, an explanation of the key concepts that help in using this package is yet to be written. Comments, questions, and suggestions are very welcome.

## Introduction

Miter is a Julia package for making 2D plots. It has the following features:

1. Close integration with LaTeX. The text on plots is rendered using LaTeX, and Miter can emit LaTeX code you can include in your document directly, if you want consistent typefaces between plots and the rest of your document. Of course you can also expot to PDF, SVG, PNG.

2. Designed for extensibility. If you want a new type of plot, or just a non-standard annotation on an existing one, you just define a new composite type (`struct`), implement a few methods, and you can start using it. The details are explained in FIXME.

3. Fast implementation (considering that it calls into LaTeX). The vector drawings are done using [Cairo](https://www.cairographics.org/), while the text and equations are rendered using [Tectonic](https://tectonic-typesetting.github.io/en-US/).

On the other hand, Miter does not support 3D plotting, interactivity, and animations; it for static 2D plots.

## How it works

Before we dive into the details, consider the following example:

```@example basic0
using Miter, LaTeXEscapes, Colors
p = Plot(Hline(0; dash = LINE_DASHED, color = colorant"green"),
         Lines([(x, sin(x)) for x in range(-2, 2; length = 100)]);
         x_axis = Axis.Linear(; label = lx"x"m),
         y_axis = Axis.Linear(; label = lx"\sin(x)"m))
```

What Miter does can be described the following way:

First, it asks the *plot elements* `Hline` (a horizontal line) and `Lines` (a line plot) for intervals that bound their *contents* along the ``x`` and ``y`` axes. `Hline` only reports bounds along the ``y`` axis, so its bounds are ``\emptyset \times [0,0]``, while `Lines` is bounded by ``[-2, 2] \times [-1, 1]``. These are *combined* into the latter box.

Second, this box is used to calculate the axes and their ticks using a customizable algorithm. The axes establish a mapping from coordinates in ``(x, y)`` to the canvas of the plot.

Third, the canvas (itself a rectangle) is cut up into smaller rectangles for the axes and the drawing area for the plot. Each part is asked to [`render`](@ref) itself in a rectangle.

Cairo is used to generate this part of the image:

![Vector graphics drawn with Cairo](./assets/basic0-cairo.svg)

Which is then included into a `standalone` LaTeX document, to add text using [TikZ](https://tikz.dev/):

![Text drawn with LaTeX/TikZ](./assets/basic0-latex.svg)

The `lx"\sin(x)"m` you see above uses the [LaTeXEscapes.jl](https://github.com/tpapp/LaTeXEscapes.jl) to indicate LaTeX input, the trailing `m` indicates that it should be wrapped in `$`s. Of course, the more widely known [LaTeXStrings.jl](https://github.com/JuliaStrings/LaTeXStrings.jl) package is also supported.

These two parts are of course combined without user intervention, and the user sees the final plot that contains both text and vector parts.
