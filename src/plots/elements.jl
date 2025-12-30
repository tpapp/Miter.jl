####
#### common plot components to visualize data
####

export Lines, Scatter, Circles, RelativeBars, ColorMatrix

####
#### Lines
####

struct Lines
    coordinates
    line_width::Length
    color
    dash::Dash
    @doc """
    $(SIGNATURES)
    """
    function Lines(coordinates; line_width::Length = DEFAULTS.line_width,
                   color = DEFAULTS.line_color, dash::Dash = LINE_SOLID)
        @argcheck line_width > 0mm
        new(ensure_vector(coordinates), line_width, color, dash)
    end
end

Coordinates.bounds_xy(lines::Lines) = Coordinates.all_coordinate_bounds_xy(lines.coordinates)

function Draw.render(sink::Draw.Sink, drawing_area::DrawingArea, lines::Lines)
    (; coordinates, line_width, color, dash) = lines
    peeled = Iterators.peel(coordinates)
    peeled ≡ nothing && return
    Draw.set_line_style(sink; color, width = line_width, dash)
    c1, cR = peeled
    Draw.pathmoveto(sink, coordinates_to_point(drawing_area, c1))
    for c in cR
        Draw.pathlineto(sink, coordinates_to_point(drawing_area, c))
    end
    Draw.usepathqstroke(sink)
end

###
### Scatter
###

struct Scatter{M}
    coordinates::AbstractVector
    mark::M
    @doc """
    $(SIGNATURES)

    A scatterplot.

    See [`MarkSymbol`](@ref) and [`MarkQ5`](@ref).
    """
    function Scatter(mark::M, coordinates) where {M}
        new{M}(ensure_vector(coordinates), mark)
    end
end

Scatter(coordinates) = Scatter(MarkSymbol(), coordinates)

Coordinates.bounds_xy(scatter::Scatter) = Coordinates.all_coordinate_bounds_xy(scatter.coordinates)

function Draw.render(sink::Draw.Sink, drawing_area::DrawingArea, scatter::Scatter)
    (; mark, coordinates) = scatter
    for xy in coordinates
        Draw.render(sink, drawing_area, mark, xy)
    end
end

Draw.wrap_in_default_canvas(plot::Plot; standalone::Bool = false) = Draw.Canvas(plot)

Draw.@declare_showable Plot

###
### Circles
###

struct Circles
    x_y_w::AbstractVector
    scale::Length
    fill_color::Union{Nothing,COLOR}
    stroke_color::Union{Nothing,COLOR}
    stroke_width::Length
    @doc """
    $(SIGNATURES)

    Taking an iterator or vector of `(x, y, w)` triplets (eg `NTuple{3}`, but anything
    iterable with 3 elements will do), draw circles centered on `(x, y)` coordinates
    with radius `scale * √w`.

    # Keyword arguments

    `stroke_color` determines the stroke color, using `nothing` if circles should not be
    stroked. `stroke_width` determines the stroke with if applicable.

    `fill_color` determines the fill color of circles.
    """
    function Circles(x_y_w, scale::Length;
                     stroke_color = nothing,
                     stroke_width::Length = DEFAULTS.line_width,
                     fill_color = DEFAULTS.fill_color)
        @argcheck scale > 0mm
        @argcheck stroke_width > 0mm
        new(collect(x_y_w),
            scale,
            convert_maybe(COLOR, fill_color),
            convert_maybe(COLOR, stroke_color),
            stroke_width)
    end
end

Coordinates.bounds_xy(circles::Circles) = Coordinates.all_coordinate_bounds_xy(circles.x_y_w)

function Draw.render(sink::Draw.Sink, drawing_area::DrawingArea, circles::Circles)
    (; x_y_w, scale, stroke_color, stroke_width, fill_color) = circles
    Draw.set_stroke_or_fill_style(sink; stroke_color, fill_color, stroke_width)
    for (x, y, w) in x_y_w
        Draw.pathcircle(sink, coordinates_to_point(drawing_area, (x, y)), scale * √w)
        Draw.path_q_stroke_or_fill(sink, stroke_color, fill_color)
    end
end

####
#### RelativeBars
####

