using Documenter
using RxInferKServe

makedocs(
    sitename = "RxInferKServe.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://pteradigm.github.io/RxInferKServe.jl",
        assets = String[],
    ),
    modules = [RxInferKServe],
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",
        "API Reference" => [
            "Models" => "api/models.md",
            "Server" => "api/server.md",
            "Client" => "api/client.md",
        ],
        "Deployment" => [
            "Docker" => "deployment/docker.md",
            "Kubernetes" => "deployment/kubernetes.md",
        ],
        "Examples" => "examples.md",
    ],
)

deploydocs(
    repo = "github.com/pteradigm/RxInferKServe.jl.git",
    devbranch = "main",
    push_preview = true,
)
