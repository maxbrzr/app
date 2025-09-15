# Timed Experiment App

A session-based data collection app that differs from the standard Experiment app by using global sensor configurations and recording step transitions with timestamps.

## Key Features

### Global Sensor Configuration
- Uses only `global_sensor_configs` from the configuration file
- No per-step sensor configuration overrides
- Sensors are activated once at session start and deactivated at session end

### Session-Based Data Collection
- Sensors activate when the experiment session begins
- Sensors remain active throughout the entire session
- Sensors deactivate when the session ends
- More efficient for continuous data collection scenarios

### CSV Data Logging
- Logs step transition events to CSV format
- Includes timestamps for each step transition
- Records time relative to session start
- Records duration for each step
- Automatic file naming with timestamps

### Data Export
- Export CSV data via Android sharing functionality
- Share data files with other apps
- Easy data transfer for analysis

## Configuration Format

```yaml
name: "My Timed Experiment"
description: "Description of the experiment"

# Global sensor configurations (applied to all steps)
global_sensor_configs:
  - sensor_name: "IMU"
    sensor_config:
      sample_rate: 30
      enabled: true
  - sensor_name: "Microphone"
    sensor_config:
      sample_rate: 16000
      enabled: true

# Experiment steps
steps:
  - name: "Baseline"
    description: "Record baseline measurements"
    duration: 30
  - name: "Activity"
    description: "Perform the main activity"
    duration: 60
  - name: "Recovery"
    description: "Recovery period"
    duration: 30
```

## Usage

1. **Select Configuration**: Choose from built-in configurations or load/create custom ones
2. **Start Session**: Begin the experiment session - sensors activate automatically
3. **Follow Steps**: Progress through experiment steps as guided
4. **Complete Session**: Finish the experiment - sensors deactivate and data is saved
5. **Export Data**: Share the CSV data file using Android's built-in sharing

## Data Format

The CSV output contains the following columns:
- `timestamp`: Absolute timestamp of the step event
- `relative_time_ms`: Time relative to session start (milliseconds)
- `step_name`: Name of the step
- `step_description`: Description of the step  
- `step_duration_sec`: Duration of the step in seconds
- `event_type`: Type of event ("step_start" or "step_end")

## Differences from Standard Experiment App

| Feature | Standard Experiment | Timed Experiment |
|---------|-------------------|------------------|
| Sensor Config | Per-step overrides | Global only |
| Sensor Activation | Per-step | Session-based |
| Data Format | Custom | CSV with timestamps |
| Export | Manual save | Android sharing |
| Use Case | Step-specific configs | Continuous monitoring |

## File Structure

```
lib/apps/timed_experiment/
├── model/
│   ├── timed_experiment_config.dart    # Configuration parsing
│   ├── timed_experiment_logger.dart    # CSV logging
│   ├── timed_experiment_manager.dart   # Session management
│   └── timed_config_storage.dart       # Configuration persistence
├── widgets/
│   ├── timed_experiment_app.dart       # Main app entry point
│   ├── timed_config_selection_page.dart # Configuration selection
│   ├── timed_create_config_dialog.dart # New configuration creation
│   ├── timed_experiment_page.dart      # Experiment execution
│   └── timed_save_config_dialog.dart   # Configuration saving
├── assets/
│   ├── sample_timed_experiment.yaml    # Sample configuration
│   └── logo.png                        # App logo
└── README.md                           # This file
```
