#!/usr/bin/env python3
"""High-performance Snowpipe Streaming demo helper."""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import sys
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

import jwt
import requests
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import load_pem_private_key

CONTROL_TIMEOUT_SECONDS = 15
APPEND_TIMEOUT_SECONDS = 30
POLL_INTERVAL_SECONDS = 1
STREAMING_HOSTNAME_ENDPOINT = "/v2/streaming/hostname"
SCOPED_TOKEN_ENDPOINT = "/oauth/token"
CLIENT_ID = "simple-streaming-demo/1.0"
SCOPED_GRANT_TYPE = "urn:ietf:params:oauth:grant-type:jwt-bearer"


@dataclass
class Config:
    account_host: str
    username: str
    private_key_path: Path
    pipe_name: str
    channel_name: str
    sample_events: int

    @classmethod
    def load(cls, path: Path) -> "Config":
        if not path.exists():
            raise FileNotFoundError(f"Config file not found: {path}")
        data = json.loads(path.read_text())
        return cls(
            account_host=data["account_host"],
            username=data["username"],
            private_key_path=Path(data["private_key_path"]).expanduser(),
            pipe_name=data["pipe_name"],
            channel_name=data.get("channel_name", f"demo_channel_{uuid.uuid4().hex[:8]}")
            or f"demo_channel_{uuid.uuid4().hex[:8]}",
            sample_events=int(data.get("sample_events", 3)),
        )


class KeyPair:
    def __init__(self, private_key_path: Path) -> None:
        if not private_key_path.exists():
            raise FileNotFoundError(f"Private key not found: {private_key_path}")
        self._key = load_pem_private_key(private_key_path.read_bytes(), password=None, backend=default_backend())
        if not isinstance(self._key, rsa.RSAPrivateKey):
            raise TypeError("Private key must be RSA")

        public_key = self._key.public_key()
        self._public_der = public_key.public_bytes(
            serialization.Encoding.DER,
            serialization.PublicFormat.SubjectPublicKeyInfo,
        )
        digest = hashes.Hash(hashes.SHA256(), backend=default_backend())
        digest.update(self._public_der)
        self._fingerprint_raw = digest.finalize()

    @property
    def fingerprint_hex(self) -> str:
        return "SHA256:" + self._fingerprint_raw.hex()

    @property
    def fingerprint_base64(self) -> str:
        return "SHA256:" + base64.b64encode(self._fingerprint_raw).decode("ascii")

    @property
    def private_key(self) -> rsa.RSAPrivateKey:
        return self._key


def normalize_account_identifier(account_host: str) -> Tuple[str, str]:
    host_prefix = account_host.split(".")[0]
    account_identifier = host_prefix.replace("-", "_").upper()
    return host_prefix, account_identifier


def build_jwt(
    private_key: rsa.RSAPrivateKey,
    account_identifier: str,
    username: str,
    fingerprint_b64: str,
    account_host: str,
) -> str:
    issued_at = dt.datetime.now(dt.timezone.utc)
    qualified_user = f"{account_identifier}.{username.upper()}"
    base64_hash = fingerprint_b64.split(":", 1)[1]
    issuer = f"{qualified_user}.SHA256:{base64_hash}"
    payload = {
        "iss": issuer,
        "sub": qualified_user,
        "aud": f"https://{account_host}",
        "iat": issued_at,
        "exp": issued_at + dt.timedelta(minutes=59),
    }
    headers = {"kid": fingerprint_b64}
    token = jwt.encode(payload, private_key, algorithm="RS256", headers=headers)
    return token if isinstance(token, str) else token.decode("ascii")


def http_post(url: str, headers: Dict[str, str], json_body: Dict[str, object]) -> requests.Response:
    response = requests.post(url, headers=headers, json=json_body, timeout=CONTROL_TIMEOUT_SECONDS)
    response.raise_for_status()
    return response


def http_get(url: str, headers: Dict[str, str]) -> requests.Response:
    response = requests.get(url, headers=headers, timeout=CONTROL_TIMEOUT_SECONDS)
    response.raise_for_status()
    return response


def http_put(url: str, headers: Dict[str, str], json_body: Dict[str, object]) -> requests.Response:
    response = requests.put(url, headers=headers, json=json_body, timeout=CONTROL_TIMEOUT_SECONDS)
    response.raise_for_status()
    return response


