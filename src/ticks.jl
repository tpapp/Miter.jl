"""
Tick placement and formatting.

# Design notes

This is a very opinionated and heuristic algorithm for tick placements, focusing on powers
of 10 multiplies by 1, 2, or 5. Other tick arrangements, such as multiples of 3 offset by 7
etc are considered exotic and avoided on purpose.
"""
module Ticks

export nontrivial_linear_tick_alternatives, TickSelection, TickFormat, sensible_linear_ticks

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES

using ..Intervals
using ..Styles: DEFAULTS
using ..PGF
using LaTeXEscapes: wrap_math, LaTeX

"""
$(SIGNATURES)

When `down == true` (`false`), find the largest (smallest) number
`z = m * k ≤ n` (`≥ n`) for an integer `m`, returning `m, z`.
"""
function closest_multiple(n::Integer, k::Integer, down::Bool)
    m, r = fldmod(n, k)
    if r == 0
        m, n
    elseif down
        m, n - r
    else
        m + 1, n - r + k
    end
end

"""
$(SIGNATURES)

“Thin” a range to a new stepsize `k`, adjusing the endpoints inwards.
"""
function thin_ticks(range::StepRange, k::Integer)
    @argcheck k > 1
    _, a = closest_multiple(minimum(range), k, false)
    _, b = closest_multiple(maximum(range), k, true)
    a:k:b
end

"""
$(SIGNATURES)

“Compress” a range by dividing the endpoints by `k`, adjusting inwards. The newstepsize is
`1`.
"""
function compress_ticks(range::StepRange, k::Integer)
    @argcheck k ≥ 1
    a, _ = closest_multiple(minimum(range), k, false)
    b, _ = closest_multiple(maximum(range), k, true)
    a:1:b
end

"""
A representation of ``s ⋅ 10^e``, where `s = significant * 10^inner_exponent` and `e` is the
`outer_exponent`.
"""
struct ShiftedDecimal
    significand::Int
    inner_exponent::Int
    outer_exponent::Int
end

"""
$(SIGNATURES)

Show the sign, digits, and decimal dot of the mantissa (ie everything without the outer
exponent).
"""
function show_mantissa(io::IO, sd::ShiftedDecimal)
    (; significand, inner_exponent) = sd
    # sign
    significand < 0 && print(io, '-')
    # zeros and decimal dot before
    Δ = 0                        # print a dot after this character
    v = string(abs(significand)) # mantissa string representation
    if inner_exponent < 0
        Δ = inner_exponent + length(v) # decimal dot should follow this index
        if Δ ≤ 0                 # insert a decimal dot after
            print(io, "0.")
            for _ in 1:(-Δ)
                print(io, '0')
            end
        end
    end
    # mantissa
    for (i, c) in enumerate(v)
        print(io, c)
        i == Δ && print(io, '.')
    end
    # trailing zeros
    if inner_exponent > 0 && significand ≠ 0
        for _ in 1:inner_exponent
            print(io, '0')
        end
    end
    nothing
end

"""
$(SIGNATURES)

Convert a representation to a coordinate. Does not need to be exact, `Float64` precision is
sufficient.
"""
function coordinate(sd::ShiftedDecimal)
    exponent = sd.inner_exponent + sd.outer_exponent
    # NOTE branch for 6 / 10 == 0.6 etc
    exponent ≥ 0 ? sd.significand * exp10(exponent) : sd.significand / exp10(-exponent)
end

function Base.show(io::IO, ::MIME"text/plain", sd::ShiftedDecimal)
    (; significand, outer_exponent) = sd
    show_mantissa(io, sd)
    significand ≠ 0 && outer_exponent ≠ 0 && print(io, "e", outer_exponent)
end

function format_latex(sd::ShiftedDecimal)
    (; significand, outer_exponent) = sd
    io = IOBuffer()
    print(io, '$')
    show_mantissa(io, sd)
    significand ≠ 0 && outer_exponent ≠ 0 && print(io, raw"\cdot 10^{", outer_exponent, "}")
    print(io, '$')
    LaTeX(String(take!(io)))
end

"""
A vector of [`ShiftedDecimal`s](@ref).
"""
struct ShiftedDecimals <: AbstractVector{ShiftedDecimal}
    significands::StepRange{Int,Int}
    inner_exponent::Int
    outer_exponent::Int
end

ShiftedDecimals(significand, inner_exponent) = ShiftedDecimals(significand, inner_exponent, 0)

Base.size(sd::ShiftedDecimals) = (length(sd.significands), )

function Base.getindex(sd::ShiftedDecimals, i::Int)
    ShiftedDecimal(sd.significands[i], sd.inner_exponent, sd.outer_exponent)
end

