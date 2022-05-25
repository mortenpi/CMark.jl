# This file contains all the wrapper functions that expose the C API of the cmark
# or cmark-gfm shared libraries.
#
# Each takes a libcmark :: CMarkLibrary function as an argument, defaulting to
# libcmarkgfm.

"""
    struct CMarkLibrary{LIBCM,LIBCMX}

Can be used to pass different `cmark` or `cmark-gfm` shared library products to the C calls.

It stores the full string paths to the shared libraries as type parameters. This way it is
possible to use the `ccall((:foo, LIBCM), ...)` syntax semi-dynamically, while still making
sure that the `LIBCM` is a compile-time constant and therefore that `ccall` is valid.

`LIBCM` is the path to the `libcmark` library, whereas the `LIBCMX` is the path to the
`libcmark-extensions` library, which can optionally be `nothing`, in which case extensions
are not allowed.
"""
struct CMarkLibrary{LIBCM,LIBCMX} end
function CMarkLibrary(libcmark::AbstractString, libcmark_extensions::Union{AbstractString,Nothing} = nothing)
    isfile(libcmark) || error("Invalid libcmark path: $(libcmark)")
    libcm = Symbol(libcmark)
    libcmx = if isnothing(libcmark_extensions)
        nothing
    else
        isfile(libcmark_extensions) || error("Invalid libcmark_extensions path: $(libcmark_extensions)")
        Symbol(libcmark_extensions)
    end
    CMarkLibrary{libcm,libcmx}()
end

function init!(libcmark::CMarkLibrary{LIBCM,LIBCMX}) where {LIBCM, LIBCMX}
    # If the extension shared library is not provided, we assume that there are no extensions.
    isnothing(LIBCMX) && return

    cmark_gfm_core_extensions_ensure_registered(libcmark)
    exts = findsyntaxextension.(extensions)
    any(exts .== C_NULL) && error("Failed to load GFM extensions, $exts")

    # Not entirely sure about the RTLD_* options here, but I am borrowing them from the JLL
    # library.
    h = Libdl.dlopen(LIBCMX, RTLD_LAZY | RTLD_DEEPBIND)
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
const libcmarkgfm = CMarkLibrary(
    cmark_gfm_jll.libcmark_gfm,
    cmark_gfm_jll.libcmark_gfm_extensions,
)

