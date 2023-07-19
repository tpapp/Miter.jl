"""
FIXME document

# The user interface

[`bounds`](@ref), [`Linear`](@ref)

# Within-package API

FIXME document

"""
module Axis

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES
import ..PGF
using ..Intervals
using ..Ticks
using Unitful: mm

####
#### Axis
####

bounds(f, itr) = isempty(itr) ? Interval{eltype(itr)}() : Interval(extrema(f, itr)...)

"""
$(SIGNATURES)
"""
bounds_xy(itr) = mapreduce(bounds_xy, hull_xy, itr)

function finalize end

function coordinate_to_unit end

Base.@kwdef struct DrawingArea{TX,TY}
    finalized_x_axis::TX
    finalized_y_axis::TY
    rectangle::PGF.Rectangle
end

function coordinates_to_point(drawing_area::DrawingArea, (x, y))
    @argcheck isfinite(x) && isfinite(y) "Non-finite coordinates."
    (; finalized_x_axis, finalized_y_axis, rectangle) = drawing_area
    x_u = coordinate_to_unit(finalized_x_axis, x)
    y_u = coordinate_to_unit(finalized_y_axis, y)
    _f(z, min, max) = z * (max - min) + min
    PGF.Point(_f(x_u, rectangle.left, rectangle.right),
              _f(y_u, rectangle.bottom, rectangle.top))
end

###
### Linear axis
###

Base.@kwdef struct Style
    "line width"
    line_width::PGF.LENGTH = 0.3mm
    "gap between the plotting area and the axis line"
    line_gap::PGF.LENGTH = 2.0mm
    "tick length"
    tick_length::PGF.LENGTH = 2.0mm
    "gap for labels"
    label_gap::PGF.LENGTH = 3.0mm
end

Base.@kwdef struct Linear
    tick_selection::TickSelection = TickSelection()
    tick_format::TickFormat = TickFormat()
    style::Style = Style()
end

Base.@kwdef struct FinalizedLinear{TT}
    interval::Interval
    ticks::TT
    style::Style
end

function finalize(axis::Linear, interval::Interval)
    (; tick_selection, tick_format, style) = axis
    ticks = sensible_linear_ticks(interval, tick_format, tick_selection)
    FinalizedLinear(; interval, ticks, style)
end

function coordinate_to_unit(finalized_axis::FinalizedLinear, x::Real)
    (; min, max) = finalized_axis.interval
    (x - min) / (max - min)
end

function PGF.render(io::IO, rectangle::PGF.Rectangle, axis::FinalizedLinear; orientation)
    is_x = orientation == :x
    !is_x && @argcheck orientation == :y "orientation has to be :x or :y"
    (; interval, ticks, style) = axis
    gap(l) = is_x ? PGF.Point(0, l) : PGF.Point(l, 0)
    (; line_gap, line_width) = style
    a = is_x ? PGF.Point(rectangle.left, rectangle.top) : PGF.Point(rectangle.right, rectangle.bottom)
    b = is_x ? PGF.Point(rectangle.right, rectangle.top) : PGF.Point(rectangle.right, rectangle.top)
    PGF.setstrokecolor(io, PGF.BLACK)
    PGF.setlinewidth(io, line_width)
    PGF.pathmoveto(io, a - gap(line_gap))
    PGF.pathlineto(io, b - gap(line_gap))
    PGF.usepathqstroke(io)
end

end
