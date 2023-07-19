module Compile

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES
using Poppler_jll: pdftocairo
using tectonic_jll: tectonic

"""
$(SIGNATURES)

When `dir` is a string, run `f(dir)`, otherwise call `mktempdir(f)`.
"""
function maybe_tmpdir(f, dir::Union{Nothing,AbstractString})
    dir ≡ nothing ? mktempdir(f) : f(dir)
end

"""
$(SIGNATURES)

Call `f(io)` to write LaTeX code, then compile to a PDF at `output_path`. If anything
goes wrong, throw an error.
"""
function pdf(f, output_path::AbstractString; tmp_dir = nothing)
    out_dir, out_file = splitdir(output_path)
    out_basename, out_ext = splitext(out_file)
    @argcheck out_ext == ".pdf" "You need to use a PDF extension for output paths."
    maybe_tmpdir(tmp_dir) do dir
        tex_file = joinpath(dir, out_basename .* ".tex")
        open(f, tex_file, "w")
        redirect_stdio(; stdout = devnull, stderr = devnull)
        if !success(`$(tectonic()) -X compile --outdir $(out_dir) $(tex_file)`)
            error("Error running tectonic")
        end
    end
    output_path
end

"""
$(SIGNATURES)

Call `f(io)` to write TeX code, compile, and send the SVG output to `io`.
"""
function svg(f, io::IO; tmp_dir = nothing)
    maybe_tmpdir(tmp_dir) do dir
        pdf_path = joinpath(dir, "miter.pdf")
        pdf(f, pdf_path; tmp_dir = dir)
        run(pipeline(`$(pdftocairo()) -svg $(pdf_path) -`; stdout = io))
    end
end

function svg(f, output_path::AbstractString; tmp_dir = nothing)
    open(io -> svg(f, io; tmp_dir), output_path, "w")
end

end
