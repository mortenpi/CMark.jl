module CMark

const libcmark = joinpath(@__DIR__, "..", "deps", "libcmark.so")

const CMARK_OPT_DEFAULT = 0

function cmark_version()
    ccall((:cmark_version, libcmark), Cint, ()) |> Int
end

function cmark_version_string()
    s = ccall((:cmark_version_string, libcmark), Cstring, ())
    unsafe_string(s)
end

end # module
