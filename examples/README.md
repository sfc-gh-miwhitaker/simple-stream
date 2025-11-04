# Examples

## Overview

This directory contains example scripts demonstrating how to work with the RFID badge event simulation system.

---

## 📄 custom_simulation.py

A standalone example showing how to generate RFID badge events with custom parameters.

**Purpose:**
- Demonstrates event generation logic
- Shows how to customize simulation parameters
- Useful as a starting point for custom workloads

**What it does:**
- Generates realistic RFID badge scan events
- Configurable number of users, events, and rates
- Displays sample event structure

**Limitations:**
- Does **not** send events to Snowflake (event generation only)
- For full REST API ingestion, use `notebooks/RFID_Simulator.ipynb`

---

## Usage

### Run from Command Line

```bash
python examples/custom_simulation.py
```

### Customize Parameters

Edit the `main()` function in `custom_simulation.py`:

```python
def main() -> None:
    """Run a short simulation with custom parameters"""
    
    run_custom_simulation(
        num_events=200,          # Total events to generate
        events_per_second=50,    # Target rate
        num_users=50             # Number of unique badge holders
    )
```

---

## For Full Functionality

**To actually send events to Snowflake via REST API:**

👉 **Use `notebooks/RFID_Simulator.ipynb`**

The Jupyter Notebook includes:
- ✅ Complete JWT authentication
- ✅ Snowpipe Streaming REST API client
- ✅ Channel management (open/close)
- ✅ Batch insertion with continuation tokens
- ✅ Real-time validation queries
- ✅ Performance metrics

---

## Event Structure

Sample generated event:

```json
{
  "badge_id": "BADGE-00042",
  "user_id": "USR-042",
  "zone_id": "ZONE-OFFICE-2",
  "event_timestamp": "2024-11-04T15:23:45.120000Z",
  "event_type": "ENTRY",
  "reader_id": "RDR-003",
  "signal_strength": -45,
  "direction": "ENTRY"
}
```

---

## Dependencies

```bash
pip install snowflake-snowpark-python cryptography requests
```

**Note:** If running outside a Snowflake Notebook, you'll need to configure Snowpark session manually.

---

## Project Structure

```
examples/
├── README.md                   # This file
└── custom_simulation.py        # Event generation example

notebooks/
└── RFID_Simulator.ipynb        # Full simulation with REST API (recommended)
```
