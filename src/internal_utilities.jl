"""
Utilities used by the implementation of the package, not exported outside it.
"""
module InternalUtilities

using DocStringExtensions: SIGNATURES

export ensure_vector, unit_to_canvas

ensure_vector(v::AbstractVector) = v

ensure_vector(v) = vec(collect(v))

ensure_vector(::Type{T}, v::AbstractVector{T}) where T = v

ensure_vector(::Type{T}, v) where T = vec(collect(T, v))

"""
$(SIGNATURES)

Transform a coordinate in `[0,1]` to `[a,b]`.
"""
unit_to_canvas(a, b, z) = a + (b - a) * z

end
