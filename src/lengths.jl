#####
##### specification of lengths
#####

"""
This module defines `Length`, a container for lengths.

The preferred way to construct `Length`s is using the exported constants `mm`, `inch`,
and `pt`, eg `100mm` (`cm == 10mm` is provided for convenience). An effort is made to
preserve the original unit with arithmetic operators `*`, `/`, `+`, `-` when it makes
sense, otherwise conversion is to `mm`.

Comparisons with `>`, `≥`, `==` are supported.

`/` should be used to obtain the dimensionless length, eg `1inch/mm == 25.4`.

!!! NOTE
    `pt` is what TeX calls `bp`, 1/72 inch.
"""
module Lengths

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES

export mm, cm, inch, pt

struct Length
    scale::Float64
    unit::Symbol
    @doc """
    $(SIGNATURES)

    Construct a length with the given unit, which can be one of `:mm`, `:inch`, `:pt`.

    Note that the preferred constructor is using the constants `mm` (`cm`), `inch`, and
    `pt`, eg `100mm`.
    """
    function Length(scale::Float64, unit::Symbol)
        @argcheck isfinite(scale)
        @argcheck unit ∈ (:mm, :inch, :pt)
        new(scale, unit)
    end
end

Length(scale::Real, unit::Symbol) = Length(Float64(scale), unit)

"One millimeter."
const mm = Length(1.0, :mm)

"One centimeter."
const cm = Length(10.0, :mm)

"One inch."
const inch = Length(1.0, :inch)

"One point (Postscript, CSS). TeX calls this unit “bp”."
const pt = Length(1.0, :pt)

function Base.show(io::IO, l::Length)
    (; scale, unit) = l
    print(io, scale, unit)
end

Base.:(*)(l::Length, v::Real) = Length(l.scale * v, l.unit)

Base.:(*)(v::Real, l::Length) = l * v

Base.:(/)(l::Length, v::Real) = Length(l.scale / v, l.unit)

const INCH2MM = 25.4
const INCH2PT = 72.0            # note that this is the BP unit in LaTeX

function Base.:(/)(A::Length, B::Length)
    r = A.scale / B.scale
    @argcheck isfinite(r) "Non-finite unit ratio"
    au = A.unit
    bu = B.unit
    if au ≡ bu
        r
    elseif au ≡ :mm && bu ≡ :inch
        r / INCH2MM
    elseif au ≡ :inch && bu ≡ :mm
        r * INCH2MM
    elseif au ≡ :pt && bu ≡ :inch
        r / INCH2PT
    elseif au ≡ :inch && bu ≡ :pt
        r * INCH2PT
    elseif au ≡ :mm && bu ≡ :pt
        r * INCH2PT / INCH2MM
    elseif au ≡ :pt && bu ≡ :mm
        r * INCH2MM / INCH2PT
    else
        # NOTE this should not happen
        error("internal error dividing $(au) by $(bu)")
    end
end

function Base.:(+)(ls::Length...)
    if allequal(x -> x.unit, ls)
        Length(mapreduce(x -> x.scale, +, ls), first(ls).unit)
    else
        Length(mapreduce(x -> x / mm, +, ls), :mm)
    end
end

Base.:(-)(l::Length) = Length(-l.scale, l.unit)

Base.:(-)(l1::Length, l2::Length) = l1 + (-l2)

"""
$(SIGNATURES)

The scales of the two lengths in the same unit (the unit of the first one). For comparisons.
"""
function _scale_in_same_unit(l1::Length, l2::Length)
    if l1.unit ≡ l2.unit
        l1.scale, l2.scale
    else
        l1.scale, (l2 / Length(1.00, l1.unit))
    end
end

Base.:(≤)(l1::Length, l2::Length) = ≤(_scale_in_same_unit(l1, l2)...)
Base.:(==)(l1::Length, l2::Length) = ==(_scale_in_same_unit(l1, l2)...)
Base.:(<)(l1::Length, l2::Length) = <(_scale_in_same_unit(l1, l2)...)

end
