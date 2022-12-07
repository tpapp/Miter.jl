export plot_area, linear_axis, point, line_plot, render

struct Interval
    left::Float64
    right::Float64
    # FIXME argcheck left < right
end

struct LinearAxis
    left::Float64
    right::Float64
    # FIXME argcheck left ≠ right
end

linear_axis(left, right) = LinearAxis(left, right)

function project_to(dst::Interval, src::LinearAxis, x::Real)
    α = (x - src.left) / (src.right - src.left)
    (1 - α) * dst.left + α * dst.right
end

struct PlotArea{TX,TY}
    canvas_x::Interval
    canvas_y::Interval
    axis_x::TX
    axis_y::TY
    # FIXME add x/y margin
end

function plot_area(lower_left::PGFPoint, upper_right::PGFPoint, axis_x, axis_y)
    PlotArea(Interval(lower_left.x, upper_right.x),
             Interval(lower_left.y, upper_right.y),
             axis_x,
             axis_y)
end


struct Point{T<:Real}
    x::T
    y::T
    # FIXME argcheck isfinite x y
end

point(x::Real, y::Real) = Point(x, y)

function project_to(plot_area::PlotArea, point::Point)
    @unpack canvas_x, canvas_y, axis_x, axis_y = plot_area
    @unpack x, y = point
    PGFPoint(project_to(canvas_x, axis_x, x), project_to(canvas_y, axis_y, y))
end

struct LinePlot{T}
    # fixme style etc
    points::T
end

line_plot(points) = LinePlot(points)

function render(ts::TeXStream, plot_area::PlotArea, line_plot::LinePlot)
    # FIXME clipping
    for (i, point) in enumerate(line_plot.points)
        p = project_to(plot_area, point)
        i == 1 ? pgfpathmoveto(ts, p) : pgfpathlineto(ts, p)
    end
    pgfusepath(ts, :stroke)
end
