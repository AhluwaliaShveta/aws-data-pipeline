import json
import os
import urllib.parse
from datetime import datetime

import boto3

DATA_BUCKET = os.environ.get("DATA_BUCKET", "")
s3 = boto3.client("s3")


def transform_record(raw_doc):
    """Flatten the nested Open-Meteo response into one analytics row."""
    current = raw_doc["api_response"]["current"]
    return {
        "farm_id": raw_doc["farm_id"],
        "farm_name": raw_doc["farm_name"],
        "source": "open-meteo",
        "ingested_at": raw_doc["ingested_at"],
        "observation_time": current["time"],
        "temperature_c": current["temperature_2m"],
        "humidity_percent": current["relative_humidity_2m"],
        "precipitation_mm": current["precipitation"],
        "wind_speed_kmh": current["wind_speed_10m"],
    }


def processed_key(farm_id, observation_time):
    """Deterministic key: the same observation always maps to the same object."""
    obs = datetime.strptime(observation_time, "%Y-%m-%dT%H:%M")
    return f"processed/{farm_id}/{obs:%Y/%m/%d}/{obs:%Y%m%dT%H%M}.json"


def handler(event, context):
    results = []
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        obj = s3.get_object(Bucket=bucket, Key=key)
        raw_doc = json.loads(obj["Body"].read().decode("utf-8"))

        flat = transform_record(raw_doc)
        out_key = processed_key(flat["farm_id"], flat["observation_time"])

        s3.put_object(
            Bucket=DATA_BUCKET,
            Key=out_key,
            Body=json.dumps(flat).encode("utf-8"),
            ContentType="application/json",
        )
        results.append(out_key)

    return {"processed": results}