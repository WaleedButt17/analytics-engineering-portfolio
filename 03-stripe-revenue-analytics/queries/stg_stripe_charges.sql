CREATE OR REPLACE VIEW `your-project.stripe.stg_stripe_charges` AS
SELECT * EXCEPT (rn)
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY id
      ORDER BY SAFE_CAST(ingested_at AS TIMESTAMP) DESC
    ) AS rn
  FROM `your-project.stripe.stripe_charges`
)
WHERE rn = 1;
