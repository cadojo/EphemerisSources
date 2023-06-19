# 
# Generate a sitemap for NASA's General Kernel URL! 
# This requires the program `lynx` to be installed.
# 

using HTTP
using IOCapture
using SPICEKernels

"""
Call the `lynx` commandline program in a non-interactive context.
"""
function lynx(url::AbstractString)
    contents = IOCapture.capture() do 
       run(`lynx -dump -listonly -nonumbers "$url"`) 
    end
    
    lines = split(contents.output)
    return Set(map(String, lines))
end

"""
Given a General Kernel URL or sub-URL, return a set of kernel file paths and subdirectories.
"""
function search(
        url::AbstractString; 
        ignore=("?", "LYNXIMGMAP", "#", "old_versions", "README"), 
        accept=(SPICEKernels.GENERAL_KERNEL_URL, "dsk", "fk", "lsk", "pck", "spk", "stars", keys(SPICEKernels.SPICE_EXTENSIONS)...)
    )

    paths = lynx(url)

    filter!(path -> !any(occursin(key, path) for key in ignore), paths)
    filter!(path -> any(occursin(key, path) for key in accept), paths)
    filter!(path -> path != HTTP.safer_joinpath(replace(url, basename(url) => ""), ""), paths)

    return paths
end

"""
Given a top-level directory, return the set of all kernel file paths found in all subdirectories.
"""
function traverse(url::AbstractString; searched::AbstractSet{<:AbstractString} = Set{String}())

    url = HTTP.safer_joinpath(url, "")
    @info "Searching for kernels in $url"

    found = Set{String}()
    paths = search(url)
    push!(searched, url)

    setdiff!(paths, searched)

    for path in paths
        push!(searched, path)
        if any(occursin(ext, basename(path)) for ext in keys(SPICEKernels.SPICE_EXTENSIONS))
            push!(found, path)
        elseif !occursin(".", basename(path))
            union!(found, traverse(path; searched = searched))
        end
    end

    return found
end

"""
Write all current kernel paths to the provided file name.
"""
function code!(kernels::AbstractSet{<:AbstractString})

    kernellist = collect(kernels)
    sort!(kernellist)

    filepath = abspath(joinpath(@__DIR__, "..", "src", "gen", "kernels.jl"))
    open(filepath, "w") do file
        write(file, "#\n# This is an autogenerated file! See /gen/make.jl for more information.\n#\n\n")
        write(file, "GENERAL_KERNELS = Base.ImmutableDict(\n")
        for kernel in kernellist
            write(file, """\t"$(basename(kernel))" => "$kernel",\n""")
        end
        write(file, ")\n\n")
    end

end

# 
# The script portion!
# 

code!(traverse(SPICEKernels.GENERAL_KERNEL_URL))