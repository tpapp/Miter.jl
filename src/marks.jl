"Marks for scatterplots."
module Marks

# reexported as API
export MarkSymbol, Q5, MarkQ5

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES
using Statistics: quantile

using ..Axis: DrawingArea, coordinates_to_point
using ..PGF: COLOR, LENGTH, Point, Sink, _length_positive, PGF
import ..PGF: render
using ..Styles: set_line_style, LINE_SOLID, DEFAULTS

struct MarkSymbol{S}
    line_width::LENGTH
    color::COLOR
    size::LENGTH
    @doc """
    $(SIGNATURES)

    A simple mark at the point. The following are provided by the package at the moment:

    - `:+` a horizontal and a vertical line crossing
    - `:o` a hollow circle
    - `:*` a filled circle
    """
    @inline function MarkSymbol(S = DEFAULTS.mark_symbol;
                        line_width = DEFAULTS.line_width,
                        color = DEFAULTS.line_color,
                        size = DEFAULTS.mark_size)
        new{S}(_length_positive(line_width), COLOR(color), _length_positive(size))
    end
end

"""
$(SIGNATURES)

Draw a mark of type `K` at the given point, with the given `size` (roughly the diameter of a
circle/square that contains the mark). Caller should set color, line width, etc.

This is a helper function for `MarkSymbol` marks. It assumes that the line width, color,
dash have been set by the caller.
"""
function draw_mark_symbol(sink::Sink, ::Val{K}, xy::Point, size::T) where {K,T}
    if T ≡ LENGTH
        error("Don't know how to draw a mark of type $K, define a method for this function.")
    else
        mark(sink, Val(K), xy, _length_positive(size))
    end
end

function draw_mark_symbol(sink::Sink, ::Val{:+}, xy::Point, size::LENGTH)
    (; x, y) = xy
    h = size / 2
    PGF.segment(sink, Point(x - h, y), Point(x + h, y))
    PGF.segment(sink, Point(x, y - h), Point(x, y + h))
end

function draw_mark_symbol(sink::Sink, ::Val{:o}, xy::Point, size::LENGTH)
    PGF.pathcircle(sink, xy, size / 2)
    PGF.usepathqstroke(sink)
end

function draw_mark_symbol(sink::Sink, ::Val{:*}, xy::Point, size::LENGTH)
    PGF.pathcircle(sink, xy, size / 2)
    PGF.usepathqfill(sink)
end

function render(sink::Sink, drawing_area::DrawingArea, mark::MarkSymbol{S}, xy) where S
    (; line_width, size, color) = mark
    set_line_style(sink; width = line_width, color, dash = LINE_SOLID)
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
    width05::LENGTH
    "width of the thicker 25%-75% line"
    width25::LENGTH
    "size (diameter) of the circle"
    size50::LENGTH
    @doc """
    $(SIGNATURES)
    """
    function MarkQ5(; color = DEFAULTS.line_color, width05 = DEFAULTS.line_width * 0.5,
                    width25 = DEFAULTS.line_width * 1.5, size50 = DEFAULTS.line_width * 4.0)
        _width05 = _length_positive(width05)
        _width25 = _length_positive(width25)
        _size50 = _length_positive(size50)
        @argcheck _size50 / 2 ≥ _width25 ≥ _width05
        new(COLOR(color), _width05, _width25, _size50)
    end
end

function render(sink::Sink, drawing_area::DrawingArea, mark::MarkQ5,
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
    PGF.setcolor(sink, color)
    PGF.setdash(sink, LINE_SOLID)
    PGF.setlinewidth(sink, width05)
    PGF.segment(sink, _point(x, p05), _point(x, p95))
    PGF.setlinewidth(sink, width25)
    PGF.segment(sink, _point(x, p25), _point(x, p75))
    draw_mark_symbol(sink, Val(:*), _point(x, p50), size50)
end

end
