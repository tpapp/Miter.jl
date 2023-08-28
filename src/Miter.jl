"""
A Julia plotting package using the PGF Basic Layer Core.
"""
module Miter

export Axis, Plot, Lines

using ColorTypes: RGB, RGB24
using DocStringExtensions: SIGNATURES, FUNCTIONNAME
using Reexport: @reexport

include("compile.jl")
include("pgf.jl")
include("intervals.jl")
include("styles.jl")
include("ticks.jl")
include("axis.jl")
include("output.jl")
include("plot.jl")
include("utilities.jl")

@reexport using .PGF: textcolor, @math_str, @latex_str

end # module
