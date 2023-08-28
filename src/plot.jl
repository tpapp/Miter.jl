####
#### plot
####

module Plots

export Plot, Tableau, Phantom, Lines, Scatter, Hline, Annotation

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES
using Unitful: mm

using ..Axis: Linear, DrawingArea, y_coordinate_to_canvas, coordinates_to_point, bounds,
    finalize
import ..Axis: bounds_xy
using ..Intervals
using ..Styles: DEFAULTS, set_line_style, LINE_SOLID, LINE_DASHED
using ..Output: @declare_showable
import ..Output: print_tex, Canvas
using ..PGF

####
#### input conversions
####

ensure_vector(v::AbstractVector) = v

ensure_vector(v) = collect(v)::AbstractVector

function float64_xy(xy)
    @argcheck length(xy) == 2
    x, y = Float64.(xy)
    @argcheck isfinite(x)
    @argcheck isfinite(y)
    x, y
end

####
#### plot styles
####

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

@declare_showable Plot

function PGF.render(sink::PGF.Sink, rectangle::PGF.Rectangle, plot::Plot)
    (; x_axis, y_axis, contents, style) = plot
    (; axis_left, axis_bottom, margin_top, margin_right) = style
    grid = PGF.split_matrix(rectangle,
                         (axis_left, PGF.SPACER , margin_right),
                         (axis_bottom, PGF.SPACER, margin_top))
    plot_rectangle = grid[2, 2]
    x_axis_rectangle = grid[2, 1]
    y_axis_rectangle = grid[1, 2]
    x_interval, y_interval = bounds_xy(contents)
    @argcheck x_interval ≢ ∅ "empty x range"
    @argcheck y_interval ≢ ∅ "empty y range"
    finalized_x_axis = finalize(x_axis, x_interval)
    finalized_y_axis = finalize(y_axis, y_interval)
    PGF.render(sink, x_axis_rectangle, finalized_x_axis; orientation = :x)
    PGF.render(sink, y_axis_rectangle, finalized_y_axis; orientation = :y)
    drawing_area = DrawingArea(; rectangle = plot_rectangle, finalized_x_axis, finalized_y_axis)
    for c in contents
        PGF.render(sink, drawing_area, c)
    end
end

####
#### Tableau
####

struct Tableau
    contents::Matrix
    horizontal_divisions
    vertical_divisions
    function Tableau(contents::AbstractMatrix;
                     horizontal_divisions = fill(PGF.SPACER, size(contents, 1)),
                     vertical_divisions = fill(PGF.SPACER, size(contents, 2)))
        x_n, y_n = size(contents)
        @argcheck length(horizontal_divisions) == x_n
        @argcheck length(vertical_divisions) == y_n
        new(Matrix(contents), horizontal_divisions, vertical_divisions)
    end
end

@declare_showable Tableau

Tableau(contents::AbstractVector; kwargs...) = Tableau(reshape(contents, 1, :); kwargs...)

function PGF.render(sink::PGF.Sink, rectangle::PGF.Rectangle, tableau::Tableau)
    (; contents, horizontal_divisions, vertical_divisions) =  tableau
    grid = PGF.split_matrix(rectangle, horizontal_divisions, vertical_divisions)
    for (subrectangle, subplot) in zip(grid, contents)
        PGF.render(sink, subrectangle, subplot)
    end
end

function print_tex(sink::PGF.Sink, tableau::Tableau; standalone::Bool = false)
    x_n, y_n = size(tableau.contents)
    canvas = Canvas(tableau;
                         width = x_n * DEFAULTS.canvas_width,
                         height = y_n * DEFAULTS.canvas_height)
    print_tex(sink, canvas; standalone)
end

####
#### plot elements
####

###
### phantom
###

struct Phantom
    object
    @doc """
    $(SIGNATURES)

    Wrap the argument so that it is not included in boundary calculations.
    """
    Phantom(object) = new(object)
end

bounds_xy(::Phantom) = (∅, ∅)

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, phantom::Phantom)
    PGF.render(sink, drawing_area, phantom.object)
end

###
### lines
###

"""
$(SIGNATURES)

A helper function to define `bounds_xy` on an iterable of coordinate pairs.
"""
function coordinate_bounds(coordinates)
    # FIXME is bounds used anywhere else? if not, remove
    (bounds(x -> x[1], coordinates), bounds(x -> x[2], coordinates))
