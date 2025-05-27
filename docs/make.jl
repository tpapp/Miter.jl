# see documentation at https://juliadocs.github.io/Documenter.jl/stable/

using Documenter, Miter, Colors

DocMeta.setdocmeta!(Miter, :DocTestSetup, :(using Miter); recursive=true)

makedocs(
    modules = [Miter],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true",
                             assets = ["assets/custom.css"]),
    authors = "Tamás K. Papp",
    sitename = "Miter.jl",
    pages = Any["index.md"],
    # strict = true,
    clean = true,
    warnonly = true,
    # checkdocs = :exports,
)

# Some setup is needed for documentation deployment, see “Hosting Documentation” and
# deploydocs() in the Documenter manual for more information.
deploydocs(
    repo = "github.com/tpapp/Miter.jl.git",
    push_preview = true
)
