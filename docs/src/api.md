```@meta
CurrentModule = RTOS
```

# API Reference

```@index
```

Common high-level workflow APIs:

- `initialize_rtos!`
- `create_app_task`
- `run_rtos!`
- `system_report`
- `kernel_registry`
- `safety_report`
- `queue_spaces_available`
- `peek_message`
- `reset_queue!`
- `notify_task_value`
- `enter_critical!`
- `exit_critical!`
- `reset_timer!`
- `change_timer_period!`
- `pend_timer_command!`
- `MLDecision`
- `ml_features`
- `evaluate_ml_model`
- `run_ml_cycle!`
- `optimize_power!`
- `predict_faults`

```@autodocs
Modules = [RTOS]
Order = [:type, :function, :constant]
```
