"""
Snowflake Snowpipe Streaming REST API client.

This module provides a client for interacting with Snowflake's native
Snowpipe Streaming REST API for high-performance data ingestion.
"""

import requests
import time
import logging
import json
from typing import List, Dict, Any, Optional
from .auth import SnowflakeAuth
from ..shared.models import BadgeEvent, ChannelOpenResponse


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SnowpipeStreamingClient:
    """
    Client for Snowflake Snowpipe Streaming REST API.
    
    Handles the complete workflow:
    1. Get control plane hostname
    2. Open a streaming channel
    3. Insert rows into the channel
    4. Check channel status
    5. Close the channel
    """
    
    def __init__(
        self,
        auth: SnowflakeAuth,
        database: str,
        schema: str,
        pipe: str,
        account_url: Optional[str] = None
    ):
        """
        Initialize Snowpipe Streaming client.
        
        Args:
            auth: SnowflakeAuth instance for JWT authentication
            database: Snowflake database name
            schema: Snowflake schema name
            pipe: Snowflake pipe name
            account_url: Optional account URL (defaults to standard format)
        """
        self.auth = auth
        self.database = database
        self.schema = schema
        self.pipe = pipe
        
        if account_url:
            self.account_url = account_url
        else:
            account_for_url = auth.account.replace('_', '-').lower()
            self.account_url = f"https://{account_for_url}.snowflakecomputing.com"
        
        self.control_host = None
        self.ingest_host = None
        self.channel_name = None
        self.scoped_token = None
        self.continuation_token = None
        self.offset_token = None
        
        self.session = requests.Session()
        self.session.headers.update({
            "Content-Type": "application/json",
            "Accept": "application/json"
        })
    
    def get_control_host(self) -> str:
        """
        Get the control plane hostname for the account.
        
        Returns:
            Control plane hostname
            
        Raises:
            RuntimeError: If API call fails
        """
        url = f"{self.account_url}/v2/streaming/hostname"
        headers = self.auth.get_auth_header()
        
        logger.info(f"Getting control plane hostname from {url}")
        
        response = self.session.get(url, headers=headers)
        
        if response.status_code != 200:
            raise RuntimeError(
                f"Failed to get control host: {response.status_code} - {response.text}"
            )
        
        if not response.text:
            raise RuntimeError("Empty response body from Snowflake API")
        
        hostname = response.text.strip()
        self.control_host = f"https://{hostname}"
        
        logger.info(f"Control plane hostname: {self.control_host}")
        return self.control_host
    
    def open_channel(self, channel_name: str) -> ChannelOpenResponse:
        """
        Open a streaming channel for ingestion.
        
        Args:
            channel_name: Name for the channel (e.g., "rfid_channel_001")
            
        Returns:
            ChannelOpenResponse with ingest host and tokens
            
        Raises:
            RuntimeError: If channel open fails
        """
        if not self.control_host:
            self.get_control_host()
        
        url = (
            f"{self.control_host}/v2/streaming/"
            f"databases/{self.database}/schemas/{self.schema}/"
            f"pipes/{self.pipe}/channels/{channel_name}"
        )
        
        headers = self.auth.get_auth_header()
        payload = {}
        
        logger.info(f"Opening channel '{channel_name}' at {url}")
        
        response = self.session.put(url, headers=headers, json=payload)
        
        if response.status_code != 200:
            raise RuntimeError(
                f"Failed to open channel: {response.status_code} - {response.text}"
            )
        
        data = response.json()
        logger.info(f"Channel open response: {data}")
        
        self.channel_name = channel_name
        self.ingest_host = self.control_host
        self.continuation_token = data.get('next_continuation_token')
        
        logger.info(f"Channel '{channel_name}' opened successfully")
        logger.info(f"Continuation token: {self.continuation_token}")
        
        return ChannelOpenResponse(**data)
    
    def insert_rows(self, events: List[BadgeEvent]) -> Dict[str, Any]:
        """
        Insert badge events into the streaming channel.
        
        Args:
            events: List of BadgeEvent objects to insert
            
        Returns:
            Response dictionary with insertion results
            
        Raises:
            RuntimeError: If insertion fails or channel not open
        """
        if not self.ingest_host or not self.channel_name:
            raise RuntimeError("Channel must be opened before inserting rows")
        
        url = (
            f"{self.ingest_host}/v2/streaming/data/"
            f"databases/{self.database}/schemas/{self.schema}/"
            f"pipes/{self.pipe}/channels/{self.channel_name}/rows"
        )
        
        params = {
            "continuationToken": self.continuation_token
        }
        
        ndjson_payload = "\n".join([
            json.dumps(event.to_snowflake_json())
            for event in events
        ]) + "\n"
        
        headers = self.auth.get_auth_header()
        headers["Content-Type"] = "application/x-ndjson"
        
        logger.debug(f"Inserting {len(events)} rows to {url}")
        
        response = self.session.post(url, headers=headers, params=params, data=ndjson_payload)
        
        if response.status_code != 200:
            raise RuntimeError(
                f"Failed to insert rows: {response.status_code} - {response.text}"
            )
        
        data = response.json()
        
        if "next_continuation_token" in data:
            self.continuation_token = data["next_continuation_token"]
        
        logger.info(f"Successfully inserted {len(events)} rows")
        
        return data
    
    def get_channel_status(self) -> Dict[str, Any]:
        """
        Get the current status of the streaming channel.
        
        Returns:
            Channel status dictionary
            
        Raises:
            RuntimeError: If status check fails
        """
        if not self.control_host or not self.channel_name:
            raise RuntimeError("Channel must be opened before checking status")
        
        url = (
            f"{self.control_host}/v2/streaming/"
            f"databases/{self.database}/schemas/{self.schema}/"
            f"pipes/{self.pipe}:bulk-channel-status"
        )
        
        headers = self.auth.get_auth_header()
        payload = {"channel_names": [self.channel_name]}
        
        logger.debug(f"Checking channel status at {url}")
        
        response = self.session.post(url, headers=headers, json=payload)
        
        if response.status_code != 200:
            raise RuntimeError(
                f"Failed to get channel status: {response.status_code} - {response.text}"
            )
        
        data = response.json()
        channel_status = data.get("channel_statuses", {}).get(self.channel_name, {})
        
        logger.info(f"Channel status: {channel_status}")
        
        return channel_status
    
    def close_channel(self) -> None:
        """
        Close the streaming channel.
        
        Note: The REST API doesn't have an explicit close endpoint.
        Channels remain open until they timeout or are explicitly dropped.
        """
        logger.info(f"Channel '{self.channel_name}' will remain open for reuse")
        logger.info("Channels automatically timeout after period of inactivity")
    
    def __enter__(self):
        """Context manager entry."""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.session.close()

