#####
##### visualization helpers
#####

export Annotation, Hgrid, Hline, Vgrid, Vline, LineThrough

####
#### Annotation
####

struct Annotation
    x::Float64
    y::Float64
    text
    top::Bool
    bottom::Bool
    base::Bool
    left::Bool
    right::Bool
    rotate::Float64
    @doc """
    $(SIGNATURES)

    Place `text` (a `LaTeX` or `AbstractString`) at the given coordinates, using the
    specified alignment and rotation. See also [`PGF.textcolor`](@ref).
    """
    function Annotation(at, text; left::Bool = false, right::Bool = false, top::Bool = false,
                        bottom::Bool = false, base::Bool = false, rotate::Real = 0)
        PGF._check_text_alignment(; left, right, top, bottom, base)
        x, y = float64_xy(at)
        new(x, y, text, top, bottom, base, left, right, Float64(rotate))
    end
end

Coordinates.bounds_xy(text::Annotation) = (Interval(text.x), Interval(text.y))

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, text::Annotation)
    (; x, y, text, top, bottom, base, left, right, rotate) = text
    PGF.text(sink, coordinates_to_point(drawing_area, (x, y)), text; top, bottom, base,
             left, right, rotate)
end

####
#### Hgrid
####

struct Hgrid
    color::COLOR
    width::LENGTH
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)

    A horizontal grid at the ticks of the ``y`` axis.
    """
    function Hgrid(; color = DEFAULTS.grid_color,
                   width = DEFAULTS.grid_width,
                   dash = DEFAULTS.grid_dash)
        new(COLOR(color), _length_positive(width), dash)
    end
end

Coordinates.bounds_xy(hgrid::Hgrid) = (nothing, nothing)

"""
$(SIGNATURES)

Internal utility function to draw a horizontal line at `y`. Caller should set the line style.
"""
function _hline(sink::PGF.Sink, drawing_area::DrawingArea, y::Real)
    (; left, right) = drawing_area.rectangle
    y_c = y_coordinate_to_canvas(drawing_area, y)
    PGF.pathmoveto(sink, PGF.Point(left, y_c))
    PGF.pathlineto(sink, PGF.Point(right, y_c))
    PGF.usepathqstroke(sink)
end

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, hgrid::Hgrid)
    (; color, width, dash) = hgrid
    set_line_style(sink; color, width, dash)
    # FIXME code below relies on nested properties of types, define an API
    for (pos, _) in drawing_area.finalized_y_axis.ticks
        _hline(sink, drawing_area, pos)
    end
end

####
#### Hline
####

struct Hline
    y::Real
    color::COLOR
    width::LENGTH
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)

    A horizontal line at `y` with the given parameters.
    """
    function Hline(y::Real; color = DEFAULTS.guide_color, width = DEFAULTS.guide_width,
                   dash = DEFAULTS.guide_dash)
        @argcheck isfinite(y)
        new(y, COLOR(color), _length_positive(width), dash)
    end
end

Coordinates.bounds_xy(hline::Hline) = (nothing, Interval(hline.y))

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, hline::Hline)
    (; y, color, width, dash) = hline
    set_line_style(sink; color, width, dash)
    _hline(sink, drawing_area, y)
end

####
#### Vgrid
####

struct Vgrid
    color::COLOR
    width::LENGTH
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)

    A horizontal grid at the ticks of the ``y`` axis.
    """
    function Vgrid(; color = DEFAULTS.grid_color,
                   width = DEFAULTS.grid_width,
                   dash = DEFAULTS.grid_dash)
        new(COLOR(color), _length_positive(width), dash)
    end
end

Coordinates.bounds_xy(vgrid::Vgrid) = (nothing, nothing)


"""
$(SIGNATURES)

Internal utility function to draw a vertical line at `x`. Caller should set the line style.
"""
function _vline(sink::PGF.Sink, drawing_area::DrawingArea, x::Real)
    (; bottom, top) = drawing_area.rectangle
    x_c = x_coordinate_to_canvas(drawing_area, x)
    PGF.pathmoveto(sink, PGF.Point(x_c, bottom))
    PGF.pathlineto(sink, PGF.Point(x_c, top))
    PGF.usepathqstroke(sink)
end

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, vgrid::Vgrid)
    (; color, width, dash) = vgrid
    set_line_style(sink; color, width, dash)
    # FIXME code below relies on nested properties of types, define an API
    for (pos, _) in drawing_area.finalized_x_axis.ticks
        _vline(sink, drawing_area, pos)
    end
end

####
#### Vline
####

struct Vline
    x::Real
    color::COLOR
    width::LENGTH
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)

    A vertical line at `x` with the given parameters.
    """
    function Vline(x::Real; color = DEFAULTS.guide_color, width = DEFAULTS.guide_width,
                   dash = DEFAULTS.guide_dash)
        @argcheck isfinite(x)
        new(x, COLOR(color), _length_positive(width), dash)
    end
