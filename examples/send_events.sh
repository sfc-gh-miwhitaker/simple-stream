#!/bin/bash
################################################################################
# Snowpipe Streaming - Event Sender Demo
# 
# PURPOSE: Demonstrate end-to-end data ingestion to Snowflake using JWT auth
# USAGE:   ./send_events.sh
# 
# REQUIREMENTS:
#   - Python 3.7+
#   - pip install PyJWT cryptography requests
#   - rsa_key.p8 file in same directory
#   - Account credentials (see configuration below)
################################################################################

set -e  # Exit on error

# ============================================================================
# CONFIGURATION - Update these values from sql/07_api_handoff.sql output
# ============================================================================

ACCOUNT_ID="YOUR_ORG-YOUR_ACCOUNT"           # e.g., "SFSENORTHAMERICA-MWHITAKER_AWS"
USERNAME="sfe_ingest_user"
PRIVATE_KEY_PATH="./rsa_key.p8"
PIPE_ENDPOINT="https://${ACCOUNT_ID}.snowflakecomputing.com/v1/data/pipes/SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE/insertRows"

# ============================================================================
# Validate prerequisites
# ============================================================================

echo "================================================================"
echo "Snowpipe Streaming Event Sender"
echo "================================================================"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 not found. Install Python 3.7+"
    exit 1
fi

# Check private key
if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo "ERROR: Private key not found at $PRIVATE_KEY_PATH"
    echo "Place rsa_key.p8 in the same directory as this script"
    exit 1
fi

# Check configuration
if [ "$ACCOUNT_ID" = "YOUR_ORG-YOUR_ACCOUNT" ]; then
    echo "ERROR: ACCOUNT_ID not configured"
    echo "Edit this script and update ACCOUNT_ID with your Snowflake account"
    exit 1
fi

echo "✓ Python 3 found: $(python3 --version)"
echo "✓ Private key found: $PRIVATE_KEY_PATH"
echo "✓ Account ID: $ACCOUNT_ID"
echo ""

# ============================================================================
# Check Python dependencies
# ============================================================================

echo "Checking Python dependencies..."
python3 -c "import jwt, cryptography, requests" 2>/dev/null || {
    echo "Missing dependencies. Installing..."
    pip3 install PyJWT cryptography requests
}
echo "✓ Dependencies ready"
echo ""

# ============================================================================
# Python Script - Token Manager & Event Sender
# ============================================================================

python3 - <<EOF
import sys
import jwt
import json
import datetime
import requests
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

class SnowpipeAuthManager:
    """Production-ready JWT token manager with auto-refresh"""
    
    def __init__(self, private_key_path, account_id, username):
        self.account_id = account_id
        self.username = username
        self.token = None
        self.token_expiry = None
        
        # Load private key once at startup
        with open(private_key_path, "rb") as key_file:
            self.private_key = serialization.load_pem_private_key(
                key_file.read(),
                password=None,
                backend=default_backend()
            )
    
    def get_token(self):
        """Get current token, refresh if needed"""
        now = datetime.datetime.utcnow()
        
        # Generate new token if none exists or expires in < 5 min
        if not self.token or not self.token_expiry or \
           (self.token_expiry - now).total_seconds() < 300:
            self._generate_token()
        
        return self.token
    
    def _generate_token(self):
        """Generate new JWT token"""
        now = datetime.datetime.utcnow()
        qualified_username = f"{self.account_id}.{self.username}"
        
        payload = {
            "iss": qualified_username,
            "sub": qualified_username,
            "iat": now,
            "exp": now + datetime.timedelta(minutes=59)
        }
        
        self.token = jwt.encode(payload, self.private_key, algorithm="RS256")
        self.token_expiry = payload["exp"]
        print(f"✓ JWT token generated (expires: {payload['exp'].strftime('%H:%M:%S')})")


def send_event(auth, endpoint, event_data):
    """Send single event to Snowpipe"""
    token = auth.get_token()
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    response = requests.post(endpoint, json=event_data, headers=headers)
    return response


def main():
    print("================================================================")
    print("Initializing Authentication")
    print("================================================================")
    print("")
    
    # Initialize auth manager
    auth = SnowpipeAuthManager(
        private_key_path="$PRIVATE_KEY_PATH",
        account_id="$ACCOUNT_ID",
        username="$USERNAME"
    )
    
    print("")
    print("================================================================")
    print("Sending Sample Events")
    print("================================================================")
    print("")
    
    # Sample events
    events = [
        {
            "badge_id": "BADGE-001",
            "user_id": "USR-001",
            "zone_id": "ZONE-LOBBY-1",
            "reader_id": "RDR-101",
            "event_timestamp": datetime.datetime.utcnow().isoformat(),
            "signal_strength": -65.5,
            "direction": "ENTRY"
        },
        {
            "badge_id": "BADGE-002",
            "user_id": "USR-002",
            "zone_id": "ZONE-OFFICE-A",
            "reader_id": "RDR-102",
            "event_timestamp": datetime.datetime.utcnow().isoformat(),
            "signal_strength": -58.2,
            "direction": "ENTRY"
        },
        {
            "badge_id": "BADGE-001",
            "user_id": "USR-001",
            "zone_id": "ZONE-OFFICE-A",
            "reader_id": "RDR-103",
            "event_timestamp": datetime.datetime.utcnow().isoformat(),
            "signal_strength": -62.1,
            "direction": "ENTRY"
        }
    ]
    
    endpoint = "$PIPE_ENDPOINT"
    success_count = 0
    
    for i, event in enumerate(events, 1):
        try:
            response = send_event(auth, endpoint, event)
            
            if response.status_code == 200:
                print(f"✓ Event {i}/3: {event['badge_id']} -> {event['zone_id']} (HTTP 200)")
                success_count += 1
            else:
                print(f"✗ Event {i}/3: HTTP {response.status_code}")
                print(f"  Response: {response.text}")
        except Exception as e:
            print(f"✗ Event {i}/3: {str(e)}")
    
    print("")
    print("================================================================")
    print("Summary")
    print("================================================================")
    print(f"Successfully sent: {success_count}/3 events")
    print("")
    
    if success_count > 0:
        print("Next Steps:")
        print("  1. Wait 1-2 minutes for data to arrive")
        print("  2. Query in Snowflake:")
        print("     SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS;")
        print("")
        print("  3. Check metrics:")
        print("     SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_INGESTION_METRICS;")
    else:
        print("Troubleshooting:")
        print("  - Verify ACCOUNT_ID is correct")
        print("  - Ensure public key is registered in Snowflake")
        print("  - Check user has INSERT privilege on pipe")
        print("  - Review Snowflake task history for errors")
    
    print("")
    print("================================================================")
    
    return 0 if success_count > 0 else 1

if __name__ == "__main__":
    sys.exit(main())
EOF

echo ""
echo "================================================================"
echo "Demo Complete"
echo "================================================================"

