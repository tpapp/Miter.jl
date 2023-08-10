"""
A Julia plotting package using the PGF Basic Layer Core.
"""
module Miter

export Axis, Plot, Lines, @math_str

using ColorTypes: RGB
using DocStringExtensions: SIGNATURES, FUNCTIONNAME

include("compile.jl")
include("pgf.jl")
include("utilities.jl")
include("intervals.jl")
include("defaults.jl")
include("ticks.jl")
include("axis.jl")
include("output.jl")
include("plot.jl")

macro math_str(str)
    PGF.math(str)
end

end # module
