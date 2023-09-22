# Miter

At the moment, this package is work in progress. The syntax may change without notice, and a lot of the functionality is undocumented. More importantly, an explanation of the key concepts that help in using this package is yet to be written.

What you see below is a gallery of plots. These serve as examples, and are also useful for visual inspection of plots.

All should be preceded by

```@example all
using Miter, Colors
using Unitful: mm
```
to load the relevant packages.

## Gallery

### Simple plots

```@example all
Plot([Lines((x, abs2(x)) for x in -1:0.02:1; color = colorant"red"),
      Scatter(MarkSymbol(; color = colorant"darkgreen"), (x, (x + 1) / 2) for x in -1:0.1:1)];
      x_axis = Axis.Linear(; label = math"x"),
      y_axis = Axis.Linear(; label = math"y"))
```

Horizontal lines and phantom objects (rendered, but ignored for boundary calculations).

```@example all
Plot(Scatter((x, sin(x) + (rand() - 0.5) / 10) for x in range(-π, π; length = 100)),
     Phantom(Hline(12.0)),      # does not show, it is outside the boundaries
     Hline(0.0))
```

Annotations.

```@example all
let c = colorant"teal",
    xy = collect((x,  0.5 * x + 0.1 * randn()) for x in range(-1, 1; length = 30))
    Plot(Scatter(MarkSymbol(; color = c), xy),
         Annotation((0, 0.3), textcolor(c, latex"random dots $y = 0.5\cdot x + N(0, 0.1)$");
                    rotate = 30))
end
```

Various kinds of marks.

```@example all
let x = range(0, 1; length = 21)
    Plot(Scatter(MarkSymbol(:+; color = colorant"firebrick"), (x, 0.2 * x) for x in x),
         Scatter(MarkSymbol(:*, color = colorant"olive"), (x, 0.1 + abs2(x)) for x in x),
         Scatter(MarkSymbol(:o; color = colorant"teal"), (x, -x + abs2(x) - 0.1) for x in x))
end
```

Guidelines, adding plot elements with `push!`.

```@example all
let plot = Plot(Scatter(MarkSymbol(:o; color = colorant"chocolate4"),
                        (sin(α), cos(α)) for α in range(-π, π, length = 61)))
    for θ in 0:30:150
        pushfirst!(plot, LineThrough((0, 0), tand(θ)))
    end
    plot
end
```

Grids.

```@example all
Plot(Hgrid(), # specified first; renders first
     Scatter((x, expm1(x) + randn() / 10)
             for x in range(0, 1; length = 100)))
```

Sync x and y bounds in a tableau.

```julia
function wobbler(x, y, r, rotate)
    Plot(Lines([sincos(θ) .* (r * (sin(θ  * 3 + rotate)/4 + 1))
                for θ in range(0, 2*π; length = 200)]))
end

m = Tableau(balanced_rectangle([wobbler(0, 0, 2, 0),
                                wobbler(1, 0, 1, π/2),
                                wobbler(-1, 0, 3, -π/2),
                                wobbler(1, 3, 1, π)]));
sync_bounds!(:xy, m)
```

Q5 (five quantiles) plots.

```@example all
Plot(Scatter(MarkQ5(),
             (x, Q5(randn(10) ./ 4 .+ (x / 3)))
             for x in range(0, 5; length = 8)),
     Scatter(MarkQ5(; color = colorant"deepskyblue1"),
             (Q5(randn(10) ./ 4 .+ (abs2(y) / 5)), y)
             for y in range(0, 5; length = 8)))
```

### Tableaus

```@example all
Tableau(balanced_rectangle(
        [Plot(Lines([(x, exp(-0.5 * abs2(x)) / √(2π))
                     for x in range(-2, 2; length = 101)]);
              y_axis = Axis.Linear(; label = "pdf of normal distribution")),
         Plot(Lines([(x, exp(-abs(x)) / 2)
                     for x in range(-2, 2; length = 101)]);
              y_axis = Axis.Linear(; label = "pdf of Laplace distribution")),
         Plot(Lines([(x, exp(-x))
                     for x in range(0.1, 2; length = 50)]);
              y_axis = Axis.Linear(; label = "pdf of exponential distribution"))]))
```

### Visual debugging

```@example all
Canvas(Tableau([Miter.dummy("$(x), $(y)") for x in 1:3, y in 1:4]),
       width = 100mm, height = 100mm)
```
