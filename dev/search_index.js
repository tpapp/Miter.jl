var documenterSearchIndex = {"docs":
[{"location":"#Miter","page":"Miter","title":"Miter","text":"","category":"section"},{"location":"","page":"Miter","title":"Miter","text":"At the moment, this package is work in progress. The syntax may change without notice, and a lot of the functionality is undocumented. More importantly, an explanation of the key concepts that help in using this package is yet to be written.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"What you see below is a gallery of plots. These serve as examples, and are also useful for visual inspection of plots.","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"All should be preceded by","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"using Miter, Colors","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"to load the relevant packages.","category":"page"},{"location":"#Gallery","page":"Miter","title":"Gallery","text":"","category":"section"},{"location":"","page":"Miter","title":"Miter","text":"Plot([Lines((x, abs2(x)) for x in -1:0.1:1; color = colorant\"red\"),\n      Scatter((x, (x + 1) / 2) for x in -1:0.1:1; color = colorant\"darkgreen\")])","category":"page"},{"location":"","page":"Miter","title":"Miter","text":"Tableau([Plot(Lines([(x, exp(-0.5 * abs2(x)) / √(2π)) for x in range(-2, 2; length = 100)])),\n         Plot(Lines([(x, exp(-abs(x)) / 2) for x in range(-2, 2; length = 100)]))])","category":"page"}]
}
