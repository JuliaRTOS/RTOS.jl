using RTOS
using Documenter

DocMeta.setdocmeta!(RTOS, :DocTestSetup, :(using RTOS); recursive=true)

makedocs(;
    modules=[RTOS],
    authors="bparbhu <brian.parbhu@gmail.com> and contributors",
    sitename="RTOS.jl",
    format=Documenter.HTML(;
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Architecture" => "architecture.md",
        "FreeRTOS Parity" => "freertos-parity.md",
        "Platform Layer" => "platform.md",
        "System Services" => "system-services.md",
        "Static Compilation" => "static-compilation.md",
        "Examples" => "examples.md",
        "API Reference" => "api.md",
    ],
)
