"""
The drawing backend.

Plots and their elements are drawn using `render`, which they should implement. Inside
those methods, they emit commands to a `sink`.

# Exported API

The user-facing API is [`save`](@ref), [`textcolor`](@ref), and [`Canvas`](@ref).

Rendering functions should use the public interface, qualified with the module name, eg
`Draw.move_to`.

$(DocStringExtensions.EXPORTS)
"""
module Draw

# reexported as API
export textcolor, save, Canvas

# for rendering functions
public render, wrap_in_default_canvas, @declare_showable

# drawing primitives
public set_color, set_line_width, move_to, line_to, circle, stroke, stroke_preserve, fill,
    fill_preserve, clip, new_path, save_context, restore_context, segment, set_line_style,
    path, text

using ArgCheck: @argcheck
using Cairo
using ColorTypes: Colorant, red, green, blue
using DocStringExtensions: FUNCTIONNAME, SIGNATURES, FIELDS, DocStringExtensions
using Printf: @printf

import ..Compilation
using ..Lengths: mm, pt, Length
using ..InternalUtilities
using ..DrawTypes
using LaTeXEscapes: print_escaped, @lx_str, LaTeX
using ..Styles: DEFAULTS
import ..Options

####
#### utilities for writing LaTeX
####

"""
$(SIGNATURES)

Write the PGF/LaTeX representation to `io`. Not exposed outside this module.
"""
latex_print(io::IO, xs...) = foreach(x -> latex_print(io, x), xs)

function latex_print(io::IO, x::Union{AbstractString,AbstractChar,Int,Float64})
    x isa Float64 && @argcheck isfinite(x)
    print(io, x)
end

latex_print(io::IO, x::Real) = latex_print(io, Float64(x))

latex_print(io::IO, x::Length) = @printf(io, "%fmm", x / mm)

function latex_print(io::IO, point::Point)
    (; x, y) = point
    latex_print(io, raw"\pgfqpoint{", x, "}{", y, "}")
end

function latex_print(io::IO, color::COLOR)
    latex_print(io,
                "rgb,1:red,", Float64(red(color)),
                ";green,", Float64(green(color)),
                ";blue,", Float64(blue(color)))
end

"""
$(SIGNATURES)

Low-level text output using the PGF/LaTeX backend.

`str` can be anything that `LaTeXEscapes.print_escaped` handles, including
`AbstractString`, `LaTeXEscapes.LaTeX`, and `LaTeXStrings.LaTeXString`.

# Notes

- This function is also abused to insert an the image for the vector graphics.
- Cairo uses up+right coordinates, while PGF uses down+right, caller needs to convert.
"""
function pgf_text(io::IO, position::Point, str;
                 left::Bool = false, right::Bool = false,
                 top::Bool = false, bottom::Bool = false,
                 base::Bool = false, rotate::Real = 0)
    @argcheck top + bottom + base ≤ 1
    @argcheck left + right ≤ 1
    (; x, y) = position
    latex_print(io, raw"\pgftext[x=", x, ",y=", y)
    left && latex_print(io, ",left")
    right && latex_print(io, ",right")
    top && latex_print(io, ",top")
    bottom && latex_print(io, ",bottom")
    base && latex_print(io, ",base")
    iszero(rotate) || latex_print(io, ",rotate=", rotate)
    latex_print(io, "]{")
    print_escaped(io, str; check = true)
    latex_print(io, "}\n")
end

####
#### sink interface
####

"""
The sink is used to record drawing operations.

Rendering functions should not call `Cairo` functions directly, but only via the sink,
using functions in this module.

Callers are expected to *restore* the context after they run (see
[`save_context`](@ref), [`restore_context`](@ref)) for: *clipping* ([`clip`](@ref)), and
should leave no unused paths (see [`new_path`](@ref)).

Otherwise, they should always set the desired color, line width, etc for each drawing
operation.

$(FIELDS)
"""
Base.@kwdef struct Sink{D,L,S,C}
    "The directory the files are located in."
    directory::D
    "The basename (ie filename within the directory without extension."
    basename::String
    "The file name of the included PDF image."
    graphics_filename::String
    "When `true`, just emit a LaTeX source code, without a premable/postamble."
    standalone::Bool
    "Width of the image."
    width::Length
    "Height of the image."
    height::Length
    "Output for LaTeX (use only for text)."
    latex_io::L
    "Cairo surface."
    cairo_surface::S
    "Cairo context."
    cairo_context::C
