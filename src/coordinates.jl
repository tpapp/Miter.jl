module Coordinates

export Interval, bounds_xy

public is_nonzero, coordinate_x, coordinate_y, combine_bounds_xy, all_bounds_xy,
    coordinate_bounds_xy, all_coordinate_bounds_xy

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES

####
#### intervals
####

struct Interval{T}
    min::T
    max::T
    level::Int
    @doc """
    $(SIGNATURES)

    A representation of the numbers in the interval `[min, max]`. It is required that
    `min ≤ max`, but `min == max` is allowed.

    The single-argument convenience constructer uses the extrema of the argument.
    """
    function Interval(min::T, max::T; level = 0) where T
        @argcheck isfinite(min) && isfinite(max)
        @argcheck min ≤ max
        new{T}(min, max, Int(level))
    end
end

Interval(a, b; level = 0) = Interval(promote(a, b)...; level)

Interval(a; level = 0) = Interval(extrema(a)...; level)

Base.minimum(a::Interval) = a.min
Base.maximum(a::Interval) = a.max
Base.extrema(a::Interval) = (a.min, a.max)

"""
$(SIGNATURES)

Test whether the interval has positive length.
"""
is_nonzero(a::Interval) = a.min < a.max

####
#### coordinate bounds
####

const CoordinateBounds = Union{Interval,Nothing}

const EMPTY_XY = (nothing, nothing)

"""
$(SIGNATURES)

Combine coordinate bounds into the narrowest interval that contains all arguments.

This is a utility funtion for use in [`combine_bounds_xy`](@ref).
"""
function combine_bounds(a::Interval, b::Interval)
    if a.level == b.level
        Interval(min(a.min, b.min), max(a.max, b.max))
    elseif a.level > b.level
        a
    else
        b
    end
end

combine_bounds(::Nothing, a::Interval) = a

combine_bounds(a::Interval, ::Nothing) = a

combine_bounds(::Nothing, ::Nothing) = nothing

"""
$(SIGNATURES)

Return two intervals for the coordinate bounds of the arguments.

For the default behavior, types should define [`bounds_xy`](@ref). For something
different (eg overriding bounds), define [`combine_bounds_xy`](@ref).
"""
bounds_xy(::Nothing) = (nothing, nothing)

function combine_bounds_xy((ax, ay)::Tuple{CoordinateBounds,CoordinateBounds}, b)
    bx, by = bounds_xy(b)
    combine_bounds(ax, bx), combine_bounds(ay, by)
end

"""
$(SIGNATURES)

Combine XY bounds of the argument, from left to right.
"""
bounds_xy(itr) = foldl(combine_bounds_xy, itr; init = EMPTY_XY)

####
#### coordinate accessors and bounds
####

"""
$(SIGNATURES)

Coordinate bounds for a coordinate `xy`. Used only in [`all_coordinate_bounds`](@ref).

Scalar-like quantities should define a method for `Base.extrema`, which has the right
fallback for reals by default.

!!! note
    Future extensions with coordinate types `(:x 1 :y 2 :size 3)` etc can go through
    this function.
"""
coordinate_bounds_xy(xy) = Interval(extrema(xy[1])...), Interval(extrema(xy[2])...)

"""
$(SIGNATURES)

Helper function to calculate all coordinate bounds from coordinates.
"""
function all_coordinate_bounds_xy(itr)
    mapreduce(coordinate_bounds_xy,
              ((ax, ay), (bx, by)) -> (combine_bounds(ax, bx), combine_bounds(ay, by)),
              itr; init = EMPTY_XY)
end

end
