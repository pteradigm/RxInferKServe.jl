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

# Deployment is handled by GitHub Actions workflow
# The docs.yml workflow uses GitHub Pages deployment action
# which has proper permissions and doesn't require pushing to gh-pages
