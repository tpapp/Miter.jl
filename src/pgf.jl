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
using DocStringExtensions: FUNCTIONNAME, SIGNATURES
using StaticArrays: SVector, SMatrix
using Printf: @printf
using Unitful: mm, ustrip, Length, Quantity, 𝐋

const BLACK = RGB(0.0, 0.0, 0.0)

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
const LENGTH = typeof(1.0mm)

const LENGTH0 = zero(LENGTH)

is_positive(x::LENGTH) = x > LENGTH0

"""
All quantities we accept as lengths, for conversion with `_length`.
"""
const INPUT_LENGTH = Quantity{T,𝐋} where T

"""
$(SIGNATURES)

Convert to `LENGTH`, ensuring an inferrable type.
"""
@inline _length(x::INPUT_LENGTH) = LENGTH(x)::LENGTH

_print(io::IO, x::LENGTH) = @printf(io, "%fbp", ustrip(mm, x) * (72 / 25.4))

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

"""
$(SIGNATURES)

Set line width, converting to `mm` if necessary.
"""
function setlinewidth(io::IO, line_width)
    _print(io, raw"\pgfsetlinewidth{", LENGTH(line_width), "}")
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

Base.:+(a::Point, b::Point) = Point(a.x + b.x, a.y + b.y)
Base.:-(a::Point, b::Point) = Point(a.x - b.x, a.y - b.y)
Base.:*(a::Point, b::Real) = Point(a.x * b, a.y * b)
Base.:*(a::Real, b::Point) = b * a
Base.:/(a::Point, b::Real) = Point(a.x / b, a.y / b)

"""
$(SIGNATURES)

Exchange coordinates of a point.
"""
flip(a::Point) = Point(a.y, a.x)


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
    Rectangle(; left = LENGTH0, right = width, bottom = LENGTH0, top = height)
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

function pathcircle(io::IO, point::Point, radius::LENGTH)
    _println(io, raw"\pgfpathcircle{", point, "}{", radius, "}")
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

# NOTE: we don't make this <: AbstracString, as it is only used as a wrapped, and only within
# this package, as an input.
struct LaTeX{T<:AbstractString}
    latex::T
    @doc """
    $(SIGNATURES)

    A wrapper that allows its contents to be passed to LaTeX directly.

    It is the responsibility of the user to ensure that this is valid LaTeX code within the
    document.
    """
    LaTeX(latex::T) where T = new{T}(latex) # FIXME checks
end

Base.length(str::LaTeX) = length(str.latex)

"""
$(SIGNATURES)

Put \$'s around the string, and wrap in `LaTeX`, to pass directly.
"""
math(str::AbstractString) = LaTeX("\$" * str * "\$")

_print_escaped(io::IO, str::LaTeX) = print(io, str.latex)

"""
$(SIGNATURES)

Outputs a version of `str` to `io` so that special characters (in LaTeX) are escaped to
produce the expected output.
"""
function _print_escaped(io::IO, str::AbstractString)
    for c in str
        if c == '\\'
            print(io, raw"\textbackslash")
        else
            c ∈ raw"#$%&~_^{}" && print(io, '\\')
            print(io, c)
        end
    end
end

"String types we can use with [`text`](@ref)."
const STRINGS = Union{AbstractString,LaTeX}

"""
$(SIGNATURES)

Text output.
"""
function text(io::IO, at::Point, str::STRINGS;
              left::Bool = false, right::Bool = false,
              top::Bool = false, bottom::Bool = false, base::Bool = false,
              rotate = 0)
    @argcheck top + bottom + base ≤ 1
    @argcheck left + right ≤ 1
    (; x, y) = at
    _print(io, raw"\pgftext[x=", x, ",y=", y)
    left && _print(io, ",left")
    right && _print(io, ",right")
    top && _print(io, ",top")
    bottom && _print(io, ",bottom")
    base && _print(io, ",base")
    iszero(rotate) || _print(io, ",rotate=", rotate)
    _print(io, "]{")
    _print_escaped(io, str)
    _println(io, "}")
end

####
#### splitting
####

struct Spacer
    factor::Float64
    @doc """
    $(SIGNATURES)

    Divide up remaining space proportionally.
    """
    function Spacer(x::Real = 1.0)
        @argcheck x ≥ 0
        new(Float64(x))
    end
end

"""
Spacer with a unit factor.

Style note: use when this is the only kind of spacer, when other factors are present provide
them explicitly.
"""
const SPACER = Spacer()

struct Relative
    factor::Float64
    @doc """
    $(SIGNATURES)

    Relative widths, calculated proportionally to the containing interval length.
    """
    function Relative(x::Real)
        @argcheck x ≥ 0
        new(Float64(x))
    end
