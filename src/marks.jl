"Marks for scatterplots."
module Marks

export MarkSymbol

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES

using ..Axis: DrawingArea, coordinates_to_point
using ..PGF: COLOR, LENGTH, Point, Sink, is_positive, _length, PGF
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
        @argcheck is_positive(size)
        new{S}(_length(line_width), COLOR(color), _length(size))
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
        mark(sink, Val(K), xy, _length(size))
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

end
