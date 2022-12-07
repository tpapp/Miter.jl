"""
A Julia plotting package using the PGF Basic Layer Core.
"""
module Miter

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES, TYPEDEF
using Unitful: Unitful, uconvert, Length, inch
using UnPack: @unpack

include("lowlevel.jl")
include("plotarea.jl")

end # module
