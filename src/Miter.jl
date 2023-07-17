"""
A Julia plotting package using the PGF Basic Layer Core.
"""
module Miter

export Axis, Plot, Lines

using Colors: @colorant_str, RGB # NOTE maybe no need for full Colors once done?
using DocStringExtensions: SIGNATURES
using Unitful: @u_str

include("compile.jl")
include("pgf.jl")
include("utilities.jl")
include("intervals.jl")
include("ticks.jl")
include("axis.jl")
include("plot.jl")

end # module
