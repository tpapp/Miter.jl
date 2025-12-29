"""
Utilities for users of this package.
"""
module Utilities

# reexported as API
export balanced_matrix, hpd_heatmap

using ArgCheck: @argcheck
using ColorTypes: RGB24, Gray
using DocStringExtensions: SIGNATURES, FUNCTIONNAME

using ..InternalUtilities: ensure_vector
using ..Lengths: mm, Length
using ..PGF

####
#### arrangement
####

"""
$(SIGNATURES)

Arrange elements of a vector (or iterable) in a `(height, width)` matrix, such that
`width / height ≈ width_bias`. Extra elements are filled with `nothing`.

When `row_major = true` (default), elements are arranged row-major.

The purpose of this function is to make balanced displays, eg in [`Tableau`](@ref).

`width` and `height` can also be specified explicitly, in which case `width_bias` is not
used.
"""
function balanced_matrix(vector_or_itr; width_bias::Real = 1.0,
                         row_major::Bool = true,
                         width::Union{Nothing,Integer} = nothing,
                         height::Union{Nothing,Integer} = nothing)
    v = ensure_vector(vector_or_itr)
    @argcheck !isempty(v)
    T = eltype(v)
    l = length(v)
    if width ≢ nothing
        @argcheck width > 0
        @argcheck height ≡ nothing
        w = Int(width)
        h = cld(l, w)
    elseif height ≢ nothing
        # NOTE: in this branch, we know that width ≡ nothing
        @argcheck height > 0
        h = Int(height)
        w = cld(l, h)
    else
        @argcheck isfinite(width_bias) && width_bias > 0
        h = min(round(Int, sqrt(l / width_bias)), l)
        w = cld(l, h)
    end
    R = Vector{Union{T,Nothing}}
    if row_major
        m_c = reshape(vcat(R(v), fill(nothing, h * w - l)), w, h)
        collect(PermutedDimsArray(m_c, (2, 1)))
    else
        collect(reshape(vcat(R(v), fill(nothing, h * w - l)), h, w))
    end
end

####
#### visual debugging
####

"""
Visual debugging, use [`dummy`](@ref) to create.
"""
struct Dummy
    label::AbstractString
    color::PGF.COLOR
    margin::Length
end

"""
$(SIGNATURES)

Return an object for visual debugging. It can be `render`ed in a rectangle, will display
label and the given color (derived from the hash by default, deterministic to that extent).
`margin` determines the margin of the rectangle.
"""
function dummy(label::AbstractString; color = reinterpret(RGB24, (hash(label) % UInt32)),
               margin = 5mm)
    Dummy(label, PGF.COLOR(color), margin)
end

function PGF.render(sink::PGF.Sink, rectangle::PGF.Rectangle, d::Dummy)
    (; color, label, margin) = d
    (; top, bottom, left, right) = rectangle
    # outer rectangle
    PGF.setfillcolor(sink, color)
    PGF.path(sink, rectangle)
    PGF.usepathqfill(sink)
    # inner
    PGF.setfillcolor(sink, Gray(1))
    PGF.path(sink, PGF.Rectangle(; top = top - margin, bottom = bottom + margin,
                               left = left + margin, right = right - margin))
    PGF.usepathqfill(sink)
    # text
    PGF.text(sink, PGF.Point((left + right) / 2, (bottom + top) / 2), label)
end

"""
$(FUNCTIONNAME)(histogram, probabilities, colors)

Generate a `ColorMatrix` from the histogram that highlights the various probability
density regions with the given colors.

`probabilities` should be increasing, between `0` and `1`, and have element *less* than
`color`. Both can be iterables.

!!! note
    Methods are only defined when the package `StatsBase` is loaded.
"""
function hpd_heatmap end

end
