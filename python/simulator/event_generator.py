"""
RFID badge event generator.

This module generates realistic badge scan events for simulation purposes.
"""

import random
from datetime import datetime, timedelta, timezone
from typing import List
from ..shared.models import BadgeEvent


class BadgeEventGenerator:
    """
    Generates realistic RFID badge scan events.
    
    Simulates badge holders moving through a property with zones,
    generating events with realistic patterns and signal characteristics.
    """
    
    def __init__(
        self,
        num_users: int = 500,
        num_zones: int = 50,
        num_readers: int = 25
    ):
        """
        Initialize event generator.
        
        Args:
            num_users: Number of unique users to simulate
            num_zones: Number of unique zones in the property
            num_readers: Number of unique badge readers
        """
        self.num_users = num_users
        self.num_zones = num_zones
        self.num_readers = num_readers
        
        self.badge_ids = [f"BADGE-{str(i).zfill(5)}" for i in range(1, num_users + 1)]
        self.user_ids = [f"USR-{str(i).zfill(3)}" for i in range(1, num_users + 1)]
        self.zone_ids = [f"ZONE-{zone_type}-{i}" 
                        for zone_type in ["LOBBY", "OFFICE", "CONF", "SECURE", "PARKING"]
                        for i in range(1, (num_zones // 5) + 1)]
        self.reader_ids = [f"RDR-{str(i).zfill(3)}" for i in range(1, num_readers + 1)]
        
        self.directions = ["ENTRY", "EXIT"]
        
        self.user_badge_mapping = dict(zip(self.user_ids, self.badge_ids))
    
    def generate_event(
        self,
        timestamp: datetime = None,
        user_id: str = None,
        badge_id: str = None
    ) -> BadgeEvent:
        """
        Generate a single badge scan event.
        
        Args:
            timestamp: Event timestamp (defaults to current time)
            user_id: Specific user ID (random if not provided)
            badge_id: Specific badge ID (random if not provided)
            
        Returns:
            BadgeEvent instance
        """
        if timestamp is None:
            timestamp = datetime.now(timezone.utc)
        
        if user_id is None:
            user_id = random.choice(self.user_ids)
        
        if badge_id is None:
            badge_id = self.user_badge_mapping.get(
                user_id,
                random.choice(self.badge_ids)
            )
        
        zone_id = random.choice(self.zone_ids)
        reader_id = random.choice(self.reader_ids)
        
        signal_strength = self._generate_signal_strength(zone_id)
        
        direction = random.choice(self.directions) if random.random() > 0.1 else None
        
        return BadgeEvent(
            badge_id=badge_id,
            user_id=user_id,
            zone_id=zone_id,
            reader_id=reader_id,
            event_timestamp=timestamp,
            signal_strength=signal_strength,
            direction=direction
        )
    
    def generate_batch(
        self,
        count: int,
        start_timestamp: datetime = None
    ) -> List[BadgeEvent]:
        """
        Generate a batch of events.
        
        Events are spread across a short time window (1 second) for realism.
        
        Args:
            count: Number of events to generate
            start_timestamp: Starting timestamp (defaults to current time)
            
        Returns:
            List of BadgeEvent instances
        """
        if start_timestamp is None:
            start_timestamp = datetime.now(timezone.utc)
        
        events = []
        
        for i in range(count):
            offset_ms = (i * 1000) // count
            timestamp = start_timestamp + timedelta(milliseconds=offset_ms)
            
            event = self.generate_event(timestamp=timestamp)
            events.append(event)
        
        return events
    
    def generate_time_series(
        self,
        duration_seconds: int,
        events_per_second: float,
        start_timestamp: datetime = None
    ) -> List[BadgeEvent]:
        """
        Generate events over a time period at specified rate.
        
        Args:
            duration_seconds: Duration to generate events for
            events_per_second: Target event rate
            start_timestamp: Starting timestamp (defaults to current time)
            
        Returns:
            List of BadgeEvent instances
        """
        if start_timestamp is None:
            start_timestamp = datetime.now(timezone.utc)
        
        total_events = int(duration_seconds * events_per_second)
        events = []
        
        for i in range(total_events):
            time_offset = (i / events_per_second)
            timestamp = start_timestamp + timedelta(seconds=time_offset)
            
            event = self.generate_event(timestamp=timestamp)
            events.append(event)
        
        return events
    
    def generate_with_patterns(
        self,
        base_timestamp: datetime,
        duration_hours: int = 24
    ) -> List[BadgeEvent]:
        """
        Generate events with realistic daily patterns.
        
        Simulates:
        - Morning arrival surge (7-9 AM)
        - Lunch period activity (12-1 PM)
        - Evening departure surge (5-7 PM)
        - Low overnight activity
        
        Args:
            base_timestamp: Starting timestamp
            duration_hours: Duration in hours
            
        Returns:
            List of BadgeEvent instances
        """
        events = []
        
        for hour in range(duration_hours):
            current_time = base_timestamp + timedelta(hours=hour)
            hour_of_day = current_time.hour
            
            if 7 <= hour_of_day < 9:
                rate = 200
            elif 12 <= hour_of_day < 13:
                rate = 150
            elif 17 <= hour_of_day < 19:
                rate = 180
            elif 9 <= hour_of_day < 17:
                rate = 50
            else:
                rate = 10
            
            hourly_events = self.generate_time_series(
                duration_seconds=3600,
                events_per_second=rate / 3600,
                start_timestamp=current_time
            )
            events.extend(hourly_events)
        
        return events
    
    def _generate_signal_strength(self, zone_id: str) -> float:
        """
        Generate realistic signal strength based on zone type.
        
        Args:
            zone_id: Zone identifier
            
        Returns:
            Signal strength in dBm (between -100 and 0)
        """
        if "PARKING" in zone_id:
            return random.uniform(-75, -50)
        elif "LOBBY" in zone_id:
            return random.uniform(-60, -30)
        elif "OFFICE" in zone_id or "CONF" in zone_id:
            return random.uniform(-55, -35)
        elif "SECURE" in zone_id:
            return random.uniform(-50, -25)
        else:
            return random.uniform(-70, -40)

