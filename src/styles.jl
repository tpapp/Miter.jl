#####
##### options and defaults
#####

module Styles

# reexported as API
export DEFAULTS, LINE_SOLID, LINE_DASHED

using ColorTypes: RGB, Gray
using DocStringExtensions: SIGNATURES
using ..Lengths: mm, Length
using ..DrawTypes

const LINE_SOLID = Dash()

const LINE_DASHED = Dash(2mm, 2mm)

"""

Documentation for fields:


"""
Base.@kwdef mutable struct Options
    # canvas
    canvas_width::Length = 100mm
    canvas_height::Length = 80mm

    # tick format
    tick_format_max_exponent::Int = 5
    tick_format_min_exponent::Int = -5
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
    axis_style_line_width::Length = 0.1mm
    axis_style_line_color::COLOR = Gray(0.0)
    axis_style_line_gap::Length = 2.0mm
    axis_style_tick_length::Length = 2.0mm
    axis_style_tick_label_gap::Length = 1.5mm
    axis_style_axis_label_gap::Length = 2mm

    # plot style
    plot_style_axis_left::Length = 20mm
    plot_style_axis_bottom::Length = 15mm
    plot_style_margin_right::Length = 5mm
    plot_style_margin_top::Length = 7mm

    # elements
    line_width::Length = 0.3mm
    line_color::COLOR = Gray(0.0)
    fill_color::COLOR = Gray(0.6)

    # guidelines
    "width for guidelines"
    guide_width::Length = 0.15mm
    "color for guidelines"
    guide_color::COLOR = Gray(0.5)
    "dash for guidelines"
    guide_dash::Dash = LINE_DASHED

    # grid lines
    "width for gridlines"
    grid_width::Length = 0.1mm
    "color for gridlines"
    grid_color::COLOR = Gray(0.75)
    "dash for gridlines"
    grid_dash::Dash = LINE_SOLID

    # bars stroke color
    bars_stroke_color::COLOR = Gray(1.0)

    # mark options
    mark_size::Length = 2mm
    mark_symbol::Symbol = :+
end

"""
Default options.

The supported API is `getproperty` and `setproperty`, the fact that it is currently a
`struct` should not matter outside this package.
"""
const DEFAULTS = Options()

end
