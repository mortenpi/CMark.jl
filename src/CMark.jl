module CMark
import Markdown
using Compat

const libcmark = joinpath(@__DIR__, "..", "deps", "libcmark.so")

const CMARK_OPT_DEFAULT = 0

@enum cmark_node_type begin
    # Error status
    CMARK_NODE_NONE

    # Block
    CMARK_NODE_DOCUMENT
    CMARK_NODE_BLOCK_QUOTE
    CMARK_NODE_LIST
    CMARK_NODE_ITEM
    CMARK_NODE_CODE_BLOCK
    CMARK_NODE_HTML_BLOCK
    CMARK_NODE_CUSTOM_BLOCK
    CMARK_NODE_PARAGRAPH
    CMARK_NODE_HEADING
    CMARK_NODE_THEMATIC_BREAK

    # CMARK_NODE_FIRST_BLOCK = CMARK_NODE_DOCUMENT
    # CMARK_NODE_LAST_BLOCK = CMARK_NODE_THEMATIC_BREAK

    # Inline
    CMARK_NODE_TEXT
    CMARK_NODE_SOFTBREAK
    CMARK_NODE_LINEBREAK
    CMARK_NODE_CODE
    CMARK_NODE_HTML_INLINE
    CMARK_NODE_CUSTOM_INLINE
    CMARK_NODE_EMPH
    CMARK_NODE_STRONG
    CMARK_NODE_LINK
    CMARK_NODE_IMAGE

    # CMARK_NODE_FIRST_INLINE = CMARK_NODE_TEXT
    # CMARK_NODE_LAST_INLINE = CMARK_NODE_IMAGE
end

@enum cmark_list_type begin
    CMARK_NO_LIST
    CMARK_BULLET_LIST
    CMARK_ORDERED_LIST
end
# } cmark_list_type;
#
# typedef enum {
# CMARK_NO_DELIM,
# CMARK_PERIOD_DELIM,
# CMARK_PAREN_DELIM
# } cmark_delim_type;


function cmark_version()
    ccall((:cmark_version, libcmark), Cint, ()) |> Int
end

function cmark_version_string()
    s = ccall((:cmark_version_string, libcmark), Cstring, ())
    unsafe_string(s)
end

function cmark_markdown_to_html(markdown::AbstractString)
    s = ccall(
        (:cmark_markdown_to_html, libcmark),
        Cstring, (Cstring, Csize_t, Cint),
        markdown, length(markdown), CMARK_OPT_DEFAULT
    )
    unsafe_string(s)
end

function cmark_parse_document(markdown::AbstractString)
    ccall(
        (:cmark_parse_document, libcmark),
        Ptr{Cvoid}, (Cstring, Csize_t, Cint),
        markdown, length(markdown), CMARK_OPT_DEFAULT
    )
end

"""
    cmark_node_get_type(node::Ptr{Cvoid}) -> node_type::Cuint

Wraps `cmark_node_get_type` from `libcmark`:

> `cmark_node_type cmark_node_get_type(cmark_node *node)`
>
> Returns the type of node, or `CMARK_NODE_NONE` on error.
"""
function cmark_node_get_type(node::Ptr{Cvoid})
    t = ccall(
        (:cmark_node_get_type, libcmark),
        Cuint, (Ptr{Cvoid},),
        node
    )
end

"""
    cmark_node_next(node::Ptr{Cvoid}) -> node::Ptr{Cvoid}

Wraps `cmark_node_next` from `libcmark`:

> `cmark_node * cmark_node_next(cmark_node *node)`
>
> Returns the next node in the sequence after `node`, or `NULL` if there is none.
"""
function cmark_node_next(node::Ptr{Cvoid})
    ccall(
        (:cmark_node_next, libcmark),
        Ptr{Cvoid}, (Ptr{Cvoid},),
        node
    )
end

"""
    cmark_node_first_child(node::Ptr{Cvoid}) -> node::Ptr{Cvoid}

Wraps `cmark_node_first_child` from `libcmark`:

> `cmark_node * cmark_node_first_child(cmark_node *node)`
>
> Returns the first child of `node`, or `NULL` if `node` has no children.
"""
function cmark_node_first_child(node::Ptr{Cvoid})
    ccall(
        (:cmark_node_first_child, libcmark),
        Ptr{Cvoid}, (Ptr{Cvoid},),
        node
    )