"""
    @cmarkapi <cmark ccall wrapper definition>

A decorator that defines an extra method for the `libcmark` library wrappers that uses the
default shared library ([`libcmarkgfm`](@ref)).

The functions are expected to be defined with the signature

```julia
function cmark_fn(::CMarkLibrary{LIBCM, LIBCMX}, args...; kwargs...) where {LIBCM, LIBCMX}
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
    #   function cmark_fn(::CMarkLibrary{LIBCM, LIBCMX}, args...) where {LIBCM, LIBCMX} ... end
    #
    # This leads to the AST that looks something like:
    #
    # (:function, [
    #     (:where, [
    #         (:call, [
    #             :cmark_fn,
    #             ::CMarkLibrary{LIBCM, LIBCMX},
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

# libcmark C API global constants:

const CMARK_OPT_DEFAULT = 0

# Node type enum for libcmark
# @enum cmark_node_type begin
#     # Error status
#     CMARK_NODE_NONE
#
#     # Block
#     CMARK_NODE_DOCUMENT
#     CMARK_NODE_BLOCK_QUOTE
#     CMARK_NODE_LIST
#     CMARK_NODE_ITEM
#     CMARK_NODE_CODE_BLOCK
#     CMARK_NODE_HTML_BLOCK
#     CMARK_NODE_CUSTOM_BLOCK
#     CMARK_NODE_PARAGRAPH
#     CMARK_NODE_HEADING
#     CMARK_NODE_THEMATIC_BREAK
#
#     # CMARK_NODE_FIRST_BLOCK = CMARK_NODE_DOCUMENT
#     # CMARK_NODE_LAST_BLOCK = CMARK_NODE_THEMATIC_BREAK
#
#     # Inline
#     CMARK_NODE_TEXT
#     CMARK_NODE_SOFTBREAK
#     CMARK_NODE_LINEBREAK
#     CMARK_NODE_CODE
#     CMARK_NODE_HTML_INLINE
#     CMARK_NODE_CUSTOM_INLINE
#     CMARK_NODE_EMPH
#     CMARK_NODE_STRONG
#     CMARK_NODE_LINK
#     CMARK_NODE_IMAGE
#
#     # CMARK_NODE_FIRST_INLINE = CMARK_NODE_TEXT
#     # CMARK_NODE_LAST_INLINE = CMARK_NODE_IMAGE
# end

# src/cmark-gfm.h:34:#define CMARK_NODE_TYPE_PRESENT (0x8000)
const CMARK_NODE_TYPE_PRESENT = 0x8000
# src/cmark-gfm.h:35:#define CMARK_NODE_TYPE_BLOCK (CMARK_NODE_TYPE_PRESENT | 0x0000)
const CMARK_NODE_TYPE_BLOCK = (CMARK_NODE_TYPE_PRESENT | 0x0000)
# src/cmark-gfm.h:36:#define CMARK_NODE_TYPE_INLINE (CMARK_NODE_TYPE_PRESENT | 0x4000)
const CMARK_NODE_TYPE_INLINE  = (CMARK_NODE_TYPE_PRESENT | 0x4000)

@enum cmark_node_type begin
    # Error status
    CMARK_NODE_NONE = 0x0000

    # Block
    CMARK_NODE_DOCUMENT       = CMARK_NODE_TYPE_BLOCK | 0x0001
    CMARK_NODE_BLOCK_QUOTE    = CMARK_NODE_TYPE_BLOCK | 0x0002
    CMARK_NODE_LIST           = CMARK_NODE_TYPE_BLOCK | 0x0003
    CMARK_NODE_ITEM           = CMARK_NODE_TYPE_BLOCK | 0x0004
    CMARK_NODE_CODE_BLOCK     = CMARK_NODE_TYPE_BLOCK | 0x0005
    CMARK_NODE_HTML_BLOCK     = CMARK_NODE_TYPE_BLOCK | 0x0006
    CMARK_NODE_CUSTOM_BLOCK   = CMARK_NODE_TYPE_BLOCK | 0x0007
    CMARK_NODE_PARAGRAPH      = CMARK_NODE_TYPE_BLOCK | 0x0008
    CMARK_NODE_HEADING        = CMARK_NODE_TYPE_BLOCK | 0x0009
    CMARK_NODE_THEMATIC_BREAK = CMARK_NODE_TYPE_BLOCK | 0x000a
    CMARK_NODE_FOOTNOTE_DEFINITION = CMARK_NODE_TYPE_BLOCK | 0x000b

    # Inline
    CMARK_NODE_TEXT          = CMARK_NODE_TYPE_INLINE | 0x0001
    CMARK_NODE_SOFTBREAK     = CMARK_NODE_TYPE_INLINE | 0x0002
    CMARK_NODE_LINEBREAK     = CMARK_NODE_TYPE_INLINE | 0x0003
    CMARK_NODE_CODE          = CMARK_NODE_TYPE_INLINE | 0x0004
    CMARK_NODE_HTML_INLINE   = CMARK_NODE_TYPE_INLINE | 0x0005
    CMARK_NODE_CUSTOM_INLINE = CMARK_NODE_TYPE_INLINE | 0x0006
    CMARK_NODE_EMPH          = CMARK_NODE_TYPE_INLINE | 0x0007
    CMARK_NODE_STRONG        = CMARK_NODE_TYPE_INLINE | 0x0008
    CMARK_NODE_LINK          = CMARK_NODE_TYPE_INLINE | 0x0009
    CMARK_NODE_IMAGE         = CMARK_NODE_TYPE_INLINE | 0x000a
    CMARK_NODE_FOOTNOTE_REFERENCE = CMARK_NODE_TYPE_INLINE | 0x000b
end
const CMARK_NODE_STRIKETHROUGH = Ref{Int32}(-1)
const CMARK_NODE_TABLE         = Ref{Int32}(-1)
const CMARK_NODE_TABLE_ROW     = Ref{Int32}(-1)
const CMARK_NODE_TABLE_CELL    = Ref{Int32}(-1)

@enum cmark_list_type begin
    CMARK_NO_LIST
    CMARK_BULLET_LIST
    CMARK_ORDERED_LIST
end

# typedef enum {
# CMARK_NO_DELIM,
# CMARK_PERIOD_DELIM,
# CMARK_PAREN_DELIM
# } cmark_delim_type;

# libcmark C function ccall wrappers:

"""
    cmark_version([::CMarkLibrary]) -> Int

