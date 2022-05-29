using CMark
using Test
import Markdown
using cmark_jll: cmark_jll

@testset "CMark.jl" begin
    # Write your own tests here.
    @test CMark.cmark_version() == 1900547
    @test CMark.cmark_version_string() == "0.29.0.gfm.3"

    # simple empty Markdown document
    let md = "" |> CMark.parse_document |> CMark.markdown_withsiblings
        @test length(md) == 1
        @test md[1] isa Markdown.MD
        @test isempty(md[1])
    end

    # single string
    let md = "foo" |> CMark.parse_document |> CMark.markdown_withsiblings
        @test length(md) == 1
        @test md[1] isa Markdown.MD
        @test length(md[1]) == 1
        @test md[1][1] isa Markdown.Paragraph
        @test length(md[1][1].content) == 1
        @test md[1][1].content[1] == "foo"
    end

    # some basic inline elements
    let md = "foo **strong** _emphasis_" |> markdown
        @test md isa Markdown.MD
        @test length(md) == 1
        @test md[1] isa Markdown.Paragraph
        @test length(md[1].content) == 4
        @test md[1].content[1] == "foo "
        @test md[1].content[2] isa Markdown.Bold
        @test md[1].content[3] == " "
        @test md[1].content[4] isa Markdown.Italic
    end

    # Headings and inline code
    let md = """
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
        """ |> markdown
        @test md isa Markdown.MD
        @test length(md) == 8
        for h in md.content
            @test h isa Markdown.Header
            @test length(h.text) == 2
            @test h.text[2] isa Markdown.Code
            level = parse(Int, h.text[2].code)
            @test h isa Markdown.Header{level}
        end
    end

    # code, blockquote and thematic break blocks
    let md = """
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
        """ |> CMark.parse_document |> CMark.markdown
        @test md isa Markdown.MD
        @test length(md) == 7
        @test md[1] isa Markdown.Code
        @test md[1].language == "foo bar baz"
        @test md[1].code == "code\nexample()\n"
        @test md[2] isa Markdown.HorizontalRule
        @test md[3] isa Markdown.BlockQuote
        @test length(md[3].content) == 1
        @test md[4] isa Markdown.HorizontalRule
        @test md[5] isa Markdown.BlockQuote
        @test length(md[5].content) == 2
        @test md[5].content[1] isa Markdown.Paragraph
        @test md[6] isa Markdown.HorizontalRule
        @test md[7] isa Markdown.Code
        @test md[7].language == ""
        @test md[7].code == "Indented code\n"
    end

    # lists
    let md = """
        * A
        * B
        ---
        * A

          B
        * C
        ---
        1. Foo
        2. Bar
        """ |> markdown
        @test md isa Markdown.MD
        @test length(md) == 5

        @test md[1] isa Markdown.List
        @test md[1].ordered == -1
        @test length(md[1].items) == 2
        @test md[1].items[1] isa Vector
        @test length(md[1].items[1]) == 1
        @test md[1].items[1][1] isa Markdown.Paragraph

        let list = md[3]
            @test list isa Markdown.List
            @test list.ordered == -1
            @test length(list.items) == 2
            @test list.items[1] isa Vector
            @test length(list.items[1]) == 2
            @test list.items[1][1] isa Markdown.Paragraph
            @test list.items[1][2] isa Markdown.Paragraph
            @test list.items[2] isa Vector
            @test length(list.items[2]) == 1
            @test list.items[2][1] isa Markdown.Paragraph
        end

        let list = md[5]
            @test list isa Markdown.List
            @test list.ordered == 1
            @test length(list.items) == 2
            @test list.items[1] isa Vector
            @test length(list.items[1]) == 1
            @test list.items[1][1] isa Markdown.Paragraph
            @test list.items[2] isa Vector
            @test length(list.items[2]) == 1
            @test list.items[2][1] isa Markdown.Paragraph
        end
    end

    # linebreaks
    let md = "Soft\nBreak\n\n---\n\nHard  \nBreak\n" |> markdown
        @test md isa Markdown.MD
        @test length(md) == 3
        let p = md[1]
            @test p isa Markdown.Paragraph
            @test length(p.content) == 3
            @test p.content[1] == "Soft"
            @test p.content[2] == " "
            @test p.content[3] == "Break"
        end
        let p = md[3]
            @test p isa Markdown.Paragraph
            @test length(p.content) == 3
            @test p.content[1] == "Hard"
            @test p.content[2] == "\n"
            @test p.content[3] == "Break"
        end
    end

    # links and link definitions
    let md = """
        [link text](url)

        [link text](url "title")

        <http://foo.bar.baz>

        [text][link1]

        [text][link2]

        [link1]: foo
        [link2]: bar "title"
        """ |> markdown
        @test md isa Markdown.MD
        @test length(md) == 5
        @test all(isa.(md.content, Markdown.Paragraph))
        @test all(length(p.content) == 1 for p in md.content)

        let link = md[1].content[1]
            @test link isa Markdown.Link
            @test link.text == ["link text"]
            @test link.url == "url"
        end
        let link = md[2].content[1]
            @test link isa Markdown.Link
            @test link.text == ["link text"]
            @test link.url == "url"
        end
        let link = md[3].content[1]
            @test link isa Markdown.Link
            @test link.text == ["http://foo.bar.baz"]
            @test link.url == "http://foo.bar.baz"
        end
        let link = md[4].content[1]
            @test link isa Markdown.Link
            @test link.text == ["text"]
            @test link.url == "foo"
        end
        let link = md[5].content[1]
            @test link isa Markdown.Link
            @test link.text == ["text"]
            @test link.url == "bar"
        end
    end

    # image
    let md = "![alt text](url \"title\")" |> markdown
        @test md isa Markdown.MD
        @test length(md) == 1
        @test md[1] isa Markdown.Paragraph
        let image = md[1].content[1]
            @test image isa Markdown.Image
            @test image.url == "url"
            @test image.alt == ""
        end
    end

    # HTML
    let md = """
        Inline <span>HTML</span>!

        <div>HTML blocks</div>
        """ |> markdown
        @test md isa Markdown.MD
        @test length(md) == 2
        let p = md[1]
            @test p isa Markdown.Paragraph
            @test length(p.content) == 5
            @test p.content[2] isa Markdown.Code
            @test p.content[2].language == "@raw html"
            @test p.content[2].code == "<span>"
            @test p.content[4] isa Markdown.Code
            @test p.content[4].language == "@raw html"
            @test p.content[4].code == "</span>"
        end
        let code = md[2]
            @test code isa Markdown.Code
            @test code.language == "@raw html"
            @test code.code == "<div>HTML blocks</div>\n"
        end
    end

    # GFM extensions
    let md = """
        ~foo bar~

        | foo | bar       |
        | --- | --------- |
        | baz | *bim* bim |
        """ |> markdown
        @test md isa Markdown.MD
        @test length(md) == 2
        let p = md[1]
            @test p isa Markdown.Paragraph
            @test length(p.content) == 1
            @test p.content[1] isa Vector
            @test length(p.content[1]) == 3
            @test p.content[1][1] isa Markdown.Code
            @test p.content[1][2] isa String
            @test p.content[1][3] isa Markdown.Code
        end
        let t = md[2]
            @test t isa Markdown.Table
            @test length(t.rows) == 2
            @test length(t.rows[1]) == 2
            @test length(t.rows[1][1]) == 1
            @test length(t.rows[1][2]) == 1
            @test length(t.rows[2]) == 2
            @test length(t.rows[2][1]) == 1
            @test length(t.rows[2][2]) == 2
        end
    end

    include("libcmark_vanilla.jl")
end