end

"""
$(SIGNATURES)

The default graphics filename.
"""
function default_graphics_filename(path::String)
    splitext(splitdir(path)[2])[1] * "-graphics.pdf"
end

"""
$(SIGNATURES)

Open a sink in `directory`, using `basename`, with the given `width` and `height`.

# Keyword arguments

- `graphics_filename`: the filename of the PDF file within `directory`. Usually this is
  not needed, only when the user wants to specify the filename in `standalone` files.
- `standalone`: `false` by default. If `true`, the pre/postamble are omitted, for just
  generating the LaTeX code.
- `baseline`: specifies the baseline, relevant in `standalone` images.
"""
function open_sink(directory::String, basename::String, width::Length, height::Length;
                   graphics_filename::String = default_graphics_filename(basename),
                   standalone::Bool = false, baseline = 0mm)
    directory = abspath(directory)
    @argcheck isdir(directory)
    @argcheck isempty(splitdir(graphics_filename)[1]) "graphics_filename should not specify a directory"
    g_f, g_e = splitext(graphics_filename)
    @argcheck !isempty(g_f) "graphics_filename cannot be empty"
    @argcheck g_e == ".pdf" "graphics_filename has to end with “.pdf”"
    # LaTeX setup
    latex_io = open(joinpath(directory, basename * (standalone ? ".tikz" : ".tex")), "w")
    if !standalone
        latex_print(latex_io, raw"""
\documentclass{standalone}
\usepackage{pgfcore}
\begin{document}
""")
    end
    print(latex_io, raw"""
\begin{pgfpicture}
""")
    latex_print(latex_io, raw"\pgfpathrectanglecorners{",
                Point(0mm, 0mm), "}{", Point(width, height), "}\n",
                raw"\pgfusepath{use as bounding box}",
                raw"\pgfsetbaseline{", baseline, "}\n",
                raw"\begin{pgfinterruptboundingbox}")
    pgf_text(latex_io, Point(0mm, 0mm),
             LaTeX(raw"\includegraphics{" * graphics_filename * "}"),
             bottom = true, left = true)
    # Cairo setup
    cairo_surface = CairoPDFSurface(joinpath(directory, graphics_filename), width / pt, height / pt)
    cairo_context = CairoContext(cairo_surface)
    Sink(; directory, basename, graphics_filename, standalone, width, height, latex_io,
         cairo_surface, cairo_context)
end

"""
$(SIGNATURES)

The full path of the LaTeX file.
"""
function tex_path(sink::Sink)
    joinpath(sink.directory, sink.basename * (sink.standalone ? ".tikz" : ".tex"))
end

"""
$(SIGNATURES)

The full path of the PDF graphics file embedded in the LaTeX file.
"""
graphics_path(sink::Sink) = joinpath(sink.directory, sink.graphics_filename)

"""
$(SIGNATURES)

Close the sink.
"""
function close_sink(sink::Sink)
    (; latex_io, cairo_surface, cairo_context, standalone) = sink
    latex_print(latex_io, raw"""
\end{pgfinterruptboundingbox}
\end{pgfpicture}
""")
    if !standalone
        latex_print(latex_io, raw"""
\end{document}
""")
    end
    close(latex_io)
    Cairo.destroy(cairo_context)
    Cairo.finish(cairo_surface)
end

####
#### rendering
####

"""
$(SIGNATURES)

Render `object` within `context` (a [`Rectangle`](@ref), or similar) using `sink`.

Rendering `nothing` is a no-op.
"""
render(sink::Sink, rectangle::Rectangle, object::Nothing) = nothing

struct Canvas
    content::Any
    width::Length
    height::Length
    @doc """
    $(SIGNATURES)

    A wrapper for rendering `content` with the given `width` and `height`.
    """
    function Canvas(content; width = DEFAULTS.canvas_width, height = DEFAULTS.canvas_height)
        new(content, width, height)
    end
end

