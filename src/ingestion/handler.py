import json
import os
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import boto3

DATA_BUCKET = os.environ.get("DATA_BUCKET", "")
s3 = boto3.client("s3")

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"
CURRENT_VARIABLES = "temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m"

FARMS = [
    {"farm_id": "farm-indiana-001", "farm_name": "Indiana Farm", "latitude": 39.77, "longitude": -86.16},
    {"farm_id": "farm-iowa-001", "farm_name": "Iowa Farm", "latitude": 41.59, "longitude": -93.62},
    {"farm_id": "farm-oregon-001", "farm_name": "Oregon Farm", "latitude": 44.94, "longitude": -123.03},
]


def fetch_current_weather(farm):
    query = urllib.parse.urlencode({
        "latitude": farm["latitude"],
        "longitude": farm["longitude"],
        "current": CURRENT_VARIABLES,
        "timezone": "GMT",
    })
    with urllib.request.urlopen(f"{OPEN_METEO_URL}?{query}", timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def handler(event, context):
    ingested_at = datetime.now(timezone.utc)
    written = []

    for farm in FARMS:
        api_response = fetch_current_weather(farm)

        raw_doc = {
            "farm_id": farm["farm_id"],
            "farm_name": farm["farm_name"],
            "ingested_at": ingested_at.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "api_response": api_response,
        }

        key = f"raw/{farm['farm_id']}/{ingested_at:%Y/%m/%d}/{ingested_at:%H%M%S}.json"
        s3.put_object(
            Bucket=DATA_BUCKET,
            Key=key,
            Body=json.dumps(raw_doc).encode("utf-8"),
            ContentType="application/json",
        )
        written.append(key)

    return {"written": written}