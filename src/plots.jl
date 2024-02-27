####
#### plot
####

module Plots

# reexported as API
export Plot, Tableau, Phantom

using Accessors: @insert
using ArgCheck: @argcheck
import ConstructionBase
using DocStringExtensions: FUNCTIONNAME, SIGNATURES
using Unitful: mm

using ..InternalUtilities
using ..Axis: Linear, DrawingArea, x_coordinate_to_canvas, y_coordinate_to_canvas,
    coordinates_to_point, finalize, FinalizedLinear
import ..Axis: bounds_xy
using ..Intervals
using ..Marks: MarkSymbol
using ..Output: @declare_showable
import ..Output: print_tex, Canvas
using ..PGF
using ..PGF: COLOR, LENGTH, _length_positive, convert_maybe, Point
using ..Styles: DEFAULTS, set_line_style, LINE_SOLID, LINE_DASHED, set_stroke_or_fill_style,
    path_q_stroke_or_fill
using ..RawLaTeX: STRINGS

####
#### input conversions
####

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
    axis_left::LENGTH = DEFAULTS.plot_style_axis_left
    axis_bottom::LENGTH = DEFAULTS.plot_style_axis_bottom
    margin_right::LENGTH = DEFAULTS.plot_style_margin_right
    margin_top::LENGTH = DEFAULTS.plot_style_margin_top
end

struct Plot
    contents::Vector{Any}
    x_axis
    y_axis
    style
    title
    @doc """
    $(SIGNATURES)

    Create a plot with the given `contents` (a vector, but a convenience form that accepts
    multiple arguments is available).

    Keyword arguments (with defaults):

    - `x_axis = Axis.Linear()`, `y_axis = Axis.Linear()`: x and y axes
    - `style = PlotStyle()`: plot style (eg margins)
    - `title = nothing`: a title for the plot
    """
    function Plot(contents::AbstractVector = []; x_axis = Linear(), y_axis = Linear(),
                  style = PlotStyle(), title = nothing)
        new(Vector{Any}(contents), x_axis, y_axis, style, title)
    end
end

function ConstructionBase.constructorof(::Type{Plot})
    (contents, x_axis, y_axis, style, title) -> Plot(contents; x_axis, y_axis, style, title)
end

Plot(contents...; kwargs...) = Plot(collect(Any, contents); kwargs...)

bounds_xy(plot::Plot) = bounds_xy(plot.contents)

@declare_showable Plot

###
### rendering and bounds
###

function PGF.render(sink::PGF.Sink, rectangle::PGF.Rectangle, plot::Plot)
    (; x_axis, y_axis, contents, style, title) = plot
    (; axis_left, axis_bottom, margin_top, margin_right) = style
    grid = PGF.split_matrix(rectangle,
                         (axis_left, PGF.SPACER , margin_right),
                         (axis_bottom, PGF.SPACER, margin_top))
    plot_rectangle = grid[2, 2]
    x_axis_rectangle = grid[2, 1]
    y_axis_rectangle = grid[1, 2]
    title_rectangle = grid[2, 3]
    if title ≢ nothing
        PGF.text(sink, PGF.relative_point(title_rectangle, (0.5, 0.3)), title; base = true)
    end
    x_interval, y_interval = bounds_xy(contents)
    @argcheck x_interval ≢ ∅ "empty x range"
    @argcheck y_interval ≢ ∅ "empty y range"
    finalized_x_axis = finalize(x_axis, x_interval)
    finalized_y_axis = finalize(y_axis, y_interval)
    PGF.render(sink, x_axis_rectangle, finalized_x_axis; orientation = :x)
    PGF.render(sink, y_axis_rectangle, finalized_y_axis; orientation = :y)
    drawing_area = DrawingArea(; rectangle = plot_rectangle,
                               finalized_x_axis, finalized_y_axis)
    for c in contents
        PGF.render(sink, drawing_area, c)
    end
end

####
#### Tableau
####

struct Tableau
    contents::Matrix{Any}
    horizontal_divisions
    vertical_divisions
    @doc """
    $(SIGNATURES)

    Make a *tableau*, an arrangement of plots on a matrix-like grid. Axes are not aligned.
    See [`balanced_rectangle`](@ref) for arranging a vector.

    Contents are exposed via the array interface as a matrix.
    """
    function Tableau(contents::AbstractMatrix;
                     horizontal_divisions = fill(PGF.SPACER, size(contents, 1)),
                     vertical_divisions = fill(PGF.SPACER, size(contents, 2)))
        x_n, y_n = size(contents)
        @argcheck length(horizontal_divisions) == x_n
        @argcheck length(vertical_divisions) == y_n
        new(Matrix(contents), horizontal_divisions, vertical_divisions)
    end
end

function ConstructionBase.constructorof(::Type{Tableau})
    (contents, horizontal_divisions, vertical_divisions) ->
        Tableau(contents; horizontal_divisions, vertical_divisions)
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

include("plots/elements.jl")
include("plots/visualization_helpers.jl")
include("plots/sync_bounds.jl")

end
