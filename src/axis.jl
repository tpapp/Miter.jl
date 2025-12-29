"""
FIXME document

"""
module Axis

using ArgCheck: @argcheck
using ColorTypes: RGB
using DocStringExtensions: FUNCTIONNAME, SIGNATURES
using LaTeXEscapes: LaTeX

import ..Draw
using ..DrawTypes
using ..Coordinates
using ..Styles
using ..Lengths: Length
using ..Ticks
using ..InternalUtilities

####
#### Axis
####

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
    rectangle::Rectangle
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
    Point(x_coordinate_to_canvas(drawing_area, x), y_coordinate_to_canvas(drawing_area, y))
end

###
### Linear axis
###

Base.@kwdef struct Style
    "line width"
    line_width::Length = DEFAULTS.axis_style_line_width
    "line color"
    line_color::COLOR = DEFAULTS.axis_style_line_color
    "gap between the plotting area and the axis line"
    line_gap::Length = DEFAULTS.axis_style_line_gap
    "tick length"
    tick_length::Length = DEFAULTS.axis_style_tick_length
    "gap for labels"
    tick_label_gap::Length = DEFAULTS.axis_style_tick_label_gap
    "gap for axis labels"
    axis_label_gap::Length = DEFAULTS.axis_style_axis_label_gap
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

function Draw.render(sink::Draw.Sink, rectangle::Rectangle, axis::FinalizedLinear; orientation)
    is_x = orientation == :x
    !is_x && @argcheck orientation == :y "orientation has to be :x or :y"
    (; interval, ticks, style, label) = axis
    _point(x, y) = is_x ? Point(x, y) : Point(y, x)
    (; line_gap, line_width, line_color, tick_length, tick_label_gap, axis_label_gap) = style
    a = is_x ? rectangle.left :  rectangle.bottom
    b = is_x ? rectangle.right : rectangle.top
    y_top_edge, y_bottom_edge = is_x ? (rectangle.top, rectangle.bottom) : (rectangle.right, rectangle.left)
    y1 = y_top_edge - line_gap  # line, tick start
    y2 = y1 - tick_length       # tick end
    y3 = y2 - tick_label_gap    # tick labels start here
    Draw.set_line_style(sink, width = line_width, color = line_color, dash = LINE_SOLID)
    Draw.segment(sink, _point(a, y1), _point(b, y1))
    for (pos, label) in ticks
        x = unit_to_canvas(a, b, coordinate_to_unit(axis, pos))
        Draw.segment(sink, _point(x, y1), _point(x, y2))
        Draw.text(sink, _point(x, y3), label; top = is_x, right = !is_x)
    end
    Draw.text(sink, _point((a + b) / 2, y_bottom_edge + axis_label_gap), label;
             bottom = is_x, top = !is_x, rotate = !is_x * 90)
end

end
