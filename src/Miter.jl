"""
A Julia plotting package using the PGF Basic Layer Core.
"""
module Miter

using Colors: @colorant_str, RGB
using Unitful: @u_str

include("compile.jl")
include("pgf.jl")
include("utilities.jl")
include("axis.jl")

end # module
