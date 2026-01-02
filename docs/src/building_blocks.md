# Building blocks

## Length units

Miter defines its own length units, but you need to be `using Miter.Lengths` explicitly to import them into the namespace in order to avoid clashes, eg with [Unitful.jl](https://juliaphysics.github.io/Unitful.jl).

```@repl units
using Miter.Lengths
0.3mm
1inch + 0.6mm
3*2pt
```

Basic arithmetic is supported. It is recommended that users use the shorthand constants above, but you can also use the type constructor. 

```@docs
Miter.Lengths.Length
```

## Colors

For specifying colors, you can use the excellent [Colors.jl](https://juliagraphics.github.io/Colors.jl/) package. A particularly nice feature of this package is named colors, eg `colorant"steelblue"`. For color schemes, see [ColorSchemes.jl](https://juliagraphics.github.io/ColorSchemes.jl/).

Internally, all colors in Miter are `RGB{Float64}`, but you are welcome to use other types, they will be converted automatically.

## Strings and LaTeX

Strings (for axis labels, annotations, plot titles) can be provided three ways:

1. using any `::AbstractString` (except for the types below), eg `"100%"` or `"$5"`. This will be automatically emitted to the \LaTeX engine in an **escaped** form, such as `100\%`or `\$5`. Use this for plain text (including Unicode). This is always valid.
2. using the [`LaTeXEscapes.LaTeX`](@ref) wrapper that emits `str` **unchanged**, or one of the convenience string literals `lx"..."`or `lx"..."m`, where the only difference is that the latter wraps the content in `$`s (for math). Be careful: some basic sanity checks are performed, but using incorrect raw LaTeX can lead to errors that are hard to trace.
3. using `LaTeXString.LaTeXString`, especially if you want interpolation, but note that `L"..."` automatically wraps its input in `$`s and you may not want that.

If you concatenate strings of the types above with the `*` operator, make sure you put a `LaTeX` first (you can always insert an empty one, eg `LaTeX()` or `lx""`. That way, the output is a `LaTeX` and everything will be correctly escaped. Other combinations are deliberately unsupported.

## Coordinates and bounds

A plot is rendered in the following manner:

1. The coordinate bound is determined using all elements.
2. Axes are set up based on the calculated bounds.

The bounds of a plot element are determined using `Miter.combine_bounds_xy`. The default uses `Miter.bounds_xy` and combines the result, special cases can be handled by using something other than combination. Plot elements need to be in containers which are iterable for deterministic results.

Individual coordinate bounds are determined using `Miter.Coordinates.coordinate_bounds_xy`. The default calls `extrema` on the first and second element of coordinates. Other coordinate formats should customize this function.