end

"""
    cmark_node_get_literal(node::Ptr{Cvoid}) -> s::Cstring

Wraps `cmark_node_get_literal` from `libcmark`:

> `const char * cmark_node_get_literal(cmark_node *node)`
>
> Returns the string contents of `node`, or an empty string if none is set. Returns `NULL` if
> called on a node that does not have string content.
"""
function cmark_node_get_literal(node::Ptr{Cvoid})
    ccall(
        (:cmark_node_get_literal, libcmark),
        Cstring, (Ptr{Cvoid},),
        node
    )
end

"""
   cmark_node_get_heading_level(node::Ptr{Cvoid}) -> level::Cint

Wraps `cmark_node_get_heading_level` from `libcmark`:

> `int cmark_node_get_heading_level(cmark_node *node)`
>
> Returns the heading level of `node`, or `0` if `node` is not a heading.
"""
function cmark_node_get_heading_level(node::Ptr{Cvoid})
   ccall(
       (:cmark_node_get_heading_level, libcmark),
       Cint, (Ptr{Cvoid},),
       node
   )
end

"""
   cmark_node_get_fence_info(node::Ptr{Cvoid}) -> Cstring

Wraps `cmark_node_get_fence_info` from `libcmark`:

> `const char * cmark_node_get_fence_info(cmark_node *node)`
>
> Returns the info string from a fenced code block.
"""
function cmark_node_get_fence_info(node::Ptr{Cvoid})
   ccall(
       (:cmark_node_get_fence_info, libcmark),
       Cstring, (Ptr{Cvoid},),
       node
   )
end

"""
   cmark_node_get_list_type(node::Ptr{Cvoid}) -> cmark_list_type

Wraps `cmark_node_get_list_type` from `libcmark`:

> `cmark_list_type cmark_node_get_list_type(cmark_node *node)`
>
> Returns the list type of `node`, or `CMARK_NO_LIST` if `node` is not a list.
"""
function cmark_node_get_list_type(node::Ptr{Cvoid})
   ccall(
       (:cmark_node_get_list_type, libcmark),
       Cuint, (Ptr{Cvoid},),
       node
   )
end

"""
   cmark_node_get_url(node::Ptr{Cvoid}) -> cmark_list_type

Wraps `cmark_node_get_url` from `libcmark`:

> `const char * cmark_node_get_url(cmark_node *node)`
>
> Returns the URL of a link or image node, or an empty string if no URL is set. Returns
> `NULL` if called on a node that is not a link or image.
"""
function cmark_node_get_url(node::Ptr{Cvoid})
   ccall(
       (:cmark_node_get_url, libcmark),
       Cstring, (Ptr{Cvoid},),
       node
   )
end

"""
    cmark_node_get_title(node::Ptr{Cvoid}) -> Cstring

Wraps `cmark_node_get_title` from `libcmark`:

> `const char * cmark_node_get_title(cmark_node *node)`
>
> Returns the title of a link or image node, or an empty string if no title is set. Returns
> `NULL` if called on a node that is not a link or image.
"""
function cmark_node_get_title(node::Ptr{Cvoid})
   ccall(
       (:cmark_node_get_title, libcmark),
       Cstring, (Ptr{Cvoid},),
       node
   )
end


# Public Julia API
struct CMarkNode
    p :: Ptr{Cvoid}
end

parse_document(markdown::AbstractString) = CMarkNode(cmark_parse_document(markdown))

function nodetype(node::CMarkNode)
    cmark_node_type(cmark_node_get_type(node.p))
end

function listtype(node::CMarkNode)
    cmark_list_type(cmark_node_get_list_type(node.p))
end

function linkinfo(node::CMarkNode)
    url = cmark_node_get_url(node.p)
    title = cmark_node_get_title(node.p)
    (
        url == C_NULL ? nothing : unsafe_string(url),
        title == C_NULL ? nothing : unsafe_string(title)
    )
end

function Base.first(node::CMarkNode)
    p = cmark_node_first_child(node.p)
    p == C_NULL ? nothing : CMarkNode(p)
end

