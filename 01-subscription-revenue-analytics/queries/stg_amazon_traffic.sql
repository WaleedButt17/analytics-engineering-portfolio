CREATE OR REPLACE VIEW `your-project.staging.stg_amazon_traffic`
AS SELECT * EXCEPT(ingested_at),
  ingested_at
FROM `your-project.raw.daily_amazon_traffic`
QUALIFY ROW_NUMBER() OVER (PARTITION BY date ORDER BY ingested_at DESC) = 1;
