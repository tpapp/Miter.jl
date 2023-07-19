"""
$(SIGNATURES)

Objects that can produce graphical output (eg a plot) should define

```julia
print_tex(io::IO, object; standalone::Bool = false)
```

where `standalone` determines whether the output should be a standalone document.
"""
function print_tex(filename::AbstractString, object; standalone::Bool = false)
    open(filename, "w") do io
        print_tex(io, object; standalone)
    end
end

function _show_as_svg(svg_io::IO, object)
    Compile.svg(io -> print_tex(io, object), svg_io)
end

"""
$(SIGNATURES)

Save `object` into `filename`.
"""
function save(filename::AbstractString, object)
    ext = splitext(filename)[2]
    if ext == ".pdf"
        Compile.pdf(filename) do io
            print_tex(io, object)
        end
    elseif ext == ".svg"
        Compile.svg(filename) do io
            print_tex(io, object)
        end
    elseif ext == ".tex"
        open(io -> print_tex(io, object), filename, "w")
    elseif ext == ".tikz"
        open(io -> print_tex(io, object; standalone = true), filename, "w")
    else
        error("don't know to handle extension $(ext)")
    end
end
