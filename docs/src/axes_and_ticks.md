# Axes and ticks

## Axes

Conceptually, *axis* maps the bounding interval box of plotted
coordinates to the canvas. The axis that is passed on to plot is a
*mapping* that performs this calculation. Given the coordinate bounds,
it also calculates the tick marks using a heuristic process that can
be customized.

```@docs
Axis.Linear
```

## Ticks

