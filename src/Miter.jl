"""
A Julia plotting package using the PGF Basic Layer Core.
"""
module Miter

include("internal_utilities.jl")
include("compile.jl")
include("pgf.jl")
include("intervals.jl")
include("styles.jl")
include("ticks.jl")
include("axis.jl")
include("output.jl")
include("marks.jl")
include("plots.jl")
include("utilities.jl")

####
#### exported API
####

using Reexport: @reexport

@reexport using .PGF
@reexport using .Output
@reexport using .Axis
@reexport using .Marks
@reexport using .Plots
@reexport using .Styles
@reexport using .Utilities

# reexport single symbols

@reexport using .Intervals: Interval

# modules that prefix symbols

export Axis

# symbols meant to be used with a Miter. prefix

using .Output: save
using .Utilities: dummy

end # module
