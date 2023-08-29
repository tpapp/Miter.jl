#####
##### options and defaults
#####

module Styles

using ColorTypes: RGB
using DocStringExtensions: SIGNATURES
using Unitful: mm

using ..PGF: LENGTH, PGF

"""

Documentation for fields:


"""
Base.@kwdef mutable struct Options
    # canvas
    canvas_width::LENGTH = 100mm
    canvas_height::LENGTH = 80mm

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
    tick_selection_exponent_penalty::Float64 = 3.0

    # axis style
    axis_style_line_width::LENGTH = 0.1mm
    axis_style_line_gap::LENGTH = 2.0mm
    axis_style_tick_length::LENGTH = 2.0mm
    axis_style_tick_label_gap::LENGTH = 1.5mm
    axis_style_axis_label_gap::LENGTH = 2mm

    # plot style
    plot_style_axis_left::LENGTH = 20mm
    plot_style_axis_bottom::LENGTH = 15mm
    plot_style_margin_right::LENGTH = 5mm
    plot_style_margin_top::LENGTH = 5mm

    # elements
    line_width::LENGTH = 0.3mm
    line_color::RGB = PGF.BLACK

end

"""
Default options.

The supported API is `getproperty` and `setproperty`, the fact that it is currently a
`struct` should not matter outside this package.
"""
const DEFAULTS = Options()

"""
$(SIGNATURES)

Helper function to set line style parameters (when `≢ nothing`).
"""
function set_line_style(sink::PGF.Sink; color = nothing, width = nothing, dash = nothing)
    color ≢ nothing && PGF.setstrokecolor(sink, color)
    width ≢ nothing && PGF.setlinewidth(sink, width)
    dash ≢ nothing && PGF.setdash(sink, dash)
end

const LINE_SOLID = PGF.Dash()

const LINE_DASHED = PGF.Dash(2mm, 2mm)

end