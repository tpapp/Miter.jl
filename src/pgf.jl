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

####
#### types and constants
####

###
### length
###

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

###
### colors
###

"""
The color representation used by the PGF backend. All colors are converted to this before
being used.
"""
const COLOR = RGB{Float64}

const BLACK::COLOR = RGB(0.0, 0.0, 0.0)

const GRAY::COLOR = RGB(0.5, 0.5, 0.5)

####
#### dash
####

struct Dash
    dimensions::Vector{LENGTH}
    offset::LENGTH
    @doc """
    $(SIGNATURES)

    A dash pattern. `Dash()` gives a solid line. See [`setdash`](@ref).
    """
    function Dash(dimensions...; offset = LENGTH0)
        @argcheck iseven(length(dimensions)) "Dashes need an even number of dimensions."
        new([(l = _length(d); @argcheck is_positive(l); l) for d in dimensions], _length(offset))
    end
end

####
#### sink interface
####

Base.@kwdef mutable struct Sink{T}
    io::T
    "last line width set"
    line_width::Union{Nothing,LENGTH} = nothing
    "last stroke color set"
    stroke_color::Union{Nothing,COLOR} = nothing
    "last fill color set"
    fill_color::Union{Nothing,COLOR} = nothing
    "last dash set"
    dash::Union{Nothing,Dash} = nothing
end

"""
$(SIGNATURES)

Wrap an `io` in a `Sink` for outputting PGF primitives.

A `Sink` records various drawing properties, so it can omit superfluous set commands.
"""
sink(io::IO) = Sink(; io = io)

"""
$(SIGNATURES)

Write the PGF/LaTeX representation to `sink`. Not exposed outside this module.

Methods are encouraged to define `_print(sink::Sink, x::T)` for types `T` which can be
directly printed for processing by LaTeX (eg numbers, lengths, colors, etc).

Printing raw strings and objects to a `sink` should only be done by this method.
"""
_print(sink::Sink, xs...) = foreach(x -> _print(sink, x), xs)

_println(sink::Sink, xs...) = (foreach(x -> _print(sink, x), xs); _print(sink, '\n'))

_print(sink::Sink, x::Union{AbstractString,AbstractChar,Int,Float64}) = print(sink.io, x)

_print(sink::Sink, x::LENGTH) = @printf(sink.io, "%fbp", ustrip(mm, x) * (72 / 25.4))

function _print(sink::Sink, color::COLOR)
    _print(sink, "rgb,1:red,", Float64(red(color)),
           ";green,", Float64(green(color)),
           ";blue,", Float64(blue(color)))
end

####
#### simple commands
####

"""
$(SIGNATURES)

Translate a symbol to a pgf command name string.
"""
_pgfcommand(s::Symbol) = "\\pgf" * string(s)

function setfillcolor(sink::Sink, color::COLOR)
    if sink.fill_color ≠ color
        sink.fill_color = color
        _println(sink, raw"\pgfsetfillcolor{", color, "}")
    end
end

setfillcolor(sink::Sink, color::AbstractRGB) = setfillcolor(sink, COLOR(color))

function setstrokecolor(sink::Sink, color::COLOR)
    if sink.stroke_color ≠ color
        sink.stroke_color = color
        _println(sink, raw"\pgfsetstrokecolor{", color, "}")
    end
end

setstrokecolor(sink::Sink, color::AbstractRGB) = setstrokecolor(sink, COLOR(color))

function setcolor(sink::Sink, color::COLOR)
    if !(sink.stroke_color == color == sink.fill_color)
        sink.fill_color = color
        sink.stroke_color = color
        _println(sink, raw"\pgfsetcolor{", color, "}")
    end
end

setcolor(sink::Sink, color::AbstractRGB) = setcolor(sink, COLOR(color))

"""
$(SIGNATURES)

Set line width, converting to `mm` if necessary.
"""
function setlinewidth(sink::Sink, line_width::LENGTH)
    if sink.line_width ≠ line_width
        sink.line_width = line_width
        _print(sink, raw"\pgfsetlinewidth{", line_width, "}")
    end
end

setlinewidth(sink::Sink, line_width) = setlinewidth(sink, _length(line_width))

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

function _print(sink::Sink, point::Point)
    (; x, y) = point
    _print(sink, raw"\pgfqpoint{", x, "}{", y, "}")
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

function pathmoveto(sink::Sink, point::Point)
    _println(sink, raw"\pgfpathmoveto{", point, "}")
end

function pathlineto(sink::Sink, point::Point)
    _println(sink, raw"\pgfpathlineto{", point, "}")
end

function pathcircle(sink::Sink, point::Point, radius::LENGTH)
    _println(sink, raw"\pgfpathcircle{", point, "}{", radius, "}")
end

# commands without arguments
for command in (:pathclose, :usepathqfill, :usepathqstroke, :usepathqfillstroke,
                :usepathqclip)
    @eval function $command(sink::Sink)
        _println(sink, $(_pgfcommand(command)))
    end
end

function path(sink::Sink, rectangle::Rectangle)
    (; left, right, bottom, top) = rectangle
    _println(sink, raw"\pgfpathrectanglecorners{",
                Point(left, bottom), "}{", Point(right, top), "}")
end

