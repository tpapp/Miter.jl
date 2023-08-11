"""
A Julia plotting package using the PGF Basic Layer Core.
"""
module Miter

export Axis, Plot, Lines, @math_str

using ColorTypes: RGB, RGB24
using DocStringExtensions: SIGNATURES, FUNCTIONNAME

include("compile.jl")
include("pgf.jl")
include("intervals.jl")
include("styles.jl")
include("ticks.jl")
include("axis.jl")
include("output.jl")
include("plot.jl")
include("utilities.jl")

macro math_str(str)
    PGF.math(str)
end

end # module
