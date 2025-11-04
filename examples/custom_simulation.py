"""
DEMO: simple-stream - Custom RFID Event Simulation Example

This standalone script demonstrates how to generate and send RFID badge events
to Snowflake using the Snowpipe Streaming REST API with custom parameters.

USAGE:
    python examples/custom_simulation.py

PREREQUISITES:
    1. Snowflake setup complete (database, pipe, secrets configured)
    2. Install dependencies: pip install snowflake-snowpark-python cryptography requests
    3. Run from Snowflake Notebook or configure Snowpark session

NOTE: This is a simplified example. For full simulation capabilities, use the
      RFID_Simulator.ipynb Jupyter Notebook.
"""

import json
import random
import time
from datetime import datetime, timedelta

import snowflake.snowpark as snowpark
import _snowflake


def get_session():
    """Get active Snowflake session (works in Snowflake Notebooks)"""
    return snowpark.context.get_active_session()


def load_config():
    """Load configuration from Snowflake secrets"""
    return {
        'account': _snowflake.get_generic_secret_string('RFID_ACCOUNT'),
        'user': _snowflake.get_generic_secret_string('RFID_USER'),
        'private_key_pem': _snowflake.get_generic_secret_string('RFID_JWT_PRIVATE_KEY'),
        'database': 'SNOWFLAKE_EXAMPLE',
        'schema': 'STAGE_BADGE_TRACKING',
        'pipe': 'BADGE_EVENTS_PIPE'
    }


class BadgeEventGenerator:
    """Generate realistic RFID badge events"""
    
    def __init__(self, num_users: int = 50, num_zones: int = 10, num_readers: int = 5):
        self.badge_ids = [f"BADGE-{str(i).zfill(5)}" for i in range(1, num_users + 1)]
        self.user_ids = [f"USR-{str(i).zfill(3)}" for i in range(1, num_users + 1)]
        self.zone_ids = [
            f"ZONE-{zone_type}-{i}" 
            for zone_type in ["LOBBY", "OFFICE", "CONF", "SECURE", "PARKING"]
            for i in range(1, (num_zones // 5) + 1)
        ]
        self.reader_ids = [f"RDR-{str(i).zfill(3)}" for i in range(1, num_readers + 1)]
        self.directions = ["ENTRY", "EXIT"]
    
    def generate_event(self, timestamp: datetime = None) -> dict:
        """Generate a single badge event"""
        if timestamp is None:
            timestamp = datetime.utcnow()
        
        user_idx = random.randint(0, len(self.user_ids) - 1)
        
        return {
            "badge_id": self.badge_ids[user_idx],
            "user_id": self.user_ids[user_idx],
            "zone_id": random.choice(self.zone_ids),
            "event_timestamp": timestamp.isoformat() + "Z",
            "event_type": random.choice(self.directions),
            "reader_id": random.choice(self.reader_ids),
            "signal_strength": random.randint(-85, -20),
            "direction": random.choice(self.directions)
        }
    
    def generate_batch(self, count: int = 100, start_time: datetime = None) -> list:
        """Generate a batch of events with slight time offsets"""
        if start_time is None:
            start_time = datetime.utcnow()
        
        events = []
        for i in range(count):
            timestamp = start_time + timedelta(seconds=i * 0.01)
            events.append(self.generate_event(timestamp))
        
        return events


def run_custom_simulation(
    num_events: int = 100,
    events_per_second: int = 50,
    num_users: int = 50
) -> None:
    """
    Run a custom RFID simulation with specified parameters.
    
    Args:
        num_events: Total number of events to generate
        events_per_second: Target ingestion rate
        num_users: Number of unique badge holders to simulate
    """
    print("=" * 70)
    print("🚀 Custom RFID Badge Event Simulation")
    print("=" * 70)
    print(f"\nParameters:")
    print(f"  Events: {num_events}")
    print(f"  Rate: {events_per_second} events/sec")
    print(f"  Users: {num_users}")
    print()
    
    # Initialize generator
    generator = BadgeEventGenerator(num_users=num_users, num_zones=10, num_readers=5)
    
    # Generate all events upfront
    print("📊 Generating events...")
    events = generator.generate_batch(count=num_events)
    print(f"✅ Generated {len(events)} events")
    
    # Display sample
    print(f"\n📋 Sample event:")
    print(json.dumps(events[0], indent=2))
    
    # NOTE: Actual REST API sending would require the full SnowpipeStreamingClient
    # from the notebook. For this example, we just show event generation.
    # To actually send data, use the RFID_Simulator.ipynb notebook.
    
    print("\n" + "=" * 70)
    print("✅ Simulation complete!")
    print("=" * 70)
    print("\n💡 To send these events to Snowflake, use RFID_Simulator.ipynb")
    print("   which includes the full REST API client implementation.")


def main() -> None:
    """Run a short simulation with custom parameters"""
    
    # Customize these parameters for your test:
    run_custom_simulation(
        num_events=200,          # Generate 200 events
        events_per_second=50,    # At 50 events/sec rate
        num_users=50             # From 50 unique badge holders
    )


if __name__ == "__main__":
    main()
