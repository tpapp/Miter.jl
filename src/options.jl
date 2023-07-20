#####
##### options and defaults
#####

module Defaults

using ..PGF: LENGTH
using Unitful: mm

"""

Documentation for fields:


"""
Base.@kwdef mutable struct Options
    # tick format
    tick_format_max_exponent::Int = 3
    tick_format_min_exponent::Int = -3
    tick_format_thousands::Bool = false
    tick_format_single_tick_sigdigits::Int = 3

    # tick selection
    tick_selection_log10_widening::Int = 1
    tick_selection_target_count::Int = 7
    tick_selection_label_penalty::Float64 = 0.1
    tick_selection_twos_penalty::Float64 = 0.0
    tick_selection_fives_penalty::Float64 = 0.0

    # axis style
    axis_style_line_width::LENGTH = 0.3mm
    axis_style_line_gap::LENGTH = 2.0mm
    axis_style_tick_length::LENGTH = 2.0mm
    axis_style_label_gap::LENGTH = 1.5mm

    # plot style
    plot_style_axis_left::LENGTH = 20mm
    plot_style_axis_bottom::LENGTH = 20mm
    plot_style_margin_right::LENGTH = 10mm
    plot_style_margin_top::LENGTH = 10mm

end

"""
Default options.

The supported API is `getproperty` and `setproperty`, the fact that it is currently a
`struct` should not matter outside this package.
"""
const DEFAULTS = Options()

end
