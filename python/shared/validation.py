"""
Data quality validation for RFID badge events.

This module provides validation functions to ensure data quality
before ingestion into Snowflake.
"""

from datetime import datetime, timedelta, timezone
from typing import List, Tuple
from .models import BadgeEvent


class ValidationError(Exception):
    """Raised when data validation fails."""
    pass


class DataQualityValidator:
    """
    Validates badge events against business rules and data quality standards.
    """
    
    def __init__(self, strict_mode: bool = False):
        """
        Initialize validator.
        
        Args:
            strict_mode: If True, reject events on warnings. If False, log warnings only.
        """
        self.strict_mode = strict_mode
        self.validation_errors = []
        self.validation_warnings = []
    
    def validate_event(self, event: BadgeEvent) -> Tuple[bool, List[str]]:
        """
        Validate a single badge event.
        
        Args:
            event: BadgeEvent to validate
            
        Returns:
            Tuple of (is_valid, list of error/warning messages)
        """
        self.validation_errors = []
        self.validation_warnings = []
        
        self._validate_required_fields(event)
        self._validate_timestamp(event)
        self._validate_signal_strength(event)
        self._validate_identifiers(event)
        
        messages = self.validation_errors + self.validation_warnings
        is_valid = len(self.validation_errors) == 0
        
        if self.strict_mode and self.validation_warnings:
            is_valid = False
        
        return is_valid, messages
    
    def _validate_required_fields(self, event: BadgeEvent) -> None:
        """Ensure all required fields are present and non-empty."""
        if not event.badge_id or not event.badge_id.strip():
            self.validation_errors.append("badge_id is required and cannot be empty")
        
        if not event.user_id or not event.user_id.strip():
            self.validation_errors.append("user_id is required and cannot be empty")
        
        if not event.zone_id or not event.zone_id.strip():
            self.validation_errors.append("zone_id is required and cannot be empty")
        
        if not event.reader_id or not event.reader_id.strip():
            self.validation_errors.append("reader_id is required and cannot be empty")
        
        if not event.event_timestamp:
            self.validation_errors.append("event_timestamp is required")
    
    def _validate_timestamp(self, event: BadgeEvent) -> None:
        """Validate event timestamp for reasonableness."""
        now = datetime.now(timezone.utc)

        event_ts = event.event_timestamp
        if event_ts.tzinfo is None:
            event_ts = event_ts.replace(tzinfo=timezone.utc)

        if event_ts > now:
            self.validation_errors.append(
                f"Event timestamp {event.event_timestamp} is in the future"
            )

        thirty_days_ago = now - timedelta(days=30)
        if event_ts < thirty_days_ago:
            self.validation_warnings.append(
                f"Event timestamp {event.event_timestamp} is more than 30 days old"
            )

        one_second_ago = now - timedelta(seconds=1)
        if event_ts < one_second_ago:
            time_diff = (now - event_ts).total_seconds()
            if time_diff > 3600:
                self.validation_warnings.append(
                    f"Event is {time_diff/3600:.1f} hours old"
                )
    
    def _validate_signal_strength(self, event: BadgeEvent) -> None:
        """Validate RFID signal strength is within expected range."""
        if event.signal_strength is None:
            return
        
        if event.signal_strength > 0:
            self.validation_errors.append(
                f"Signal strength {event.signal_strength} dBm cannot be positive"
            )
        
        if event.signal_strength < -100:
            self.validation_errors.append(
                f"Signal strength {event.signal_strength} dBm is too weak (< -100 dBm)"
            )
        
        if event.signal_strength < -80:
            self.validation_warnings.append(
                f"Weak signal strength: {event.signal_strength} dBm"
            )
    
    def _validate_identifiers(self, event: BadgeEvent) -> None:
        """Validate identifier formats."""
        if event.badge_id and len(event.badge_id) > 50:
            self.validation_errors.append("badge_id exceeds maximum length of 50")
        
        if event.user_id and len(event.user_id) > 50:
            self.validation_errors.append("user_id exceeds maximum length of 50")
        
        if event.zone_id and len(event.zone_id) > 50:
            self.validation_errors.append("zone_id exceeds maximum length of 50")
        
        if event.reader_id and len(event.reader_id) > 50:
            self.validation_errors.append("reader_id exceeds maximum length of 50")


def validate_batch(events: List[BadgeEvent], strict_mode: bool = False) -> Tuple[List[BadgeEvent], List[dict]]:
    """
    Validate a batch of events.
    
    Args:
        events: List of BadgeEvent objects to validate
        strict_mode: If True, reject events with warnings
        
    Returns:
        Tuple of (valid_events, rejected_events_with_reasons)
    """
    validator = DataQualityValidator(strict_mode=strict_mode)
    
    valid_events = []
    rejected_events = []
    
    for event in events:
        is_valid, messages = validator.validate_event(event)
        
        if is_valid:
            valid_events.append(event)
        else:
            rejected_events.append({
                "event": event.model_dump(),
                "reasons": messages
            })
    
    return valid_events, rejected_events