Returns the version of the libcmark library as an integer (wrapping the `cmark_version`
function from `libcmark`).
"""
function cmark_version end
@cmarkapi function cmark_version(::CMarkLibrary{LIBCM,LIBCMX}) where {LIBCM, LIBCMX}
    version = ccall((:cmark_version, LIBCM), Cint, ())
    return Int(version)
end

"""
    cmark_version_string([::CMarkLibrary]) -> String

Returns the version of the libcmark library as a string (wrapping the `cmark_version_string`
function from `libcmark`).
"""
function cmark_version_string end
@cmarkapi function cmark_version_string(::CMarkLibrary{LIBCM,LIBCMX}) where {LIBCM, LIBCMX}
    s = ccall((:cmark_version_string, LIBCM), Cstring, ())
    return unsafe_string(s)
end

"""
    cmark_markdown_to_html([::CMarkLibrary{LIBCM,LIBCMX},] markdown::AbstractString) -> String

Wraps the `cmark_markdown_to_html` function from `libcmark`.
"""
function cmark_markdown_to_html end
@cmarkapi function cmark_markdown_to_html(::CMarkLibrary{LIBCM,LIBCMX}, markdown::AbstractString) where {LIBCM, LIBCMX}
    s = ccall(
        (:cmark_markdown_to_html, LIBCM),
        Cstring, (Cstring, Csize_t, Cint),
        markdown, length(markdown), CMARK_OPT_DEFAULT
    )
    return unsafe_string(s)
end

"""
    cmark_parse_document([::CMarkLibrary{LIBCM,LIBCMX},] markdown::AbstractString) -> Ptr{Cvoid}

Wraps the `cmark_parse_document` function from `libcmark`:

> `cmark_node *cmark_parse_document(const char *buffer, size_t len, int options)`
>
> Parse a CommonMark document in 'buffer' of length 'len'.
> Returns a pointer to a tree of nodes.  The memory allocated for
> the node tree should be released using 'cmark_node_free'
> when it is no longer needed.
"""
function cmark_parse_document end
@cmarkapi function cmark_parse_document(::CMarkLibrary{LIBCM,LIBCMX}, markdown::AbstractString) where {LIBCM, LIBCMX}
    ccall(
        (:cmark_parse_document, LIBCM),
        Ptr{Cvoid}, (Cstring, Csize_t, Cint),
        markdown, length(markdown), CMARK_OPT_DEFAULT
    )
end

"""
    cmark_node_get_type([::CMarkLibrary,] node::Ptr{Cvoid}) -> node_type::Cint

Wraps `cmark_node_get_type` from `libcmark`:

> `cmark_node_type cmark_node_get_type(cmark_node *node)`
>
> Returns the type of node, or `CMARK_NODE_NONE` on error.
"""
function cmark_node_get_type end
@cmarkapi function cmark_node_get_type(::CMarkLibrary{LIBCM,LIBCMX}, node::Ptr{Cvoid}) where {LIBCM, LIBCMX}
    t = ccall(
        (:cmark_node_get_type, LIBCM),
        Cint, (Ptr{Cvoid},),
        node
    )
end

"""
    cmark_node_next([::CMarkLibrary,] node::Ptr{Cvoid}) -> node::Ptr{Cvoid}

Wraps `cmark_node_next` from `libcmark`:

> `cmark_node * cmark_node_next(cmark_node *node)`
>
> Returns the next node in the sequence after `node`, or `NULL` if there is none.
"""
function cmark_node_next end
@cmarkapi function cmark_node_next(::CMarkLibrary{LIBCM,LIBCMX}, node::Ptr{Cvoid}) where {LIBCM, LIBCMX}
    ccall(
        (:cmark_node_next, LIBCM),
        Ptr{Cvoid}, (Ptr{Cvoid},),
        node
    )
end

"""
    cmark_node_first_child([::CMarkLibrary,] node::Ptr{Cvoid}) -> node::Ptr{Cvoid}

