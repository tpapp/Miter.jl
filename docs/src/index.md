# Miter

At the moment, this package is work in progress. The syntax may change without notice, and a lot of the functionality is undocumented. More importantly, an explanation of the key concepts that help in using this package is yet to be written.

What you see below is a gallery of plots. These serve as examples, and are also useful for visual inspection of plots.

All should be preceded by

```@example all
using Miter, Colors
```
to load the relevant packages.

## Gallery

```@example all
Plot([Lines((x, abs2(x)) for x in -1:0.1:1; color = colorant"red"),
      Scatter((x, (x + 1) / 2) for x in -1:0.1:1; color = colorant"darkgreen")])
```

```@example all
Tableau([Plot(Lines([(x, exp(-0.5 * abs2(x)) / √(2π)) for x in range(-2, 2; length = 100)])),
         Plot(Lines([(x, exp(-abs(x)) / 2) for x in range(-2, 2; length = 100)]))])
```
