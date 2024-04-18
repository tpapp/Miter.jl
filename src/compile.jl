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
    nothing
end

"""
$(SIGNATURES)

Run the specified command, capturing stderr and stdout, returning them as `stdout_log`
and `stderr_log`, along with `process_error` for exit status, in a `NamedTuple`.
"""
function run_with_logging(cmd::Cmd)
    stdout_pipe = Pipe()
    stderr_pipe = Pipe()
    process = run(pipeline(ignorestatus(cmd); stdout = stdout_pipe, stderr = stderr_pipe))
    # FIXME using fields, cf https://github.com/JuliaLang/julia/issues/54133
    close(stdout_pipe.in)
    close(stderr_pipe.in)
    stdout_log = String(read(stdout_pipe))
    stderr_log = String(read(stderr_pipe))
    (; stdout_log, stderr_log, process_error = !success(process))
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
        tectonic_cmd = `$(tectonic()) -X compile --outdir $(out_dir) $(tex_file)`
        (; stderr_log, process_error) = run_with_logging(tectonic_cmd)
        if process_error
            error("Error running tectonic:\n$(stderr_log)")
        end
    end
    output_path
end

"""
$(SIGNATURES)

Helper function to read `filename` and write it to `io`.
"""
function read_to_io(filename::AbstractString, io::IO; bufsize = 2^12)
    buffer = Vector{UInt8}(undef, bufsize)
    open(filename, "r") do src_io
        while !eof(src_io)
            n = readbytes!(src_io, buffer, bufsize)
            write(io, @view buffer[1:n])
        end
    end
end

"Filename we use for PDFs inside temporary directories."
const DEFAULT_PDF = "miter.pdf"

function pdf(f, io::IO; tmp_dir = nothing)
    maybe_tmpdir(tmp_dir) do dir
        pdf_path = joinpath(dir, DEFAULT_PDF)
        pdf(f, pdf_path; tmp_dir)
        read_to_io(pdf_path, io)
    end
end

const TARGETS = Union{IO,AbstractString}

"""
$(SIGNATURES)

Run `pdftocairo`, compiling to `target`. `format` is `"svg`", etc.
"""
function _run_pdftocairo(f, target::TARGETS, format; tmp_dir = nothing)
    maybe_tmpdir(tmp_dir) do dir
        pdf_path = joinpath(dir, DEFAULT_PDF)
        pdf(f, pdf_path; tmp_dir = dir)
        function _run(io)
            _extra = format == "svg" ? () : ("-singlefile", ) # pdftocairo quirk
            run(pipeline(`$(pdftocairo()) -$(format) $(pdf_path) $(_extra...)  -`; stdout = io))
        end
        if target isa IO
            _run(target)
        else
            open(_run, target, "w")
        end
    end
end

"""
$(SIGNATURES)

Call `f(io)` to write TeX code, compile, and send/write the SVG output to `target`.
"""
function svg(f, target::TARGETS; tmp_dir = nothing)
    _run_pdftocairo(f, target, "svg"; tmp_dir)
end

function png(f, target::TARGETS; tmp_dir = nothing, scale_to_x = 500)
    _run_pdftocairo(f, target, "png"; tmp_dir)
end

end
