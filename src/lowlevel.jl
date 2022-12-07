#####
##### low-level commands
#####

mutable struct TeXStream{T<:IO}
    io::T
    indentation::Int
end

function change_indentation!(ts::TeXStream, Δ::Int)
    ts.indentation += Δ
    @argcheck ts.indentation ≥ 0
    nothing
end

function tex_indent(ts::TeXStream)
    @unpack io, indentation = ts
    for _ in 1:(indentation * 2)
        print(io, ' ')
    end
end

function tex_print(ts::TeXStream, args...)
    for arg in args
        tex_print(ts, arg)
    end
end

function tex_print(ts::TeXStream, arg::Union{AbstractChar,AbstractString,Real})
    print(ts.io, arg)
end

function tex_print_iln(ts::TeXStream, args...)
    tex_indent(ts)
    for arg in args
        tex_print(ts, arg)
    end
    tex_print('\n')
end

struct PGFPoint
    x::Float64
    y::Float64
    function Point(x::Float64, y::Float64)
        @argcheck isfinite(x)
        @argcheck isfinite(y)
        new(x, y)
    end
end

pgfpoint(x::Real, y::Real) = PGFPoint(Float64(x), Float64(y))

function tex_print(ts::TeXStream, point::PGFPoint)
    @unpack x, y = point
    tex_print(ts, raw"\pgfpoint{", x, "}{", y, "}")
end

function pgfpathmoveto(ts::TeXStream, point::PGFPoint)
    tex_print_iln(ts, raw"\pgfpathmoveto{", point, "}")
end

function pgfpathlineto(ts::TeXStream, point::PGFPoint)
    tex_print_iln(ts, raw"\pgfpathlineto{", point, "}")
end

pgfpathclose(ts::TeXStream) = tex_print_iln(ts, raw"\pgfpathclose")

function pgfusepath(ts::TeXStream, actions...)
    had_fill = false
    had_stroke = false
    had_clip = false
    is_first = true
    tex_print(ts, raw"\pgfusepath{")
    for action in actions
        if is_first
            is_first = false
        else
            tex_print(ts, ',')
        end
        if action ≡ :fill
            @argcheck !had_fill "Duplicate `:fill`."
            tex_print(ts, "fill")
            had_fill = true
        elseif action ≡ :stroke
            @argcheck !had_stroke "Duplicate `:stroke`."
            tex_print(ts, "stroke")
            had_stroke = true
        elseif action ≡ :clip
            @argcheck !had_clip "Duplicate `:clip`."
            tex_print(ts, "clip")
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
end

function tex_preamble(ts::TeXStream)
    tex_print(ts, raw"""
\documentclass{standalone}
\usepackage{pgfcore}
\begin{document}
\begin{pgfpicture}
""")
    change_indentation!(1)
end

function tex_postamble(ts::TeXStream)
    change_indentation!(-1)
    tex_print(ts, raw"""
\end{pgfpicture}
\end{document}
    """)
end
