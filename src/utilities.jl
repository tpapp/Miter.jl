export balanced_rectangle

"""
$(SIGNATURES)

Arrange elements of a vector in a `(w, h)` matrix, such that `width / height ≈ width_bias`.
Extra elements are filled with `nothing`.

When `columns_down = true` (default), columns will be reversed, corresponding to a top-down
visual arrangement.

When `row_major = false` (default), elements are arranged row-major. Note that in this
package, the `x` coordinate is the first, so for left-right top-down arrangements you
usually don't want this.

The purpose of this function is to make balanced displays, eg in [`Tableau`](@ref).
"""
function balanced_rectangle(v::AbstractVector{T}; width_bias::Real = 1.0,
                            columns_down::Bool = true, row_major::Bool = false) where T
    @argcheck width_bias > 0
    l = length(v)
    w = round(Int, sqrt(l / width_bias))
    h = cld(l, w)
    if row_major
        m_c = reshape(vcat(Vector{Union{T,Nothing}}(v), fill(nothing, h * w - l)), h, w)
        m = collect(PermutedDimsArray(m_c, (2, 1)))
    else
        m = collect(reshape(vcat(Vector{Union{T,Nothing}}(v), fill(nothing, h * w - l)), w, h))
    end
    if columns_down
        reverse!(m; dims = 2 - row_major)
    end
    m
end

####
#### visual debugging
####

"""
Visual debugging, use [`dummy`](@ref) to create.
"""
struct Dummy
    label::AbstractString
    color::RGB24
    margin::PGF.LENGTH
end

"""
$(SIGNATURES)

Return an object for visual debugging. It can be `render`ed in a rectangle, will display
label and the given color (derived from the hash by default, deterministic to that extent).
`margin` determines the margin of the rectangle.
"""
function dummy(label::AbstractString; color = reinterpret(RGB24, (hash(label) % UInt32)),
               margin = 5mm)
    Dummy(label, RGB24(color), margin)
end

function PGF.render(sink::PGF.Sink, rectangle::Miter.PGF.Rectangle, d::Dummy)
    (; color, label, margin) = d
    (; top, bottom, left, right) = rectangle
    # outer rectangle
    PGF.setfillcolor(io, color)
    PGF.path(io, rectangle)
    PGF.usepathqfill(io)
    # inner
    PGF.setfillcolor(io, RGB(1, 1, 1))
    PGF.path(io, PGF.Rectangle(; top = top - margin, bottom = bottom + margin,
                               left = left + margin, right = right - margin))
    PGF.usepathqfill(io)
    # text
    PGF.text(io, PGF.Point((left + right) / 2, (bottom + top) / 2), label)
end

Canvas(Tableau([dummy("$(x), $(y)") for x in 1:3, y in 1:4]), width = 100mm, height = 100mm)