function usepath(sink::Sink, actions...)
    had_fill = false
    had_stroke = false
    had_clip = false
    is_first = true
    _print(sink, raw"\pgfusepath{")
    for action in actions
        if is_first
            is_first = false
        else
            _print(sink, ',')
        end
        if action ≡ :fill
            @argcheck !had_fill "Duplicate `:fill`."
            _print(sink, "fill")
            had_fill = true
        elseif action ≡ :stroke
            @argcheck !had_stroke "Duplicate `:stroke`."
            _print(sink, "stroke")
            had_stroke = true
        elseif action ≡ :clip
            @argcheck !had_clip "Duplicate `:clip`."
            _print(sink, "clip")
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
    _print(sink, "}\n")
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

"""
$(SIGNATURES)

Enclose `str` in `\$`s and indicate that it is to be treated as (valid, self-contained) LaTeX
code.
"""
macro math_str(str)
    PGF.math(str)
end

"""
$(SIGNATURES)

Indicate the argument is to be treated as (valid, self-contained) LaTeX code.
"""
macro latex_str(str)
    PGF.LaTeX(str)
end

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

Check alignment args of `PGF.text`, provide a sensible error message.
"""
function _check_text_alignment(; top, bottom, base, left, right)
    @argcheck top + bottom + base ≤ 1
    @argcheck left + right ≤ 1
end

"""
$(SIGNATURES)

Text output.
"""
function text(sink::Sink, at::Point, str::STRINGS;
              left::Bool = false, right::Bool = false,
              top::Bool = false, bottom::Bool = false, base::Bool = false,
              rotate = 0)
    _check_text_alignment(; top, bottom, base, left, right)
    (; x, y) = at
    _print(sink, raw"\pgftext[x=", x, ",y=", y)
    left && _print(sink, ",left")
    right && _print(sink, ",right")
    top && _print(sink, ",top")
    bottom && _print(sink, ",bottom")
    base && _print(sink, ",base")
    iszero(rotate) || _print(sink, ",rotate=", rotate)
    _print(sink, "]{")
    _print_escaped(sink.io, str)
    _println(sink, "}")
end

"""
$(SIGNATURES)

Wrap text (`LaTeX`, or plain text) in the LaTeX command that makes it have the given `color`.
"""
function textcolor(color::COLOR, text)
    io = IOBuffer()
    print(io, raw"\textcolor[rgb]{", Float64(red(color)), ",", Float64(green(color)), ",",
          Float64(blue(color)), "}{")
    _print_escaped(io, text)
    print(io, "}")
    LaTeX(String(take!(io)))
end

textcolor(color::AbstractRGB, text) = textcolor(COLOR(color), text)

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
function preamble(sink::Sink, bounding_box::Rectangle;
                  standalone::Bool, baseline = LENGTH(0))
    standalone || _print(sink, raw"""
\documentclass{standalone}
\usepackage{pgfcore}
\begin{document}
""")
    _print(sink, raw"""
\begin{pgfpicture}
""")
    PGF.path(sink, bounding_box)
    _println(sink, raw"\pgfusepath{use as bounding box}",
           raw"\pgfsetbaseline{", LENGTH(baseline), "}\n",
           raw"\begin{pgfinterruptboundingbox}")
end

"""
$(SIGNATURES)
"""
function postamble(sink::Sink; standalone::Bool)
    _print(sink, raw"""
\end{pgfinterruptboundingbox}
\end{pgfpicture}
""")
    standalone || _print(sink, raw"""
\end{document}
""")
end

"""
$(SIGNATURES)

Render `object` within `rectangle` by issuing the relevant drawing commands to `io`, using
the `PGF` module.

Rendering `nothing` is a no-op.
"""
render(sink::Sink, rectangle::Rectangle, object::Nothing) = nothing

####
#### utilities
####

"""
$(SIGNATURES)

Path and stroke a line segment between two points. Caller sets everything else before.
"""
function segment(sink::Sink, a::Point, b::Point)
    pathmoveto(sink, a)
    pathlineto(sink, b)
    usepathqstroke(sink)
end

####
#### marks
####

"""
$(SIGNATURES)

Draw a mark of type `K` at the given point, with the given `size` (roughly the diameter of a
circle/square that contains the mark). Caller should set color, line width, etc.
"""
function mark(sink::Sink, ::Val{K}, at::Point, size::T) where {K,T}
    if T ≡ LENGTH
        error("Don't know how to draw a mark of type $K, define a method for `Miter.PGF.mark`.")
    else
        mark(sink, Val(K), at, _length(size))
    end
end

function mark(sink::Sink, ::Val{:+}, at::Point, size::LENGTH)
    @argcheck is_positive(size)
    (; x, y) = at
    h = size / 2
    segment(sink, Point(x - h, y), Point(x + h, y))
    segment(sink, Point(x, y - h), Point(x, y + h))
end

function mark(sink::Sink, ::Val{:o}, at::Point, size::LENGTH)
    @argcheck is_positive(size)
    pathcircle(sink, at, size / 2)
    usepathqstroke(sink)
end

function mark(sink::Sink, ::Val{:*}, at::Point, size::LENGTH)
    @argcheck is_positive(size)
    pathcircle(sink, at, size / 2)
    usepathqfill(sink)
end

"A table of built-in marks."
const MARK_KINDS = """
- `:+` a horizontal and a vertical line crossing
- `:o` a hollow circle
- `:*` a filled circle
"""

function setdash(sink::Sink, dash::Dash)
    if sink.dash ≠ dash
        sink.dash = dash
        (; dimensions, offset) = dash
        _print(sink, raw"\pgfsetdash{")
        for d in dimensions
            _print(sink, '{', d, '}')
        end
        _print(sink, "}{", offset, "}")
    end
end

end
