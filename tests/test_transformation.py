import unittest

from src.transformation.handler import processed_key, transform_record

SAMPLE_RAW = {
    "farm_id": "farm-indiana-001",
    "farm_name": "Indiana Farm",
    "ingested_at": "2026-09-28T01:49:50Z",
    "api_response": {
        "current": {
            "time": "2026-09-28T01:45",
            "temperature_2m": 21.5,
            "relative_humidity_2m": 65,
            "precipitation": 0.0,
            "wind_speed_10m": 8.4,
        }
    },
}


class TransformationTests(unittest.TestCase):
    def test_transform_flattens_record(self):
        flat = transform_record(SAMPLE_RAW)
        self.assertEqual(flat["farm_id"], "farm-indiana-001")
        self.assertEqual(flat["observation_time"], "2026-09-28T01:45")
        self.assertEqual(flat["temperature_c"], 21.5)
        self.assertEqual(flat["wind_speed_kmh"], 8.4)

    def test_processed_key_format(self):
        self.assertEqual(
            processed_key("farm-indiana-001", "2026-09-28T01:45"),
            "processed/farm-indiana-001/2026/09/28/20260928T0145.json",
        )

    def test_same_observation_gives_same_key(self):
        first = processed_key("farm-iowa-001", "2026-09-28T01:45")
        second = processed_key("farm-iowa-001", "2026-09-28T01:45")
        self.assertEqual(first, second)


if __name__ == "__main__":
    unittest.main()