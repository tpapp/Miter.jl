module Coordinates

export Interval, is_nonzero, hull, hull_xy, CoordinateBounds

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES

struct Interval{T}
    min::T
    max::T
    @doc """
    $(SIGNATURES)

    A representation of the numbers `[min, max]`. It is required that `min ≤ max`, but
    `min == max` is allowed.
    """
    function Interval(min::T, max::T) where T
        @argcheck isfinite(min) && isfinite(max)
        @argcheck min ≤ max
        new{T}(min, max)
    end
end

Interval(a, b) = Interval(promote(a, b)...)

Interval(a) = Interval(a, a)

Base.minimum(a::Interval) = a.min
Base.maximum(a::Interval) = a.max
Base.extrema(a::Interval) = (a.min, a.max)

const CoordinateBounds = Union{Interval,Nothing}

"""
$(SIGNATURES)

Test whether the interval has positive length.
"""
is_nonzero(a::Interval) = a.min < a.max

"""
$(SIGNATURES)

The convex hull, ie the narrowest interval that contains all arguments.
"""
function hull(a::Interval, b::Interval)
    Interval(min(a.min, b.min), max(a.max, b.max))
end

hull(::Nothing, a::Interval) = a

hull(a::Interval, ::Nothing) = a

hull(::Nothing, ::Nothing) = nothing

"""
$(SIGNATURES)

Convex hull for a 2-tuple of intervals.
"""
function hull_xy((ax, ay), (bx, by))
    (hull(ax, bx), hull(ay, by))
end

end
