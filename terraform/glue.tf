resource "aws_glue_catalog_database" "agriculture" {
  name = "agriculture_data"
}

resource "aws_glue_catalog_table" "weather_observations" {
  name          = "weather_observations"
  database_name = aws_glue_catalog_database.agriculture.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "json"
    "EXTERNAL"       = "TRUE"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data.bucket}/processed/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
    }

    columns {
      name = "farm_id"
      type = "string"
    }
    columns {
      name = "farm_name"
      type = "string"
    }
    columns {
      name = "source"
      type = "string"
    }
    columns {
      name = "ingested_at"
      type = "string"
    }
    columns {
      name = "observation_time"
      type = "string"
    }
    columns {
      name = "temperature_c"
      type = "double"
    }
    columns {
      name = "humidity_percent"
      type = "double"
    }
    columns {
      name = "precipitation_mm"
      type = "double"
    }
    columns {
      name = "wind_speed_kmh"
      type = "double"
    }
  }
}