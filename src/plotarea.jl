export plot_area, linear_axis, point, line_plot, render

struct LinearAxis
    left::Float64
    right::Float64
    # FIXME argcheck left ≠ right
end

linear_axis(left, right) = LinearAxis(left, right)

function project_to(lower::Float64, upper::Float64, src::LinearAxis, x::Real)
    α = (x - src.left) / (src.right - src.left)
    (1 - α) * lower + α * upper
end

struct PlotArea{TX,TY}
    rectangle::PGFRectangle
    axis_x::TX
    axis_y::TY
    # FIXME add x/y margin
end

function plot_area(rectangle::PGFRectangle, axis_x, axis_y)
    PlotArea(rectangle, axis_x, axis_y)
end

struct Point{T<:Real}
    x::T
    y::T
    # FIXME argcheck isfinite x y
end

point(x::Real, y::Real) = Point(x, y)

function project_to(plot_area::PlotArea, point::Point)
    @unpack rectangle, axis_x, axis_y = plot_area
    @unpack x, y = point
    @unpack top, bottom, left, right = rectangle
    PGFPoint(project_to(left, right, axis_x, x), project_to(bottom, top, axis_y, y))
end

struct LinePlot{T}
    # fixme style etc
    points::T
end

line_plot(points) = LinePlot(points)

function render(ts::TeXStream, plot_area::PlotArea, line_plot::LinePlot)
    pgfsetstrokecolor(ts, RGB(0, 0, 0)) # FIXME modify when color is introduced
    # FIXME clipping
    for (i, point) in enumerate(line_plot.points)
        p = project_to(plot_area, point)
        i == 1 ? pgfpathmoveto(ts, p) : pgfpathlineto(ts, p)
    end
    pgfusepath(ts, :stroke)
end
