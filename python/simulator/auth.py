"""
JWT authentication for Snowflake Snowpipe Streaming REST API.

This module handles key-pair authentication and JWT token generation
for secure communication with Snowflake.
"""

import jwt
import hashlib
import base64
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend


class SnowflakeAuth:
    """
    Handles JWT token generation for Snowflake authentication.
    
    Uses RS256 algorithm with private key for secure authentication.
    """
    
    def __init__(
        self,
        account: str,
        user: str,
        private_key_path: str,
        private_key_passphrase: Optional[str] = None
    ):
        """
        Initialize Snowflake authentication.
        
        Args:
            account: Snowflake account identifier (e.g., MYORG)
            user: Snowflake user name
            private_key_path: Path to RSA private key file (PEM format)
            private_key_passphrase: Optional passphrase for encrypted key
        """
        self.account = account
        self.user = user
        self.private_key_path = private_key_path
        self.private_key_passphrase = private_key_passphrase
        self.private_key = None
        self.public_key_fingerprint = None
        
        self._load_private_key()
        self._calculate_public_key_fingerprint()
    
    def _load_private_key(self) -> None:
        """
        Load private key from file.
        
        Raises:
            FileNotFoundError: If private key file doesn't exist
            ValueError: If private key format is invalid
        """
        key_path = Path(self.private_key_path)
        
        if not key_path.exists():
            raise FileNotFoundError(f"Private key file not found: {self.private_key_path}")
        
        with open(key_path, "rb") as key_file:
            key_data = key_file.read()
        
        passphrase = self.private_key_passphrase.encode() if self.private_key_passphrase else None
        
        try:
            self.private_key = serialization.load_pem_private_key(
                key_data,
                password=passphrase,
                backend=default_backend()
            )
        except TypeError as e:
            if "Password was given but private key is not encrypted" in str(e):
                print(f"DEBUG: Key path: {self.private_key_path}")
                print(f"DEBUG: Passphrase provided: {self.private_key_passphrase is not None}")
                print(f"DEBUG: Key header: {key_data[:50]}")
                raise ValueError(
                    f"Your private key is not encrypted, but a passphrase was provided. "
                    f"Either remove SNOWFLAKE_PRIVATE_KEY_PASSPHRASE from .env, or use an encrypted key."
                )
            raise ValueError(f"Failed to load private key: {str(e)}")
        except Exception as e:
            raise ValueError(f"Failed to load private key: {str(e)}")
    
    def _calculate_public_key_fingerprint(self) -> None:
        """
        Calculate the SHA256 fingerprint of the public key.
        
        This is required for the JWT issuer field.
        """
        public_key = self.private_key.public_key()
        
        public_key_der = public_key.public_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        )
        
        sha256_hash = hashlib.sha256(public_key_der).digest()
        
        self.public_key_fingerprint = 'SHA256:' + base64.b64encode(sha256_hash).decode('utf-8')
    
    def generate_jwt_token(self, expiration_minutes: int = 59) -> str:
        """
        Generate a JWT token for Snowflake authentication.
        
        The token is valid for the specified duration (max 60 minutes).
        
        Args:
            expiration_minutes: Token validity period (default: 59 minutes, max: 60)
            
        Returns:
            JWT token string
            
        Raises:
            ValueError: If expiration exceeds 60 minutes
        """
        if expiration_minutes > 60:
            raise ValueError("JWT token expiration cannot exceed 60 minutes")
        
        now = datetime.utcnow()
        
        qualified_username = f"{self.account}.{self.user}".upper()
        
        payload = {
            "iss": f"{qualified_username}.{self.public_key_fingerprint}",
            "sub": qualified_username,
            "iat": now,
            "exp": now + timedelta(minutes=expiration_minutes)
        }
        
        token = jwt.encode(
            payload,
            self.private_key,
            algorithm="RS256"
        )
        
        return token
    
    def get_auth_header(self) -> dict:
        """
        Get Authorization header with fresh JWT token.
        
        Returns:
            Dictionary with Authorization header
        """
        token = self.generate_jwt_token()
        return {"Authorization": f"Bearer {token}"}


def generate_keypair(output_dir: str = ".") -> tuple:
    """
    Generate an RSA key pair for Snowflake authentication.
    
    This is a utility function for initial setup. The public key must be
    registered with Snowflake using:
    ALTER USER <username> SET RSA_PUBLIC_KEY='<public_key>';
    
    Args:
        output_dir: Directory to save key files (default: current directory)
        
    Returns:
        Tuple of (private_key_path, public_key_path)
    """
    from cryptography.hazmat.primitives.asymmetric import rsa
    
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
        backend=default_backend()
    )
    
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )
    
    public_key = private_key.public_key()
    public_pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    
    private_key_path = output_path / "private_key.pem"
    public_key_path = output_path / "public_key.pem"
    
    with open(private_key_path, "wb") as f:
        f.write(private_pem)
    
    with open(public_key_path, "wb") as f:
        f.write(public_pem)
    
    public_key_content = public_pem.decode("utf-8")
    public_key_oneline = public_key_content.replace("-----BEGIN PUBLIC KEY-----\n", "")
    public_key_oneline = public_key_oneline.replace("\n-----END PUBLIC KEY-----\n", "")
    public_key_oneline = public_key_oneline.replace("\n", "")
    
    print(f"Private key saved to: {private_key_path}")
    print(f"Public key saved to: {public_key_path}")
    print("\nTo register the public key with Snowflake, run:")
    print(f"ALTER USER <username> SET RSA_PUBLIC_KEY='{public_key_oneline}';")
    
    return str(private_key_path), str(public_key_path)

