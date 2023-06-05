using Miter
using Test
using Unitful.DefaultSymbols
using ColorTypes

####
#### test utilities
####

is_pdf(path) = open(io -> read(io, 4), path, "r") == b"%PDF"

####
#### compilation
####

@testset "compile" begin
    LATEX_MWE = raw"""
              \documentclass{article}
              \begin{document}
              Hello world
              \end{document}
              """
    pdf_path = tempname() * ".pdf"
    @time Miter._compile(io -> write(io, LATEX_MWE), pdf_path)
    @test is_pdf(pdf_path)
end

####
#### test internals
####

using Miter: pgfusepath, pgfpath, pgfsetcolor, pgfusepathqfill, split_rectangle_fourways

lp = line_plot([point(x, abs2(x)) for x in 0:0.01:1])
c = canvas(10cm, 8cm)
r1, r2, r3, r4 = split_rectangle_fourways(c, 2cm, 2cm)
pa = plot_area(r4, linear_axis(0, 1), linear_axis(0, 1))

writing_tex_stream("/tmp/x.tex") do ts
    Miter.tex_preamble(ts)
    for (r, c) in [r1 => RGB(1.0, 0.0, 0.0),
                   r2 => RGB(1.0, 1.0, 0.0),
                   r3 => RGB(0.0, 0.0, 1.0),
                   r4 => RGB(0.9, 0.9, 0.9)]
        pgfpath(ts, r)
        pgfsetcolor(ts, c)
        pgfusepathqfill(ts)
    end
    render(ts, pa, lp)
    Miter.tex_postamble(ts)
end