struct RelativeBars
    orientation::Symbol
    edges_and_values::Vector{Tuple{Float64,Float64,Float64}}
    baseline::Float64
    fill_color::Union{Nothing,COLOR}
    stroke_color::Union{Nothing,COLOR}
    stroke_width::Length
    """
    $(SIGNATURES)

    Draw bars relative to `baseline` with the given `orientation`, which may be
    `:horizontal` or `:vertical`.

    The second argument should be an iterable of `(e1, e2, v)` values, all finite, which
    specify the edges and the value for each bar (`baseline` provides the other value).

    At least `fill_color` or `stroke_color` should be specified.

    Note that for most applications, an algorithm would calculate the edges and values,
    and such a method should be provided. For example, when `StatsBase` is loaded, a
    `Histogram` is a valid second argument and will be converted accordingly.
    """
    function RelativeBars(orientation::Symbol, edges_and_values; baseline = 0,
                          stroke_color = DEFAULTS.bars_stroke_color,
                          stroke_width = DEFAULTS.line_width,
                          fill_color = DEFAULTS.fill_color)
        @argcheck orientation ∈ (:vertical, :horizontal)
        @argcheck isfinite(baseline)
        new(orientation,
            map(x -> (_x = convert(Tuple{Float64,Float64,Float64}, x);
                      @argcheck all(isfinite, _x);
                      @argcheck _x[1] < _x[2];
                      _x),
                edges_and_values),
            convert(Float64, baseline),
            convert_maybe(COLOR, fill_color),
            convert_maybe(COLOR, stroke_color),
            convert(Length, stroke_width))
    end
end

function Coordinates.bounds_xy(relative_bars::RelativeBars)
    (; orientation, edges_and_values, baseline) = relative_bars
    e = mapreduce(x -> Interval(x[1], x[2]), Coordinates.combine_bounds, edges_and_values)
    v = Interval(extrema((baseline, extrema(x -> x[3], edges_and_values)...))...)
    orientation ≡ :vertical ? (e, v) : (v, e)
end

function Draw.render(sink::Draw.Sink, drawing_area::DrawingArea, relative_bars::RelativeBars)
    (; orientation, edges_and_values, baseline, stroke_color, stroke_width,
     fill_color) = relative_bars
    Draw.set_stroke_or_fill_style(sink; stroke_color, fill_color, stroke_width)
    for (e1, e2, v) in edges_and_values
        c1 = coordinates_to_point(drawing_area, orientation ≡ :vertical ?
            (e1, baseline) : (baseline, e1))
        c2 = coordinates_to_point(drawing_area, orientation ≡ :vertical ? (e2, v) : (v, e2))
        Draw.path(sink, Rectangle(c1, c2))
        Draw.path_q_stroke_or_fill(sink, stroke_color, fill_color)
    end
end

####
#### color matrix
####

struct ColorMatrix
    x_edges::Vector{Float64}
    y_edges::Vector{Float64}
    colors::Matrix{Union{Nothing,COLOR}}
    @doc """
    $(SIGNATURES)

    A “matrix” of colors, with the specified edges. Colors of `nothing` are not drawn.

    *Note*: this is a building block for various plot types, including heatmaps.
    """
    function ColorMatrix(x_edges, y_edges, colors)
        x_edges = Float64.(x_edges)
        y_edges = Float64.(y_edges)
        colors = collect(Union{Nothing,COLOR},
                         convert_maybe(COLOR, c) for c in colors)
        @argcheck x_edges isa Vector{Float64} && issorted(x_edges)
        @argcheck y_edges isa Vector{Float64} && issorted(y_edges)
        @argcheck colors isa Matrix{Union{Nothing,COLOR}}
        @argcheck size(colors) == (length(x_edges) - 1, length(y_edges) - 1)
        new(x_edges, y_edges, colors)
    end
end

function Coordinates.bounds_xy(color_matrix::ColorMatrix)
    (; x_edges, y_edges) = color_matrix
    (Interval(x_edges[begin], x_edges[end]), Interval(y_edges[begin], y_edges[end]))
end

function Draw.render(sink::Draw.Sink, drawing_area::DrawingArea, color_matrix::ColorMatrix)
    (; x_edges, y_edges, colors) = color_matrix
    x_c = x_coordinate_to_canvas.(drawing_area, x_edges)
    y_c = y_coordinate_to_canvas.(drawing_area, y_edges)
    for i in axes(colors, 1)
        for j in axes(colors, 2)
            c = colors[i, j]
            if c ≢ nothing
                Draw.setfillcolor(sink, c)
                Draw.path(sink, Rectangle(; left = x_c[i], right = x_c[i + 1],
                                          bottom = y_c[j], top = y_c[j + 1]))
                Draw.usepathqfill(sink)
            end
        end
    end
end
