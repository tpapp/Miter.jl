"""
FIXME document

# The user interface

[`bounds`](@ref), [`Linear`](@ref)

# Within-package API

FIXME document

"""
module Axis

using ArgCheck: @argcheck
using DocStringExtensions: FUNCTIONNAME, SIGNATURES
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

"""
$(FUNCTIONNAME)(finalized_axis, x)

Map the coordinate to `[0, 1]` using `finalized_axis`.

When the rectangle is known during rendering, use [`unit_to_canvas`](@ref).
"""
function coordinate_to_unit end

Base.@kwdef struct DrawingArea{TX,TY}
    finalized_x_axis::TX
    finalized_y_axis::TY
    rectangle::PGF.Rectangle
end

"""
$(SIGNATURES)

Transform a coordinate in `[0,1]` to `[a,b]`.
"""
unit_to_canvas(a, b, z) = a + (b - a) * z

function coordinates_to_point(drawing_area::DrawingArea, (x, y))
    @argcheck isfinite(x) && isfinite(y) "Non-finite coordinates."
    (; finalized_x_axis, finalized_y_axis, rectangle) = drawing_area
    x_u = coordinate_to_unit(finalized_x_axis, x)
    y_u = coordinate_to_unit(finalized_y_axis, y)
    PGF.Point(unit_to_canvas(rectangle.left, rectangle.right, x_u),
              unit_to_canvas(rectangle.bottom, rectangle.top, y_u))
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
    label_gap::PGF.LENGTH = 1.5mm
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
    _point(x, y) = is_x ? PGF.Point(x, y) : PGF.Point(y, x)
    (; line_gap, line_width, tick_length, label_gap) = style
    a = is_x ? rectangle.left :  rectangle.bottom
    b = is_x ? rectangle.right : rectangle.top
    edge = is_x ? rectangle.top : rectangle.right
    y1 = edge - line_gap        # line, tick start
    y2 = y1 - tick_length       # tick end
    y3 = y2 - label_gap         # labels start here
    PGF.setstrokecolor(io, PGF.BLACK)
    PGF.setlinewidth(io, line_width)
    PGF.segment(io, _point(a, y1), _point(b, y1))
    for (pos, label) in ticks
        x = unit_to_canvas(a, b, coordinate_to_unit(axis, pos))
        PGF.segment(io, _point(x, y1), _point(x, y2))
        PGF.text(io, _point(x, y3), label; top = is_x, right = !is_x)
    end
end

end
