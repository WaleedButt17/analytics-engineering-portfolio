# Telecom Sales and Marketing Data Layer

**Stack:** Salesforce (exported to Google Sheets), BigQuery external tables, BigQuery SQL views and scheduled queries, Google Apps Script, Windsor.ai (Google Ads, Meta, GA4), an AI reporting agent

> This is real client work. The company, market (city and region), product, package, account and campaign names are replaced with placeholders such as Market 1, Region 1 and District 1. Project, dataset, sheet and property IDs are removed (`your-project`, `client_dataset`, `ga4_residential`, `ga4_business`). The SQL is the real SQL with comments removed and table, column and label names translated into English. Headline sales figures are left out; differences and pass rates are real.

## Situation and goal

The client is a large telecom and internet provider with a residential and a business segment. I worked for the marketing agency that runs its reporting. The agency was building an AI reporting agent that writes the weekly and monthly performance report, and the agent needed a data layer it could trust.

The goal was to bring three things into one model in BigQuery:

- **Sales and installations** from Salesforce. By company policy there is no API access, so the only source is a Google Sheet the operations team fills in by hand.
- **Ad spend** from Google Ads and Meta, through Windsor.ai.
- **Web behaviour and leads** from two GA4 properties (residential and business).

The agent had to answer both "national sales last week" and "sales in Market 1 for the first half of the month" without double counting, for weekly, biweekly, monthly and month to date periods. All the metric logic had to live in the data layer so the agent only reads finished numbers and never calculates them itself.

The work was split into three flows:

| Flow | Source | What it is |
|---|---|---|
| A | Salesforce via Google Sheets | Commercial results: sales and installations by day, district, market and subchannel (E-commerce, Call Center) |
| B | A Looker Studio report | Direct media figures. Blocked on the client: the report's data sources were never shared, so I did not build an extraction against a dashboard |
| C | Google Ads, Meta, GA4 | Digital measurement: spend, campaigns, sessions and leads, to explain what happened around the sales in Flow A |

## Architecture

```
Salesforce -> Google Sheet (4 monthly tabs, one column per day, months appended to the right)
   |
   +-> 4 external tables, 702 explicit STRING columns (01)
   |      |
   |      +-> stg_salesforce_v2 (02): date read from the header row,
   |            one row per day x district x subchannel
   |              |
   |              +-> vw_national_v2 (03): the sheet's Total row
   |              |     +-> qc_national_vs_markets_v2, vw_national_v2_validated (03)
   |              |     +-> vw_periods_national_v2 (04) -> agent_national (08)
   |              |
   |              +-> vw_periods_district_v2 (04) -> agent_market (09)
   |              +-> vw_periods_market_v2 (05), qc_districts_without_market_v2 (05)
   |
   +-> Apps Script (daily, reads tabs in row order) -> dim_market_district
         (joined into 05 and 09)

agent_national + agent_market: scheduled daily as base tables -> AI reporting agent

Windsor.ai -> google_ads_campaigns, facebook_ads_campaigns, GA4 session tables
                     |
 Client-owned mapping tab -> ext_campaign_mapping -> dim_campaign_client_v2 (10)
 Rules fallback for unmapped campaigns -> dim_campaign_rules_v2 (11)
 QC: spend with no mapping, mapping rows with no spend, unclassified spend
```

## Flow A: sales and installations

### What I found in the existing model

The client already had a staging view over the sheet and a weekly view on top. When I read the live definitions, I found five defects. Only the last one raised an error; the other four gave wrong numbers that looked right.

1. **The date came from the column position, with the month hardcoded.** The view computed each date as a fixed first-of-month plus the column index. The sheet had since grown to hold three months, so the first month's days were published under the second month's labels, and the second month's Total column was published as a single day.
2. **New months were invisible.** The UNPIVOT listed 31 columns by name. A month appended to the right landed outside that list with no error.
3. **Every figure above 999 disappeared.** BigQuery returns values like `"7,243"` with quotes and a thousands comma. `SAFE_CAST` on that is NULL, so large values, including the national total itself, dropped out silently.
4. **The national filter was a pattern.** `LIKE '%total%'` would also match any market whose name contained the word.
5. **The view was down.** Two tabs had been renamed with a leading space. The external tables pointed at the old names, could not read their tabs, and because the staging view unions all four, the whole chain returned an error.

The first defect was a design problem, not a parsing problem. No smarter parsing fixes a model whose time dimension is a column offset.

### What I built

