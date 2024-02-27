module MiterLaTeXStringsExt

import Miter
using LaTeXStrings: LaTeXString

Miter.PGF._print_escaped(io::IO, str::LaTeXString) = write(io, str)

end
