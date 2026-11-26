# Analytics Engineering Portfolio

Waleed Butt. I build data pipelines and reporting for ecommerce, subscription and lead generation businesses: n8n and APIs into BigQuery, SQL views that hold the business logic, and Looker Studio on top. Most of my work is making sure the numbers match the source system.

**Tools:** BigQuery (SQL), n8n, Looker Studio, Google Sheets and Apps Script, Windsor.ai, REST APIs (Stripe, Shopify, Meta, Google Ads and others)

## Projects

| Project | What it shows |
|---|---|
| [Stripe Revenue Analytics](03-stripe-revenue-analytics/) | n8n loads 4 Stripe endpoints into BigQuery every night; 18 views for true net revenue after fees, refunds and disputes, cohorts, LTV and refund patterns; 10 page Looker Studio report |

More projects are being added.

## How each project is laid out

```
project/
  README.md      the problem, how it works, results
  n8n/           workflow JSON (import into n8n) and a screenshot
  queries/       BigQuery SQL, one file per view
  screenshots/   dashboard pages
```

## About the data

Everything here comes from real client work. Client names, product names, customer details, account IDs and headline numbers are removed or blurred, and project and table names are replaced with placeholders like `your-project`. No credentials or API keys are included.
