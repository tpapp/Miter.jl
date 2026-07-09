#####
##### syncing plot boundaries
#####

export JustBounds, sync_bounds

using ..Coordinates: CoordinateBounds

####
#### JustBounds
####

struct JustBounds
    x::CoordinateBounds
    y::CoordinateBounds
    @doc """
    $(SIGNATURES)

    Create an invisible object with the sole function of extending coordinate bounds to
    `x, y`, which should be `Interval`s or `nothing`.

    You can also use `JustBounds(bounds_xy(object)...)` to extend bounds to those in `object`,
    or `JustBounds(bounds_xy(object)[1], nothing)` to extend only the `x` axes, etc.

    Use [`Interval`](@ref) with a high `level` to force bounds, eg
    ```julia
    JustBounds(Interval(-1,1; level = 10), Interval(0, 1; level = 10))
    ```
    """
    function JustBounds(x::CoordinateBounds, y::CoordinateBounds)
        new(x, y)
    end
end

Coordinates.bounds_xy(invisible::JustBounds) = (invisible.x, invisible.y)

Draw.render(sink::Draw.Sink, drawing_area::DrawingArea, ::JustBounds) = nothing

####
#### sync_bounds
####

"""
$(SIGNATURES)

Add an `JustBounds(xy)` to each plot in `itr`. Internal helper function.
"""
function _add_invisible(x::CoordinateBounds, y::CoordinateBounds, itr)
    invisible = JustBounds(x, y)
    map(x -> x ≡ nothing ? x : @insert(last(x.contents) = invisible), itr)
end

"""
Types that the low-level [`sync_bounds`](@ref) can deal with. Internal, for organizing
the implementation.
"""
const _SYNCABLE = Union{AbstractVector,AbstractMatrix}

"""
$(SIGNATURES)

Make sure that axis bounds are the same for axes as determined
by `tag` (see below).

Possible tags:

- `:X`, `:Y`, `:XY`: make the specified axes in *all* items of the collection the same

- `:x`, `:y`, `:xy`: make x/y axes the same in plots that are in the same column/row, only works for

`:x`, `:y`, and `:xy` only work for matrix-like arguments.

All methods return the modified second argument, which can be an `AbstractMatrix`, a
`Tableau`, or an `::AbstractVector` (the last only for some tags). Iterables are
accepted, and collected first.

# Explanation

To illustrate the lowercase tags, consider the arrangement

```ascii
y/vertical axis
│
│ C  D
│ A  B
└────────x/horizontal axis
```
which could be entered as eg
```julia
t = Tableau([A C; B D])
```
Then `$(FUNCTIONNAME)(:x, t)` would ensure that A and C have the same bounds for the
x-axis, and similarly B and D.
"""
function sync_bounds(tag::Symbol, collection::_SYNCABLE)
    _sync_bounds(Val(tag), collection)
end

sync_bounds(tag::Symbol, itr) = sync_bounds(tag, collect(itr))

function sync_bounds(tag::Symbol, tableau::Tableau)
    (; contents, horizontal_divisions, vertical_divisions) = tableau
    Tableau(sync_bounds(tag, contents); horizontal_divisions, vertical_divisions)
end

sync_bounds(tag::Symbol) = Base.Fix1(sync_bounds, tag)

####
#### implementation
####

function _sync_bounds(tag::Val{:X}, collection::_SYNCABLE)
    # vectors are treated like 1×N matrices, x axes are synced
    xb, _ = bounds_xy(collection)
    _add_invisible(xb, nothing, collection)
end

function _sync_bounds(tag::Val{:Y}, collection::_SYNCABLE)
    _, yb = bounds_xy(collection)
    _add_invisible(nothing, yb, collection)
end

function _sync_bounds(tag::Val{:XY}, collection::_SYNCABLE)
    _add_invisible(bounds_xy(collection)..., collection)
end

function _sync_bounds(tag::Union{Val{:x},Val{:y},Val{:xy}}, collection::AbstractVector)
    throw(ArgumentError("Tag $(tag) only works for matrix-like arguments."))
end

function _sync_bounds(::Val{:x}, m::AbstractMatrix)
    mapreduce(row -> permutedims(_sync_bounds(Val(:X), row)), vcat, eachrow(m))
end

function _sync_bounds(::Val{:y}, m::AbstractMatrix)
    mapreduce(col -> _sync_bounds(Val(:Y), col), hcat, eachcol(m))
end

_sync_bounds(::Val{:xy}, m::AbstractMatrix) = _sync_bounds(Val(:x), _sync_bounds(Val(:y), m))
