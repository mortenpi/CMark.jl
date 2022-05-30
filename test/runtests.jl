using CMark
using Test
using MarkdownAST: MarkdownAST, @ast
using cmark_jll: cmark_jll

@testset "CMark.jl" begin
    # Write your own tests here.
    @test CMark.cmark_version() == 1900547
    @test CMark.cmark_version_string() == "0.29.0.gfm.3"

    # simple empty Markdown document
    @test "" |> CMark.parse_document |> CMark.markdownast == MarkdownAST.Node(MarkdownAST.Document())

    # single string
    @test "foo" |> CMark.parse_document |> CMark.markdownast == @ast MarkdownAST.Document() do
        MarkdownAST.Paragraph() do
            "foo"
        end
    end

    # some basic inline elements
    @test "foo **strong** _emphasis_" |> CMark.parse_document_gfm |> CMark.markdownast == @ast MarkdownAST.Document() do
        MarkdownAST.Paragraph() do
            "foo "
            MarkdownAST.Strong() do; "strong"; end
            " "
            MarkdownAST.Emph() do; "emphasis"; end
        end
    end

    # Headings and inline code
    @test """
    # Heading `1`
    ## Heading `2`
    ### Heading `3`
    #### Heading `4`
    ##### Heading `5`
    ###### Heading `6`

    Setext `1`
    ==========

    Setext `2`
    ----------
    """ |> CMark.parse_document_gfm |> CMark.markdownast == @ast MarkdownAST.Document() do
        MarkdownAST.Heading(1) do; "Heading "; MarkdownAST.Code("1"); end
        MarkdownAST.Heading(2) do; "Heading "; MarkdownAST.Code("2"); end
        MarkdownAST.Heading(3) do; "Heading "; MarkdownAST.Code("3"); end
        MarkdownAST.Heading(4) do; "Heading "; MarkdownAST.Code("4"); end
        MarkdownAST.Heading(5) do; "Heading "; MarkdownAST.Code("5"); end
        MarkdownAST.Heading(6) do; "Heading "; MarkdownAST.Code("6"); end
        MarkdownAST.Heading(1) do; "Setext "; MarkdownAST.Code("1"); end
        MarkdownAST.Heading(2) do; "Setext "; MarkdownAST.Code("2"); end
    end

    # code, blockquote and thematic break blocks
    @test """
    ```foo bar baz
    code
    example()
    ```

    ---

    > Paragraph 1
    ---
    > Paragraph 1
    >
    > Paragraph 2

    ---

        Indented code
    """ |> CMark.parse_document_gfm |> CMark.markdownast == @ast MarkdownAST.Document() do
        MarkdownAST.CodeBlock("foo bar baz", "code\nexample()\n")
        MarkdownAST.ThematicBreak()
        MarkdownAST.BlockQuote() do
            MarkdownAST.Paragraph() do; "Paragraph 1"; end
        end
        MarkdownAST.ThematicBreak()
        MarkdownAST.BlockQuote() do
            MarkdownAST.Paragraph() do; "Paragraph 1"; end
            MarkdownAST.Paragraph() do; "Paragraph 2"; end
        end
        MarkdownAST.ThematicBreak()
        MarkdownAST.CodeBlock("", "Indented code\n")
    end

    # lists
    @test_broken """
    * A
    * B
    ---
    * A

        B
    * C
    ---
    1. Foo
    2. Bar
    """ |> CMark.parse_document_gfm |> CMark.markdownast == @ast MarkdownAST.Document() do
        # TODO: needs proper List conversion
    end

    # linebreaks
    @test_broken "Soft\nBreak\n\n---\n\nHard  \nBreak\n" |> CMark.parse_document_gfm |> CMark.markdownast == @ast MarkdownAST.Document() do
        # TODO: needs break implementations in MarkdownAST
    end

    # links and link definitions
    @test """
    [link text](url)

    [link text](url "title")

    <http://foo.bar.baz>

    [text][link1]

    [text][link2]

    [link1]: foo
    [link2]: bar "title"
    """ |> CMark.parse_document_gfm |> CMark.markdownast == @ast MarkdownAST.Document() do
        MarkdownAST.Paragraph() do
            MarkdownAST.Link("url", "") do; "link text"; end
        end
        MarkdownAST.Paragraph() do
            MarkdownAST.Link("url", "title") do; "link text"; end
        end
        MarkdownAST.Paragraph() do
            MarkdownAST.Link("http://foo.bar.baz", "") do; "http://foo.bar.baz"; end
        end
        MarkdownAST.Paragraph() do
            MarkdownAST.Link("foo", "") do; "text"; end
        end
        MarkdownAST.Paragraph() do
            MarkdownAST.Link("bar", "title") do; "text"; end
        end
    end

    # image
    @test "![alt text](url \"title\")" |> CMark.parse_document_gfm |> CMark.markdownast == @ast MarkdownAST.Document() do
        MarkdownAST.Paragraph() do
            MarkdownAST.Image("url", "title") do
                "alt text"
            end
        end
    end

    # HTML
    @test """
    Inline <span>HTML</span>!

    <div>HTML blocks</div>
    """ |> CMark.parse_document_gfm |> CMark.markdownast == @ast MarkdownAST.Document() do
        MarkdownAST.Paragraph() do
            "Inline "
            MarkdownAST.HTMLInline("<span>")
            "HTML"
            MarkdownAST.HTMLInline("</span>")
            "!"
        end
        MarkdownAST.HTMLBlock("<div>HTML blocks</div>\n")
    end

    # GFM extensions
    @test_broken """
    ~foo bar~

    | foo | bar       |
    | --- | --------- |
    | baz | *bim* bim |
    """ |> CMark.parse_document_gfm |> CMark.markdownast == @ast MarkdownAST.Document() do
        # TODO: needs proper Table implementation
    end

    include("libcmark_vanilla.jl")
end
