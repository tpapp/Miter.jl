module Intervals

export Interval, is_nonempty, is_nonzero, hull, hull_xy

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES

struct Interval{T}
    min::T
    max::T
    @doc """
    $(SIGNATURES)

    A representation of the numbers `[min, max]`. It is required that `min ≤ max`, but
    `min == max` is allowed. All other combinations represent the empty set and require the
    `Interval{T}()` constructor.
    """
    function Interval(min::T, max::T) where T
        @argcheck isfinite(min) && isfinite(max)
        @argcheck min ≤ max
        new{T}(min, max)
    end
    @doc """
    $(SIGNATURES)

    Represent the empty set ``∅``. Test with [`is_nonempty`](@ref).
    """
    Interval{T}() where T = new{T}(typemax(T), typemin(T))
end

Interval(a, b) = Interval(promote(a, b)...)

"""
$(SIGNATURES)

Test whether the interval is the empty set.
"""
is_nonempty(a::Interval) = a.min ≤ a.max

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

"""
$(SIGNATURES)

Convex hull for a 2-tuple of intervals.
"""
function hull_xy((ax, ay)::T, (bx, by)::T) where {T<:Tuple{Interval,Interval}}
    (hull(ax, bx), hull(ay, by))
end

end
