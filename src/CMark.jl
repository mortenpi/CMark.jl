module CMark
import Markdown
using Libdl
using cmark_gfm_jll: cmark_gfm_jll

include("ccalls.jl")

const extensions = ["autolink", "strikethrough", "table", "tagfilter", "tasklist"]

# Public Julia API
struct CMarkNode
    p :: Ptr{Cvoid}
end

struct CMarkSyntaxExtension
    p :: Ptr{Cvoid}
end

#"autolink", "strikethrough", "table", "tagfilter"
function findsyntaxextension(name)
    p = cmark_find_syntax_extension(name)
    p == C_NULL ? nothing : CMarkSyntaxExtension(p)
end

parse_document(markdown::AbstractString) = CMarkNode(cmark_parse_document(markdown))

function parse_document_gfm(markdown::AbstractString)
    p = cmark_parser_new()
    for e in extensions
        ext_p = cmark_find_syntax_extension(e)
        cmark_parser_attach_syntax_extension(p, ext_p)
    end
    cmark_parser_feed(p, markdown)
    n = cmark_parser_finish(p)
    cmark_parser_free(p)
    CMarkNode(n)
end

function nodetype(node::CMarkNode) :: Union{cmark_node_type,Symbol,Missing}
    t_int = cmark_node_get_type(node.p)
    if t_int == CMARK_NODE_STRIKETHROUGH[]
        return :CMARK_NODE_STRIKETHROUGH
    elseif t_int == CMARK_NODE_TABLE[]
        return :CMARK_NODE_TABLE
    elseif t_int == CMARK_NODE_TABLE_CELL[]
        return :CMARK_NODE_TABLE_CELL
    elseif t_int == CMARK_NODE_TABLE_ROW[]
        return :CMARK_NODE_TABLE_ROW
    end
    try
        t = cmark_node_type(t_int)
        return t
    catch e
        isa(e, ArgumentError) ? missing : rethrow(e)
    end
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

    # Extension nodes
    elseif ntype == :CMARK_NODE_STRIKETHROUGH
        # TODO: we end up with a vector in a vector here
        [
            Markdown.Code("@raw html", "<del>"),
            markdown_withsiblings(first(node))...,
            Markdown.Code("@raw html", "</del>")
        ]
    elseif ntype == :CMARK_NODE_TABLE
        # TODO: alignment
        rows = markdown_withsiblings(first(node))
        ncols = maximum(length.(rows))
        Markdown.Table(rows, [:l for _ in 1:ncols])
    elseif ntype == :CMARK_NODE_TABLE_ROW
        markdown_withsiblings(first(node))
    elseif ntype == :CMARK_NODE_TABLE_CELL
        markdown_withsiblings(first(node))
    else
        error("Node type $(ntype) not implemented")
    end
end

markdown(s::AbstractString) = markdown(parse_document_gfm(s))

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

function __init__()
    # Initialize the default libcmark library
    init!(libcmarkgfm)
end

end # module
