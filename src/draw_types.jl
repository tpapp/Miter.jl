"""
Types used by drawing commands.
"""
module DrawTypes

export COLOR, Point, flip, Rectangle, relative_point, Spacer, Relative, split_matrix, Dash

using ArgCheck: @argcheck
using ColorTypes: RGB
using DocStringExtensions: SIGNATURES
using StaticArrays: SVector, SMatrix

using ..InternalUtilities: unit_to_canvas
using ..Lengths: Length, mm

####
#### Color
####

"""
The color representation used by the backend. All colors are converted to this before
being used. Use this type for conversion.
"""
const COLOR = RGB{Float64}

####
#### Point
####

struct Point
    x::Length
    y::Length
    @doc """
    $(SIGNATURES)

    Create a point at the `x` and `y` coordinates.
    """
    Point(x::Length, y::Length) = new(x, y)
end

Base.:+(a::Point, b::Point) = Point(a.x + b.x, a.y + b.y)
Base.:-(a::Point, b::Point) = Point(a.x - b.x, a.y - b.y)
Base.:*(a::Point, b::Real) = Point(a.x * b, a.y * b)
Base.:*(a::Real, b::Point) = b * a
Base.:/(a::Point, b::Real) = Point(a.x / b, a.y / b)

"""
$(SIGNATURES)

Exchange coordinates of a point.
"""
flip(a::Point) = Point(a.y, a.x)

####
#### Rectangle
####

struct Rectangle
    left::Length
    right::Length
    bottom::Length
    top::Length
    @doc """
    $(SIGNATURES)

    Create a rectangle with the given boundaries, which are `Length` values.
    """
    function Rectangle(left::Length, right::Length, bottom::Length, top::Length)
        if left > right
            left, right = right, left
        end
        if bottom > top
            bottom, top = top, bottom
        end
        new(left, right, bottom, top)
    end
end

Rectangle(c1::Point, c2::Point) = Rectangle(c1.x, c2.x, c1.y, c2.y)

Rectangle(; left, right, bottom, top) = Rectangle(left, right, bottom, top)

"""
$(SIGNATURES)

A point relative to the boundaries of the rectangle (`x = 0` for left, `y = 0` for
bottom).
"""
function relative_point(rectangle::Rectangle, (x, y))
    (; left, right, bottom, top) = rectangle
    Point(unit_to_canvas(left, right, x), unit_to_canvas(bottom, top, y))
end

####
#### subdivisions
####

struct Spacer
    factor::Float64
    @doc """
    $(SIGNATURES)

    Divide up remaining space proportionally.

    Style note: use when this is the only kind of spacer.
    """
    function Spacer(x::Real = 1.0)
        @argcheck x ≥ 0
        new(Float64(x))
    end
end

struct Relative
    factor::Float64
    @doc """
    $(SIGNATURES)

    Relative widths, calculated proportionally to the containing interval length.
    """
    function Relative(x::Real)
        @argcheck x ≥ 0
        new(Float64(x))
    end
end

function split_interval(a::Length, b::Length, divisions)
    total = b - a
    @argcheck total ≥ 0mm
    function _resolve1(d)       # first pass: everything but Spacer
        if d isa Length
            @argcheck d ≥ 0mm
            d
        elseif d isa Relative
            d.factor * total
        else
            error("Invalid division specification $(d).")
        end
    end
    absolute_sum = sum(_resolve1(d) for d in divisions if !(d isa Spacer); init = 0mm)
    @argcheck absolute_sum ≤ total
    spacer_sum = sum(d.factor for d in divisions if d isa Spacer; init = 0.0)
    remainder = total - absolute_sum
    @argcheck spacer_sum > 0 || remainder ≈ 0
    spacer_coefficient = remainder / spacer_sum
    function _resolve2(d)       # second pass
        if d isa Length
            d                   # has been checked before
        elseif d isa Relative
            d.factor * total
        else
            d.factor * spacer_coefficient
        end
    end
    accumulate(((a, b), d) -> (b, b + _resolve2(d)), divisions; init = (a, a))
end

"""
$(SIGNATURES)

Split `rectangle` along `x_divisions` and `y_divisions`. Return the result as a
`Matrix`, or `SMatrix` when both divisions are specified as `Tuple`s.

Note: the matrix is indexed with *horizontal* and *vertical* coordinates (in this
order), and indexing conventions follow the Cartesian coordinate system. If you want the
arrangement of how matrices are usually displayed, use
```julia
reverse(permutedims(split_matrix(...)); dims = 1)
```
"""
function split_matrix(rectangle::Rectangle,
                      x_divisions::Union{NTuple{N,Any},AbstractVector},
                      y_divisions::Union{NTuple{M,Any},AbstractVector}) where {N,M}
    (; top, left, bottom, right) = rectangle
    x_intervals = split_interval(left, right, x_divisions)
    y_intervals = split_interval(bottom, top, y_divisions)
    if x_intervals isa Tuple && y_intervals isa Tuple
        SMatrix{N,M}((Rectangle(; left, right, bottom, top)
                      for (left, right) in x_intervals, (bottom, top) in y_intervals))
    else
        [Rectangle(; left, right, bottom, top)
         for (left, right) in x_intervals, (bottom, top) in y_intervals]
    end
end

####
#### Dash
####

struct Dash
    dimensions::Vector{Length}
    offset::Length
    @doc """
    $(SIGNATURES)

    A dash pattern. `Dash()` gives a solid line. See [`setdash`](@ref).
    """
    function Dash(dimensions::Length...; offset::Length = 0mm)
        @argcheck iseven(length(dimensions)) "Dashes need an even number of dimensions."
        @argcheck all(d -> d > 0mm, dimensions) "Dash lengths need to be positive."
        new([d for d in dimensions], offset)
    end
end

end
