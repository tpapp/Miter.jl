# Miter

At the moment, this package is work in progress. The syntax may change without notice, and a lot of the functionality is undocumented. More importantly, an explanation of the key concepts that help in using this package is yet to be written.

What you see below is a gallery of plots. These serve as examples, and are also useful for visual inspection of plots.

All should be preceded by

```@example all
using Miter, Colors
```

## Gallery

```@example all
Plot([Lines((x, abs2(x)) for x in -1:0.1:1; color = colorant"red"),
      Scatter((x, (x + 1) / 2) for x in -1:0.1:1; color = colorant"darkgreen")])
```
