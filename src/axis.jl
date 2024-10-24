"""
FIXME document

"""
module Axis

# reexported as API
export bounds_xy

using ArgCheck: @argcheck
using ColorTypes: RGB
using DocStringExtensions: FUNCTIONNAME, SIGNATURES
using LaTeXEscapes: LaTeX
using Unitful: mm

import ..PGF
using ..Intervals
using ..Styles: DEFAULTS, set_line_style, LINE_SOLID
using ..Ticks
using ..InternalUtilities

####
#### Axis
####

"""
$(SIGNATURES)

Return two intervals for the axis bounds of the plot contents.

# Extending

User defined types `T` can either define a `bounds_xy(::Tuple{T,T})` method (or other
applicable combinations), or a method for `extrema(::T)`.
"""
bounds_xy(a::AbstractArray) = isempty(a) ? (nothing, nothing) : mapreduce(bounds_xy, hull_xy, vec(a))

# bounds for a coordinate pair
bounds_xy(xy::Tuple) = (Interval(extrema(xy[1])...), Interval(extrema(xy[2])...))

bounds_xy(::Nothing) = (nothing, nothing)

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

Broadcast.broadcastable(drawing_area::DrawingArea) = Ref(drawing_area)

function x_coordinate_to_canvas(drawing_area::DrawingArea, x::Real)
    @argcheck isfinite(x) "Non-finite x coordinate."
    (; finalized_x_axis, rectangle) = drawing_area
    x_u = coordinate_to_unit(finalized_x_axis, x)
    unit_to_canvas(rectangle.left, rectangle.right, x_u)
end

function y_coordinate_to_canvas(drawing_area::DrawingArea, y::Real)
    @argcheck isfinite(y) "Non-finite y coordinate."
    (; finalized_y_axis, rectangle) = drawing_area
    y_u = coordinate_to_unit(finalized_y_axis, y)
    unit_to_canvas(rectangle.bottom, rectangle.top, y_u)
end

function coordinates_to_point(drawing_area::DrawingArea, (x, y))
    PGF.Point(x_coordinate_to_canvas(drawing_area, x),
              y_coordinate_to_canvas(drawing_area, y))
end

###
### Linear axis
###

Base.@kwdef struct Style
    "line width"
    line_width::PGF.LENGTH = DEFAULTS.axis_style_line_width
    "line color"
    line_color::RGB = DEFAULTS.axis_style_line_color
    "gap between the plotting area and the axis line"
    line_gap::PGF.LENGTH = DEFAULTS.axis_style_line_gap
    "tick length"
    tick_length::PGF.LENGTH = DEFAULTS.axis_style_tick_length
    "gap for labels"
    tick_label_gap::PGF.LENGTH = DEFAULTS.axis_style_tick_label_gap
    "gap for axis labels"
    axis_label_gap::PGF.LENGTH = DEFAULTS.axis_style_axis_label_gap
end

Base.@kwdef struct Linear
    tick_selection::TickSelection = TickSelection()
    tick_format::TickFormat = TickFormat()
    style::Style = Style()
    label = ""
end

Base.@kwdef struct FinalizedLinear{TT}
    interval::Interval          # FIXME check positive length in constructor
    ticks::TT
    style::Style
    label = ""
end

"""
$(SIGNATURES)

En
"""
function ensure_nonempty_interval(interval::Interval)
    mi, ma = extrema(interval)
    if mi == ma
        mi = floor(mi)
        ma = ceil(ma)
        if mi == ma
            ma += one(ma)
        end
        Interval(mi, ma)
    else
        interval
    end
end

function finalize(axis::Linear, interval::Interval)
    (; tick_selection, tick_format, style, label) = axis
    ticks = sensible_linear_ticks(interval, tick_format, tick_selection)
    interval = ensure_nonempty_interval(interval) # NOTE: after tick selection
    FinalizedLinear(; interval, ticks, style, label)
end

function coordinate_to_unit(finalized_axis::FinalizedLinear, x::Real)
    (; min, max) = finalized_axis.interval
    (x - min) / (max - min)
end

function PGF.render(sink::PGF.Sink, rectangle::PGF.Rectangle, axis::FinalizedLinear; orientation)
    is_x = orientation == :x
    !is_x && @argcheck orientation == :y "orientation has to be :x or :y"
    (; interval, ticks, style, label) = axis
    _point(x, y) = is_x ? PGF.Point(x, y) : PGF.Point(y, x)
    (; line_gap, line_width, line_color, tick_length, tick_label_gap, axis_label_gap) = style
    a = is_x ? rectangle.left :  rectangle.bottom
    b = is_x ? rectangle.right : rectangle.top
    y_top_edge, y_bottom_edge = is_x ? (rectangle.top, rectangle.bottom) : (rectangle.right, rectangle.left)
    y1 = y_top_edge - line_gap  # line, tick start
    y2 = y1 - tick_length       # tick end
    y3 = y2 - tick_label_gap    # tick labels start here
    set_line_style(sink, width = line_width, color = line_color, dash = LINE_SOLID)
    PGF.segment(sink, _point(a, y1), _point(b, y1))
    for (pos, label) in ticks
        x = unit_to_canvas(a, b, coordinate_to_unit(axis, pos))
        PGF.segment(sink, _point(x, y1), _point(x, y2))
        PGF.text(sink, _point(x, y3), label; top = is_x, right = !is_x)
    end
    PGF.text(sink, _point((a + b) / 2, y_bottom_edge + axis_label_gap), label;
             bottom = is_x, top = !is_x, rotate = !is_x * 90)
end

end
