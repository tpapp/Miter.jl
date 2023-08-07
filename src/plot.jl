####
#### plot
####

export Plot, Lines, Scatter

using ArgCheck: @argcheck
using ..Axis: Linear, DrawingArea, coordinates_to_point, bounds
import ..Axis: bounds_xy
using ..Intervals
using ..Defaults: DEFAULTS
using ..PGF
using Unitful: mm

Base.@kwdef struct PlotStyle
    axis_left::PGF.LENGTH = DEFAULTS.plot_style_axis_left
    axis_bottom::PGF.LENGTH = DEFAULTS.plot_style_axis_bottom
    margin_right::PGF.LENGTH = DEFAULTS.plot_style_margin_right
    margin_top::PGF.LENGTH = DEFAULTS.plot_style_margin_top
end

struct Plot
    contents
    x_axis
    y_axis
    style
    @doc """
    $(SIGNATURES)
    """
    function Plot(contents::AbstractVector = []; x_axis = Linear(), y_axis = Linear(), style = PlotStyle())
        new(Vector{Any}(contents), x_axis, y_axis, style)
    end
end

Plot(contents...; kwargs...) = Plot(collect(Any, contents); kwargs...)

Base.show(svg_io::IO, ::MIME"image/svg+xml", plot::Plot) = _show_as_svg(svg_io, plot)

function PGF.render(io::IO, rectangle::PGF.Rectangle, plot::Plot)
    (; x_axis, y_axis, contents, style) = plot
    (; axis_left, axis_bottom, margin_top, margin_right) = style
    split = PGF.split_matrix(rectangle,
                         (axis_left, PGF.SPACER , margin_right),
                         (axis_bottom, PGF.SPACER, margin_top))
    plot_rectangle = split[2, 2]
    x_axis_rectangle = split[2, 1]
    y_axis_rectangle = split[1, 2]
    x_interval, y_interval = Axis.bounds_xy(contents)
    @argcheck x_interval ≢ ∅ "empty x range"
    @argcheck y_interval ≢ ∅ "empty y range"
    finalized_x_axis = Axis.finalize(x_axis, x_interval)
    finalized_y_axis = Axis.finalize(y_axis, y_interval)
    PGF.render(io, x_axis_rectangle, finalized_x_axis; orientation = :x)
    PGF.render(io, y_axis_rectangle, finalized_y_axis; orientation = :y)
    drawing_area = Axis.DrawingArea(; rectangle = plot_rectangle, finalized_x_axis, finalized_y_axis)
    for c in contents
        PGF.render(io, drawing_area, c)
    end
end

"""
$(SIGNATURES)

A helper function to define `bounds_xy` on an iterable of coordinate pairs.
"""
function coordinate_bounds(coordinates)
    # FIXME is bounds used anywhere else? if not, remove
    (bounds(x -> x[1], coordinates), bounds(x -> x[2], coordinates))
end

struct Lines
    coordinates
    line_width::PGF.LENGTH
    color
    function Lines(coordinates; line_width = 0.3mm, color = PGF.BLACK)
        line_width = PGF._length(line_width)
        @argcheck PGF.is_positive(line_width)
        new(coordinates, line_width, color)
    end
end

bounds_xy(lines::Lines) = coordinate_bounds(lines.coordinates)

function PGF.render(io::IO, drawing_area::DrawingArea, lines::Lines)
    (; coordinates, line_width, color) = lines
    peeled = Iterators.peel(coordinates)
    peeled ≡ nothing && return
    PGF.setlinewidth(io, line_width)
    PGF.setstrokecolor(io, color)
    c1, cR = peeled
    PGF.pathmoveto(io, coordinates_to_point(drawing_area, c1))
    for c in cR
        PGF.pathlineto(io, coordinates_to_point(drawing_area, c))
    end
    PGF.usepathqstroke(io)
end

struct Scatter
    coordinates
    line_width::PGF.LENGTH
    color
    kind::Symbol
    size::PGF.LENGTH
    function Scatter(coordinates; line_width = 0.3mm, color = PGF.BLACK, kind = :+, size = 2mm)
        line_width = PGF._length(line_width)
        size = PGF._length(size)
        @argcheck PGF.is_positive(line_width)
        @argcheck PGF.is_positive(size)
        new(coordinates, line_width, color, kind, size)
    end
end

bounds_xy(scatter::Scatter) = coordinate_bounds(scatter.coordinates)

function PGF.render(io::IO, drawing_area::DrawingArea, scatter::Scatter)
    (; coordinates, line_width, color, kind, size) = scatter
    PGF.setlinewidth(io, line_width)
    PGF.setstrokecolor(io, color)
    for c in coordinates
        PGF.mark(io, Val(kind), coordinates_to_point(drawing_area, c), size)
    end
end

function print_tex(io::IO, plot::Plot; standalone::Bool = false)
    print_tex(io, Canvas(plot); standalone)
end
