"""
A Julia plotting package using the PGF Basic Layer Core.
"""
module Miter

export Axis, Plot, Lines

using ColorTypes: RGB
using DocStringExtensions: SIGNATURES, FUNCTIONNAME
using Unitful: @u_str

include("compile.jl")
include("pgf.jl")
include("utilities.jl")
include("intervals.jl")
include("ticks.jl")
include("axis.jl")
include("output.jl")
include("plot.jl")

end # module
