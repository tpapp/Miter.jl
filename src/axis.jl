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
using ..PGF: Rectangle, Point
using ..Intervals
using ..Ticks

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
    rectangle::Rectangle
end

function coordinates_to_point(drawing_area::DrawingArea, (x, y))
    @argcheck isfinite(x) && isfinite(y) "Non-finite coordinates."
    (; finalized_x_axis, finalized_y_axis, rectangle) = drawing_area
    x_u = coordinate_to_unit(finalized_x_axis, x)
    y_u = coordinate_to_unit(finalized_y_axis, y)
    _f(z, min, max) = z * (max - min) + min
    Point(_f(x_u, rectangle.left, rectangle.right),
          _f(y_u, rectangle.bottom, rectangle.top))
end

###
### Linear axis
###

Base.@kwdef struct Linear
    tick_selection::TickSelection = TickSelection()
    tick_format::TickFormat = TickFormat()
end

Base.@kwdef struct FinalizedLinear{TT}
    interval::Interval
    ticks::TT
end

function finalize(axis::Linear, interval::Interval)
    (; tick_selection, tick_format) = axis
    ticks = sensible_linear_ticks(interval, tick_format, tick_selection)
    FinalizedLinear(; interval, ticks)
end

function coordinate_to_unit(finalized_axis::FinalizedLinear, x::Real)
    (; min, max) = finalized_axis.interval
    (x - min) / (max - min)
end

end
