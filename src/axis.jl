"""
FIXME document

# The user interface

[`Interval`](@ref), [`bounds`](@ref), [`Linear`](@ref)

# Within-package API

FIXME document

"""
module Axis

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES
using ..PGF: Rectangle, Point

####
#### Interval arithmetic
####

struct Interval
    min::Float64
    max::Float64
    @doc """
    $(SIGNATURES)

    A representation of the numbers `[min, max]`. It is required that `min ≤ max`, but `min
    == max` is allowed.
    """
    function Interval(min, max)
        @argcheck isfinite(min) && isfinite(max)
        @argcheck min ≤ max
        new(Float64(min), Float64(max))
    end
    @doc """
    $(SIGNATURES)

    Represent the empty set ``∅``. Test with [`is_nonempty`](@ref).
    """
    Interval() = new(Inf, -Inf) # sentinel for empty interval
end

"""
$(SIGNATURES)

Test whether the interval is the empty set.
"""
is_nonempty(a::Interval) = a.min ≤ a.max

"""
$(SIGNATURES)

The convex hull, ie the narrowest interval that contains both intervals.
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

"""
$(SIGNATURES)

A helper function that wraps `extrema(f, itr)` in an `Interval`.
"""
bounds(f, itr) = isempty(itr) ? Interval() : Interval(extrema(f, itr)...)

bounds_xy(itr) = mapreduce(bounds_xy, hull_xy, itr; init = (Interval(), Interval()))

####
#### Axis
####

###
### Generic axis API
###

function finalize end

function coordinate_to_unit end

Base.@kwdef struct DrawingArea{TX,TY}
    finalized_x_axis::TX
    finalized_y_axis::TY
    rectangle::Rectangle
end

function coordinates_to_point(drawing_area::DrawingArea, (x, y))
    @argcheck isfinite(x) && isfinite(y) "Non-finite coordinates."
    (; finalized_x_axis, finalized_y_axis, rectangle) = drawing_area
    x_u = coordinate_to_unit(finalized_x_axis, x)
    y_u = coordinate_to_unit(finalized_y_axis, y)
    _f(z, min, max) = z * (max - min) + min
    Point(_f(x_u, rectangle.left, rectangle.right),
          _f(y_u, rectangle.bottom, rectangle.top))
end

###
### Linear axis
###

struct Linear end

struct LinearFinalized
    interval::Interval
end

function finalize(axis::Linear, interval::Interval)
    if interval.min < interval.max
        LinearFinalized(interval)
    else
        error("FIXME write code to handle points")
    end
end

function coordinate_to_unit(finalized_axis::LinearFinalized, x::Real)
    (; min, max) = finalized_axis.interval
    (x - min) / (max - min)
end

end
