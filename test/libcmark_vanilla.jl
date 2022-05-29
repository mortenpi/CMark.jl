using Test
using CMark: CMark
using cmark_jll: cmark_jll


@testset "Custom CMarkLibrary" begin
    libcmark = CMark.CMarkLibrary(cmark_jll.libcmark)
    @test CMark.cmark_version(libcmark) == 7682
    @test CMark.cmark_version_string(libcmark) == "0.30.2"
end
