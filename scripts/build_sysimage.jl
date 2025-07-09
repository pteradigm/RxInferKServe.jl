"""
Build a custom system image for fast startup
"""

using PackageCompiler
using Pkg

# Ensure we're in the right directory
cd(dirname(@__DIR__))

# Create sysimage
println("Building custom system image...")
println("This may take 10-20 minutes...")

create_sysimage(
    ["RxInferKServe", "RxInfer", "HTTP", "JSON3"],
    sysimage_path = "rxinfer_server.so",
    precompile_execution_file = "scripts/precompile.jl",
    cpu_target = PackageCompiler.default_app_cpu_target(),
    include_transitive_dependencies = true,
)

println("\nSystem image created successfully!")
println("To use it, start Julia with:")
println("  julia --sysimage=rxinfer_server.so")
println("\nOr set the JULIA_SYSIMAGE environment variable:")
println("  export JULIA_SYSIMAGE=$(pwd)/rxinfer_server.so")
