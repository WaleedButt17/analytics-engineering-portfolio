# Analytics Engineering Portfolio

Waleed Butt. I build data pipelines and reporting for ecommerce, subscription and lead generation businesses: n8n and APIs into BigQuery, SQL views that hold the business logic, and Looker Studio on top. Most of my work is making sure the numbers match the source system.

**Tools:** BigQuery (SQL), n8n, Looker Studio, Google Sheets and Apps Script, Windsor.ai, REST APIs (Stripe, Shopify, Meta, Google Ads and others)

## Projects

| Project | What it shows |
|---|---|
| [Subscription Revenue Analytics](01-subscription-revenue-analytics/) | 6 stores on Loop and CheckoutChamp plus Shopify, Meta and daily FX loaded by n8n into BigQuery; 14 marts for MRR, churn, cohorts, LTV and payment health; MRR fixed from about $750K (wrong) to $1.355M (verified) |
| [Lead Generation Reporting System](02-lead-gen-reporting/) | 7 ad platforms (Windsor plus custom n8n API flows) and real time lead webhooks into BigQuery; 21 views for product mapping, CPL, research spend and a full financial model; 13 page Looker Studio report; lead counts matched to the source every month |
| [Stripe Revenue Analytics](03-stripe-revenue-analytics/) | n8n loads 4 Stripe endpoints into BigQuery every night; 18 views for true net revenue after fees, refunds and disputes, cohorts, LTV and refund patterns; 10 page Looker Studio report |
| [Ecommerce Automation and Profit Dashboard](04-ecommerce-profit-dashboard/) | Apps Script scoring engine that ranks a 2,900 product supplier catalog, Make flows to list and delist on Shopify, contribution margin per order line in BigQuery, and a profit dashboard that caught products sold at a loss |
| [Mobile App Analytics](05-mobile-app-analytics/) | GA4 app export and 3 ad platforms in BigQuery; 24 views from ad spend to install, signup, engagement, creator activity and paid orders; retention rebuilt after finding background push notifications counted as returns; 12 section Looker Studio report |



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