"""
$(SIGNATURES)

Change the inner exponent by `-Δ` and the outer by `Δ`.
"""
function inner_to_outer(sd::ShiftedDecimals, Δ)
    ShiftedDecimals(sd.significands, sd.inner_exponent - Δ, sd.outer_exponent + Δ)
end

"""
$(SIGNATURES)

A heuristic algorithm for choosing linear ticks inside `[a, b]`, with `a < b`.

Return a vector of [`ShiftedDecimals`](@ref), representing various options. Caller should
select from these.

`log10_widening` determines the division with the most ticks, which are then thinned step by
step.

!!! NOTE
    Any `a < b` is accepted, but the algorithm is not designed to give good results for `a ≈
    b`. You may want to use a different method for that.
"""
function nontrivial_linear_tick_alternatives(interval::Interval{<:Real}; log10_widening::Int = 1)
    is_nontrivial(x) = length(x) ≥ 2
    (; min, max) = interval
    Δ = max - min
    @argcheck Δ > 0 "Use an interval with positive length."
    @argcheck log10_widening ≥ 1
    e1 = floor(Int, log10(Δ) - log10_widening)
    E1 = exp10(e1)
    min1 = ceil(Int, min / E1)
    max1 = floor(Int, max / E1)
    ticks1 = min1:1:max1
    ticks = [ShiftedDecimals(ticks1, e1)]
    while is_nontrivial(ticks1)
        ticks2 = thin_ticks(ticks1, 2)
        is_nontrivial(ticks2) && push!(ticks, ShiftedDecimals(ticks2, e1))
        ticks5 = thin_ticks(ticks1, 5)
        is_nontrivial(ticks5) && push!(ticks, ShiftedDecimals(ticks5, e1))
        e1 += 1
        ticks1 = compress_ticks(ticks1, 10)
        is_nontrivial(ticks1) && push!(ticks, ShiftedDecimals(ticks1, e1))
    end
    ticks
end

Base.@kwdef struct TickFormat
    max_exponent::Int = DEFAULTS.tick_format_max_exponent
    min_exponent::Int = DEFAULTS.tick_format_min_exponent
    thousands::Bool = DEFAULTS.tick_format_thousands
    single_tick_sigdigits::Int = DEFAULTS.tick_format_single_tick_sigdigits
end

"""
$(SIGNATURES)

Bring the inner exponent into the range permitted by `tick_format`, making sure that the
values are unchanged.
"""
function regularize_exponent(tick_format, sd::ShiftedDecimals)
    (; max_exponent, min_exponent, thousands) = tick_format
    (; inner_exponent) = sd
    if (min_exponent ≤ inner_exponent ≤ max_exponent)
        sd
    else
        if thousands
            Δ = closest_multiple(inner_exponent, 3, true)[2]
        else
            Δ = inner_exponent
        end
        inner_to_outer(sd, Δ)
    end
end

Base.@kwdef struct TickSelection
    log10_widening::Int = DEFAULTS.tick_selection_log10_widening
    target_count::Int = DEFAULTS.tick_selection_target_count
    label_penalty::Float64 = DEFAULTS.tick_selection_label_penalty
    twos_penalty::Float64 = DEFAULTS.tick_selection_twos_penalty
    fives_penalty::Float64 = DEFAULTS.tick_selection_fives_penalty
    exponent_penalty::Float64 = DEFAULTS.tick_selection_exponent_penalty
end

function ticks_penalty(tick_selection::TickSelection, sd::ShiftedDecimals)
    (; target_count, label_penalty, twos_penalty, fives_penalty, exponent_penalty) = tick_selection
    (; significands, inner_exponent, outer_exponent) = sd
    # NOTE taking length here is a shortcut as it is penalizes LaTeX commands like `\cdot`
    n = length(significands)
    score::Float64 = 1.0 * abs2(n - target_count)
    score += (abs(inner_exponent) + (outer_exponent ≠ 0) * exponent_penalty) * n * label_penalty
    k = step(significands)
    if k == 2
        score += twos_penalty
    elseif k == 5
        score += fives_penalty
    end
    score
end

"""
$(SIGNATURES)
"""
function sensible_linear_ticks(interval::Interval{<:Real}, tick_format::TickFormat,
                               tick_selection::TickSelection)
    if is_nonzero(interval)
        ticks_alternatives = map(t -> regularize_exponent(tick_format, t),
                                 nontrivial_linear_tick_alternatives(interval; tick_selection.log10_widening))
        _, ix = findmin(ticks -> ticks_penalty(tick_selection, ticks), ticks_alternatives)
        ticks = ticks_alternatives[ix]
        map(s -> coordinate(s) => format_latex(s), ticks)
    else
        # note formatting here is really a heuristic, eg it cannot deal with Date, fix later
        t = round(interval.min, sigdigits = tick_format.single_tick_sigdigits)
        [t => wrap_math(string(t))]
    end
end

end
