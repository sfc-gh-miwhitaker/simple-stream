"""
Configuration management for the RFID simulator.

Loads configuration from environment variables and .env files.
"""

import os
from pathlib import Path
from typing import Optional
from dotenv import load_dotenv


class Config:
    """
    Configuration for the RFID simulator and Snowflake connection.
    
    Loads values from environment variables with sensible defaults.
    """
    
    def __init__(self, env_file: Optional[str] = None):
        """
        Initialize configuration.
        
        Args:
            env_file: Path to .env file. If None, looks for .env in config/
        """
        if env_file is None:
            config_dir = Path(__file__).parent.parent.parent / "config"
            env_file = config_dir / ".env"
        
        if Path(env_file).exists():
            load_dotenv(env_file)
    
    @property
    def snowflake_account(self) -> str:
        """Snowflake account identifier (e.g., MYORG)."""
        return os.getenv("SNOWFLAKE_ACCOUNT", "")
    
    @property
    def snowflake_user(self) -> str:
        """Snowflake user name."""
        return os.getenv("SNOWFLAKE_USER", "")
    
    @property
    def snowflake_database(self) -> str:
        """Snowflake database name."""
        return os.getenv("SNOWFLAKE_DATABASE", "SNOWFLAKE_EXAMPLE")
    
    @property
    def snowflake_schema(self) -> str:
        """Snowflake schema name."""
        return os.getenv("SNOWFLAKE_SCHEMA", "STAGE_BADGE_TRACKING")
    
    @property
    def snowflake_pipe(self) -> str:
        """Snowflake pipe name."""
        return os.getenv("SNOWFLAKE_PIPE", "BADGE_EVENTS_PIPE")
    
    @property
    def private_key_path(self) -> str:
        """Path to private key file for JWT authentication."""
        return os.getenv("SNOWFLAKE_PRIVATE_KEY_PATH", "")
    
    @property
    def private_key_passphrase(self) -> Optional[str]:
        """Passphrase for encrypted private key (optional)."""
        passphrase = os.getenv("SNOWFLAKE_PRIVATE_KEY_PASSPHRASE")
        return passphrase if passphrase else None
    
    @property
    def channel_name(self) -> str:
        """Name for the streaming channel."""
        return os.getenv("CHANNEL_NAME", "rfid_channel_001")
    
    @property
    def events_per_second(self) -> int:
        """Target events per second for simulation."""
        return int(os.getenv("EVENTS_PER_SECOND", "100"))
    
    @property
    def simulation_duration_days(self) -> int:
        """Duration of simulation in days."""
        return int(os.getenv("SIMULATION_DURATION_DAYS", "10"))
    
    @property
    def num_users(self) -> int:
        """Number of unique users to simulate."""
        return int(os.getenv("NUM_USERS", "500"))
    
    @property
    def num_zones(self) -> int:
        """Number of unique zones to simulate."""
        return int(os.getenv("NUM_ZONES", "50"))
    
    @property
    def num_readers(self) -> int:
        """Number of unique readers to simulate."""
        return int(os.getenv("NUM_READERS", "25"))
    
    @property
    def batch_size(self) -> int:
        """Number of events to send in each API request."""
        return int(os.getenv("BATCH_SIZE", "100"))
    
    @property
    def strict_validation(self) -> bool:
        """Enable strict validation (reject on warnings)."""
        return os.getenv("STRICT_VALIDATION", "false").lower() == "true"
    
    def validate(self) -> None:
        """
        Validate required configuration values are present.
        
        Raises:
            ValueError: If required configuration is missing
        """
        if not self.snowflake_account:
            raise ValueError("SNOWFLAKE_ACCOUNT is required")
        
        if not self.snowflake_user:
            raise ValueError("SNOWFLAKE_USER is required")
        
        if not self.private_key_path:
            raise ValueError("SNOWFLAKE_PRIVATE_KEY_PATH is required")
        
        if not Path(self.private_key_path).exists():
            raise ValueError(f"Private key file not found: {self.private_key_path}")
    
    def __repr__(self) -> str:
        """String representation (hides sensitive data)."""
        return (
            f"Config(account={self.snowflake_account}, "
            f"user={self.snowflake_user}, "
            f"database={self.snowflake_database}, "
            f"schema={self.snowflake_schema}, "
            f"pipe={self.snowflake_pipe})"
        )

