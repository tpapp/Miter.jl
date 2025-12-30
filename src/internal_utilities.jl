"""
Utilities used by the implementation of the package, not exported outside it.
"""
module InternalUtilities

using DocStringExtensions: SIGNATURES, FUNCTIONNAME

export ensure_vector, unit_to_canvas, convert_maybe

"""
$(FUNCTIONNAME)([T], v)

Convert the argument `v` to a vector (optionally with the given type) if necessary,
otherwise return it as is.
"""
ensure_vector(v::AbstractVector) = v

ensure_vector(v) = vec(collect(v))

ensure_vector(::Type{T}, v::AbstractVector{T}) where T = v

ensure_vector(::Type{T}, v) where T = vec(collect(T, v))

"""
$(SIGNATURES)

Transform a coordinate in `[0,1]` to `[a,b]`.
"""
unit_to_canvas(a, b, z) = a + (b - a) * z

"""
$(SIGNATURES)

Convert user-specified arguments to types we use internally, passing through `nothing`.
"""
convert_maybe(::Type{T}, value) where T = value ≡ nothing ? value : convert(T, value)

end
