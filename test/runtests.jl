using Miter, Miter.Intervals, Miter.Ticks, Miter.PGF
using Miter.Ticks: ShiftedDecimals, ShiftedDecimal, format_latex
using Miter.PGF: math
using Test
using Unitful.DefaultSymbols
using Colors, ColorSchemes
using StatsBase: fit, Histogram

####
#### test utilities
####

###
### rudimentary checks for output files
###

is_pdf(path) = open(io -> read(io, 4), path, "r") == b"%PDF"
is_svg(path) = open(io -> read(io, 5), path, "r") == b"<?xml"
is_png(path) = open(io -> read(io, 4), path, "r") == b"\x89PNG"

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
#### pgf
####

###
### splitting
###

using Miter.PGF: split_interval, Spacer, Relative, split_matrix

@testset "split" begin
    @test split_interval(0.0mm, 10.0mm, (Spacer(), 1mm, Relative(0.5), Spacer())) ==
        ((0.0mm, 2.0mm), (2.0mm, 3.0mm), (3.0mm, 8.0mm), (8.0mm, 10.0mm))
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

@testset "nontrivial linear ticks" begin
    @test @inferred nontrivial_linear_tick_alternatives(Interval(0, 10)) ==
        [ShiftedDecimals(0:1:10, 0),
         ShiftedDecimals(0:2:10, 0),
         ShiftedDecimals(0:5:10, 0),
         ShiftedDecimals(0:1:1, 1)]

    @test @inferred nontrivial_linear_tick_alternatives(Interval(-2.1, 7.3)) ==
        [ShiftedDecimals(-21:1:73, -1),
         ShiftedDecimals(-20:2:72, -1),
         ShiftedDecimals(-20:5:70, -1),
         ShiftedDecimals(-2:1:7, 0),
         ShiftedDecimals(-2:2:6, 0),
         ShiftedDecimals(0:5:5, 0)]

    @test @inferred nontrivial_linear_tick_alternatives(Interval(-0.021, 0.073)) ==
        map(t -> ShiftedDecimals(t.significands, t.inner_exponent - 2),
            nontrivial_linear_tick_alternatives(Interval(-2.1, 7.3)))
end

@testset "format ticks" begin
    # no outer exponent
    @test format_latex(ShiftedDecimal(5, 0, 0)) == math"5"
    @test format_latex(ShiftedDecimal(-5, 0, 0)) == math"-5"
    @test format_latex(ShiftedDecimal(5, 3, 0)) == math"5000"
    @test format_latex(ShiftedDecimal(-5, 3, 0)) == math"-5000"
    @test format_latex(ShiftedDecimal(5, -1, 0)) == math"0.5"
    @test format_latex(ShiftedDecimal(-5, -1, 0)) == math"-0.5"
    @test format_latex(ShiftedDecimal(5, -2, 0)) == math"0.05"
    @test format_latex(ShiftedDecimal(-5, -2, 0)) == math"-0.05"
    @test format_latex(ShiftedDecimal(0, -2, 0)) == math"0.00"

    # outer exponent
    @test format_latex(ShiftedDecimal(5, 0, 2)) == math"5\cdot 10^{2}"
    @test format_latex(ShiftedDecimal(-5, 0, -2)) == math"-5\cdot 10^{-2}"
    @test format_latex(ShiftedDecimal(5, 3, 2)) == math"5000\cdot 10^{2}"
    @test format_latex(ShiftedDecimal(-5, 3, -2)) == math"-5000\cdot 10^{-2}"

    # zeros - outer exponent is always ignored
    @test format_latex(ShiftedDecimal(0, 0, 0)) == math"0"
    @test format_latex(ShiftedDecimal(0, -1, 0)) == math"0.0"
    @test format_latex(ShiftedDecimal(0, -2, 0)) == math"0.00"
    @test format_latex(ShiftedDecimal(0, 2, 0)) == math"0"
    @test format_latex(ShiftedDecimal(0, 0, -2)) == math"0"
end

@testset "sensible linear ticks" begin
    @test sensible_linear_ticks(Interval(0, 1), TickFormat(), TickSelection()) ==
        [0.0 => math("0.0"), 0.2 => math("0.2"), 0.4 => math("0.4"),
         0.6000000000000001 => math("0.6"), 0.8 => math("0.8"), 1.0 => math("1.0")]
end

@testset "API sanity checks" begin
    # throw elements in a plot and make sure it compiles
    L = Lines((x, abs2(x)) for x in -1:0.1:1)
    S = Scatter((x, (x + 1) / 2) for x in -1:0.1:1)
    C = Circles([(randn(), randn(), abs(randn())) for _ in 1:10], 1mm)
    HX = RelativeBars(:horizontal, fit(Histogram, randn(100)))
    HY = RelativeBars(:vertical, fit(Histogram, randn(100)))
    H2 = hpd_heatmap(fit(Histogram, (randn(100), randn(100))),
                     0.2:0.2:0.8, ColorSchemes.OrRd_5)
    A = Annotation((1, 2), math"\cos(φ)")
    HG = Hgrid()
    HL = Hline(1.0)
    LT = LineThrough((1.0, 2.0), 1.0)

    plot = Plot(L, S, A, HG, HL, LT;
                x_axis = Axis.Linear(; label = math"x"),
                y_axis = Axis.Linear(; label = math"y"),
                title = "what a great title")

    let filename = tempname() * ".pdf"
        Miter.save(filename, plot)
        @test is_pdf(filename)
    end

    let filename = tempname() * ".png"
        Miter.save(filename, plot)
        @test is_png(filename)
    end

    let filename = tempname() * ".svg"
        Miter.save(filename, plot)
        @test is_svg(filename)
    end

    tableau = Tableau(balanced_rectangle(Plot(e) for e in [L, S, C, HX, HY, H2]))
    filename = tempname() * ".pdf"
    Miter.save(filename, tableau)
    @test is_pdf(filename)
end

@testset "balanced rectangle" begin
    @test @inferred(balanced_rectangle(1:3)) == [3 1; nothing 2]
end

@testset "sync bounds" begin
    v = [Plot(Scatter(zip(randn(10), randn(10)))) for i in 1:4]
    @test allequal([first(bounds_xy(p)) for p in sync_bounds(:X, v)])
    @test allequal([last(bounds_xy(p)) for p in sync_bounds(:Y, v)])
    @test allequal([bounds_xy(p) for p in sync_bounds(:XY, v)])
    @test_throws ArgumentError sync_bounds(:x, v)

    m = [Plot(Scatter(zip(randn(10), randn(10)))) for _ in 1:2, _ in 1:3]

    m_x = sync_bounds(:x, m)
    @test size(m_x) == size(m)
    for i in axes(m, 1)
        @test allequal(first.(bounds_xy.(m_x[i, :])))
    end

    m_y = sync_bounds(:y, m)
    @test size(m_y) == size(m)
    for j in axes(m, 2)
        @test allequal(last.(bounds_xy.(m_y[:, j])))
    end

    m_xy = sync_bounds(:xy, m)
    @test size(m_xy) == size(m)
    for i in axes(m, 1)
        @test allequal(first.(bounds_xy.(m_xy[i, :])))
    end
    for j in axes(m, 2)
        @test allequal(last.(bounds_xy.(m_xy[:, j])))
    end

    @test bounds_xy.(sync_bounds(:xy, (m[i,j] for i in axes(m, 1), j in axes(m, 2)))) ==
        bounds_xy.(m_xy)
end