**Read the date from the header, never count columns.** Row 1 of each tab holds a real date per column. The new staging view ([02](queries/01_flow_a_ingestion/02_stg_salesforce.sql)) turns each row into JSON, reads every key at run time, and joins each value to the date in its column's header. Columns whose header is not a date (the monthly Total columns) drop out by themselves. I used JSON instead of UNPIVOT for two reasons: the column list changes every month, and BigQuery typed some date columns INT64 and others STRING depending on cell formatting, which UNPIVOT cannot mix. Header dates come in two shapes (`dd/mm/yyyy` text and Sheets serial numbers), so both are parsed.

**Values are cleaned before casting.** Quotes and thousands commas are stripped, then cast to INT64.

**The operations team changes nothing.** The client offered to change the sheet layout. I recommended keeping it exactly as it was: same tabs, same Total columns and Subtotal rows, same monthly append. The problem was in the SQL, not the sheet, and a format the team finds awkward eventually gets filled in inconsistently.

**External tables over Sheets, with an explicit wide schema** ([01](queries/01_flow_a_ingestion/01_external_tables_wide_schema.sql)). The views read the sheet live, so a correction in the sheet shows up on the next query with nothing to rerun or backfill, and running a query twice cannot create duplicates. BigQuery autodetects an external table's width on the day it is created (106 to 118 columns here) and freezes it, so a new month beyond that width would be invisible. I rebuilt the four tables with 702 explicit STRING columns, matching the sheet range `A1:ZZ1000`. That is about 18 months of headroom. All STRING on purpose, so cell formatting cannot change a column's type.

**Districts, not markets, at row level.** The market name appears only on the first row of each group in column A. Column B holds the district on every row. My first draft filtered on column A being present and dropped about two thirds of the rows; the live view keys on column B.

**District to market dimension.** BigQuery gives external tables over Sheets no row order, so the market cannot be carried down in SQL. A small Apps Script reads the tabs in order through the Sheets API, builds the district to market map and loads `dim_market_district` with a full replace every morning. It refuses to write if it reads fewer than 50 districts, so a partial read fails loudly instead of shrinking the map. Before building on it I checked that no district name appears under two markets, so the district is a real key. About 80 districts map to just over 40 markets.

**National vs market rollups** ([03](queries/01_flow_a_ingestion/03_national_figure_and_reconciliation.sql)). The client asked to keep the sheet's consolidated Total row as the audited national figure and to use the sum of markets only as a check. So:

- `vw_national_v2` reads the Total row, matched exactly with `TRIM(col_a) = 'Total'`. I verified each tab holds exactly one such row and nothing else matches.
- `qc_national_vs_markets_v2` lists every day and subchannel where the Total row and the sum of markets disagree. FULL OUTER JOIN on purpose, so a day missing on one side also shows up. Empty means pass.
- `vw_national_v2_validated` carries the national figure plus a `reconciles` flag. A suspect figure is never silently corrected; it is published with the flag so the agent can decline to report it.

National and market figures are never added together.

**Period logic** ([04](queries/01_flow_a_ingestion/04_periods_national_and_district.sql), [05](queries/01_flow_a_ingestion/05_periods_market_and_guard.sql)). Four grains, all from the same daily rows:

| Grain | Definition |
|---|---|
| weekly | Monday to Sunday |
| biweekly | 1st to 15th, and 16th to month end |
| monthly | calendar month |
| month_to_date | 1st of the latest month to the latest date in the data |

Month to date is its own grain because the newest month is always partial. Labelled as a month, it invites comparing 23 days against 31. Every row carries `period_complete` (every day in the period has data) and, at national level, `reconciles` (every day passed the market check). Subchannel rollups come from GROUPING SETS with an `(all)` row, so the agent never has to add two rows together.

The market view uses a LEFT JOIN with a `(no market)` label. An inner join would make an unmapped district vanish from regional reporting while the total still looked fine. `qc_districts_without_market_v2` is the standing guard: empty means every district has a market; a row means a new district appeared or the Apps Script stopped.

**Agent tables** ([08](queries/03_agent_tables/08_agent_national.sql), [09](queries/03_agent_tables/09_agent_market.sql)). The agent imports base tables and cannot read views, so two scheduled queries rebuild `agent_national` and `agent_market` every day after the morning dimension refresh. They add a daily grain, partition by period start, cluster by grain, market and subchannel, and carry `is_total_row`, `period_complete`, the reconciliation flag and a note on where the national figure comes from. The market table is marked `is_audited_figure = FALSE` so it is never presented as the national number.

