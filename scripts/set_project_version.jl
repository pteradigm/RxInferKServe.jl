#!/usr/bin/env julia

using Pkg

if length(ARGS) != 1
    error("usage: set_project_version.jl <semver-version>")
end

version = only(ARGS)
if match(r"^[0-9]+[.][0-9]+[.][0-9]+([-.][0-9A-Za-z.]+)?$", version) === nothing
    error("version must be a semantic version without a leading v, got $(repr(version))")
end

project_path = joinpath(@__DIR__, "..", "Project.toml")
project = read(project_path, String)

if match(r"(?m)^version = \".*\"$", project) === nothing
    error("Project.toml version field was not updated")
end

updated = replace(project, r"(?m)^version = \".*\"$" => "version = \"$version\""; count = 1)
write(project_path, updated)
Pkg.resolve()
