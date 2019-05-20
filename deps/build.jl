if isdir(joinpath(@__DIR__, "cmark-0.29.0"))
    rm(joinpath(@__DIR__, "cmark-0.29.0"), recursive=true)
end
if isfile(joinpath(@__DIR__, "0.29.0.tar.gz"))
    rm(joinpath(@__DIR__, "0.29.0.tar.gz"))
end
if isfile(joinpath(@__DIR__, "libcmark.so"))
    rm(joinpath(@__DIR__, "libcmark.so"))
end

cd(@__DIR__)
run(`wget https://github.com/commonmark/cmark/archive/0.29.0.tar.gz`)
run(`tar -xf 0.29.0.tar.gz`)
cd("cmark-0.29.0") do
#run(`make INSTALL_PREFIX="$(@__DIR__)" install`)
    run(`make`)
end
cp("cmark-0.29.0/build/src/libcmark.so.0.29.0", "libcmark.so")