"""
$(SIGNATURES)

Wrap the input in a `Canvas`. Should be available for types that [`declare_showable`](@ref).
"""
wrap_in_default_canvas(canvas::Canvas) = canvas

"""
$(SIGNATURES)

Render the contents of `canvas` into a LaTeX file, using the a sink. For the other
arguments, see [`open_sink`](@ref).

Return the `tex_path` and the `graphics_path` in a NamedTuple.
"""
function render_to_tex(canvas::Canvas, directory, basename;
                       graphics_filename = default_graphics_filename(basename),
                       standalone = false)
    (; content, width, height) = canvas
    sink = open_sink(directory, basename, width, height; standalone, graphics_filename)
    try
        render(sink, Rectangle(; left = 0mm, right = width, top = 0mm, bottom = height), content)
    finally
        close_sink(sink)
    end
    (; tex_path = joinpath(directory, basename * (standalone ? ".tikz" : ".tex")),
     pdf_path = joinpath(directory, graphics_filename))
end

"""
$(SIGNATURES)

Render and compile the contents of `canvas` into a PDF file, using the a sink. For the
other arguments, see [`open_sink`](@ref).

Return the full path of the compiled PDF file.
"""
function render_to_pdf(canvas::Canvas, dir, basename;
                       graphics_filename = default_graphics_filename(basename))
    tex_path = render_to_tex(canvas, dir, basename; graphics_filename).tex_path
    Compilation.compile_pdf_in_dir(tex_path)
end

"""
$(SIGNATURES)

Helper function to render `object` to `io` using `format` (either `:svg` or `:png`).
`object` is wrapped in a `Canvas` using [`wrap_in_default_canvas`](@ref).
"""
function _show_as(svg_io::IO, object, format::Symbol)
    mktempdir() do dir
        pdf_path = render_to_pdf(wrap_in_default_canvas(object), dir, "miter")
        Compilation.convert_pdf_to_io(pdf_path, format, svg_io)
    end
end

"""
$(SIGNATURES)

Define a graphical `Base.show` method for type `T`.
"""
macro declare_showable(T)
    quote
        # png
        Base.showable(::MIME"image/png", ::$(esc(T))) = Options.get_show_format() == :png
        Base.show(io::IO, ::MIME"image/png", object::$(esc(T))) = _show_as(io, object, :png)
        # svg
        Base.showable(::MIME"image/svg+xml", ::$(esc(T))) = Options.get_show_format() == :svg
        Base.show(io::IO, ::MIME"image/svg+xml", object::$(esc(T))) = _show_as(io, object, :svg)
        # text, fallback
        Base.show(io::IO, ::MIME"text/plain", ::$(esc(T))) = print(io, "« ", $(esc(T)), " »")
    end
end

@declare_showable Canvas

"""
$(SIGNATURES)

Save `object` into `filename`.

File type is determined by its extension. Valid options are:

- `.pdf`: Portable Document Format (PDF)
- `.svg`: Scalable Vector Graphics (SVG)
- `.png`: Portable Network Graphics (PNG)
- `.tex`: standalone LaTeX code that can be compiled *as is*
- `.tikz`: LaTeX code that can be included in a document

For tex/tikz, the LaTeX package `pgf` needs to be available/included in the document.

# Keyword arguments

`graphics_filename` is relevant for standalone `tex` and `tikz` files, and determines
the PDF file created by Cairo, used for everything but the text.

`resolution` is only relevantt for PNG output at the moment, and defaults to
`Miter.Options_get_default_resolution()`.
"""
function save(filename::AbstractString, object;
              graphics_filename = default_graphics_filename(filename),
              resolution = Options.get_default_resolution())
    ext = lowercase(splitext(filename)[2])
    @argcheck !isempty(ext) "A filename extension is needed to determine output type."
    canvas = wrap_in_default_canvas(object)
    if ext == ".tex" || ext == ".tikz"
        standalone = ext == ".tikz"
        dir, file_ext = splitdir(filename)
        basename = splitext(file_ext)[1]
        render_to_tex(canvas, dir, basename; graphics_filename, standalone)
    else
        mktempdir() do dir
            pdf_path = render_to_pdf(canvas, dir, "miter")
            if ext == ".pdf"
                cp(pdf_path, filename; force = true)
            elseif ext == ".svg" || ext == ".png"
                Compilation.convert_pdf_to_file(pdf_path, filename; resolution)
            else
                error("don't know to handle extension $(ext)")
            end
        end
    end
    nothing
