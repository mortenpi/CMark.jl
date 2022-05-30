module CMark
using MarkdownAST: MarkdownAST
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

function first_child(node::CMarkNode)
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

# Convert to MarkdownAST

function markdownast_children(node::CMarkNode)
    nodes = Any[]
    child = first_child(node)
    while !isnothing(child)
        push!(nodes, markdown(child))
        child = next(child)
    end
    return nodes
end

function markdownast(node::CMarkNode)
    ntype = nodetype(node)
    element = if ntype == CMARK_NODE_DOCUMENT
        MarkdownAST.Document()
    elseif ntype == CMARK_NODE_PARAGRAPH
        MarkdownAST.Paragraph()
    elseif ntype == CMARK_NODE_HEADING
        MarkdownAST.Heading(heading_level(node))
    elseif ntype == CMARK_NODE_BLOCK_QUOTE
        MarkdownAST.BlockQuote()
    elseif ntype == CMARK_NODE_CODE_BLOCK
        MarkdownAST.CodeBlock(code_fence_info(node), literal(node))
    elseif ntype == CMARK_NODE_HTML_BLOCK
         MarkdownAST.HTMLBlock(literal(node))
    elseif ntype == CMARK_NODE_THEMATIC_BREAK
        MarkdownAST.ThematicBreak()
    elseif ntype == CMARK_NODE_LIST
        list_type = listtype(node)
        list_type_symbol = if list_type == CMARK_BULLET_LIST
            :bullet
        elseif list_type == CMARK_ORDERED_LIST
            :ordered
        else
            error("Bad list type $(list_type)")
        end
        # TODO: implement cmark_node_get_list_start
        # TODO: implement cmark_node_get_list_tight
        MarkdownAST.List(list_type_symbol, true)
    elseif ntype == CMARK_NODE_ITEM
        MarkdownAST.Item()
    # elseif ntype == CMARK_NODE_CUSTOM_BLOCK

    # Inline
    elseif ntype == CMARK_NODE_TEXT
        MarkdownAST.Text(literal(node))
    elseif ntype == CMARK_NODE_EMPH
        MarkdownAST.Emph()
    elseif ntype == CMARK_NODE_STRONG
        MarkdownAST.Strong()
    elseif ntype == CMARK_NODE_LINK
        url, title = linkinfo(node)
        MarkdownAST.Link(url, title)
    elseif ntype == CMARK_NODE_IMAGE
        url, title = linkinfo(node)
        MarkdownAST.Image(url, title)
    elseif ntype == CMARK_NODE_CODE
        MarkdownAST.Code(literal(node))
    elseif ntype == CMARK_NODE_HTML_INLINE
        MarkdownAST.HTMLInline(literal(node))
    # elseif ntype == CMARK_NODE_SOFTBREAK
    #     " "
    # elseif ntype == CMARK_NODE_LINEBREAK
    #     # TODO: not really supported by Base Markdown?
    #     "\n"

    # elseif ntype == CMARK_NODE_CUSTOM_INLINE

    # # Extension nodes
    # elseif ntype == :CMARK_NODE_STRIKETHROUGH
    #     # TODO: MarkdownAST doesn't currently implement strikethrough
    #     # TODO: we end up with a vector in a vector here
    #     [
    #         Markdown.Code("@raw html", "<del>"),
    #         markdown_withsiblings(first(node))...,
    #         Markdown.Code("@raw html", "</del>")
    #     ]
    # elseif ntype == :CMARK_NODE_TABLE
    #     # TODO: alignment
    #     rows = markdown_withsiblings(first(node))
    #     ncols = maximum(length.(rows))
    #     Markdown.Table(rows, [:l for _ in 1:ncols])
    # elseif ntype == :CMARK_NODE_TABLE_ROW
    #     markdown_withsiblings(first(node))
    # elseif ntype == :CMARK_NODE_TABLE_CELL
    #     markdown_withsiblings(first(node))
    else
        error("Node type $(ntype) not implemented")
    end
    mdast_node = MarkdownAST.Node(element)
    if first_child(node) !== nothing
        # TODO: a possible error condition he is that we might try to append children to
        # elements that do not support them (MarkdownAST throws an error), but for some
        # reason in the libcmark AST they have children.
        child = first_child(node)
        while !isnothing(child)
            push!(mdast_node, markdownast(child))
            child = next(child)
        end
    end
    return mdast_node
end

function typetree(node::CMarkNode; level=0)
    n = node
    while !isnothing(n)
        c = first_child(n)
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

function __init__()
    # Initialize the default libcmark library
    init!(libcmarkgfm)
end

end # module