end

function split_interval(a::LENGTH, b::LENGTH, divisions)
    total = b - a
    @argcheck total ≥ LENGTH0
    function _resolve1(d)       # first pass: everything but Spacer
        if d isa INPUT_LENGTH
            @argcheck d ≥ LENGTH0
            _length(d)
        elseif d isa Relative
            d.factor * total
        else
            error("Invalid division specification $(d).")
        end
    end
    absolute_sum = sum(_resolve1(d) for d in divisions if !(d isa Spacer); init = LENGTH0)
    @argcheck absolute_sum ≤ total
    spacer_sum = sum(d.factor for d in divisions if d isa Spacer; init = 0.0)
    remainder = total - absolute_sum
    @argcheck spacer_sum > 0 || remainder ≈ 0
    spacer_coefficient = remainder / spacer_sum
    function _resolve2(d)       # second pass
        if d isa INPUT_LENGTH
            _length(d)          # has been checked before
        elseif d isa Relative
            d.factor * total
        else
            d.factor * spacer_coefficient
        end
    end
    accumulate(((a, b), d) -> (b, b + _resolve2(d)), divisions; init = (a, a))
end

function split_matrix(rectangle::Rectangle,
                      x_divisions::Union{NTuple{N,Any},AbstractVector},
                      y_divisions::Union{NTuple{M,Any},AbstractVector}) where {N,M}
    (; top, left, bottom, right) = rectangle
    x_intervals = split_interval(left, right, x_divisions)
    y_intervals = split_interval(bottom, top, y_divisions)
    if x_intervals isa Tuple && y_intervals isa Tuple
        SMatrix{N,M}((Rectangle(; left, right, bottom, top)
                      for (left, right) in x_intervals, (bottom, top) in y_intervals))
    else
        [Rectangle(; left, right, bottom, top)
         for (left, right) in x_intervals, (bottom, top) in y_intervals]
    end
end

####
#### pre- and postambles
####

"""
$(SIGNATURES)

The preamble that should precede output generated by this module to compile in LaTeX. Cf
[`postamble`](@ref). When `standalone = true`, the document setup is skipped.

`bounding_box` is a rectangle that determines the bounding box, with the given `baseline` (converted to `mm` if necesary).

After the preamble, bounding box calculations are suspended.
"""
function preamble(io::IO, bounding_box::Rectangle;
                  standalone::Bool, baseline = LENGTH(0))
    standalone || _print(io, raw"""
\documentclass{standalone}
\usepackage{pgfcore}
\begin{document}
""")
    _print(io, raw"""
\begin{pgfpicture}
""")
    PGF.path(io, bounding_box)
    _println(io, raw"\pgfusepath{use as bounding box}",
           raw"\pgfsetbaseline{", LENGTH(baseline), "}\n",
           raw"\begin{pgfinterruptboundingbox}")
end

"""
$(SIGNATURES)
"""
function postamble(io::IO; standalone::Bool)
    _print(io, raw"""
\end{pgfinterruptboundingbox}
\end{pgfpicture}
""")
    standalone || _print(io, raw"""
\end{document}
""")
end

"""
$(FUNCTIONNAME)(io, rectangle, object; kwargs...)

Render `object` within `rectangle` by issuing the relevant drawing commands to `io`, using
the `PGF` module.
"""
function render end

####
#### utilities
####

"""
$(SIGNATURES)

Path and stroke a line segment between two points. Caller sets everything else before.
"""
function segment(io::IO, a::Point, b::Point)
    pathmoveto(io, a)
    pathlineto(io, b)
    usepathqstroke(io)
end

####
#### marks
####

"""
$(SIGNATURES)

Draw a mark of type `K` at the given point, with the given `size` (roughly the diameter of a
circle/square that contains the mark). Caller should set color, line width, etc.
"""
function mark(io::IO, ::Val{K}, at::Point, size::T) where {K,T}
    if T ≡ LENGTH
        error("Don't know how to draw a mark of type $K, define a method for `Miter.PGF.mark`.")
    else
        mark(io, Val(K), at, _length(size))
    end
end

function mark(io::IO, ::Val{:+}, at::Point, size::LENGTH)
    @argcheck is_positive(size)
    (; x, y) = at
    h = size / 2
    segment(io, Point(x - h, y), Point(x + h, y))
    segment(io, Point(x, y - h), Point(x, y + h))
end

function mark(io::IO, ::Val{:o}, at::Point, size::LENGTH)
    @argcheck is_positive(size)
    pathcircle(io, at(x - h, y), Point(x + h, y), size / 2)
    pathqstroke(io)
end

end
