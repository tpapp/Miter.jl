####
#### plot
####

export Plot, Lines

using ArgCheck: @argcheck
using ..Axis: Linear, DrawingArea, coordinates_to_point, bounds
import ..Axis: bounds_xy
using ..Intervals

struct Plot
    contents
    x_axis
    y_axis
    @doc """
    $(SIGNATURES)
    """
    function Plot(contents = []; x_axis = Linear(), y_axis = Linear())
        new(contents, x_axis, y_axis)
    end
end

Base.show(svg_io::IO, ::MIME"image/svg+xml", plot::Plot) = _show_as_svg(svg_io, plot)

function render(io::IO, rectangle::PGF.Rectangle, plot::Plot)
    (; x_axis, y_axis, contents) = plot
    (_, x_axis_rectangle, y_axis_rectangle,
     plot_rectangle) = PGF.split_matrix(rectangle, 20u"mm", 20u"mm")
    x_interval, y_interval = Axis.bounds_xy(contents)
    @argcheck x_interval ≢ ∅ "empty x range"
    @argcheck y_interval ≢ ∅ "empty y range"
    finalized_x_axis = Axis.finalize(x_axis, x_interval)
    finalized_y_axis = Axis.finalize(y_axis, y_interval)
    fill_rectangle(io, x_axis_rectangle, colorant"blue")
    fill_rectangle(io, y_axis_rectangle, colorant"red")
    drawing_area = Axis.DrawingArea(; rectangle = plot_rectangle, finalized_x_axis, finalized_y_axis)
    for c in contents
        render(io, drawing_area, c)
    end
end

struct Lines{T}
    coordinates::T
end

function bounds_xy(lines::Lines)
    (; coordinates) = lines
    (bounds(x -> x[1], coordinates), bounds(x -> x[2], coordinates))
end

function render(io::IO, drawing_area::DrawingArea, lines::Lines)
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
    standalone || PGF.preamble(io)
    render(io, PGF.canvas(10u"cm", 8u"cm"), plot)
    standalone || PGF.postamble(io)
end
