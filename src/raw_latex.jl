"Passing raw LaTeX output."
module RawLaTeX

export @math_str, @latex_str, LaTeX # reexported

using Automa
using DocStringExtensions: SIGNATURES

####
#### basic LaTeX checks
####

@enum LaTeXToken error CHAR MATHMODE COMMAND LEFT_CURLY RIGHT_CURLY

LaTeX_tokens = [
    CHAR => re".",
    MATHMODE => re"$",
    COMMAND => re"\\[a-zA-Z]+" | re"\\.",
    LEFT_CURLY => re"{",
    RIGHT_CURLY => re"}",
]

make_tokenizer((error, LaTeX_tokens)) |> eval

function check_latex_msg(escaped_str)
    flag_mathmode::Bool = false
    count_curly::Int = 0
    for (_, _, token) in tokenize(LaTeXToken, escaped_str)
        if token == MATHMODE
            flag_mathmode = !flag_mathmode
        elseif token == LEFT_CURLY
            count_curly += 1
        elseif token == RIGHT_CURLY
            count_curly -= 1
        end
    end
    if flag_mathmode
        "Math mode not closed (missing '\$')."
    elseif count_curly > 0
        "$(count_curly) too many opening curly braces ('{')"
    elseif count_curly < 0
        "$(-count_curly) too many closing curly braces ('}')"
    else
        nothing
    end
end

"""
$(SIGNATURES)

Perform some superficial checks on the argument as LaTeX code. If there is a problem,
throw an error, with a descriptive message.
"""
function check_latex(escaped_str)
    msg = check_latex_msg(escaped_str)
    msg ≢ nothing && throw(ArgumentError(msg))
    nothing
end

####
#### wrappers and printing
####

# NOTE: we don't make this <: AbstracString, as it is only used as a wrapped, and only within
# this package, as an input.
struct LaTeX
    latex::String
    skip_check::Bool
    @doc """
    $(SIGNATURES)

    A wrapper that allows its contents to be passed to LaTeX directly.

    It is the responsibility of the user to ensure that this is valid LaTeX code within the
    document. Nevertheless, when `skip_check = false` (the default), some very basic checks
    may be performed when writing the final output to catch *some* errors (eg unbalanced
    math mode, mismatch curly braces), but these *do not guarantee valid LaTeX code*.

    The string literals `latex` and `math` provide a convenient way to enter raw
    strings, with `math` wrapping its input in `\$`s.

    ```jldoctest
    julia> latex"\\cos(\\phi)"
    LaTeX{String}("\\cos(\\phi)")

    julia> math"\\cos(\\phi)"
    LaTeX{String}("\$\\\\cos(\\\\phi)\$")
    ```

    The type supports concatenation with `*`, just ensure that the first argument is of
    this type (can be empty).
    """
    function LaTeX(latex::AbstractString; skip_check::Bool = false)
        if !(latex isa String)
            latex = convert(String, latex)
        end
        new(latex, skip_check)
    end
end

skip_check(::AbstractString) = false

skip_check(str::LaTeX) = str.skip_check

"""
$(SIGNATURES)

Put \$'s around the string, and wrap in `LaTeX`, to pass directly.
"""
math(str::AbstractString) = LaTeX("\$" * str * "\$")

"""
$(SIGNATURES)

Enclose `str` in `\$`s and indicate that it is to be treated as (valid, self-contained) LaTeX
code.
"""
macro math_str(str)
    math(str)
end

"""
$(SIGNATURES)

Indicate the argument is to be treated as (valid, self-contained) LaTeX code.
"""
macro latex_str(str)
    LaTeX(str)
end

function print_escaped(io::IO, str::LaTeX, check)
    (; skip_check, latex) = str
    if check && !skip_check
        check_latex(latex)
    end
    print(io, latex)
end

"""
$(SIGNATURES)

Outputs a version of `str` to `io` so that special characters (in LaTeX) are escaped to
produce the expected output.
"""
function print_escaped(io::IO, str::AbstractString, check)
    # NOTE: check is ignored, it is always valid output
    for c in str
        if c == '\\'
            print(io, raw"\textbackslash{}")
        elseif c == '~'
            print(io, raw"\textasciitilde{}")
        elseif c == '^'
            print(io, raw"\textasciicircum{}")
        else
            c ∈ raw"#$%&_{}" && print(io, '\\')
            print(io, c)
        end
    end
end

print_escaped(io::IO, x, check) = print_escaped(io, string(x), check)

function Base.:(*)(str1::LaTeX, str_rest...)
    io = IOBuffer()
    _skip_check = true
    for str in (str1, str_rest...)
        if str isa LaTeX
            _skip_check |= skip_check(str)
        end
        print_escaped(io, str, false)
    end
    LaTeX(String(take!(io)); skip_check = _skip_check)
end

"String types we can use with [`text`](@ref)."
const STRINGS = Union{AbstractString,LaTeX}

end