end

###
### Lines
###

struct Lines
    coordinates
    line_width::PGF.LENGTH
    color
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)
    """
    function Lines(coordinates; line_width = DEFAULTS.line_width,
                   color = DEFAULTS.line_color, dash::PGF.Dash = LINE_SOLID)
        line_width = PGF._length(line_width)
        @argcheck PGF.is_positive(line_width)
        new(ensure_vector(coordinates), line_width, color, dash)
    end
end

bounds_xy(lines::Lines) = coordinate_bounds(lines.coordinates)

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, lines::Lines)
    (; coordinates, line_width, color, dash) = lines
    peeled = Iterators.peel(coordinates)
    peeled ≡ nothing && return
    set_line_style(sink; color, width = line_width, dash)
    c1, cR = peeled
    PGF.pathmoveto(sink, coordinates_to_point(drawing_area, c1))
    for c in cR
        PGF.pathlineto(sink, coordinates_to_point(drawing_area, c))
    end
    PGF.usepathqstroke(sink)
end

###
### Scatter
###

struct Scatter
    coordinates
    line_width::PGF.LENGTH
    color
    kind::Symbol
    size::PGF.LENGTH
    @doc """
    $(SIGNATURES)

    # Mark kinds

    $(PGF.MARK_KINDS)
    """
    function Scatter(coordinates; line_width = 0.3mm, color = PGF.BLACK, kind = :+, size = 2mm)
        line_width = PGF._length(line_width)
        size = PGF._length(size)
        @argcheck PGF.is_positive(line_width)
        @argcheck PGF.is_positive(size)
        new(ensure_vector(coordinates), line_width, color, kind, size)
    end
end

bounds_xy(scatter::Scatter) = coordinate_bounds(scatter.coordinates)

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, scatter::Scatter)
    (; coordinates, line_width, color, kind, size) = scatter
    PGF.setlinewidth(sink, line_width)
    PGF.setcolor(sink, color)
    for c in coordinates
        PGF.mark(sink, Val(kind), coordinates_to_point(drawing_area, c), size)
    end
end

function print_tex(sink::PGF.Sink, plot::Plot; standalone::Bool = false)
    print_tex(sink, Canvas(plot); standalone)
end

###
### Hline
###

struct Hline
    y::Real
    color::PGF.COLOR
    width::PGF.LENGTH
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)

    A horizontal line at `y` with the given parameters.
    """
    function Hline(y::Real; phantom::Bool = false, color = PGF.GRAY,
                   width = DEFAULTS.line_width / 2, dash = LINE_DASHED)
        @argcheck isfinite(y)
        new(y, RGB(color), PGF._length(width), dash)
    end
end

bounds_xy(hline::Hline) = (∅, Interval(hline.y))

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, hline::Hline)
    (; y, color, width, dash) = hline
    (; left, right) = drawing_area.rectangle
    y_c = y_coordinate_to_canvas(drawing_area, y)
    set_line_style(sink; color, width, dash)
    PGF.pathmoveto(sink, PGF.Point(left, y_c))
    PGF.pathlineto(sink, PGF.Point(right, y_c))
    PGF.usepathqstroke(sink)
end

###
### Annotation
###

struct Annotation
    x::Float64
    y::Float64
    text::Union{AbstractString,PGF.LaTeX}
    top::Bool
    bottom::Bool
    base::Bool
    left::Bool
    right::Bool
    rotate::Float64
    @doc """
    $(SIGNATURES)

    Place `text` (a `LaTeX` or `AbstractString`) at the given coordinates, using the
    specified alignment and rotation. See also [`PGF.textcolor`](@ref).
    """
    function Annotation(at, text; left::Bool = false, right::Bool = false, top::Bool = false,
                        bottom::Bool = false, base::Bool = false, rotate::Real = 0)
        PGF._check_text_alignment(; left, right, top, bottom, base)
        x, y = float64_xy(at)
        new(x, y, text, top, bottom, base, left, right, Float64(rotate))
    end
end

bounds_xy(text::Annotation) = (Interval(text.x), Interval(text.y))

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, text::Annotation)
    (; x, y, text, top, bottom, base, left, right, rotate) = text
    PGF.text(sink, coordinates_to_point(drawing_area, (x, y)), text; top, bottom, base,
             left, right, rotate)
end

end