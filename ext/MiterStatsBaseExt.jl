module MiterStatsBaseExt

import Miter, StatsBase
using Miter.InternalUtilities: ensure_vector
using ArgCheck: @argcheck

function Miter.Plots.RelativeBars(orientation::Symbol, histogram::StatsBase.Histogram{T,1};
                                  kwargs...) where T
    (; edges, weights) = histogram
    e = only(edges)
    Miter.Plots.RelativeBars(orientation,
                             (e[i], e[i+1], w) for (i, w) in enumerate(weights);
                             kwargs...);
end

function Miter.Utilities.hpd_heatmap(histogram::StatsBase.Histogram{T,2},
                                     probabilities, colors) where T
    # check argument consistency
    p = ensure_vector(Float64, probabilities)
    c = ensure_vector(Miter.PGF.COLOR, colors)
    Base.require_one_based_indexing(p, c)
    @argcheck issorted(p; lt = <) && p[begin] > 0 && p[end] < 1
    @argcheck length(p) + 1 == length(c) ≥ 1

    # sort by density, preserving cell location
    (; edges, weights, isdensity) = histogram
    (x_edges, y_edges) = edges
    x_w = diff(x_edges)
    y_w = diff(y_edges)
    density_mass(d, w) = isdensity ? (d, d * w) : (d / w, d)
    z = [(density_mass(weights[i, j], wx * wy)..., (i, j))
         for (j, wy) in enumerate(y_w) for (i, wx) in enumerate(x_w)]

    # assign colors
    sort!(z; by = first)        # sort by density
    s = cumsum(z[2] for z in z) # by bin cumulative mass
    S = s[end]
    k = map(s -> searchsortedfirst(p, s / S), s) # color index
    ij_k = map((z, k) -> (z[3], z[1] == 0 ? nothing : c[k]), z, k)
    sort!(ij_k, by = reverse ∘ first, lt = isless)  # rearrange as original
    matrix_colors = map(last, reshape(ij_k, length(x_edges) - 1, length(y_edges) - 1))

    # format as a ColorMatrix
    Miter.Plots.ColorMatrix(x_edges, y_edges, matrix_colors)
end

end
