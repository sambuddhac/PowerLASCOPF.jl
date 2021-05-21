using PowerLASCOPF
using Documenter

DocMeta.setdocmeta!(PowerLASCOPF, :DocTestSetup, :(using PowerLASCOPF); recursive=true)

makedocs(;
    modules=[PowerLASCOPF],
    authors="Sambuddha Chakrabarti, Mahdi Kefayati, Ross Baldick",
    repo="https://github.com/sambuddhac/PowerLASCOPF.jl/blob/{commit}{path}#{line}",
    sitename="PowerLASCOPF.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://sambuddhac.github.io/PowerLASCOPF.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/sambuddhac/PowerLASCOPF.jl",
)
