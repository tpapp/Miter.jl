using Miter, Miter.Intervals, Miter.Ticks
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
    @time Miter.Compile.pdf(io -> write(io, LATEX_MWE), pdf_path)
    @test is_pdf(pdf_path)
end

####
#### test internals
####

# using Miter: pgfusepath, pgfpath, pgfsetcolor, pgfusepathqfill, split_rectangle_fourways

# lp = line_plot([point(x, abs2(x)) for x in 0:0.01:1])
# c = canvas(10cm, 8cm)
# r1, r2, r3, r4 = split_rectangle_fourways(c, 2cm, 2cm)
# pa = plot_area(r4, linear_axis(0, 1), linear_axis(0, 1))

# writing_tex_stream("/tmp/x.tex") do ts
#     Miter.tex_preamble(ts)
#     for (r, c) in [r1 => RGB(1.0, 0.0, 0.0),
#                    r2 => RGB(1.0, 1.0, 0.0),
#                    r3 => RGB(0.0, 0.0, 1.0),
#                    r4 => RGB(0.9, 0.9, 0.9)]
#         pgfpath(ts, r)
#         pgfsetcolor(ts, c)
#         pgfusepathqfill(ts)
#     end
#     render(ts, pa, lp)
#     Miter.tex_postamble(ts)
# end

####
#### test ticks
####

using Miter.Ticks
using Miter.Ticks: format_ticks

@testset "nontrivial linear ticks" begin
    @test @inferred nontrivial_linear_ticks(Interval(0, 10)) ==
        [(significands = 0:1:10, exponent = 0),
         (significands = 0:2:10, exponent = 0),
         (significands = 0:5:10, exponent = 0),
         (significands = 0:1:1, exponent = 1)]

    @test @inferred nontrivial_linear_ticks(Interval(-2.1, 7.3)) ==
        [(significands = -21:1:73, exponent = -1),
         (significands = -20:2:72, exponent = -1),
         (significands = -20:5:70, exponent = -1),
         (significands = -2:1:6, exponent = 0),
         (significands = -2:2:6, exponent = 0),
         (significands = 0:5:5, exponent = 0)]

    @test @inferred nontrivial_linear_ticks(Interval(-0.021, 0.073)) ==
        map(((; significands, exponent),) -> (; significands, exponent = exponent -2),
            nontrivial_linear_ticks(Interval(-2.1, 7.3)))
end

@testset "format ticks" begin
    @test format_ticks(-1:2, 0, TickFormat()) == ["\$-1\$", "\$0\$", "\$1\$", "\$2\$"]
    @test format_ticks(-1:2, 3, TickFormat()) == ["\$-1000\$", "\$0\$", "\$1000\$", "\$2000\$"]
    @test format_ticks(-1:2, 4, TickFormat()) == ["\$-1 \\times 10^{4}\$", "\$0 \\times 10^{4}\$", "\$1 \\times 10^{4}\$", "\$2 \\times 10^{4}\$"]
    @test format_ticks(-1:2, 4, TickFormat(; thousands = true)) == ["\$-10 \\times 10^{3}\$", "\$0 \\times 10^{3}\$", "\$10 \\times 10^{3}\$", "\$20 \\times 10^{3}\$"]
    @test format_ticks(-1:2, -4, TickFormat()) == ["\$-1 \\times 10^{-4}\$", "\$0 \\times 10^{-4}\$", "\$1 \\times 10^{-4}\$", "\$2 \\times 10^{-4}\$"]
    @test format_ticks(-1:2, -4, TickFormat(; thousands = true)) == ["\$-100 \\times 10^{-6}\$", "\$0 \\times 10^{-6}\$", "\$100 \\times 10^{-6}\$", "\$200 \\times 10^{-6}\$"]
    @test format_ticks(0:2:10, -1, TickFormat()) == ["\$0.0\$", "\$0.2\$", "\$0.4\$", "\$0.6\$", "\$0.8\$", "\$1.0\$"]
end

@testset "sensible linear ticks" begin
    @test sensible_linear_ticks(Interval(0, 1), TickFormat(), TickSelection()) ==
        [0.0 => "\$0.0\$", 0.2 => "\$0.2\$", 0.4 => "\$0.4\$", 0.6000000000000001 => "\$0.6\$", 0.8 => "\$0.8\$", 1.0 => "\$1.0\$"]
end

plot = Plot([Lines((x, abs2(x)) for x in -1:0.1:1)])
filename = tempname() * ".pdf"
Miter.save(filename, plot)
@test is_pdf(filename)
