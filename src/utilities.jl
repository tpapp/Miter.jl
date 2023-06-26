####
#### various utilities
####

function fill_rectangle(io, rectangle::PGF.Rectangle, color)
    PGF.setfillcolor(io, color)
    PGF.path(io, rectangle)
    PGF.usepath(io, :fill)
end
