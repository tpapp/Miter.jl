module MiterLaTeXStringsExt

import Miter
using LaTeXStrings: LaTeXString

function Miter.RawLaTeX.print_escaped(io::IO, str::LaTeXString, check)
    check && Miter.RawLaTeX.check_latex(str)
    write(io, str)
end

end
