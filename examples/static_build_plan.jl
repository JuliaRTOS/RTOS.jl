using RTOS

reset_kernel!()

function firmware_entry()
    return 0
end

target = create_build_target("host-demo", firmware_entry;
                             output_dir="build/host-demo")

println("StaticCompiler available: ", static_compile_available())
println("build target valid: ", isempty(validate_build_target(target)))
plan = build_plan("host-demo")
println("build plan:")

println(" - target: ", plan.target)
println(" - output_dir: ", plan.output_dir)
println(" - artifact_kind: ", plan.artifact_kind)
println(" - valid: ", plan.valid)
