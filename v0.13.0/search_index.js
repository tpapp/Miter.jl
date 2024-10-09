var documenterSearchIndex = {"docs":
[{"location":"#Miter","page":"Miter","title":"Miter","text":"","category":"section"},{"location":"","page":"Miter","title":"Miter","text":"At the moment, this package is work in progress. The syntax may change without notice, and a lot of the functionality is undocumented. More importantly, an explanation of the key concepts that help in using this package is yet to be written.","category":"page"},{"location":"#Introduction","page":"Miter","title":"Introduction","text":"","category":"section"},{"location":"","page":"Miter","title":"Miter","text":"TBW","category":"page"},{"location":"#String-like-arguments","page":"Miter","title":"String-like arguments","text":"","category":"section"},{"location":"","page":"Miter","title":"Miter","text":"Strings (for axis labels, annotations, plot titles) can be provided three ways:","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"using any ::AbstractString (except for the types below), eg \"100%\" or \"$5\". This will be automatically emitted to the \\LaTeX engine in an escaped form, such as 100\\%or \\$5. Use this for plain text (including Unicode). This is always valid.\nusing the [LaTeX]@ref) wrapper that emits strunchanged, or one of the convenience string literals latex\"...\"or math\"..., where the only difference is that the latter wraps the content in $s (for math). Be careful, as using incorrect raw LaTeX can lead to errors that are hard to trace. Some basic sanity checks are performed, unless you are using LaTeX(str; skip_check = true).\nusing LaTeXString.LaTeXString, especially if you want interpolation, but note that L\"...\" automatically wraps its input in $s and you may not want that.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"If you concatenate strings of the types above with the * operator, make sure you put a LaTeX first (you can always insert an empty one, eg LaTeX() or latex\"\". That way, the output is a LaTeX and everything will be correctly escaped. Other combinations are deliberately unsupported. Please note that the skip_check flag is contagious: if any argument has it enabled, then so does the concatenated result.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"LaTeX","category":"page"},{"location":"#Miter.RawLaTeX.LaTeX","page":"Miter","title":"Miter.RawLaTeX.LaTeX","text":"LaTeX(latex; skip_check)\n\n\nA wrapper that allows its contents to be passed to LaTeX directly.\n\nIt is the responsibility of the user to ensure that this is valid LaTeX code within the document. Nevertheless, when skip_check = false (the default), some very basic checks may be performed when writing the final output to catch some errors (eg unbalanced math mode, mismatch curly braces), but these do not guarantee valid LaTeX code.\n\nThe string literals latex and math provide a convenient way to enter raw strings, with math wrapping its input in $s.\n\njulia> latex\"\\cos(\\phi)\"\nLaTeX(\"\\\\cos(\\\\phi)\")\n\njulia> math\"\\cos(\\phi)\"\nLaTeX(\"\\$\\\\cos(\\\\phi)\\$\")\n\nThe type supports concatenation with *, just ensure that the first argument is of this type (can be empty).\n\n\n\n\n\n","category":"type"},{"location":"#Gallery","page":"Miter","title":"Gallery","text":"","category":"section"},{"location":"","page":"Miter","title":"Miter","text":"What you see below is a gallery of plots. These serve as examples, and are also useful for visual inspection of plots.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"All should be preceded by","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"using Miter, Colors\nusing Unitful: mm","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"to load the relevant packages.","category":"page"},{"location":"#Simple-plots","page":"Miter","title":"Simple plots","text":"","category":"section"},{"location":"","page":"Miter","title":"Miter","text":"Plot([Lines((x, abs2(x)) for x in -1:0.02:1; color = colorant\"red\"),\n      Scatter(MarkSymbol(; color = colorant\"darkgreen\"), (x, (x + 1) / 2) for x in -1:0.1:1)];\n      x_axis = Axis.Linear(; label = math\"x\"),\n      y_axis = Axis.Linear(; label = math\"y\"),\n      title = \"line and scatter\")","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Horizontal and vertical lines, and phantom objects (rendered, but ignored for boundary calculations).","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Plot(Scatter((x, sin(x) + (rand() - 0.5) / 10) for x in range(-π, π; length = 100)),\n     Phantom(Hline(12.0)),      # does not show, it is outside the boundaries\n     Hline(0.0), Vline(0.0))","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Bar plots with bars directly specified.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"let c = [(0, 1, 2), (1, 2, 1), (2, 4, -0.5)]\n    Tableau([Plot(RelativeBars(:vertical, c)),\n             Plot(RelativeBars(:horizontal, c))])\nend","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Bar plots from a histogram.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"using StatsBase\nPlot(RelativeBars(:vertical, fit(Histogram, randn(100))))","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Annotations.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"let c = colorant\"teal\",\n    xy = collect((x,  0.5 * x + 0.1 * randn()) for x in range(-1, 1; length = 30))\n    Plot(Scatter(MarkSymbol(; color = c), xy),\n         Annotation((0, 0.3), textcolor(c, latex\"random dots $y = 0.5\\cdot x + N(0, 0.1)$\");\n                    rotate = 30))\nend","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Various kinds of marks.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"let x = range(0, 1; length = 21)\n    Plot(Scatter(MarkSymbol(:+; color = colorant\"firebrick\"), (x, 0.2 * x) for x in x),\n         Scatter(MarkSymbol(:*, color = colorant\"olive\"), (x, 0.1 + abs2(x)) for x in x),\n         Scatter(MarkSymbol(:o; color = colorant\"teal\"), (x, -x + abs2(x) - 0.1) for x in x))\nend","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Guidelines, adding plot elements (with push! & friends).","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"let plot = Plot(Scatter(MarkSymbol(:o; color = colorant\"chocolate4\"),\n                        (sin(α), cos(α)) for α in range(-π, π, length = 61)))\n    for θ in 0:30:150\n        pushfirst!(plot.contents, LineThrough((0, 0), tand(θ)))\n    end\n    plot\nend","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Grids.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Plot(Hgrid(), Vgrid(), # specified first; renders first\n     Scatter((x, expm1(x) + randn() / 10)\n             for x in range(0, 1; length = 100)))","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Sync x and y bounds in a tableau.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"using Accessors # for @modify\n\nfunction wobbler(x, y, r, rotate)\n    Plot(Lines([sincos(θ) .* (r * (sin(θ  * 3 + rotate)/4 + 1))\n                for θ in range(0, 2*π; length = 200)]))\nend\n\nm = Tableau(balanced_matrix([wobbler(0, 0, 2, 0),\n                                wobbler(1, 0, 1, π/2),\n                                wobbler(-1, 0, 3, -π/2),\n                                wobbler(1, 3, 1, π)]));\n@modify(sync_bounds(:xy), m.contents) # sync columns and rows","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Add an invisible object to extend the y axis.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Plot([Lines((x, x^2) for x in range(0, 1; length = 20)),\n      Invisible(nothing, Interval(-1, 1))])","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Q5 (five quantiles) plots.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Plot(Scatter(MarkQ5(),\n             (x, Q5(randn(10) ./ 4 .+ (x / 3)))\n             for x in range(0, 5; length = 8)),\n     Scatter(MarkQ5(; color = colorant\"deepskyblue1\"),\n             (Q5(randn(10) ./ 4 .+ (abs2(y) / 5)), y)\n             for y in range(0, 5; length = 8)))","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Circles.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"x_y_w = [(x, y, 6 - hypot(x, y)) for x in -5:5 for y in -5:5 if hypot(x, y) ≤ 5]\n# make the largest point have 3mm radius\nPlot(Circles(x_y_w, 3mm / √maximum(last, x_y_w)))","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Color matrix (a building block for heatmaps etc).","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Plot(ColorMatrix([0, 1, 3], [2, 4, 5],\n                 [nothing colorant\"green\";\n                  colorant\"blue\" colorant\"red\"]))","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Color matrix built from a histogram.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"using StatsBase, ColorSchemes\nh = fit(Histogram, (randn(1000), randn(1000)); nbins = (15, 17))\nPlot(hpd_heatmap(h, range(0.2, 0.8; step = 0.2), ColorSchemes.OrRd_5))","category":"page"},{"location":"#Tableaus","page":"Miter","title":"Tableaus","text":"","category":"section"},{"location":"","page":"Miter","title":"Miter","text":"Tableau(balanced_matrix(\n        [Plot(Lines([(x, exp(-0.5 * abs2(x)) / √(2π))\n                     for x in range(-2, 2; length = 101)]);\n              y_axis = Axis.Linear(; label = \"pdf of normal distribution\")),\n         Plot(Lines([(x, exp(-abs(x)) / 2)\n                     for x in range(-2, 2; length = 101)]);\n              y_axis = Axis.Linear(; label = \"pdf of Laplace distribution\")),\n         Plot(Lines([(x, exp(-x))\n                     for x in range(0.1, 2; length = 50)]);\n              y_axis = Axis.Linear(; label = \"pdf of exponential distribution\"))]))","category":"page"},{"location":"#Visual-debugging","page":"Miter","title":"Visual debugging","text":"","category":"section"},{"location":"","page":"Miter","title":"Miter","text":"Canvas(Tableau([Miter.dummy(\"$(x), $(y)\") for x in 1:3, y in 1:4]),\n       width = 100mm, height = 100mm)","category":"page"},{"location":"#Corner-cases","page":"Miter","title":"Corner cases","text":"","category":"section"},{"location":"#Handle-collapsing-axes-gracefully","page":"Miter","title":"Handle collapsing axes gracefully","text":"","category":"section"},{"location":"","page":"Miter","title":"Miter","text":"Plot(Scatter([(0.49999,0.49999)]))","category":"page"}]
}
