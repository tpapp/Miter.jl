module Axis

using ArgCheck: @argcheck
using ..PGF: Rectangle, Point

struct Interval
    min::Float64
    max::Float64
    function Interval(min, max)
        @argcheck isfinite(min) && isfinite(max)
        @argcheck min ≤ max
        new(Float64(min), Float64(max))
    end
    Interval() = new(Inf, -Inf) # sentinel for empty interval
end

is_nonempty(a::Interval) = a.min ≤ a.max

function extend(a::Interval, b::Real)
    @argcheck isfinite(b)
    Interval(min(a.min, b), max(a.max, b))
end

function extend(a::Interval, b::Interval)
    @argcheck is_nonempty(b)
    Interval(min(a.min, b.min), max(a.max, b.max))
end

function extend_xy((ax, ay)::Tuple{Interval,Interval},
                 (bx, by)::Tuple{Interval,Interval})
    (extend(ax, bx), extend(ay, by))
end

bounds(f, itr) = Interval(extrema(f, itr)...)

bounds_xy(itr) = mapreduce(bounds_xy, extend_xy, itr; init = (Interval(), Interval()))

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

end
