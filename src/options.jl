#####
##### runtime options
#####

"""
$(DocStringExtensions.EXPORTS)
"""
module Options

public set_default_resolution, get_default_resolution, set_show_format, get_show_format

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES, DocStringExtensions

"Default resolution. **Not part of the API**."
const DEFAULT_RESOLUTION = 300

"""
The default resolution (in points / inch) for pixel-based output.

 **Not part of the API**, see [`get_default_resolution`](@ref),
[`set_default_resolution`](@ref).
"""
global default_resolution::Int = DEFAULT_RESOLUTION

"""
$(SIGNATURES)

Set the default resolution (in points / inch) for pixel-based output.

The default is `$(repr(DEFAULT_RESOLUTION))`, which is set when no argument is provided.

Cf [`get_default_resolution`](@ref).
"""
function set_default_resolution(ppi = DEFAULT_RESOLUTION)
    ppi = Int(ppi)
    @argcheck ppi > 0
    global default_resolution = ppi
end

"""
$(SIGNATURES)

Get the default resolution (in points / inch) for pixel-based output.

Cf [`set_default_resolution`](@ref).
"""
get_default_resolution() = default_resolution

####
#### show format
####

"Default `show_format`. **Not part of the API**."
const DEFAULT_SHOW_FORMAT = :png

global show_format::Symbol = DEFAULT_SHOW_FORMAT

"""
$(SIGNATURES)

Set the format used by `Base.show`. It can be `:text`, `:svg` or `:png`, otherwise an
error is thrown.

If there is no argument, it sets the default `$(repr(DEFAULT_SHOW_FORMAT))`.
"""
function set_show_format(format::Symbol = DEFAULT_SHOW_FORMAT)
    @argcheck format ∈ (:png, :svg, :text)
    global show_format = format
end

"""
$(SIGNATURES)

The format use by `Base.show`, cf [`set_show_format`](@ref).
"""
get_show_format() = show_format

end