### QC before and after, and the rollback plan

The client set two conditions for approval: a before and after comparison and a rollback reference.

- **Rollback.** Before creating anything, I copied the client's old view definitions verbatim from `INFORMATION_SCHEMA.VIEWS` and kept them unedited. Every new object has a new name and sits beside the old ones; nothing was replaced or repointed until the client confirmed. I did not repair the client's broken external tables, because that would have changed their object and the rollback copy would no longer show the real state. (The rollback file is not in this repo because it is the client's original code, not mine.)
- **Before and after** ([07](queries/02_flow_a_qc/07_qc_before_after_v1.sql)). The query compares the old weekly view and the new model by ISO week. It could not run because the old chain was down, so I compared the new model against the figures actually published in the weekly decks instead (results below).
- **Schema neutrality** ([06](queries/02_flow_a_qc/06_qc_wide_schema_neutrality.sql)). Month by subchannel totals run before and after rebuilding the external tables (must be identical), the reconciliation count, and a headroom check: declared columns from `INFORMATION_SCHEMA.COLUMNS` against the highest column actually filled.

## Flow C: campaigns, spend and GA4

The client defined Flow C as the digital layer that explains the sales in Flow A, not as a campaign report. Campaign is a dimension, the result stays in Flow A, and the agent may say that something coincided with a change but never that it caused it. Only the residential segment is modelled; business data is still loaded but kept apart and never mixed.

**Campaign mapping sheet** ([10](queries/04_flow_c_campaigns/10_campaign_mapping_sheet.sql)). New campaigns launch every week. If the mapping lived in SQL, every new campaign would need me, and until then its spend would drop out of every cost per sale figure. So I added a mapping tab to the client's own spreadsheet, seeded it with the campaigns from their list (brand, channel, KPI, account, GA4 property, lead definition), and connected it as an external table. Their team adds a row and the next query picks it up. Lessons from Flow A applied from day one: explicit schema, a tab name they agreed not to rename, and a normalised join key (lowercase, trimmed, internal whitespace collapsed). The last one was needed because the sheet and the platforms differed in capitalisation and in double spaces inside names, and `TRIM` alone misses the second.

Two QC views keep it honest: spend with no mapping ranked by spend (the order anyone should work through it), and mapping rows that match no campaign, which catches typos the first check cannot see.

**Rules fallback** ([11](queries/04_flow_c_campaigns/11_campaign_rules_fallback.sql)). For campaigns not on the client's list, a classifier derives subchannel, segment, geography scope and campaign type from the account and campaign name. The naming followed three different conventions (Google named market size tiers, Meta named regions and cities, both had national campaigns), and it had silent traps:

- `ECC` contains `CC`, so a naive match booked the largest E-commerce campaign as Call Center. Account is checked first, since Google runs one account per subchannel, and campaign tokens use word boundaries.
- Negations: "national excluding Market 1" contains the market's name. Negations are checked before any market rule.
- Platform conversions are not sales. One campaign reported more conversions than several months of real national sales, so cost per sale must divide spend by Flow A sales, never by platform conversions.
- A large share of spend is brand video with no subchannel, and `(no channel)` is a real value, not an error.

A hand-maintained override table beats the rules for campaigns that name two markets or a district instead of a market. `qc_campaigns_unclassified_v2` lists everything that fell to a default, ranked by spend, as the maintenance queue.

**GA4 and Windsor.** I added session-grain GA4 pulls next to the event-grain ones, because `sessions` on an event-grain table repeats each session once per event and read about seven times too high. Reach and unique users live in their own tables and are never summed. Before saving any Windsor field, I tested it, because a wrong field name is accepted silently and returns null on every row.

## Query files

| # | File | What it does |
|---|---|---|
| 01 | [external_tables_wide_schema](queries/01_flow_a_ingestion/01_external_tables_wide_schema.sql) | Four external tables over the sales and installs tabs with 702 explicit STRING columns |
| 02 | [stg_salesforce](queries/01_flow_a_ingestion/02_stg_salesforce.sql) | Staging at day x district x subchannel, date read from the header row |
| 03 | [national_figure_and_reconciliation](queries/01_flow_a_ingestion/03_national_figure_and_reconciliation.sql) | National figure from the Total row, national vs markets QC, national figure with its reconciliation flag |
| 04 | [periods_national_and_district](queries/01_flow_a_ingestion/04_periods_national_and_district.sql) | Weekly, biweekly, monthly and month to date at national and district level |
| 05 | [periods_market_and_guard](queries/01_flow_a_ingestion/05_periods_market_and_guard.sql) | Same four grains by market, plus the guard for districts with no market |
| 06 | [qc_wide_schema_neutrality](queries/02_flow_a_qc/06_qc_wide_schema_neutrality.sql) | Totals before and after the schema rebuild, reconciliation count, column headroom |
| 07 | [qc_before_after_v1](queries/02_flow_a_qc/07_qc_before_after_v1.sql) | Old weekly view vs new model by ISO week |
| 08 | [agent_national](queries/03_agent_tables/08_agent_national.sql) | Scheduled table for the agent: national figure, daily plus four grains |
| 09 | [agent_market](queries/03_agent_tables/09_agent_market.sql) | Scheduled table for the agent: district and market detail, daily plus four grains |
| 10 | [campaign_mapping_sheet](queries/04_flow_c_campaigns/10_campaign_mapping_sheet.sql) | External table over the client's mapping tab, normalised dimension, two mapping QC views |
| 11 | [campaign_rules_fallback](queries/04_flow_c_campaigns/11_campaign_rules_fallback.sql) | Override table, rules classifier for unmapped campaigns, unclassified spend QC |

## Problems found and fixed

**External table width dropped from 702 to 110 columns.** After I flagged the leading spaces, the client renamed the two tabs back to plain names. Recreating the two E-commerce external tables for the new names made BigQuery autodetect their width again, and they came back at 110 and 112 columns. That silently undid the headroom the client had just been told about: the next appended months would have been invisible. I caught it by checking the column count straight after the rebuild, re-widened both tables to 702 the same evening, and confirmed with the neutrality query that every month by subchannel total was identical before and after. Lesson: rebuilding an external table resets its schema silently, so check the column count every time.

**The client's weekly flow was down, not wrong.** The before and after query failed with "Unable to parse range" on one of the old external tables. The cause was a leading space in two tab names that the old tables did not declare. Because the staging view unions all four tabs, two unreadable tabs took down the staging view and the weekly view on top. This also raised a question for the client: if the weekly view could not run, how was the weekly deck being produced? Since a sheet range cannot be wildcarded, this cannot be designed out, so the tab names are now agreed as fixed and the Apps Script fails with a clear "tab not found" error if one changes.

**One source cell was 1,000 times too big.** The reconciliation caught it on its first run: on one day the Call Center Total cell held a thousands separator typed into a small number, so it read 1,000 times the sum of its markets, while installations on the same day matched exactly (which rules out a shifted column or a wrong date). The old model had turned that cell into NULL, so the published deck had been understating that week since the sheet was first loaded. I did not patch it, because the audited figure is the client's. It was published with `reconciles = FALSE`, raised with the client, they fixed the cell, and the flag cleared on the next read with nothing to deploy.

**GROUPING SETS rollups came back blank.** Writing `IFNULL(subchannel, '(all)') AS subchannel` (aliasing a column to its own name) made BigQuery resolve the GROUPING SETS reference against the alias, so every rollup row had an empty subchannel instead of the label. Row counts were unchanged, which is why it looked right. Fixed by grouping in a CTE and labelling in the outer SELECT, in all three period views.

**The repo file drifted from the live view.** The local staging file still held the early draft that dropped two thirds of the rows, while BigQuery held the corrected view. I re-pulled the live definition from `INFORMATION_SCHEMA.VIEWS` and now always pull the live definition before editing.

## Validation and results

- **Against the sheet's own Total row:** month by subchannel, all six month and subchannel combinations exact.
- **Against the published weekly decks:** three weeks available. The new model read +1, +3 and +2 against the published weekly totals. Broken down by subchannel and metric, 8 of 10 comparable figures were exact. Every difference was E-commerce sales, always upward, at most 0.06%. That fits the source: a web order can still be confirmed after the deck is cut, while a call centre sale and an installation are final when logged.
- **National vs markets:** 167 of 168 day and subchannel periods reconciled exactly on first run. The one failure was the source cell above; after the client fixed it, 168 of 168.
- **Market and district totals** agree to the unit on every grain, with zero rows labelled `(no market)` and zero districts without a market.
- **Schema rebuilds:** month by subchannel totals identical before and after both rebuilds. Headroom after the fix: 584 to 596 spare columns per tab, about 18 months.
- **Duplicates:** none possible by design. The Flow A objects are views over the live sheet, and the only loaded table (the district map) is fully replaced on each run.
