####
#### plot
####

module Plots

# reexported as API
export Plot, Tableau, Phantom, Lines, Scatter, Hline, Hgrid, LineThrough, Annotation,
    Invisible, sync_bounds!

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES
using Unitful: mm

using ..Axis: Linear, DrawingArea, y_coordinate_to_canvas, coordinates_to_point, finalize,
    FinalizedLinear
import ..Axis: bounds_xy
using ..Intervals
using ..Marks: MarkSymbol
using ..Output: @declare_showable
import ..Output: print_tex, Canvas
using ..PGF
using ..Styles: DEFAULTS, set_line_style, LINE_SOLID, LINE_DASHED

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

struct Plot <: AbstractVector{Any}
    contents::Vector{Any}
    x_axis
    y_axis
    style
    @doc """
    $(SIGNATURES)

    Create a plot with the given `contents` (a vector, but a convenience form that accepts
    multiple arguments is available).

    A plot behaves like a `Vector{Any}` and its contents be indexed as such. It also
    supports `push!`, `pushfirst!`, `append!`, `pop!`, `insert!`.
    """
    function Plot(contents::AbstractVector = []; x_axis = Linear(), y_axis = Linear(), style = PlotStyle())
        new(Vector{Any}(contents), x_axis, y_axis, style)
    end
end

Plot(contents...; kwargs...) = Plot(collect(Any, contents); kwargs...)

@declare_showable Plot

###
### vector and dequeue API
###

Base.size(plot::Plot) = size(plot.contents)

Base.getindex(plot::Plot, i::Integer) = Base.getindex(plot.contents, i)

Base.setindex!(plot::Plot, value, i::Integer) = Base.setindex(plot.contents, value, i)

Base.push!(plot::Plot, items...) = push!(plot.contents, items...)

Base.pushfirst!(plot::Plot, items...) = pushfirst!(plot.contents, items...)

Base.append!(plot::Plot, collections...) = pushfirst!(plot.contents, collections...)

Base.pop!(plot::Plot) = pop!(plot.contents)

Base.insert!(plot::Plot, i::Integer, item) = insert!(plot.contents, i, item)

###
### rendering and bounds
###

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

struct Tableau <: AbstractMatrix{Any}
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

@declare_showable Tableau

Tableau(contents::AbstractVector; kwargs...) = Tableau(reshape(contents, 1, :); kwargs...)

Base.size(tableau::Tableau) = size(tableau.contents)

Base.getindex(tableau::Tableau, i::Vararg{Int}) = getindex(tableau.contents, i...)

Base.setindex!(tableau::Tableau, item, i::Vararg{Int}) = setindex(tableau.contents, item, i...)

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

bounds_xy(lines::Lines) = bounds_xy(lines.coordinates)

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

struct Scatter{M}
    coordinates::AbstractVector
    mark::M
    @doc """
    $(SIGNATURES)

    A scatterplot.
    """
    function Scatter(mark::M, coordinates) where {M}
        new{M}(ensure_vector(coordinates), mark)
    end
end

Scatter(coordinates) = Scatter(MarkSymbol(), coordinates)

bounds_xy(scatter::Scatter) = bounds_xy(scatter.coordinates)

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, scatter::Scatter)
    (; mark, coordinates) = scatter
    for xy in coordinates
        PGF.render(sink, drawing_area, mark, xy)
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
    function Hline(y::Real; color = DEFAULTS.guide_color, width = DEFAULTS.guide_width,
                   dash = DEFAULTS.guide_dash)
        @argcheck isfinite(y)
        new(y, PGF.COLOR(color), PGF._length(width), dash)
    end
end

bounds_xy(hline::Hline) = (∅, Interval(hline.y))

"""
$(SIGNATURES)

Internal utility function to draw a horizontal line at `y`. Caller should set the line style.
"""
function _hline(sink::PGF.Sink, drawing_area::DrawingArea, y::Real)
    (; left, right) = drawing_area.rectangle
    y_c = y_coordinate_to_canvas(drawing_area, y)
    PGF.pathmoveto(sink, PGF.Point(left, y_c))
    PGF.pathlineto(sink, PGF.Point(right, y_c))
    PGF.usepathqstroke(sink)
end

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, hline::Hline)
    (; y, color, width, dash) = hline
    set_line_style(sink; color, width, dash)
    _hline(sink, drawing_area, y)
end

###
### LineThrough
###

struct LineThrough
    x::Float64
    y::Float64
    slope::Float64
    color::PGF.COLOR
    width::PGF.LENGTH
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)

    A line through the given coordinates. Slope can be finite or ±Inf. Does not extend bounds.
    """
    function LineThrough(xy, slope::Real; color = DEFAULTS.guide_color,
                         width = DEFAULTS.guide_width, dash = DEFAULTS.guide_dash)
        x, y = float64_xy(xy)
        slope = Float64(slope)
        @argcheck isfinite(slope) || isinf(slope)
        new(x, y, slope, color, width, dash)
    end
end

bounds_xy(::LineThrough) = (∅, ∅)

"""
$(SIGNATURES)

