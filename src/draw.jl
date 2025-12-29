"""
A module containing low-level drawing commands.

# Conventions



# API

FIXME document it
"""
module Draw

# reexported as API
export textcolor

using ArgCheck: @argcheck
using ColorTypes: Colorant, red, green, blue
using DocStringExtensions: FUNCTIONNAME, SIGNATURES
using Printf: @printf

using ..Lengths: mm, pt, Length
using ..InternalUtilities
using ..DrawTypes
using LaTeXEscapes: print_escaped, @lx_str

####
#### sink interface
####

Base.@kwdef mutable struct Sink{T}
    io::T
    "last line width set"
    line_width::Union{Nothing,Length} = nothing
    "last stroke color set"
    stroke_color::Union{Nothing,COLOR} = nothing
    "last fill color set"
    fill_color::Union{Nothing,COLOR} = nothing
    "last dash set"
    dash::Union{Nothing,Dash} = nothing
end

"""
$(SIGNATURES)

Reset the state that the sink remembers.
"""
function reset!(sink::Sink)
    sink.line_width = nothing
    sink.stroke_color = nothing
    sink.fill_color = nothing
    sink.dash = nothing
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

_print(sink::Sink, x::Length) = @printf(sink.io, "%fpt", x / pt)

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

setfillcolor(sink::Sink, color::Colorant) = setfillcolor(sink, COLOR(color))

function setstrokecolor(sink::Sink, color::COLOR)
    if sink.stroke_color ≠ color
        sink.stroke_color = color
        _println(sink, raw"\pgfsetstrokecolor{", color, "}")
    end
end

setstrokecolor(sink::Sink, color::Colorant) = setstrokecolor(sink, COLOR(color))

function setcolor(sink::Sink, color::COLOR)
    if !(sink.stroke_color == color == sink.fill_color)
        sink.fill_color = color
        sink.stroke_color = color
        _println(sink, raw"\pgfsetcolor{", color, "}")
    end
end

setcolor(sink::Sink, color::Colorant) = setcolor(sink, COLOR(color))

"""
$(SIGNATURES)

Set line width, converting to `mm` if necessary.
"""
function setlinewidth(sink::Sink, line_width::Length)
    if sink.line_width ≠ line_width
        sink.line_width = line_width
        _print(sink, raw"\pgfsetlinewidth{", line_width, "}")
    end
end

####
#### points
####


function _print(sink::Sink, point::Point)
    (; x, y) = point
    _print(sink, raw"\pgfqpoint{", x, "}{", y, "}")
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

function pathcircle(sink::Sink, point::Point, radius::Length)
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

###
### scope
###

begin_scope(sink::Sink) = _print(sink, "\\begin{pgfscope}")

end_scope(sink::Sink) = (_print(sink, "\\end{pgfscope}"); reset!(sink))

function with_scope(f, sink::Sink)
    begin_scope(sink)
    f()
    end_scope(sink)
end


###
### text
###

"""
$(SIGNATURES)

Check alignment args of `Draw.text`, provide a sensible error message.
"""
function _check_text_alignment(; top, bottom, base, left, right)
    @argcheck top + bottom + base ≤ 1
    @argcheck left + right ≤ 1
end

"""
$(SIGNATURES)

Text output.

`str` can be anything that `LaTeXEscapes.print_escaped` handles, including
`AbstractString`, `LaTeXEscapes.LaTeX`, and `LaTeXStrings.LaTeXString`.
"""
function text(sink::Sink, at::Point, str;
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
    print_escaped(sink.io, str; check = true)
    _println(sink, "}")
end

"""
$(SIGNATURES)

Wrap text (`LaTeX`, or plain text) in the LaTeX command that makes it have the given `color`.
"""
function textcolor(color::COLOR, text)
    (lx"\textcolor[rgb]{" *
        Float64(red(color)) * "," * Float64(green(color)) * "," * Float64(blue(color)) *
        lx"}{" * text * lx"}")
end

textcolor(color::Colorant, text) = textcolor(COLOR(color), text)

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
                  standalone::Bool, baseline::Length = 0mm)
    standalone || _print(sink, raw"""
\documentclass{standalone}
\usepackage{pgfcore}
\begin{document}
""")
    _print(sink, raw"""
\begin{pgfpicture}
""")
    Draw.path(sink, bounding_box)
    _println(sink, raw"\pgfusepath{use as bounding box}",
           raw"\pgfsetbaseline{", baseline, "}\n",
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
the `Draw` module.

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
