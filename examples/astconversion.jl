CMark.parse_document("""
# Foobar

Hello

---

> Foo

```julia
x = 2
```

    more = code

<div></div>
""") |> CMark.markdownast |> MarkdownAST.showast

CMark.parse_document("""
1. Foo
2. Bar

* X
* Y
  - Y1
  - Y2
* Z

""") |> CMark.markdownast |> MarkdownAST.showast

CMark.parse_document("""
Foo **bar** _baz_.

[xyz](https://example.org "asd") ![xyz](https://example.org "asd") <span>foo</span>
""") |> CMark.markdownast |> MarkdownAST.showast
