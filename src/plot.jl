####
#### plot
####

export Plot, Lines

using ArgCheck: @argcheck
using ..Axis: Linear, DrawingArea, coordinates_to_point, bounds
import ..Axis: bounds_xy
using ..Intervals
using ..PGF
using Unitful: mm

Base.@kwdef struct PlotStyle
    axis_left::PGF.LENGTH = 20mm
    axis_bottom::PGF.LENGTH = 20mm
    margin_right::PGF.LENGTH = 10mm
    margin_top::PGF.LENGTH = 10mm
end


struct Plot
    contents
    x_axis
    y_axis
    style
    @doc """
    $(SIGNATURES)
    """
    function Plot(contents = []; x_axis = Linear(), y_axis = Linear(), style = PlotStyle())
        new(contents, x_axis, y_axis, style)
    end
end

Base.show(svg_io::IO, ::MIME"image/svg+xml", plot::Plot) = _show_as_svg(svg_io, plot)

function PGF.render(io::IO, rectangle::PGF.Rectangle, plot::Plot)
    (; x_axis, y_axis, contents, style) = plot
    (; axis_left, axis_bottom, margin_top, margin_right) = style
    inner_rectangle = PGF.split_matrix(rectangle, -margin_right, -margin_top)[1] # remove margin
    (_, x_axis_rectangle, y_axis_rectangle,
     plot_rectangle) = PGF.split_matrix(inner_rectangle, axis_left, axis_bottom)
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

struct Lines{T}
    coordinates::T
end

function bounds_xy(lines::Lines)
    (; coordinates) = lines
    (bounds(x -> x[1], coordinates), bounds(x -> x[2], coordinates))
end

function PGF.render(io::IO, drawing_area::DrawingArea, lines::Lines)
    peeled = Iterators.peel(lines.coordinates)
    peeled ≡ nothing && return
    c1, cR = peeled
    PGF.pathmoveto(io, coordinates_to_point(drawing_area, c1))
    for c in cR
        PGF.pathlineto(io, coordinates_to_point(drawing_area, c))
    end
    PGF.usepathqstroke(io)
end

function print_tex(io::IO, plot::Plot; standalone::Bool = false)
    canvas = PGF.canvas(10u"cm", 8u"cm")
    PGF.preamble(io, canvas; standalone)
    PGF.render(io, canvas, plot)
    PGF.postamble(io; standalone)
end
