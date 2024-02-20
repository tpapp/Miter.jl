"""
Utilities used by the implementation of the package, not exported outside it.
"""
module InternalUtilities

export ensure_vector

ensure_vector(v::AbstractVector) = v

ensure_vector(v) = collect(v)::AbstractVector

ensure_vector(::Type{T}, v::AbstractVector{T}) where T = v

ensure_vector(::Type{T}, v) where T = collect(T, v)

end
