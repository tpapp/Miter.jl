"""
A Julia plotting package using the PGF Basic Layer Core.
"""
module Miter

using ArgCheck: @argcheck
using ColorTypes: AbstractRGB, red, green, blue, RGB
using DocStringExtensions: SIGNATURES, TYPEDEF
using tectonic_jll: tectonic
using Unitful: Unitful, uconvert, Length, inch
using UnPack: @unpack

include("compile.jl")
include("primitives.jl")
include("tex_output.jl")
include("plotarea.jl")


end # module
