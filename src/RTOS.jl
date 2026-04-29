module RTOS

export RTTask, TaskControlBlock, KernelState, kernel_state, reset_kernel!,
       create_task, suspend_task, resume_task, stop_task, delete_task, get_task,
       list_tasks, task_state, notify_task, take_notification, start_scheduler,
       notify_task_value, stop_scheduler, schedule_once!, yield_task, set_task_priority!,
       set_task_deadline!, delay_task, stack_stats,
       MessageQueue, create_queue, send_message, receive_message, queue_length,
       queue_spaces_available, peek_message, reset_queue!,
       FixedBlockPool, create_memory_pool, allocate_block, free_block!, memory_stats,
       DynamicAllocator, create_allocator, rtos_malloc, rtos_free,
       RTOSTimer, create_timer, start_timer, stop_timer, tick!, timer_active,
       reset_timer!, change_timer_period!, timer_fire_count, pend_timer_command!,
       InterruptHandler, register_interrupt, trigger_interrupt, enable_interrupt,
       disable_interrupt,
       DeviceDriver, register_driver, get_driver, read_device, write_device,
       control_device,
       RTOSMutex, CountingSemaphore, create_mutex, lock_mutex, unlock_mutex,
       create_recursive_mutex, create_semaphore, take_semaphore, give_semaphore,
       create_binary_semaphore, create_counting_semaphore,
       DeadlockGraph, would_deadlock, Watchdog, create_watchdog, feed_watchdog,
       watchdog_expired, check_watchdogs!,
       LogRecord, set_log_level!, log_debug, log_info, log_warn, log_error,
       recent_logs, clear_logs!,
       static_compile_available, compile_rtos, compile_rtos_executable,
       compile_rtos_library,
       RTOSException, DuplicateResourceError, InvalidStateError,
       ResourceNotFoundError, CapacityError, TimeoutError,
       IntegrationUnavailableError,
       RingBuffer, ring_capacity, ring_length, ring_empty, ring_full,
       push_ring!, pop_ring!, peek_ring, clear_ring!,
       TaskPool, create_task_pool, add_task_to_pool!, remove_task_from_pool!,
       pool_tasks, run_task_pool!,
       SharedCache, create_shared_cache, cache_put!, cache_get, cache_delete!,
       cache_stats,
       ResourceSnapshot, sample_resources!, resource_history, latest_resources,
       PowerProfile, create_power_profile, set_power_profile!, current_power_profile,
       balance_ready_tasks, rebalance_priorities!,
       FaultPolicy, register_fault_policy, handle_task_fault!,
       EventRecord, record_event!, events, clear_events!,
       analytics_summary, task_run_counts, event_counts,
       set_config!, get_config, load_config!, config_snapshot,
       PeriodicJob, create_periodic_task, start_periodic_task!,
       stop_periodic_task!, release_periodic_tasks!,
       integration_available, require_integration,
       system_model, optimize_system, control_step,
       MLDecision, register_ml_model, get_ml_model, ml_features,
       evaluate_ml_model, adapt_scheduler!, optimize_power!, predict_faults,
       detect_anomaly, run_ml_cycle!,
       EventGroup, create_event_group, set_event_bits!, clear_event_bits!,
       get_event_bits, wait_event_bits,
       StreamBuffer, create_stream_buffer, stream_send!, stream_receive!,
       stream_available,
       MessageBuffer, create_message_buffer, message_send!, message_receive!,
       message_available,
       QueueSet, create_queue_set, add_to_queue_set!, remove_from_queue_set!,
       select_from_queue_set,
       register_hook!, register_tick_hook!, register_idle_hook!,
       register_task_switch_hook!, register_malloc_fail_hook!,
       register_stack_overflow_hook!, clear_hooks!, run_hooks,
       enter_critical!, exit_critical!, critical_nesting,
       suspend_scheduler!, resume_scheduler!, scheduler_suspended,
       send_message_from_isr, give_semaphore_from_isr, notify_task_from_isr,
       defer_from_isr!, process_deferred_interrupts!,
       PortConfig, register_port!, current_port, set_core_count!,
       set_task_affinity!, assign_ready_tasks_to_cores,
       init_queue!, init_mutex!, init_timer!, init_event_group!,
       init_stream_buffer!, runtime_stats, trace_records, clear_trace!,
       export_trace,
       RTOSConfig, configure!, current_config, validate_config,
       TicklessPlan, next_wakeup_ms, plan_tickless_idle,
       TaskContract, set_task_contract!, get_task_contract,
       utilization, schedulability_report, deadline_misses,
       Capability, MemoryRegion, grant_capability!, revoke_capability!,
       has_capability, define_memory_region!, assign_region!,
       validate_security,
       chrome_trace,
       RTOSBuildTarget, create_build_target, build_plan, validate_build_target,
       build_target!, build_firmware,
       BoardSupportPackage, register_board!, current_board, start_board!,
       stop_board!, reset_board!,
       KernelObject, kernel_registry, find_kernel_object, kernel_snapshot,
       DaemonService, start_daemon!, stop_daemon!, daemon_running,
       post_daemon_command!, process_daemon_commands!,
       Heap1, Heap2, Heap4, RegionHeap, create_heap!, heap_alloc!,
       heap_free!, heap_stats,
       set_task_local!, get_task_local, delete_task_local!,
       SafetyProfile, create_safety_profile, validate_safety_profile,
       safety_report,
       NetworkInterface, register_network_interface!, network_send!,
       network_receive!, network_status,
       OTAUpdater, register_ota_updater!, stage_update!, verify_update!,
       apply_update!,
       initialize_rtos!, system_report, create_app_task, run_rtos!

include("Task.jl")
include("Utils.jl")
include("Debug.jl")
include("RingBuffer.jl")
include("EventLogger.jl")
include("Analytics.jl")
include("ConfigManager.jl")
include("Hooks.jl")
include("RTOSConfig.jl")
include("Critical.jl")
include("Safety.jl")
include("Sync.jl")
include("IPC.jl")
include("EventGroups.jl")
include("Buffers.jl")
include("QueueSet.jl")
include("Memory.jl")
include("Timers.jl")
include("Interrupts.jl")
include("ISR.jl")
include("Drivers.jl")
include("Port.jl")
include("StaticAllocation.jl")
include("BSP.jl")
include("TaskPool.jl")
include("SharedCache.jl")
include("ResourceMonitor.jl")
include("PowerManager.jl")
include("LoadBalancer.jl")
include("FaultTolerance.jl")
include("PeriodicScheduler.jl")
include("Scheduler.jl")
include("RuntimeStats.jl")
include("Tickless.jl")
include("Contracts.jl")
include("Security.jl")
include("Trace.jl")
include("Build.jl")
include("KernelRegistry.jl")
include("DaemonTask.jl")
include("HeapSchemes.jl")
include("TaskLocalStorage.jl")
include("SafetyProfile.jl")
include("NetworkInterfaces.jl")
include("OTA.jl")
include("UX.jl")
include("RTOSCompiler.jl")
include("SystemModeling.jl")
include("Optimization.jl")
include("ControlSystems.jl")
include("MLIntegration.jl")

const TaskControlBlock = RTTask

end
