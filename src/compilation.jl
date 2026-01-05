#####
##### compile LaTeX
#####

module Compilation

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES
using Poppler_jll: pdftocairo
using tectonic_jll: tectonic

import ..Options

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

function compile_pdf_in_dir(tex_path)
    dir, tex_file = splitdir(tex_path)
    base_path, ext = splitext(tex_path)
    @argcheck ext == ".tex"
    cd(dir) do
        tectonic_cmd = `$(tectonic()) -X compile $(tex_file)`
        (; stderr_log, process_error) = run_with_logging(tectonic_cmd)
        if process_error
            error("Error running tectonic:\n$(stderr_log)")
        end
    end
    base_path .* ".pdf"
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

function convert_pdf_to_io(pdf_path::AbstractString, format::Symbol, io::IO;
                           resolution::Int = Options.get_default_resolution())
    if format ≡ :png
        run(pipeline(`$(pdftocairo()) -png $(pdf_path) -r $(resolution) -singlefile -`;
                     stdout = io))
    elseif format ≡ :svg
        run(pipeline(`$(pdftocairo()) -svg $(pdf_path) -`; stdout = io))
    else
        error("Unknown format $(format)")
    end
end

function convert_pdf_to_file(pdf_path::AbstractString, target::AbstractString;
                             resolution::Int = Options.get_default_resolution())
    ext = splitext(target)[2]
    if ext == ".svg"
        format = :svg
    elseif ext == ".png"
        format = :png
    else
        error("Unrecognized extension $(ext).")
    end
    open(io -> convert_pdf_to_io(pdf_path, format, io; resolution), target, "w")
end

end
