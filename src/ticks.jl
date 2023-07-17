"""
Tick placement and formatting.

# Design notes

This is a very opinionated and heuristic algorithm for tick placements, focusing on powers
of 10 multiplies by 1, 2, or 5. Other tick arrangements, such as multiples of 3 offset by 7
etc are considered exotic and avoided on purpose.
"""
module Ticks

export nontrivial_linear_ticks, TickSelection, TickFormat, sensible_linear_ticks

using ArgCheck: @argcheck
using DocStringExtensions: SIGNATURES
using ..Intervals

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
        m - 1, n - r
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
$(SIGNATURES)

A heuristic algorithm for choosing linear ticks inside `[a, b]`, with `a < b`.

Return a vector of `(significands = c:k:d, exponent = e)`, where `e` is the exponent, and
`significands` is a `StepRange{Int,Int}` to be adjusted by the exponent.

`log10_widening` determines the division with the most ticks, which are then thinned step by
step.

!!! NOTE
    Any `a < b` is accepted, but the algorithm is not designed to give good results for `a ≈
    b`. You may want to use a different method for that.
"""
function nontrivial_linear_ticks(interval::Interval{<:Real}; log10_widening::Int = 1)
    is_nontrivial(x) = length(x) ≥ 2
    (; min, max) = interval
    Δ = max - min
    @argcheck Δ > 0 "Use an interval with positive length."
    @argcheck log10_widening ≥ 1
    e1 = floor(Int, log10(Δ) - log10_widening)
    E1 = exp10(e1)
    min1 = floor(Int, min / E1)
    max1 = ceil(Int, max / E1)
    ticks1 = min1:1:max1
    ticks = [(significands = ticks1, exponent = e1)]
    while is_nontrivial(ticks1)
        ticks2 = thin_ticks(ticks1, 2)
        is_nontrivial(ticks2) && push!(ticks, (significands = ticks2, exponent = e1))
        ticks5 = thin_ticks(ticks1, 5)
        is_nontrivial(ticks5) && push!(ticks, (significands = ticks5, exponent = e1))
        e1 += 1
        ticks1 = compress_ticks(ticks1, 10)
        is_nontrivial(ticks1) && push!(ticks, (significands = ticks1, exponent = e1))
    end
    ticks
end

wrap_math(str::AbstractString) = raw"$" * str * raw"$"

"""
$(SIGNATURES)

`significand * exp10(exponent)` as a string, using an exact representation.
"""
function format_shifted(significand::Int, exponent::Int)
    io = IOBuffer()
    print(io, significand)
    if exponent > 0 && significand ≠ 0 # print trailing zeros
        for _ in 1:exponent
            print(io, '0')
        end
    end
    v = take!(io)
    if exponent < 0
        D = UInt8('.')
        Z = UInt8('0')
        Δ = exponent + length(v) # decimal dot should follow this index
        if Δ > 0                 # insert a decimal dot after
            insert!(v, Δ + 1, D)
        else
            prepend!(v, Z for _ in 1:(-Δ))
            pushfirst!(v, D)
            pushfirst!(v, Z)
        end
    end
    String(v)
end

Base.@kwdef struct TickFormat
    max_exponent::Int = 3
    min_exponent::Int = -3
    thousands::Bool = false
    single_tick_sigdigits::Int = 3
end

function format_ticks(significands, exponent, tick_format)
    (; max_exponent, min_exponent, thousands) = tick_format
    l = if min_exponent ≤ exponent ≤ max_exponent
        map(s -> wrap_math(format_shifted(s, exponent)), significands)
    else
        if thousands
            Δ = closest_multiple(exponent, 3, true)[2]
            e = exponent - Δ
        else
            Δ = exponent
            e = 0
        end
        tag = raw" \times 10^{" * string(Δ) * "}"
        map(s -> wrap_math(format_shifted(s, e) * tag), significands)
    end
end

Base.@kwdef struct TickSelection
    log10_widening::Int = 1
    target_count::Int = 7
    label_penalty::Float64 = 0.1
    twos_penalty::Float64 = 0.0
    fives_penalty::Float64 = 0.0
end

function select_ticks(significand_exponent_formatted, tick_selection::TickSelection)
    (; target_count, label_penalty, twos_penalty, fives_penalty) = tick_selection
    function _score((significand, exponent, formatted))
        score = 1.0 * abs2(length(significand) - target_count) +
            sum(length, formatted) * label_penalty
        k = step(significand)
        if k == 2
            score += twos_penalty
        elseif k == 5
            score += fives_penalty
        end
        score
    end
    (_, index) = findmin(_score, significand_exponent_formatted)
    significand_exponent_formatted[index]
end

"""
$(SIGNATURES)
"""
function sensible_linear_ticks(interval::Interval{<:Real}, tick_format::TickFormat,
                               tick_selection::TickSelection)
    if is_nonzero(interval)
        ticks = nontrivial_linear_ticks(interval; tick_selection.log10_widening)
        formatted_ticks = map(((s, e),) -> (s, e, format_ticks(s, e, tick_format)), ticks)
        significand, exponent, formatted = select_ticks(formatted_ticks, tick_selection)
        E = exp10(exponent)
        map((s, f) -> s * E => f, significand, formatted)
    else
        # note formatting here is really a heuristic, eg it cannot deal with Date, fix latex
        t = round(interval.min, sigdigits = tick_format.single_tick_sigdigits)
        [t => wrap_math(string(t))]
    end
end

end
