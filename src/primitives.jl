####
#### primitives we use for drawing
####

export canvas

###
### Postscript basis point conversion
###

"Types we (may) accept as lengths. Dimensionsless quantities have to be `==0`."
const LENGTH = Union{Real,Length}

"""
$(SIGNATURES)

Convert to Postscript basis points, which we use internally. Equivalent to 1/72 inch. Only 0
is accepted without a dimension.
"""
to_bp(x::Length) = Float64(uconvert(Unitful.NoUnits, x / ((1/72)inch)))

function to_bp(x::Real)
    @argcheck x == 0 "Only 0 is accepted without a dimension."
    0.0
end

####
#### points
####

"""
$(TYPEDEF)

A pair of coordinates, represented internally in `bp` (Postscript point, 1/72in) units.

The preferred constructor is [`pgfpoint`](@ref), using `Unitful.Length` units.
"""
struct PGFPoint
    x::Float64
    y::Float64
    function PGFPoint(x::Float64, y::Float64)
        @argcheck isfinite(x)
        @argcheck isfinite(y)
        new(x, y)
    end
end

function pgf_point(x::LENGTH, y::LENGTH)
    PGFPoint(to_bp(x), to_bp(y))
end

####
#### rectangles
####

struct PGFRectangle
    bottom_left::PGFPoint
    top_right::PGFPoint
    function PGFRectangle(bottom_left::PGFPoint, top_right::PGFPoint)
        @argcheck bottom_left.x ≤ top_right.x
        @argcheck bottom_left.y ≤ top_right.y
        new(bottom_left, top_right)
    end
end

function Base.getproperty(rectangle::PGFRectangle, sym::Symbol)
    ll = getfield(rectangle, :bottom_left)
    ur = getfield(rectangle, :top_right)
    if sym ≡ :left
        ll.x
    elseif sym ≡ :right
        ur.x
    elseif sym ≡ :top
        ur.y
    elseif sym ≡ :bottom
        ll.y
    elseif sym ≡ :width
        ur.x - ll.x
    elseif sym ≡ :height
        ur.y - ll.y
    else
        getfield(rectangle, sym)
    end
end

"""
$(SIGNATURES)

When only the width and the height are given, create a rectangle where bottom left is the
origin.
"""
function canvas(width::LENGTH, height::LENGTH)
    PGFRectangle(pgf_point(0, 0), pgf_point(width, height))
end

function split_rectangle_horizontally(rectangle::PGFRectangle, y::Length)
    y_bp = to_bp(y)
    @argcheck 0 < abs(y_bp) < rectangle.height
    y_mid = (y_bp > 0 ? rectangle.bottom : rectangle.top) + y_bp
    (PGFRectangle(rectangle.bottom_left, PGFPoint(rectangle.right, y_mid)),
     PGFRectangle(PGFPoint(rectangle.left, y_mid), rectangle.top_right))
end

function split_rectangle_vertically(rectangle::PGFRectangle, x::Length)
    x_bp = to_bp(x)
    @argcheck 0 < abs(x_bp) < rectangle.width
    x_mid = (x_bp > 0 ? rectangle.left : rectangle.right) + x_bp
    (PGFRectangle(rectangle.bottom_left, PGFPoint(x_mid, rectangle.top)),
     PGFRectangle(PGFPoint(x_mid, rectangle.bottom), rectangle.top_right))
end

"""
$(SIGNATURES)

Split rectangle into four parts, by `x` horizontally and `y` vertically. Return 4 values,
arranged as

```ascii
3 4
1 2
```

See [`split_rectangle_horizontally`](@ref) and [`split_rectangle_vertically`](@ref).
"""
function split_rectangle_fourways(rectangle::PGFRectangle, x::Length, y::Length)
    R12, R34 = split_rectangle_vertically(rectangle, y)
    R1, R2 = split_rectangle_horizontally(R12, x)
    R3, R4 = split_rectangle_horizontally(R34, x)
    (R1, R2, R3, R4)
end
