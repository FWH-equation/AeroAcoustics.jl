using Documenter, AeroAcoustics

makedocs(
    modules = [AeroAcoustics],
    checkdocs = :none,
    sitename = "AeroAcoustics.jl",
    pages = Any["index.md"]
)

deploydocs(
    repo = "https://gitlab.windenergy.dtu.dk/ollyl/AeroAcoustics.jl/blob/{commit}{path}#{line}",
)
