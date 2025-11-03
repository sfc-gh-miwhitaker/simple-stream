"""
RFID Badge Tracking Simulator - Main Entry Point.

This module provides the main simulator for generating and sending
RFID badge events to Snowflake via Snowpipe Streaming REST API.
"""

import argparse
import logging
import math
import time
from datetime import datetime, timedelta, timezone
from typing import Optional

from .config import Config
from .auth import SnowflakeAuth
from .rest_client import SnowpipeStreamingClient
from .event_generator import BadgeEventGenerator
from ..shared.validation import validate_batch


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class RFIDSimulator:
    """
    Main RFID badge tracking simulator.
    
    Generates realistic badge events and streams them to Snowflake
    using the Snowpipe Streaming REST API.
    """
    
    def __init__(self, config: Optional[Config] = None):
        """
        Initialize simulator.
        
        Args:
            config: Configuration object (creates default if None)
        """
        self.config = config or Config()
        self.config.validate()
        
        logger.info(f"Initializing RFID Simulator: {self.config}")
        
        self.auth = SnowflakeAuth(
            account=self.config.snowflake_account,
            user=self.config.snowflake_user,
            private_key_path=self.config.private_key_path,
            private_key_passphrase=self.config.private_key_passphrase
        )
        
        self.client = SnowpipeStreamingClient(
            auth=self.auth,
            database=self.config.snowflake_database,
            schema=self.config.snowflake_schema,
            pipe=self.config.snowflake_pipe
        )
        
        self.generator = BadgeEventGenerator(
            num_users=self.config.num_users,
            num_zones=self.config.num_zones,
            num_readers=self.config.num_readers
        )
        
        self.total_events_sent = 0
        self.total_events_rejected = 0
        self.start_time = None
    
    def run(
        self,
        duration_days: Optional[int] = None,
        events_per_second: Optional[int] = None
    ) -> None:
        """
        Run the simulator for specified duration.
        
        Args:
            duration_days: Simulation duration (defaults to config)
            events_per_second: Event rate (defaults to config)
        """
        duration_days = duration_days or self.config.simulation_duration_days
        events_per_second = events_per_second or self.config.events_per_second
        
        logger.info(f"Starting {duration_days}-day simulation at {events_per_second} events/sec")
        
        self.start_time = datetime.now(timezone.utc)
        
        try:
            logger.info("Opening streaming channel...")
            self.client.open_channel(self.config.channel_name)
            
            total_seconds = duration_days * 24 * 3600
            batch_interval = self.config.batch_size / events_per_second
            if batch_interval <= 0:
                raise ValueError("Calculated batch_interval must be positive")
            
            logger.info(f"Generating events for {duration_days} days...")
            logger.info(f"Batch size: {self.config.batch_size}, Interval: {batch_interval:.2f}s")
            
            simulation_start = datetime.now(timezone.utc) - timedelta(days=duration_days)

            total_batches = max(1, math.ceil(total_seconds / batch_interval))
            
            for batch_index in range(total_batches):
                elapsed_seconds = batch_index * batch_interval
                batch_timestamp = simulation_start + timedelta(seconds=elapsed_seconds)
                
                events = self.generator.generate_batch(
                    count=self.config.batch_size,
                    start_timestamp=batch_timestamp
                )
                
                valid_events, rejected = validate_batch(
                    events,
                    strict_mode=self.config.strict_validation
                )
                
                if rejected:
                    logger.warning(f"Rejected {len(rejected)} events due to validation failures")
                    self.total_events_rejected += len(rejected)
                
                if valid_events:
                    self.client.insert_rows(valid_events)
                    self.total_events_sent += len(valid_events)
                
                if self.total_events_sent % 10000 == 0 and self.total_events_sent > 0:
                    self._log_progress(elapsed_seconds, total_seconds)
                
                time.sleep(batch_interval)
            
            logger.info("Checking final channel status...")
            status = self.client.get_channel_status()
            logger.info(f"Channel status: {status}")
            
        except KeyboardInterrupt:
            logger.info("Simulation interrupted by user")
        except Exception as e:
            logger.error(f"Simulation error: {str(e)}", exc_info=True)
            raise
        finally:
            self._log_summary()
    
    def run_continuous(self, events_per_second: Optional[int] = None) -> None:
        """
        Run simulator continuously until interrupted.
        
        Args:
            events_per_second: Event rate (defaults to config)
        """
        events_per_second = events_per_second or self.config.events_per_second
        
        logger.info(f"Starting continuous simulation at {events_per_second} events/sec")
        logger.info("Press Ctrl+C to stop")
        
        self.start_time = datetime.now(timezone.utc)
        
        try:
            logger.info("Opening streaming channel...")
            self.client.open_channel(self.config.channel_name)
            
            batch_interval = self.config.batch_size / events_per_second
            if batch_interval <= 0:
                raise ValueError("Calculated batch_interval must be positive")
            
            while True:
                events = self.generator.generate_batch(
                    count=self.config.batch_size
                )
                
                valid_events, rejected = validate_batch(
                    events,
                    strict_mode=self.config.strict_validation
                )
                
                if rejected:
                    self.total_events_rejected += len(rejected)
                
                if valid_events:
                    self.client.insert_rows(valid_events)
                    self.total_events_sent += len(valid_events)
                
                if self.total_events_sent % 10000 == 0 and self.total_events_sent > 0:
                    logger.info(f"Events sent: {self.total_events_sent:,}")
                
                time.sleep(batch_interval)
                
        except KeyboardInterrupt:
            logger.info("Simulation stopped by user")
        finally:
            self._log_summary()
    
    def _log_progress(self, elapsed: float, total: float) -> None:
        """Log progress update."""
        if total <= 0:
            total = 1
        pct = min(100.0, (elapsed / total) * 100)
        logger.info(
            f"Progress: {pct:.1f}% | "
            f"Events sent: {self.total_events_sent:,} | "
            f"Rejected: {self.total_events_rejected:,}"
        )
    
    def _log_summary(self) -> None:
        """Log simulation summary."""
        if self.start_time:
            duration = (datetime.now(timezone.utc) - self.start_time).total_seconds()
            avg_rate = self.total_events_sent / duration if duration > 0 else 0
            
            logger.info("=" * 60)
            logger.info("SIMULATION SUMMARY")
            logger.info("=" * 60)
            logger.info(f"Total events sent: {self.total_events_sent:,}")
            logger.info(f"Total events rejected: {self.total_events_rejected:,}")
            logger.info(f"Duration: {duration:.1f} seconds")
            logger.info(f"Average rate: {avg_rate:.1f} events/sec")
            logger.info("=" * 60)


def main():
    """Main entry point for CLI."""
    parser = argparse.ArgumentParser(
        description="RFID Badge Tracking Simulator for Snowflake"
    )
    
    parser.add_argument(
        "--duration-days",
        type=int,
        help="Simulation duration in days (default: from config)"
    )
    
    parser.add_argument(
        "--events-per-second",
        type=int,
        help="Events per second rate (default: from config)"
    )
    
    parser.add_argument(
        "--continuous",
        action="store_true",
        help="Run continuously until interrupted"
    )
    
    parser.add_argument(
        "--config",
        type=str,
        help="Path to .env configuration file"
    )
    
    args = parser.parse_args()
    
    config = Config(env_file=args.config) if args.config else Config()
    
    simulator = RFIDSimulator(config)
    
    if args.continuous:
        simulator.run_continuous(events_per_second=args.events_per_second)
    else:
        simulator.run(
            duration_days=args.duration_days,
            events_per_second=args.events_per_second
        )


if __name__ == "__main__":
    main()

