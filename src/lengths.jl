#####
##### specification of lengths
#####

module Lengths

using ArgCheck: @argcheck

export mm, cm, inch, pt

struct Length
    scale::Float64
    unit::Symbol
    function Length(scale::Float64, unit::Symbol)
        @argcheck isfinite(scale)
        @argcheck unit ∈ (:mm, :inch, :pt)
        new(scale, unit)
    end
end

Length(scale::Real, unit::Symbol) = Length(Float64(scale), unit)

const mm = Length(1.0, :mm)
const cm = Length(10.0, :mm)
const inch = Length(1.0, :inch)
const pt = Length(1.0, :pt)

function Base.show(io::IO, l::Length)
    (; scale, unit) = l
    print(io, scale, unit)
end

function Base.:(/)(A::Length, B::Length)
    r = A.scale / B.scale
    @argcheck isfinite(r) "Non-finite unit ratio"
    au = A.unit
    bu = B.unit
    INCH2MM = 25.4
    INCH2PT = 72.0
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

Base.:(*)(l::Length, v::Real) = Length(l.scale * v, l.unit)

Base.:(*)(v::Real, l::Length) = l * v

function Base.:(+)(ls::Length...)
    if allequal(x -> x.unit, ls)
        Length(mapreduce(x -> x.scale, +, ls), first(ls).unit)
    else
        Length(mapreduce(x -> x / mm, +, ls), :mm)
    end
end

Base.:(-)(l::Length) = Length(-l.scale, l.unit)

Base.:(-)(l1::Length, l2::Length) = l1 + (-l2)

end