end

Coordinates.bounds_xy(vline::Vline) = (Interval(vline.x), nothing)

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, vline::Vline)
    (; x, color, width, dash) = vline
    set_line_style(sink; color, width, dash)
    _vline(sink, drawing_area, x)
end

####
#### LineThrough
####

struct LineThrough
    x::Float64
    y::Float64
    slope::Float64
    color::COLOR
    width::LENGTH
    dash::PGF.Dash
    @doc """
    $(SIGNATURES)

    A line through the given coordinates. Slope can be finite or ±Inf. Does not extend bounds.
    """
    function LineThrough(xy, slope::Real; color = DEFAULTS.guide_color,
                         width = DEFAULTS.guide_width, dash = DEFAULTS.guide_dash)
        x, y = float64_xy(xy)
        slope = Float64(slope)
        @argcheck isfinite(slope) || isinf(slope)
        new(x, y, slope, color, width, dash)
    end
end

Coordinates.bounds_xy(::LineThrough) = (nothing, nothing)

"""
$(SIGNATURES)

Return two points where `line_through` crosses the rectangle defined by intervals,
ordered by the `x` coordinate.

If there is no crossing, return `nothing`.
"""
function line_through_endpoints(line_through::LineThrough,
                                x_interval::Interval,
                                y_interval::Interval)
    (; x, y, slope) = line_through
    if slope == 0               # horizontal line
        (x_interval.min, y), (x_interval.max, y)
    elseif abs(slope) == Inf    # vertical line
        (x, y_interval.min), (x, y_interval.max)
    else
        x1 = y1 = x2 = y2 = 0.0 # saved valid crossings
        is_first = true
        tol = max(x_interval.max - x_interval.min, y_interval.max - y_interval.min, 1.0) * √eps()
        function _save(x, y)
            # save coordinates, return `true` when two have been collected
            if is_first
                x1, y1 = x, y
                is_first = false
                false
            else
                if isapprox(x, x1; atol = tol) && isapprox(y, y1; atol = tol)
                    # same as previous, don't save
                    false
                else
                    x2, y2 = x, y
                    true
                end
            end
        end
        function _is_in(z, a)
            # test if z ∈ a, but allow for numerical error
            (; min, max) = a
            min - tol ≤ z ≤ max + tol
        end
        function _find_x_crossing(ŷ)
            # find the crossing of a horizontal line at `ŷ`, save when it is in bounds,
            # return true when `_save` does
            x̂ = (ŷ - y) / slope + x
            _is_in(x̂, x_interval) && _save(x̂, ŷ)
        end
        function _find_y_crossing(x̂)
            # same as _find_x_crossing, mutatis mutandis
            ŷ = (x̂ - x) * slope + y
            _is_in(ŷ, y_interval) && _save(x̂, ŷ)
        end
        if _find_x_crossing(y_interval.min) ||
            _find_x_crossing(y_interval.max) ||
            _find_y_crossing(x_interval.min) ||
            _find_y_crossing(x_interval.max)
            if x1 > x2
                x1, x2 = x2, x1
                y1, y2 = y2, y1
            end
            return (x1, y1), (x2, y2)
        else
            return nothing
        end
    end
end

function PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, line_through::LineThrough)
    (; finalized_x_axis, finalized_y_axis) = drawing_area
    (; color, width, dash) = line_through
    @argcheck(finalized_x_axis isa FinalizedLinear && finalized_y_axis isa FinalizedLinear,
              "LineThrough only supported for linear axes.")
    z1z2 = line_through_endpoints(line_through,
                                  finalized_x_axis.interval,
                                  finalized_y_axis.interval)
    if z1z2 ≢ nothing
        z1, z2 = z1z2
        set_line_style(sink; color, width, dash)
        PGF.pathmoveto(sink, coordinates_to_point(drawing_area, z1))
        PGF.pathlineto(sink, coordinates_to_point(drawing_area, z2))
        PGF.usepathqstroke(sink)
    end
end
