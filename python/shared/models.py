"""
Pydantic models for RFID badge events.

This module defines the data models used throughout the application for
type safety, validation, and serialization.
"""

from datetime import datetime, timezone
from typing import Optional
from pydantic import BaseModel, Field, field_validator


class BadgeEvent(BaseModel):
    """
    Represents a single RFID badge scan event.
    
    This model is used for both API requests and internal processing.
    All fields are validated according to business rules.
    """
    
    badge_id: str = Field(
        ...,
        description="Unique badge identifier",
        min_length=1,
        max_length=50,
        examples=["BADGE-12345", "BADGE-00001"]
    )
    
    user_id: str = Field(
        ...,
        description="User associated with badge",
        min_length=1,
        max_length=50,
        examples=["USR-001", "USR-12345"]
    )
    
    zone_id: str = Field(
        ...,
        description="Zone where event occurred",
        min_length=1,
        max_length=50,
        examples=["ZONE-LOBBY-1", "ZONE-OFFICE-2A"]
    )
    
    reader_id: str = Field(
        ...,
        description="Badge reader that captured the event",
        min_length=1,
        max_length=50,
        examples=["RDR-101", "RDR-B101"]
    )
    
    event_timestamp: datetime = Field(
        ...,
        description="Timestamp when badge was scanned (ISO 8601 format)"
    )
    
    signal_strength: Optional[float] = Field(
        default=None,
        description="RFID signal strength in dBm (-100 to 0, or None)",
        ge=-100,
        le=0
    )
    
    direction: Optional[str] = Field(
        default=None,
        description="Direction of movement",
        pattern="^(ENTRY|EXIT)$"
    )
    
    @field_validator("event_timestamp")
    @classmethod
    def validate_timestamp(cls, v: datetime) -> datetime:
        """Ensure timestamp is not in the future."""
        if v.tzinfo is None:
            v = v.replace(tzinfo=timezone.utc)
        now = datetime.now(timezone.utc)
        if v > now:
            raise ValueError("Event timestamp cannot be in the future")
        return v
    
    def to_snowflake_json(self) -> dict:
        """
        Convert to JSON format expected by Snowflake REST API.
        
        Returns:
            Dictionary with ISO 8601 formatted timestamp
        """
        # Convert to UTC and format without timezone info for TIMESTAMP_NTZ
        # Snowflake Streaming API expects: "YYYY-MM-DDTHH:MM:SS.ffffff" (no Z or timezone)
        if self.event_timestamp.tzinfo is not None:
            utc_time = self.event_timestamp.astimezone(timezone.utc)
            timestamp_str = utc_time.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]  # Trim to milliseconds
        else:
            timestamp_str = self.event_timestamp.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]
        
        return {
            "badge_id": self.badge_id,
            "user_id": self.user_id,
            "zone_id": self.zone_id,
            "reader_id": self.reader_id,
            "event_timestamp": timestamp_str,
            "signal_strength": self.signal_strength,
            "direction": self.direction
        }
    
    class Config:
        """Pydantic configuration."""
        json_schema_extra = {
            "example": {
                "badge_id": "BADGE-12345",
                "user_id": "USR-001",
                "zone_id": "ZONE-LOBBY-1",
                "reader_id": "RDR-101",
                "event_timestamp": "2025-10-31T14:23:45.123Z",
                "signal_strength": -45.5,
                "direction": "ENTRY"
            }
        }


class ChannelOpenResponse(BaseModel):
    """Response from Snowflake when opening a streaming channel."""
    
    next_continuation_token: str = Field(..., description="Continuation token for next request")
    channel_status: dict = Field(..., description="Channel status information")


class InsertRowsResponse(BaseModel):
    """Response from Snowflake when inserting rows."""
    
    status: str = Field(..., description="Status of insertion")
    rows_inserted: int = Field(..., description="Number of rows successfully inserted")
    errors: Optional[list] = Field(default=None, description="Any errors encountered")

