####
#### axis
####

# struct LinearAxis
#     left::Float64
#     right::Float64
#     # FIXME argcheck left ≠ right
# end

# linear_axis(left, right) = LinearAxis(left, right)

# function project_to(lower::Float64, upper::Float64, src::LinearAxis, x::Real)
#     α = (x - src.left) / (src.right - src.left)
#     (1 - α) * lower + α * upper
# end

export axis

Base.@kwdef struct Axis
end

axis() = Axis()

function render(io::IO, rectangle::PGF.Rectangle, axis::Axis)
    m = PGF.split_matrix(rectangle, 20u"mm", 20u"mm")
    fill_rectangle(io, m[1, 2], RGB(1, 0.5, 0.5))
    fill_rectangle(io, m[2, 1], RGB(0.5, 1, 0.5))
    fill_rectangle(io, m[2, 2], RGB(0.5, 0.5, 1))
end

function print_tex(io::IO, axis::Axis; standalone::Bool = false)
    standalone || PGF.preamble(io)
    render(io, PGF.canvas(10u"cm", 8u"cm"), axis)
    standalone || PGF.postamble(io)
end

function print_tex(filename::AbstractString, object; standalone::Bool = false)
    open(filename, "w") do io
        print_tex(io, object; standalone)
    end
end

function Base.show(svg_io::IO, ::MIME"image/svg+xml", axis::Axis)
    Compile.svg(svg_io) do io
        print_tex(io, axis)
    end
end

function save(filename::AbstractString, object)
    ext = splitext(filename)[2]
    if ext == ".pdf"
        Compile.pdf(filename) do io
            print_tex(io, object)
        end
    else
        error("don't know to handle extension $(ext)")
    end
end
