using Test
using Debug

@testset "Debug Logging Tests" begin
    clear_event_log()
    log_event("INFO", "Test event")
    logs = dump_event_log()

    @test length(logs) == 1
    @test logs[1][2] == "INFO"

    set_log_level("ERROR")
    log_event("INFO", "This should not be logged")
    logs = dump_event_log()

    @test length(logs) == 1  # Previous event should be the only one
end