Wraps `cmark_node_first_child` from `libcmark`:

> `cmark_node * cmark_node_first_child(cmark_node *node)`
>
> Returns the first child of `node`, or `NULL` if `node` has no children.
"""
function cmark_node_first_child end
@cmarkapi function cmark_node_first_child(::CMarkLibrary{LIBCM,LIBCMX}, node::Ptr{Cvoid}) where {LIBCM, LIBCMX}
    ccall(
        (:cmark_node_first_child, LIBCM),
        Ptr{Cvoid}, (Ptr{Cvoid},),
        node
    )
end

"""
    cmark_node_get_literal([::CMarkLibrary,] node::Ptr{Cvoid}) -> s::Cstring

Wraps `cmark_node_get_literal` from `libcmark`:

> `const char * cmark_node_get_literal(cmark_node *node)`
>
> Returns the string contents of `node`, or an empty string if none is set. Returns `NULL` if
> called on a node that does not have string content.
"""
function cmark_node_get_literal end
@cmarkapi function cmark_node_get_literal(::CMarkLibrary{LIBCM,LIBCMX}, node::Ptr{Cvoid}) where {LIBCM, LIBCMX}
    ccall(
        (:cmark_node_get_literal, LIBCM),
        Cstring, (Ptr{Cvoid},),
        node
    )
end

"""
   cmark_node_get_heading_level([::CMarkLibrary,] node::Ptr{Cvoid}) -> level::Cint

Wraps `cmark_node_get_heading_level` from `libcmark`:

> `int cmark_node_get_heading_level(cmark_node *node)`
>
> Returns the heading level of `node`, or `0` if `node` is not a heading.
"""
function cmark_node_get_heading_level end
@cmarkapi function cmark_node_get_heading_level(::CMarkLibrary{LIBCM,LIBCMX}, node::Ptr{Cvoid}) where {LIBCM, LIBCMX}
   ccall(
       (:cmark_node_get_heading_level, LIBCM),
       Cint, (Ptr{Cvoid},),
       node
   )
end

"""
   cmark_node_get_fence_info([::CMarkLibrary,] node::Ptr{Cvoid}) -> Cstring

Wraps `cmark_node_get_fence_info` from `libcmark`:

> `const char * cmark_node_get_fence_info(cmark_node *node)`
>
> Returns the info string from a fenced code block.
"""
function cmark_node_get_fence_info end
@cmarkapi function cmark_node_get_fence_info(::CMarkLibrary{LIBCM,LIBCMX}, node::Ptr{Cvoid}) where {LIBCM, LIBCMX}
   ccall(
       (:cmark_node_get_fence_info, LIBCM),
       Cstring, (Ptr{Cvoid},),
       node
   )
end

"""
   cmark_node_get_list_type([::CMarkLibrary,] node::Ptr{Cvoid}) -> cmark_list_type

Wraps `cmark_node_get_list_type` from `libcmark`:

> `cmark_list_type cmark_node_get_list_type(cmark_node *node)`
>
> Returns the list type of `node`, or `CMARK_NO_LIST` if `node` is not a list.
"""
function cmark_node_get_list_type end
@cmarkapi function cmark_node_get_list_type(::CMarkLibrary{LIBCM,LIBCMX}, node::Ptr{Cvoid}) where {LIBCM, LIBCMX}
   ccall(
       (:cmark_node_get_list_type, LIBCM),
       Cuint, (Ptr{Cvoid},),
       node
   )
end

"""
   cmark_node_get_url([::CMarkLibrary,] node::Ptr{Cvoid}) -> cmark_list_type

Wraps `cmark_node_get_url` from `libcmark`:

> `const char * cmark_node_get_url(cmark_node *node)`
>
> Returns the URL of a link or image node, or an empty string if no URL is set. Returns
> `NULL` if called on a node that is not a link or image.
"""
function cmark_node_get_url end
@cmarkapi function cmark_node_get_url(::CMarkLibrary{LIBCM,LIBCMX}, node::Ptr{Cvoid}) where {LIBCM, LIBCMX}
   ccall(
       (:cmark_node_get_url, LIBCM),
       Cstring, (Ptr{Cvoid},),
       node
   )
end

"""
    cmark_node_get_title([::CMarkLibrary,] node::Ptr{Cvoid}) -> Cstring

