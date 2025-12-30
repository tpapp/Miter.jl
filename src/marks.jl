"Marks for scatterplots."
module Marks

# reexported as API
export MarkSymbol, Q5, MarkQ5

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES
using Statistics: quantile

using ..Axis: DrawingArea, coordinates_to_point
using ..DrawTypes
using ..Lengths: Length, mm
import ..Draw
using ..Styles

struct MarkSymbol{S}
    line_width::Length
    color::COLOR
    size::Length
    @doc """
    $(SIGNATURES)

    A simple mark at the point. The following are provided by the package at the moment:

    - `:+` a horizontal and a vertical line crossing
    - `:o` a hollow circle
    - `:*` a filled circle
    """
    @inline function MarkSymbol(S = DEFAULTS.mark_symbol;
                                line_width::Length = DEFAULTS.line_width,
                                color = DEFAULTS.line_color,
                                size::Length = DEFAULTS.mark_size)
        @argcheck line_width > 0mm
        @argcheck size > 0mm
        new{S}(line_width, COLOR(color), size)
    end
end

"""
$(SIGNATURES)

Draw a mark of type `K` at the given point, with the given `size` (roughly the diameter of a
circle/square that contains the mark). Caller should set color, line width, etc.

This is a helper function for `MarkSymbol` marks. It assumes that the line width, color,
dash have been set by the caller.
"""
function draw_mark_symbol(sink::Draw.Sink, ::Val{K}, xy::Point, size::Length) where K
    @argcheck size > 0mm
    mark(sink, Val(K), xy, size)
end

function draw_mark_symbol(sink::Draw.Sink, ::Val{:+}, xy::Point, size::Length)
    (; x, y) = xy
    h = size / 2
    Draw.segment(sink, Point(x - h, y), Point(x + h, y))
    Draw.segment(sink, Point(x, y - h), Point(x, y + h))
end

function draw_mark_symbol(sink::Draw.Sink, ::Val{:o}, xy::Point, size::Length)
    Draw.pathcircle(sink, xy, size / 2)
    Draw.usepathqstroke(sink)
end

function draw_mark_symbol(sink::Draw.Sink, ::Val{:*}, xy::Point, size::Length)
    Draw.pathcircle(sink, xy, size / 2)
    Draw.usepathqfill(sink)
end

function Draw.render(sink::Draw.Sink, drawing_area::DrawingArea,
                     mark::MarkSymbol{S}, xy) where S
    (; line_width, size, color) = mark
    Draw.set_line_style(sink; width = line_width, color, dash = LINE_SOLID)
    Draw.setfillcolor(sink, color)   # NOTE currently same fill and stroke color
    draw_mark_symbol(sink, Val(S), coordinates_to_point(drawing_area, xy), size)
end

struct Q5{T<:Real}
    p05::T
    p25::T
    p50::T
    p75::T
    p95::T
    @doc """
    $(SIGNATURES)

    Quantiles a univariate quantity at 5%, 25%, 50%, 75%, 95%. See [`MarkQ5`](@ref) for
    plotting.
    """
    function Q5(p05::T, p25::T, p50::T, p75::T, p95::T) where {T <: Real}
        @argcheck isfinite(p05) && isfinite(p25) && isfinite(p50) && isfinite(p75) && isfinite(p95)
        @argcheck p05 ≤ p25 ≤ p50 ≤ p75 ≤ p95
        new{T}(p05, p25, p50, p75, p95)
    end
end

Q5(args...) = Q5(promote(args)...)

Q5(; p05, p25, p50, p75, p95) = Q5(p05, 025, p50, p75, p95)

Q5(itr) = Q5(quantile(itr, (0.05, 0.25, 0.5, 0.75, 0.95))...)

Base.extrema(q5::Q5) = (q5.p05, q5.p95)

struct MarkQ5
    "color of the lines and the circle"
    color::COLOR
    "width of the thinner 5%-95% line"
    width05::Length
    "width of the thicker 25%-75% line"
    width25::Length
    "size (diameter) of the circle"
    size50::Length
    @doc """
    $(SIGNATURES)
    """
    function MarkQ5(; color = DEFAULTS.line_color,
                    width05::Length = DEFAULTS.line_width * 0.5,
                    width25::Length = DEFAULTS.line_width * 1.5,
                    size50::Length = DEFAULTS.line_width * 4.0)
        @argcheck width05 > 0mm
        @argcheck width25 > 0mm
        @argcheck size50 / 2 ≥ width25 ≥ width05
        new(COLOR(color), width05, width25, size50)
    end
end

function Draw.render(sink::Draw.Sink, drawing_area::DrawingArea, mark::MarkQ5,
                     xy::Union{Tuple{Real,Q5},Tuple{Q5,Real}})
    x, y = xy
    horizontal = false
    if x isa Q5
        horizontal = true
        y, x = x, y
    end
    _point(x, y) = coordinates_to_point(drawing_area, horizontal ? (y, x) : (x, y))
    (; p05, p25, p50, p75, p95) = y
    (; color, width05, width25, size50) = mark
    Draw.setcolor(sink, color)
    Draw.setdash(sink, LINE_SOLID)
    Draw.setlinewidth(sink, width05)
    Draw.segment(sink, _point(x, p05), _point(x, p95))
    Draw.setlinewidth(sink, width25)
    Draw.segment(sink, _point(x, p25), _point(x, p75))
    draw_mark_symbol(sink, Val(:*), _point(x, p50), size50)
end

end
