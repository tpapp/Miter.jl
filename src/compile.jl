#####
##### compile
#####

"""
$(SIGNATURES)

Call `f(io)` to write LaTeX code, then compile to a PDF at `output_path`. If anything goes
wrong, throw an error.
"""
function _compile(f, output_path)
    out_dir, out_file = splitdir(output_path)
    out_basename, out_ext = splitext(out_file)
    @argcheck out_ext == ".pdf" "You need to use a PDF extension for output paths."
    mktempdir() do dir
        tex_file = joinpath(dir, out_basename .* ".tex")
        open(f, tex_file, "w")
        run(`$(tectonic()) -X compile $(tex_file) -o $(out_dir)`)
        rm(dir; recursive = true)
    end
    output_path
end