function next(node::CMarkNode)
    p = cmark_node_next(node.p)
    p == C_NULL ? nothing : CMarkNode(p)
end

function heading_level(node::CMarkNode)
    level = cmark_node_get_heading_level(node.p)
    iszero(level) ? nothing : Int(level)
end

function literal(node::CMarkNode)
    s = cmark_node_get_literal(node.p)
    s == C_NULL ? nothing : unsafe_string(s)
end

function code_fence_info(node::CMarkNode)
    s = cmark_node_get_fence_info(node.p)
    s == C_NULL ? nothing : unsafe_string(s)
end

# Convert to Base Markdown
function markdown_withsiblings(node::Union{CMarkNode,Nothing})
    nodes = Any[]
    n = node
    while !isnothing(n)
        push!(nodes, markdown(n))
        n = next(n)
    end
    return nodes
end

function markdown(node::CMarkNode)
    ntype = nodetype(node)
    if ntype == CMARK_NODE_DOCUMENT
        Markdown.MD(markdown_withsiblings(first(node)))
    elseif ntype == CMARK_NODE_BLOCK_QUOTE
        Markdown.BlockQuote(markdown_withsiblings(first(node)))
    elseif ntype == CMARK_NODE_LIST
        # TODO: implement cmark_node_get_list_start
        # TODO: implement cmark_node_get_list_tight
        list_type = listtype(node)
        items = markdown_withsiblings(first(node))
        if list_type == CMARK_BULLET_LIST
            Markdown.List(items)
        elseif list_type == CMARK_ORDERED_LIST
            Markdown.List(items, 1)
        else
            error("Bad list type $(list_type)")
        end
    elseif ntype == CMARK_NODE_ITEM
        markdown_withsiblings(first(node))
    elseif ntype == CMARK_NODE_CODE_BLOCK
        Markdown.Code(code_fence_info(node), literal(node))
    elseif ntype == CMARK_NODE_HTML_BLOCK
        Markdown.Code("@raw html", literal(node))
    # elseif ntype == CMARK_NODE_CUSTOM_BLOCK
    elseif ntype == CMARK_NODE_PARAGRAPH
        Markdown.Paragraph(markdown_withsiblings(first(node)))
    elseif ntype == CMARK_NODE_HEADING
        level = heading_level(node)
        Markdown.Header(markdown_withsiblings(first(node)), level)
    elseif ntype == CMARK_NODE_THEMATIC_BREAK
        Markdown.HorizontalRule()
    # # Inline
    elseif ntype == CMARK_NODE_TEXT
        literal(node)
    elseif ntype == CMARK_NODE_SOFTBREAK
        " "
    elseif ntype == CMARK_NODE_LINEBREAK
        # TODO: not really supported by Base Markdown?
        "\n"
    elseif ntype == CMARK_NODE_CODE
        Markdown.Code(literal(node))
    elseif ntype == CMARK_NODE_HTML_INLINE
        Markdown.Code("@raw html", literal(node))
    # elseif ntype == CMARK_NODE_CUSTOM_INLINE
    elseif ntype == CMARK_NODE_EMPH
        Markdown.Italic(markdown_withsiblings(first(node)))
    elseif ntype == CMARK_NODE_STRONG
        Markdown.Bold(markdown_withsiblings(first(node)))
    elseif ntype == CMARK_NODE_LINK
        url, _ = linkinfo(node) # we're discarding the title
        Markdown.Link(markdown_withsiblings(first(node)), url)
    elseif ntype == CMARK_NODE_IMAGE
        url, _ = linkinfo(node) # we're discarding the title
        # TODO: we will also discard the alt text, since Julia only supports string, but
        # CommonMark allows for arbitrary formatting.
        Markdown.Image(url, "")
    else
        error("Node type $(ntype) not implemented")
    end
end

markdown(s::AbstractString) = markdown(parse_document(s))

function typetree(node::CMarkNode; level=0)
    n = node
    while !isnothing(n)
        c = first(n)
        if isnothing(c)
            println("\t"^level, nodetype(n))
        else
            println("\t"^level, nodetype(n), " => {")
            typetree(c, level = level + 1)
            println("\t"^level, "}")
        end
        n = next(n)
    end
end

export markdown

end # module