def http_delete(url: str, headers: Dict[str, str]) -> None:
    response = requests.delete(url, headers=headers, timeout=CONTROL_TIMEOUT_SECONDS)
    if response.status_code not in (200, 202, 204, 404):
        response.raise_for_status()


def generate_events(count: int) -> List[Dict[str, object]]:
    now = dt.datetime.now(dt.timezone.utc)
    events = []
    for index in range(count):
        events.append(
            {
                "badge_id": f"BADGE-{index:03d}",
                "user_id": f"USR-{index:03d}",
                "zone_id": "ZONE-LOBBY-1",
                "reader_id": f"RDR-{100 + index}",
                "event_timestamp": (now - dt.timedelta(seconds=(count - index) * 2)).isoformat(),
                "signal_strength": -65.0 + index,
                "direction": "ENTRY" if index % 2 == 0 else "EXIT",
            }
        )
    return events


def events_to_ndjson(events: List[Dict[str, object]]) -> str:
    return "\n".join(json.dumps(event) for event in events)


def main() -> int:
    parser = argparse.ArgumentParser(description="Send sample events via Snowpipe Streaming REST API")
    parser.add_argument("--config", default="config.json", help="Path to configuration JSON (default: config.json)")
    parser.add_argument("--dry-run", action="store_true", help="Generate payloads but skip REST calls")
    args = parser.parse_args()

    config = Config.load(Path(args.config))
    keypair = KeyPair(config.private_key_path)

    host_prefix, account_identifier = normalize_account_identifier(config.account_host)

    print("✓ Configuration loaded")
    print(f"✓ Account host: https://{config.account_host}")
    print(f"✓ Account identifier: {account_identifier}")
    print(f"✓ RSA fingerprint: {keypair.fingerprint_base64}")

    events = generate_events(config.sample_events)
    ndjson_payload = events_to_ndjson(events)

    if args.dry_run:
        print("--dry-run enabled; skipping REST calls")
        print("NDJSON payload:")
        print(ndjson_payload)
        return 0

    jwt_token = build_jwt(keypair.private_key, account_identifier, config.username, keypair.fingerprint_base64, config.account_host)
    print("✓ JWT generated")

    control_base = f"https://{config.account_host}"
    auth_headers = {
        "Authorization": f"Bearer {jwt_token}",
        "User-Agent": CLIENT_ID,
        "X-Snowflake-Authorization-Token-Type": "KEYPAIR_JWT",
    }

    ingest_resp = http_get(control_base + STREAMING_HOSTNAME_ENDPOINT, auth_headers)
    ingest_host = ingest_resp.json()["hostname"].replace("_", "-").lower()
    print(f"✓ Ingest host: https://{ingest_host}")

    token_resp = http_post(
        control_base + SCOPED_TOKEN_ENDPOINT,
        auth_headers,
        {"grant_type": SCOPED_GRANT_TYPE, "scope": ingest_host},
    )
    scoped_token = token_resp.json()["access_token"]
    print("✓ Scoped token acquired")

    database, schema, pipe = config.pipe_name.split(".")
    channel_headers = {
        "Authorization": f"Bearer {scoped_token}",
        "Content-Type": "application/json",
        "User-Agent": CLIENT_ID,
    }

    open_url = (
        f"https://{ingest_host}/v2/streaming/databases/{database}/schemas/{schema}/pipes/{pipe}/channels/{config.channel_name}"
    )
    open_resp = http_put(open_url, channel_headers, {})
    continuation_token = open_resp.json()["next_continuation_token"]
    print(f"✓ Channel opened: {config.channel_name}")

    append_url = (
        f"https://{ingest_host}/v2/streaming/data/databases/{database}/schemas/{schema}/pipes/{pipe}/channels/{config.channel_name}/rows"
        f"?continuationToken={continuation_token}&offsetToken=0"
    )
    append_headers = {
        "Authorization": f"Bearer {scoped_token}",
        "Content-Type": "application/x-ndjson",
        "User-Agent": CLIENT_ID,
    }
    append_resp = requests.post(
        append_url,
        headers=append_headers,
        data=ndjson_payload.encode("utf-8"),
        timeout=APPEND_TIMEOUT_SECONDS,
    )
    append_resp.raise_for_status()
    next_token = append_resp.json()["next_continuation_token"]
    print(f"✓ Appended {len(events)} events (next token prefix: {next_token[:16]})")

    http_delete(open_url, channel_headers)
    print("✓ Channel closed")

    return 0


if __name__ == "__main__":
    sys.exit(main())
