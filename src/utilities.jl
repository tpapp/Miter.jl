#####
##### various utilities
#####

"""
$(SIGNATURES)

Draw a filled rectangle with a given color. For visual debugging.
"""
function fill_rectangle(io, rectangle::PGF.Rectangle, color)
    PGF.setfillcolor(io, color)
    PGF.path(io, rectangle)
    PGF.usepath(io, :fill)
end
