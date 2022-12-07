using Miter
using Test
using Unitful.DefaultSymbols

lp = line_plot([point(x, abs2(x)) for x in 0:0.01:1])

pa = plot_area(pgfpoint(0cm, 0cm), pgfpoint(10cm, 10cm),
               linear_axis(0, 1), linear_axis(0, 1))

writing_tex_stream("/tmp/x.tex") do ts
    Miter.tex_preamble(ts)
    render(ts, pa, lp)
    Miter.tex_postamble(ts)
end