end

####
#### simple commands
####

"""
$(SIGNATURES)

Set the color.
"""
function set_color(sink::Sink, color::COLOR)
    Cairo.set_source(sink.cairo_context, color)
end

set_color(sink::Sink, color::Colorant) = set_color(sink, COLOR(color))

"""
$(SIGNATURES)

Set line width.
"""
function set_line_width(sink::Sink, line_width::Length)
    Cairo.set_line_width(sink.cairo_context, line_width / pt)
end

###
### path manipulation
###

"""
$(SIGNATURES)

A helper function to convert coordinates to Cairo. For internal use in `Draw`.
"""
function cairo_coordinates(sink::Sink, point::Point)
    point.x / pt, (sink.height - point.y) / pt
end

"""
$(SIGNATURES)

Move to a new point. If there is an existing path, it will not be connected.
"""
function move_to(sink::Sink, point::Point)
    Cairo.move_to(sink.cairo_context, cairo_coordinates(sink, point)...)
end

"""
$(SIGNATURES)

Connect to a new point with a line.
"""
function line_to(sink::Sink, point::Point)
    Cairo.line_to(sink.cairo_context, cairo_coordinates(sink, point)...)
end

"""
$(SIGNATURES)

Make a path for a circle.
"""
function circle(sink::Sink, point::Point, radius::Length)
    Cairo.circle(sink.cairo_context, cairo_coordinates(sink, point)..., radius / pt)
end

for command in (:stroke, :stroke_preserve, :fill, :fill_preserve, :clip, :new_path)
    @eval function $command(sink::Sink)
        Cairo.$command(sink.cairo_context)
    end
end

###
### scope
###

"""
$(SIGNATURES)

Save the Cairo context on a FIFO stack managed by Cairo. See [`restore_context`](@ref)
"""
save_context(sink::Sink) = Cairo.save(sink.cairo_context)

"""
$(SIGNATURES)

Restore the context saved by [`save_context`](@ref).
"""
restore_context(sink::Sink) = Cairo.restore(sink.cairo_context)

####
#### utilities
####

"""
$(SIGNATURES)

Path and stroke a line segment between two points. Caller sets everything else before.
"""
function segment(sink::Sink, a::Point, b::Point)
    move_to(sink, a)
    line_to(sink, b)
    stroke(sink)
end

"""
$(SIGNATURES)

Helper function to set line style parameters (when `≢ nothing`).
"""
function set_line_style(sink::Draw.Sink; color = nothing, width = nothing, dash = nothing)
    color ≢ nothing && Draw.set_color(sink, color)
    width ≢ nothing && Draw.set_line_width(sink, width)
    dash ≢ nothing && Draw.set_dash(sink, dash)
end

####
#### marks
####

"""
$(SIGNATURES)

Set the dash.
"""
function set_dash(sink::Sink, dash::Dash)
    (; dimensions, offset) = dash
    Cairo.set_dash(sink.cairo_context, [d / pt for d in dimensions], offset / pt)
end

"""
$(SIGNATURES)

Draw a path corresponding to the argument.
"""
function path(sink::Sink, rectangle::Rectangle)
    (; top, left, bottom, right) = rectangle
    Cairo.rectangle(sink.cairo_context,
                    left / pt, (sink.height - top) / pt,
                    (right - left) / pt, (top - bottom) / pt)
end

####
#### text
####

"""
$(SIGNATURES)

Place `str`, which can be a `LaTeXEscapes.LaTeX` wrapper or a plain vanilla
`AbstractString` (which will be escaped) at given `position`.

Alignment is controlled by `left`, `right` (horizontal), `top`, `bottom` and `base`
(vertical), only one of them can be `true` in each direction. By default, they are all
set to `false`, implying centering.
"""
function text(sink::Sink, position::Point, str;
              left::Bool = false, right::Bool = false,
              top::Bool = false, bottom::Bool = false,
              base::Bool = false, rotate::Real = 0)
    pgf_text(sink.latex_io, position, str;
             left, right, top, bottom, base, rotate)
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

end
