"""
A module containing low-level drawing commands via PGF.

# Conventions

PGF command names translate with the prefix, eg "pgfpathclose" is `PGF.pathclose`.

Each function takes an `IO` argument, where it writes the relevant output to it.

**Coordinates** should be subtypes of `Unitful.Length`, and will be converted internally.

# API

FIXME document it
"""
module PGF

using ArgCheck: @argcheck
using ColorTypes: AbstractRGB, red, green, blue, RGB
using DocStringExtensions: SIGNATURES
using StaticArrays: SVector, push
using Unitful: @u_str, ustrip, Length

"""
$(SIGNATURES)

Print the PGF/LaTeX representation to `io`. Not exposed outside this module.
"""
_print(io::IO, xs...) = foreach(x -> _print(io, x), xs)

_println(io::IO, xs...) = (foreach(x -> _print(io, x), xs); print(io, '\n'))

_print(io::IO, x::Union{AbstractString,AbstractChar,Int,Float64}) = print(io, x)

####
#### length
####

"""
The length type we use internally in this module. Not exposed outside this module.
"""
const LENGTH = typeof(1.0u"mm")

"""
$(SIGNATURES)

Convert to `LENGTH`, ensuring an inferrable type.
"""
@inline _length(x) = LENGTH(x)::LENGTH

_print(io::IO, x::LENGTH) = print(io, ustrip(u"mm", x) * (72 / 25.4), "bp")

####
#### colors
####

function _print(io::IO, color::AbstractRGB)
    _print(io, "rgb,1:red,", Float64(red(color)),
           ";green,", Float64(green(color)),
           ";blue,", Float64(blue(color)))
end

"""
$(SIGNATURES)

Translate a symbol to a pgf command name string.
"""
_pgfcommand(s::Symbol) = "\\pgf" * string(s)

for command in (:setfillcolor, :setstrokecolor, :setcolor)
    @eval function $command(io::IO, color)
        _println(io, $(_pgfcommand(command)), '{', color, '}')
    end
end

####
#### points
####

struct Point
    x::LENGTH
    y::LENGTH
    @doc """
    $(SIGNATURES)

    Create a point at the `x` and `y` coordinates.
    """
    function Point(x, y)
        result = new(_length(x), _length(y))
        @argcheck isfinite(result.x)
        @argcheck isfinite(result.y)
        result
    end
end

function _print(io::IO, point::Point)
    (; x, y) = point
    _print(io, raw"\pgfqpoint{", x, "}{", y, "}")
end

####
#### rectangles
####

struct Rectangle
    left::LENGTH
    right::LENGTH
    bottom::LENGTH
    top::LENGTH
    @doc """
    $(SIGNATURES)

    Create a rectangle with the given boundaries, which are `Unitful.Length` values.
    """
    function Rectangle(left, right, bottom, top)
        result = new(_length(left), _length(right), _length(bottom), _length(top))
        @argcheck result.left ≤ result.right
        @argcheck result.bottom ≤ result.top
        result
    end
end

Rectangle(; left, right, bottom, top) = Rectangle(left, right, bottom, top)

"""
$(SIGNATURES)

When only the width and the height are given, create a rectangle where bottom left is the
origin.
"""
function canvas(width, height)
    Rectangle(; left = zero(LENGTH), right = width, bottom = zero(LENGTH), top = height)
end

###
### path manipulation
###

function pathmoveto(io::IO, point::Point)
    _println(io, raw"\pgfpathmoveto{", point, "}")
end

function pathlineto(io::IO, point::Point)
    _println(io, raw"\pgfpathlineto{", point, "}")
end

# commands without arguments
for command in (:pathclose, :usepathqfill, :usepathqstroke, :usepathqfillstroke,
                :usepathqclip)
    @eval function $command(io::IO)
        _println(io, $(_pgfcommand(command)))
    end
end

function path(io::IO, rectangle::Rectangle)
    (; left, right, bottom, top) = rectangle
    _println(io, raw"\pgfpathrectanglecorners{",
                Point(left, bottom), "}{", Point(right, top), "}")
end

function usepath(io::IO, actions...)
    had_fill = false
    had_stroke = false
    had_clip = false
    is_first = true
    _print(io, raw"\pgfusepath{")
    for action in actions
        if is_first
            is_first = false
        else
            _print(io, ',')
        end
        if action ≡ :fill
            @argcheck !had_fill "Duplicate `:fill`."
            _print(io, "fill")
            had_fill = true
        elseif action ≡ :stroke
            @argcheck !had_stroke "Duplicate `:stroke`."
            _print(io, "stroke")
            had_stroke = true
        elseif action ≡ :clip
            @argcheck !had_clip "Duplicate `:clip`."
            _print(io, "clip")
            had_clip = true
        elseif action ≡ :discard
            @argcheck(had_fill == had_stroke == had_clip == false,
                      "Can't use `:discard` with other actions.")
            # NOTE: we don't print "discard", empty list has same effect
            break
        else
            throw(ArgumentError("Unknown action $(action)."))
        end
    end
    _print(io, "}\n")
end

####
#### splitting
####

function split_interval(min, max, interior::Union{NTuple,SVector})
    x = push(SVector(map((i -> i > zero(LENGTH) ? min + i : max + i) ∘ _length, interior)),
             _length(max))
    intervals = map(axes(x, 1)) do i
        z_prev = i == 1 ? min : x[i - 1]
        z = x[i]
        @argcheck z_prev ≤ z "Non-ascending coordinates."
        (z_prev, z)
    end
    SVector(intervals)
end

split_interval(min, max, interior::Length) = split_interval(min, max, SVector(interior))

function split_horizontally(rectangle::Rectangle, x_interior)
    (; top, left, bottom, right) = rectangle
    map(((a, b),) -> Rectangle(; top, bottom, left = a, right = b),
        split_interval(left, right, x_interior))
end

function split_vertically(rectangle::Rectangle, y_interior)
    (; top, left, bottom, right) = rectangle
    map(((a, b),) -> Rectangle(; bottom = a, top = b, left, right),
        split_interval(bottom, top, y_interior))
end

function split_matrix(rectangle::Rectangle, x_interior, y_interior)
    mapreduce(r -> split_horizontally(r, x_interior), hcat,
              split_vertically(rectangle, y_interior))
end

"""
$(SIGNATURES)

The preamble that should precede output generated by this module to compile in LaTeX. Cf
[`postamble`](@ref).
"""
function preamble(io::IO)
    _print(io, raw"""
\documentclass{standalone}
\usepackage{pgfcore}
\begin{document}
\begin{pgfpicture}
""")
end

"""
$(SIGNATURES)
"""
function postamble(io::IO)
    _print(io, raw"""
\end{pgfpicture}
\end{document}
    """)
end

end