Return two points where `line_through` crosses the rectangle defined by intervals.
"""
function line_through_endpoints(line_through::LineThrough, x_interval::Interval,
                                y_interval::Interval)
    (; x, y, slope) = line_through
    if slope == 0               # horizontal line
        (x_interval.min, y), (x_interval.max, y)
    elseif abs(slope) == Inf    # vertical line
        (x, y_interval.min), (x, y_interval.max)
    else
        x1 = y1 = x2 = y2 = 0.0 # saved valid crossings
        is_first = true
        tol = max(x_interval.max - x_interval.min, y_interval.max - y_interval.min, 1.0) * √eps()
        function _save(x, y)
            # save coordinates, return `true` when two have been collected
            if is_first
                x1, y1 = x, y
                is_first = false
                false
            else
                if isapprox(x, x1; atol = tol) && isapprox(y, y1; atol = tol)
                    # same as previous, don't save
                    false
                else
                    x2, y2 = x, y
                    true
                end
            end
        end
        function _is_in(z, a)
            # test if z ∈ a, but allow for numerical error
            (; min, max) = a
            min - tol ≤ z ≤ max + tol
        end
        function _find_x_crossing(ŷ)
            # find the crossing of a horizontal line at `ŷ`, save when it is in bounds,
            # return true when `_save` does
            x̂ = (ŷ - y) / slope + x
            _is_in(x̂, x_interval) && _save(x̂, ŷ)
        end
        function _find_y_crossing(x̂)
            # same as _find_x_crossing, mutatis mutandis
            ŷ = (x̂ - x) * slope + y
            _is_in(ŷ, y_interval) && _save(x̂, ŷ)
        end
        if _find_x_crossing(y_interval.min) ||
            _find_x_crossing(y_interval.max) ||
            _find_y_crossing(x_interval.min) ||
            _find_y_crossing(x_interval.max)
            return (x1, y1), (x2, y2)
        else
            error("internal error: no valid crossing found, investigate numerical error")
        end
    end
end

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, line_through::LineThrough)
    (; finalized_x_axis, finalized_y_axis) = drawing_area
    (; color, width, dash) = line_through
    @argcheck(finalized_x_axis isa FinalizedLinear && finalized_y_axis isa FinalizedLinear,
              "LineThrough only supported for linear axes.")
    z1, z2 = line_through_endpoints(line_through, finalized_x_axis.interval,
                                    finalized_y_axis.interval)
    set_line_style(sink; color, width, dash)
    PGF.pathmoveto(sink, coordinates_to_point(drawing_area, z1))
    PGF.pathlineto(sink, coordinates_to_point(drawing_area, z2))
    PGF.usepathqstroke(sink)
end

###
### Hgrid
###

struct Hgrid
    color::PGF.COLOR
    width::PGF.LENGTH
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)

    A horizontal grid at the ticks of the ``y`` axis.
    """
    function Hgrid(; color = DEFAULTS.grid_color,
                   width = DEFAULTS.grid_width,
                   dash = DEFAULTS.grid_dash)
        new(PGF.COLOR(color), PGF._length(width), dash)
    end
end

bounds_xy(hgrid::Hgrid) = (∅, ∅)

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, hgrid::Hgrid)
    (; color, width, dash) = hgrid
    set_line_style(sink; color, width, dash)
    # FIXME code below relies on nested properties of types, define an API
    for (pos, _) in drawing_area.finalized_y_axis.ticks
        _hline(sink, drawing_area, pos)
    end
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

###
### Invisible
###

struct Invisible
    xy::Tuple{CoordinateBounds,CoordinateBounds}
    @doc """
    $(SIGNATURES)

    Create an invisible object with the sole function of extending coordinate bounds to (x,
    y), which should be `Interval`s or `∅`.

    You can also use `Invisible(bounds_xy(object))` to extend bounds to those in `object`.
    """
    function Invisible(xy::Tuple{CoordinateBounds,CoordinateBounds})
        new(xy)
    end
end

bounds_xy(invisible::Invisible) = invisible.xy

PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, ::Invisible) = nothing

"""
$(SIGNATURES)

Add an `Invisible(xy)` to each plot in `itr`.
"""
function _add_invisible!(xy::Tuple{CoordinateBounds,CoordinateBounds}, itr)
    invisible = Invisible(xy)
    for i in itr
        push!(i, invisible)
    end
    itr
end

"""
$(SIGNATURES)

Make sure that axis bounds are the same for axes `:x`, `:y`, or both (`:xy`), as determined
by `tag`. Tag can be given in the form of `Val(tag)` too, this is a convenience wrapper.

Matrices (like [`Tableau`](@ref) are synced by column- and row, according to the `tag`.

Vectors are just synced as specified.

All methods return the (modified) second argument.
"""
@inline function sync_bounds!(tag::Symbol, collection)
    @argcheck tag ∈ (:x, :y, :xy)
    sync_bounds!(Val(tag), collection)
end

function sync_bounds!(::Val{:x}, v::AbstractVector)
    xb, _ = bounds_xy(v)
    _add_invisible!((xb, ∅), v)
end

function sync_bounds!(::Val{:y}, v::AbstractVector)
    _, yb = bounds_xy(v)
    _add_invisible!((∅, yb), v)
end

sync_bounds!(::Val{:xy}, v::AbstractVector) = _add_invisible!(bounds_xy(v), v)

function sync_bounds!(::Val{:x}, m::AbstractMatrix)
    for row in eachrow(m)
        sync_bounds!(Val(:x), row)
    end
    m
end

function sync_bounds!(::Val{:y}, m::AbstractMatrix)
    for col in eachcol(m)
        sync_bounds!(Val(:y), col)
    end
    m
end

function sync_bounds!(::Val{:xy}, m::AbstractMatrix)
    sync_bounds!(Val(:x), m)
    sync_bounds!(Val(:y), m)
    m
end

end