Wraps `cmark_node_get_title` from `libcmark`:

> `const char * cmark_node_get_title(cmark_node *node)`
>
> Returns the title of a link or image node, or an empty string if no title is set. Returns
> `NULL` if called on a node that is not a link or image.
"""
function cmark_node_get_title end
@cmarkapi function cmark_node_get_title(::CMarkLibrary{LIBCM,LIBCMX}, node::Ptr{Cvoid}) where {LIBCM, LIBCMX}
   ccall(
       (:cmark_node_get_title, LIBCM),
       Cstring, (Ptr{Cvoid},),
       node
   )
end

"""''
> cmark_syntax_extension *cmark_find_syntax_extension(const char *name);
"""
function cmark_find_syntax_extension end
@cmarkapi function cmark_find_syntax_extension(::CMarkLibrary{LIBCM,LIBCMX}, name::AbstractString) where {LIBCM, LIBCMX}
    ccall(
        (:cmark_find_syntax_extension, LIBCM),
        Ptr{Cvoid}, (Cstring,),
        name
    )
end

"""
cmark_parser * cmark_parser_new(int options)

Creates a new parser object.
"""
function cmark_parser_new end
@cmarkapi function cmark_parser_new(::CMarkLibrary{LIBCM,LIBCMX}) where {LIBCM, LIBCMX}
    ccall(
        (:cmark_parser_new, LIBCM),
        Ptr{Cvoid}, (Cint,),
        CMARK_OPT_DEFAULT
    )
end

"""
void cmark_parser_free(cmark_parser *parser)

Frees memory allocated for a parser object.
"""
function cmark_parser_free end
@cmarkapi function cmark_parser_free(::CMarkLibrary{LIBCM,LIBCMX}, p::Ptr{Cvoid}) where {LIBCM, LIBCMX}
    ccall(
        (:cmark_parser_free, LIBCM),
        Cvoid, (Ptr{Cvoid},),
        p
    )
end

"""
void cmark_parser_feed(cmark_parser *parser, const char *buffer, size_t len)

Feeds a string of length len to parser.
"""
function cmark_parser_feed end
@cmarkapi function cmark_parser_feed(::CMarkLibrary{LIBCM,LIBCMX}, p::Ptr{Cvoid}, s::AbstractString) where {LIBCM, LIBCMX}
    ccall(
        (:cmark_parser_feed, LIBCM),
        Cvoid, (Ptr{Cvoid}, Cstring, Csize_t),
        p, s, length(s)
    )
end

"""
cmark_node * cmark_parser_finish(cmark_parser *parser)

Finish parsing and return a pointer to a tree of nodes.
"""
function cmark_parser_finish end
@cmarkapi function cmark_parser_finish(::CMarkLibrary{LIBCM,LIBCMX}, p::Ptr{Cvoid}) where {LIBCM, LIBCMX}
    ccall(
        (:cmark_parser_finish, LIBCM),
        Ptr{Cvoid}, (Ptr{Cvoid},),
        p
    )
end

# int cmark_parser_attach_syntax_extension(cmark_parser *parser, cmark_syntax_extension *extension);
@cmarkapi function cmark_parser_attach_syntax_extension(::CMarkLibrary{LIBCM,LIBCMX}, p::Ptr{Cvoid}, ext::Ptr{Cvoid}) where {LIBCM, LIBCMX}
    ccall(
        (:cmark_parser_attach_syntax_extension, LIBCM),
        Cint, (Ptr{Cvoid}, Ptr{Cvoid}),
        p, ext
    )
end

# Extensions
#void cmark_gfm_core_extensions_ensure_registered(void);
@cmarkapi function cmark_gfm_core_extensions_ensure_registered(::CMarkLibrary{LIBCM,LIBCMX}) where {LIBCM, LIBCMX}
    ccall((:cmark_gfm_core_extensions_ensure_registered, LIBCMX), Cvoid, ())
end
