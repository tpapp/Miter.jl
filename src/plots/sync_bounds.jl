#####
##### syncing plot boundaries
#####

export Invisible, sync_bounds

####
#### Invisible
####

struct Invisible
    x::CoordinateBounds
    y::CoordinateBounds
    @doc """
    $(SIGNATURES)

    Create an invisible object with the sole function of extending coordinate bounds to
    `x, y`, which should be `Interval`s or `nothing`.

    You can also use `Invisible(bounds_xy(object)...)` to extend bounds to those in `object`,
    or `Invisible(bounds_xy(object)[1], nothing)` to extend only the `x` axes, etc.
    """
    function Invisible(x::CoordinateBounds, y::CoordinateBounds)
        new(x, y)
    end
end

bounds_xy(invisible::Invisible) = (invisible.x, invisible.y)

PGF.render(sink::PGF.Sink, drawing_area::DrawingArea, ::Invisible) = nothing

####
#### sync_bounds
####

"""
$(SIGNATURES)

Add an `Invisible(xy)` to each plot in `itr`. Internal helper function.
"""
function _add_invisible(x::CoordinateBounds, y::CoordinateBounds, itr)
    invisible = Invisible(x, y)
    map(x -> x ≡ nothing ? x : @insert(last(x.contents) = invisible), itr)
end

"""
$(SIGNATURES)

Make sure that axis bounds are the same for axes as determined
by `tag` (see below).

Tag can be given in the form of `Val(tag)` too, this is a convenience wrapper.

Possible tags:

- `:X`, `:Y`, `:XY`: make the specified axes in *all* items of the collection the same

- `:x`, `:y`, `:xy`: make x/y axes the same in plots that are in the same column/row, only works for

`:x`, `:y`, and `:xy` only work for matrix-like arguments.

All methods return the (modified) first argument.

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
@inline function sync_bounds(tag::Symbol, collection)
    @argcheck tag ∈ (:x, :y, :xy, :X, :Y, :XY)
    sync_bounds(Val(tag), collection)
end

sync_bounds(tag::Val) = Base.Fix1(sync_bounds, tag)

@inline sync_bounds(tag::Symbol) = sync_bounds(Val(tag))

function sync_bounds(tag::Val{:X}, collection)
    # vectors are treated like 1×N matrices, x axes are synced
    xb, _ = bounds_xy(collection)
    _add_invisible(xb, nothing, collection)
end

function sync_bounds(tag::Val{:Y}, collection)
    _, yb = bounds_xy(collection)
    _add_invisible(nothing, yb, collection)
end

sync_bounds(tag::Val{:XY}, collection) = _add_invisible(bounds_xy(collection)..., collection)

function sync_bounds(tag::Union{Val{:x},Val{:y},Val{:xy}}, collection::T) where T
    if Base.IteratorSize(T) == Base.HasShape{2}()
        sync_bounds(tag, collect(collection))
    else
        throw(ArgumentError("Tag $(tag) only works for matrix-like arguments."))
    end
end

function sync_bounds(::Val{:x}, m::AbstractMatrix)
    mapreduce(row -> permutedims(sync_bounds(Val(:X), row)), vcat, eachrow(m))
end

function sync_bounds(::Val{:y}, m::AbstractMatrix)
    mapreduce(col -> sync_bounds(Val(:Y), col), hcat, eachcol(m))
end

sync_bounds(::Val{:xy}, m::AbstractMatrix) = sync_bounds(Val(:x), sync_bounds(Val(:y), m))
