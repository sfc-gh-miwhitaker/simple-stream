"""Example: generate a short burst of RFID events with custom parameters."""

from python.simulator.simulator import RFIDSimulator
from python.simulator.config import Config


def main() -> None:
    """Run a 2-minute simulation at a modest rate."""
    config = Config()
    simulator = RFIDSimulator(config)
    simulator.run(duration_days=0, events_per_second=50)


if __name__ == "__main__":
    main()
