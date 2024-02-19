module MiterStatsBaseExt

import Miter, StatsBase

function Miter.Plots.RelativeBars(orientation::Symbol, histogram::StatsBase.Histogram{T,1};
                                  kwargs...) where T
    (; edges, weights) = histogram
    e = only(edges)
    Miter.Plots.RelativeBars(orientation,
                             (e[i], e[i+1], w) for (i, w) in enumerate(weights);
                             kwargs...);
end

end
