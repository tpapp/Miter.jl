module Output

# reexported as API
export Canvas

using DocStringExtensions: SIGNATURES
using Unitful: mm

using LaTeXCompilers: pdf, svg, png
using ..PGF
using ..Styles: DEFAULTS

"""
$(SIGNATURES)

Objects that can produce graphical output (eg a plot) should define

```julia
print_tex(sink::PGF.Sink, object; standalone::Bool = false)
```

where `standalone` determines whether the output should be a standalone document.

!!! NOTE

This function is meant for `objects` that map directly to graphical output (files), not plot
elements.

The `print_tex(sink::Sink, object; standalone)` method should be defined for objects,
methods called with other argument types will call this one.
"""
print_tex(io::IO, object; standalone = false) = print_tex(PGF.sink(io), object; standalone)

function print_tex(filename::AbstractString, object; standalone::Bool = false)
    open(filename, "w") do io
        print_tex(io, object; standalone)
    end
end

function _show_as_svg(svg_io::IO, object)
    svg(io -> print_tex(io, object), svg_io)
end

"""
$(SIGNATURES)

Define a graphical `Base.show` method for type `T`.
"""
macro declare_showable(T)
    :(Base.show(io::IO, ::MIME"image/svg+xml", object::$(esc(T))) = _show_as_svg(io, object))
end

"""
$(SIGNATURES)

Save `object` into `filename`.

File type is determined by its extension, which can be overidden by `ext` (a string, case
does not matter as it is normalized). Valid options are:

- `pdf`: Portable Document Format (PDF)
- `svg`: Scalable Vector Graphics (SVG)
- `png`: Portable Network Graphics (PNG)
- `tex`: standalone LaTeX code that can be compiled *as is*
- `tikz`: LaTeX code that can be included in a document

For tex/tikz, the LaTeX package `pgf` needs to be available/included in the document.
"""
function save(filename::AbstractString, object; ext = lstrip(splitext(filename)[2], '.'))
    ext = splitext(filename)[2]
    _print_tex = Base.Fix2(print_tex, object)
    ext = lowercase(ext)
    if ext == ".pdf"
        pdf(_print_tex, filename)
    elseif ext == ".svg"
        svg(_print_tex, filename)
    elseif ext == ".png"
        png(_print_tex, filename)
    elseif ext == ".tex"
        open(_print_tex, filename, "w")
    elseif ext == ".tikz"
        open(io -> print_tex(io, object; standalone = true), filename, "w")
    elseif ext == ""
        error("could not determine file type without extension, specify it explicitly")
    else
        error("don't know to handle extension $(ext)")
    end
end

struct Canvas
    content::Any
    width::PGF.LENGTH
    height::PGF.LENGTH
    @doc """
    $(SIGNATURES)

    A wrapper for rendering `content` with the given `width` and `height`.
    """
    function Canvas(content; width = DEFAULTS.canvas_width, height = DEFAULTS.canvas_height)
        new(content, width, height)
    end
end

function print_tex(sink::PGF.Sink, canvas::Canvas; standalone::Bool = false)
    (; content, width, height) = canvas
    _canvas = PGF.canvas(width, height)
    PGF.preamble(sink, _canvas; standalone)
    PGF.render(sink, _canvas, content)
    PGF.postamble(sink; standalone)
end

@declare_showable Canvas

end
