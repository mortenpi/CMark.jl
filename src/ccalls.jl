# This file contains all the wrapper functions that expose the C API of the cmark
# or cmark-gfm shared libraries.
#
# Each takes a libcmark :: CMarkLibrary function as an argument, defaulting to
# libcmarkgfm.

"""
    struct CMarkLibrary{PATH}

Can be used to pass different `cmark` or `cmark-gfm` shared library products to the C calls.

It stores the full string of the path to the shared library as the type parameter `PATH`, so
that we could use the `ccall((:foo, PATH), ...)` syntax semi-dynamically, while still making
sure that the `PATH` is a compile-time constant and therefore that `ccall` is valid.
"""
struct CMarkLibrary{PATH} end
CMarkLibrary(path) = CMarkLibrary{Symbol(path)}()

function init!(::CMarkLibrary{PATH}) where PATH
    cmark_gfm_core_extensions_ensure_registered()
    exts = findsyntaxextension.(extensions)
    any(exts .== C_NULL) && error("Failed to load GFM extensions, $exts")

    # Not entirely sure about the RTLD_* options here, but I am borrowing them from the JLL
    # library.
    h = Libdl.dlopen(PATH, RTLD_LAZY | RTLD_DEEPBIND)
    CMARK_NODE_STRIKETHROUGH[] = unsafe_load(Ptr{Cint}(dlsym(h, :CMARK_NODE_STRIKETHROUGH)))
    CMARK_NODE_TABLE[] = unsafe_load(Ptr{Cint}(dlsym(h, :CMARK_NODE_TABLE)))
    CMARK_NODE_TABLE_ROW[] = unsafe_load(Ptr{Cint}(dlsym(h, :CMARK_NODE_TABLE_ROW)))
    CMARK_NODE_TABLE_CELL[] = unsafe_load(Ptr{Cint}(dlsym(h, :CMARK_NODE_TABLE_CELL)))
end

"""
    const libcmarkgfm :: CMarkLibrary

Default [`CMarkLibrary`](@ref) instance, pointing to the cmark-gfm library JLL that is a
binary dependency of this package.
"""
const libcmarkgfm = CMarkLibrary(cmark_gfm_jll.libcmark_gfm_extensions)

"""
    @cmarkapi <cmark ccall wrapper definition>

A decorator that defines an extra method for the `libcmark` library wrappers that uses the
default shared library ([`libcmarkgfm`](@ref)).

The functions are expected to be defined with the signature

```julia
function cmark_fn(::CMarkLibrary{PATH}, args...; kwargs...) where PATH
    ...
end
```

for some value of `args` and `kwargs`. The macro then defines an additional method with
the signature

```julia
cmark_fn(args...; kwargs...) = cmark_fn(libcmarkgfm, args...; kwargs...)
```
"""
macro cmarkapi(expr)
    # The expression should be a function definition that looks something like
    #
    #   function cmark_fn(::CMarkLibrary{PATH}, args...) where PATH ... end
    #
    # This leads to the AST that looks something like:
    #
    # (:function, [
    #     (:where, [
    #         (:call, [
    #             :cmark_fn,
    #             ::CMarkLibrary{PATH},
    #             args...
    #         ]),
    #         :PATH
    #     ]),
    #     <function body>
    # ])
    #
    # The only thing we really need is to extract the function name:
    @assert expr.head === :function
    @assert expr.args[1].head === :where
    @assert expr.args[1].args[1].head === :call
    @assert expr.args[1].args[1].args[1] isa Symbol
    fn_name = expr.args[1].args[1].args[1]
    quote
        $(esc(expr))
        function $(esc(fn_name))(args...; kwargs...)
            $(esc(fn_name))($(esc(:libcmarkgfm)), args...; kwargs...)
        end
    end
end
