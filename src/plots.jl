####
#### plot
####

module Plots

# reexported as API
export Plot, Tableau, Phantom, Lines, Scatter, Circles, Hline, Hgrid, LineThrough,
    Annotation, Invisible, sync_bounds

using Accessors: @insert
using ArgCheck: @argcheck
import ConstructionBase
using DocStringExtensions: FUNCTIONNAME, SIGNATURES
using Unitful: mm

using ..Axis: Linear, DrawingArea, y_coordinate_to_canvas, coordinates_to_point, finalize,
    FinalizedLinear
import ..Axis: bounds_xy
using ..Intervals
using ..Marks: MarkSymbol
using ..Output: @declare_showable
import ..Output: print_tex, Canvas
using ..PGF
using ..PGF: COLOR, LENGTH, _length_positive, convert_maybe
using ..Styles: DEFAULTS, set_line_style, LINE_SOLID, LINE_DASHED, set_stroke_or_fill_style,
    path_q_stroke_or_fill

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

function ConstructionBase.constructorof(::Type{Plot})
    (contents, x_axis, y_axis, style) -> Plot(contents; x_axis, y_axis, style)
end

Plot(contents...; kwargs...) = Plot(collect(Any, contents); kwargs...)

bounds_xy(plot::Plot) = bounds_xy(plot.contents)

@declare_showable Plot

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

###
### Lines
###

struct Lines
    coordinates
    line_width::LENGTH
    color
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)
    """
    function Lines(coordinates; line_width = DEFAULTS.line_width,
                   color = DEFAULTS.line_color, dash::PGF.Dash = LINE_SOLID)
        new(ensure_vector(coordinates), _length_positive(line_width), color, dash)
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

    See [`MarkSymbol`](@ref) and [`MarkQ5`](@ref).
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
### Circles
###

struct Circles
    x_y_w::AbstractVector
    scale::LENGTH
    fill_color::Union{Nothing,COLOR}
    stroke_color::Union{Nothing,COLOR}
    stroke_width::LENGTH
    @doc """
    $(SIGNATURES)

    Taking an iterator or vector of `(x, y, w)` triplets (eg `NTuple{3}`, but anything
    iterable with 3 elements will do), draw circles centered on `(x, y)` coordinates
    with radius `scale * √w`.

    # Keyword arguments

    `stroke_color` determines the stroke color, using `nothing` if circles should not be
    stroked. `stroke_width` determines the stroke with if applicable.

    `fill_color` determines the fill color of circles.
    """
    function Circles(x_y_w, scale;
                     stroke_color = nothing,
                     stroke_width = DEFAULTS.line_width,
                     fill_color = DEFAULTS.fill_color)
        new(collect(x_y_w),
            _length_positive(scale),
            convert_maybe(COLOR, fill_color),
            convert_maybe(COLOR, stroke_color),
            _length_positive(stroke_width))
    end
end

bounds_xy(circles::Circles) = bounds_xy(circles.x_y_w)

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, circles::Circles)
    (; x_y_w, scale, stroke_color, stroke_width, fill_color) = circles
    set_stroke_or_fill_style(sink; stroke_color, fill_color, stroke_width)
    for (x, y, w) in x_y_w
        PGF.pathcircle(sink, coordinates_to_point(drawing_area, (x, y)), scale * √w)
        path_q_stroke_or_fill(sink, stroke_color, fill_color)
    end
end

###
### Hline
###

struct Hline
    y::Real
    color::COLOR
    width::LENGTH
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)

    A horizontal line at `y` with the given parameters.
    """
    function Hline(y::Real; color = DEFAULTS.guide_color, width = DEFAULTS.guide_width,
                   dash = DEFAULTS.guide_dash)
        @argcheck isfinite(y)
        new(y, COLOR(color), _length_positive(width), dash)
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
    color::COLOR
    width::LENGTH
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
    color::COLOR
    width::LENGTH
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)

    A horizontal grid at the ticks of the ``y`` axis.
    """
    function Hgrid(; color = DEFAULTS.grid_color,
                   width = DEFAULTS.grid_width,
                   dash = DEFAULTS.grid_dash)
        new(COLOR(color), _length_positive(width), dash)
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

Add an `Invisible(xy)` to each plot in `itr`. Internal helper function.
"""
function _add_invisible(xy::Tuple{CoordinateBounds,CoordinateBounds}, itr)
    invisible = Invisible(xy)
    map(x -> @insert(last(x.contents) = invisible), itr)
end

"""
$(SIGNATURES)

Make sure that axis bounds are the same for axes as determined
by `tag` (see below).

Tag can be given in the form of `Val(tag)` too, this is a convenience wrapper.

Possible tags:

- `:X`, `:Y`, `:XY`: make the specified axes in *all* items of the collection the same

- `:x`, `:y`, `:xy`: make x/y axes the same in plots that are in the same column/row, only works for

`:x`, `:y`, and `:xy` only work for matrix-like arguments.

All methods return the (modified) first argument.

# Explanation

To illustrate the lowercase tags, consider the arrangement

```ascii
y/vertical axis
│
│ C  D
│ A  B
└────────x/horizontal axis
```
which could be entered as eg
```julia
t = Tableau([A C; B D])
```
Then `$(FUNCTIONNAME)(:x, t)` would ensure that A and C have the same bounds for the
x-axis, and similarly B and D.
"""
@inline function sync_bounds(tag::Symbol, collection)
    @argcheck tag ∈ (:x, :y, :xy, :X, :Y, :XY)
    sync_bounds(Val(tag), collection)
end

sync_bounds(tag::Val) = Base.Fix1(sync_bounds, tag)

@inline sync_bounds(tag::Symbol) = sync_bounds(Val(tag))

function sync_bounds(tag::Val{:X}, collection)
    # vectors are treated like 1×N matrices, x axes are synced
    xb, _ = bounds_xy(collection)
    _add_invisible((xb, ∅), collection)
end

function sync_bounds(tag::Val{:Y}, collection)
    _, yb = bounds_xy(collection)
    _add_invisible((∅, yb), collection)
end

sync_bounds(tag::Val{:XY}, collection) = _add_invisible(bounds_xy(collection), collection)

function sync_bounds(tag::Union{Val{:x},Val{:y},Val{:xy}}, collection::T) where T
    if Base.IteratorSize(T) == Base.HasShape{2}()
        sync_bounds(tag, collect(collection))
    else
        throw(ArgumentError("Tag $(tag) only works for matrix-like arguments."))
    end
end

function sync_bounds(::Val{:x}, m::AbstractMatrix)
    mapreduce(row -> permutedims(sync_bounds(Val(:X), row)), vcat, eachrow(m))
end

function sync_bounds(::Val{:y}, m::AbstractMatrix)
    mapreduce(col -> sync_bounds(Val(:Y), col), hcat, eachcol(m))
end

sync_bounds(::Val{:xy}, m::AbstractMatrix) = sync_bounds(Val(:x), sync_bounds(Val(:y), m))

end
