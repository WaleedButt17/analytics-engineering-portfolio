# Multi-Brand Marketing Data Layer (Healthcare)

**Stack:** Windsor.ai, BigQuery (SQL views, table functions, scheduled queries), GA4, Meta Ads, Google Ads, DV360 (YouTube), Spotify Ads, Google Sheets, Apps Script, Looker Studio as the reference dashboard

> This is real client work for a marketing agency. The end client is a large multi-brand healthcare company. All company, brand, product, programme and campaign names are replaced (Brand A to Brand H, Initiative C1, Therapy Area 1 and so on). Project, dataset, property, account, campaign and document IDs are removed and replaced with placeholders like `your-project`, `ga4_property_A` and `YOUR_SPREADSHEET_ID`. The original object names were in Spanish and are translated to English, consistently across every file. The SQL logic is the real logic, with comments removed.

## The situation

The agency ran paid media for eight brands of one healthcare company: Meta, Google Ads, DV360 (YouTube) and later Spotify, plus GA4 on four web properties. Windsor.ai loaded all of it into BigQuery. On top of BigQuery sat two things that had to be right:

- an AI reporting agent that answers questions about campaign performance from BigQuery tables
- recurring client reports (Google Sheets) filled by Apps Script

The reference for "right" was the agency's Looker Studio dashboard, which reads the ad platforms and GA4 directly, not BigQuery. The warehouse numbers did not match it, the agent could only see one brand, and nobody knew which differences were bugs and which were definitions.

**My job:** audit the data layer end to end, find every reason the numbers differed, and standardise it across all eight brands so that every published figure reconciles to its source and the agent and reports read one consistent contract.

The client set clear rules, and they shaped how I worked:

1. Build on what exists. No parallel systems.
2. All metric logic lives in the data layer. The agent and the reports never recalculate anything.
3. Reconciliation is a deliverable. Every difference is written down with metric, period, source compared, variance, root cause and decision.
4. Nothing in production changes without joint review. New objects are built next to the old ones and the old ones stay as rollback.
5. Published historical figures are never changed. Method differences are documented instead.

## The brands

| Brand | Channels | GA4 | Shape |
|---|---|---|---|
| Brand A | Meta, Google, DV360 | own property | full funnel, weekly client report |
| Brand B | Meta, Google, DV360 | own property | full funnel at campaign grain, biweekly and monthly client report |
| Brand C | Meta (2 ad accounts), Google | lands on two properties | paid plus partial funnel |
| Brand D | Meta, DV360 | own property (the company's online store) | paid plus traffic, no lead event |
| Brand E | Meta, Google | own property (a professional portal) | full funnel |
| Brand F | Meta, Google | shares Brand E's property | paid plus funnel, no dashboard page for most history |
| Brand G | Meta, Google | shares Brand E's property | historical only, campaigns ended |
| Brand H | DV360 (YouTube), Spotify | none | video and audio only, no web funnel |

## Architecture

```
  Meta Ads   Google Ads   DV360 / YouTube   Spotify Ads   GA4 (4 properties)
      \           |              |               |             /
       +----------+---- Windsor.ai (daily tasks, upsert keys) +
                                   |
                         BigQuery raw tables
          facebook_ads_campaigns_v2, google_ads_campaigns_v2, dv360_campaign_v2,
          dv360_trueview_ad, spotify_campaigns, ga4_* (session grain and event grain)
                                   |
                     staging (stg_*): one view per brand and channel,
                     session-scoped GA4 base, events base
                                   |
          dimensions and mapping: dim_campaign (client's mapping sheet, cleaned),
          dim_utm (GA4 utm -> brand and initiative), dim_content_brand_b, dim_episode_brand_h
                                   |
              brand models: mart_kpis_* -> vw_* contract views (one per brand)
                                   |
        +--------------------------+---------------------------+
        |                          |                           |
  reach and users            attribution                 rollups
  (period tables, exact      (session scope vs           rollup_base_* ->
   or NULL, never summed)     first-user scope)          weekly / biweekly / monthly
        |                          |                           |
        +--------------------------+---------------------------+
                                   |
          agent tables: agent_daily, agent_period (scheduled, all 8 brands)
          table functions: tf_* (read by Apps Script reports)
                                   |
             AI reporting agent          Apps Script -> Google Sheets reports

  Around every layer: qc_* controls (empty = pass), reconciliation queries
  against the dashboard and the platform catalogue, freshness checks.
```

## How I did it

### 1. Audit: map what actually exists

I started by reading every Windsor connection (20 at the start, four of them belonging to another client on the same key), every BigQuery object and every chart source in the dashboard. Three things stood out early:

- The dashboard did not read BigQuery at all. It connected straight to the platforms. So the warehouse had never been asked for fields the reports showed, and nobody had noticed the gaps.
- Every staging view had a hardcoded campaign list, and each used a different way to identify campaigns.
- The agent's datastore was a one-off copy of nine tables for one brand, frozen on one date. Seven of eight brands were not in it at all.

I logged 15 findings with priorities (P1 blocks reliable reporting, P2 causes drift, P3 hygiene), each in the client's five-field format. The first one I proved end to end on Brand A: GA4 session metrics were pulled in the same request as event dimensions, so each session was repeated once per event type. Summed sessions were **1.92x** too high and new users read **0 for the whole history** of that brand. A second, correctly scoped pull already existed. The fix was to read sessions from the session-grain table and events from the event-grain table.

### 2. Decisions before building

- **Build alongside production.** New objects get a version suffix (`_v2`, `_v3`) and the old ones stay untouched as rollback until the client approves a repoint.
- **Catalogue-driven staging.** The client already kept a campaign mapping sheet with brand, initiative, objective and campaign ID for every campaign. I put it behind an external table and a cleaning view (`dim_campaign`) and made every staging view join to it instead of listing campaign names. Adding a campaign became a row in the sheet, not a code change.
- **One normalised join key.** Google Ads campaign names contained non-breaking spaces. `LENGTH` counts them as one character, so both sides looked identical and three joins silently failed. `campaign_key = REGEXP_REPLACE(NORMALIZE(TRIM(name), NFKC), r'\s+', ' ')` fixed it once for the whole account, and `campaign_id` is preferred wherever the platform provides it.
- **DV360 spend is `revenue_advertiser`** (client-billed cost), with platform `spend` kept in the base layer. The client approved this.
- **Ratios are recomputed from period totals, never averaged.** Durations and rates are weighted by sessions.
- **Reach and users are never summed.** They are deduplicated counts. A period figure is either exact (one campaign, one property) or NULL with an upper bound beside it.
- **One view per grain** (weekly, biweekly, monthly) on top of one shared rollup base, so a query that forgets a grain filter cannot return triple counts.

### 3. Block 1: the two brands with live reports (A and B)

For each brand: staging per channel, a mart that joins paid media to GA4 by date, channel and initiative, a contract view, a rollup base and three grain views, plus table functions that the Apps Script reports call with a date range.

Brand A's July spend gap against the dashboard went from **20.0% to 0.018%**. Three causes: DV360 was summing the wrong spend field, the Meta connection had no backfill so the first three days of July were never fetched, and a duplicate load under the wrong upsert key had overstated Meta by **45%** with no error anywhere. Brand B recovered spend from two campaigns that the old hardcoded lists excluded, and its micro-event counts matched the dashboard exactly by channel.

Brand B's report needed figures per campaign, while the warehouse held micro-events per channel. Every number looked plausible and none reconciled. The answer was a GA4 field that was already ingested (`session_manual_ad_content`, the utm_content value) and never selected. I built a campaign-grain layer on it with a content catalogue, its own staging, rollups and table functions.

### 4. Block 2: six more brands from one template

I ran discovery queries first ([`discovery/`](queries/discovery/)) to settle the questions that could change the plan: was `campaign_id` ingested, was the older history in the tables, did a campaign ID shared by two brands split cleanly, could the shared GA4 property be split by brand. Both "blocking" gates turned out to be open already.

Then I built Brand C end to end as the template (it had a dashboard page to prove it against), and applied the same shape to D, E, F, G and H.

**The UTM mapping.** GA4 records utm_campaign values, not platform campaign names, so the campaign catalogue could not reach GA4 at all. I built `dim_utm`: every utm value seen on each property and source, assigned to a brand and initiative on evidence (identical start dates, name matches, sessions only on days that brand was spending), or explicitly marked as not paid, out of scope or no evidence. 91 rows, reviewed by the client, **zero unassigned sessions**. Two flags, not one: `is_paid` (money was spent) and `in_model` (the row reaches a staging view), so excluded paid media is not recorded as unpaid.

What changed per brand:

- **Brand C** sessions went from 10,780 to **72,818**. The staging read one GA4 property when the brand lands on two, and its Meta staging listed 3 of 7 campaigns. The missing campaigns came back automatically through the catalogue join.
- **Brand D** sessions went from 166,424 to 121,948, which is three separate movements, not a drop: 45,797 sessions belonged to Brand C (its campaign drives traffic to the store), 48,020 were organic search and free listings counted as paid, and 49,803 DV360 sessions were added because DV360 staging for this brand had never existed. The two corrections had to ship together, or Brand C's store traffic would be counted twice.
- **Brand E** paid media matched the dashboard exactly, and monthly reach matched **to the unit**.
- **Brands F and G** have no dashboard page for most of their history, so I reconciled them against the platform tables and the client's catalogue (exact on every closed campaign). Brand G's contract carries `is_historical` and its last active day, so the agent answers about a finished period instead of reporting it as live.
- **Brand H** is video and audio only. Its VTR and CPV were calculated on `complete_views_video` (the 100% quartile, a whole 30 minute episode). The client's VTR is on TrueView views (30 seconds). July read **8.42% against a published 31.84%**. I moved both ratios to `trueview_views`, kept both view metrics under different names, and declared `base_vtr` and `base_cpv` in the contract. Per-episode figures needed a separate DV360 pull, because TrueView ad dimensions cannot be requested together with `campaign`. The Spotify account carried four advertisers, so its staging filters to the one campaign. Without that filter another advertiser's impressions landed in the report.

### 5. Shared staging and repoints

- **Session-scoped GA4 base** (`staging/31`): new Windsor tasks at session grain (one row per date, campaign and source/medium) replaced the `MAX(sessions)` workaround on the event table. Users, bounce rate and engagement rate came with it. I did not add the medium dimension to the existing event tasks, because every staging view took `MAX(sessions)` per group and a new dimension would have silently returned the largest medium instead of the total.
- **Google repoint** (`staging/35`): a new Google Ads table with `campaign_id` on 100% of rows (it was 96 of 555) and a noon UTC schedule. The old schedule ran at midnight UTC, which is the previous evening in the reporting timezone, so the latest day was always three quarters complete and read 8 to 12% low. One documented accepted difference: a removed campaign, 3 days, 0.2% of one brand's spend, in a month no report covers.
- **Column parity** (`brand_models/26`): a column available on one brand is available on all, so the agent answers the same question the same way for every brand. Brand A and B reports read table functions **by column position**, so new columns were only ever appended at the end.

### 6. Reach and users

Reach and users deduplicate across days, campaigns and properties. Summing daily reach for Brand E in July gave **280,951**. The deduplicated monthly figure is **112,114**, which is what the dashboard publishes. Across brands, summing overstated by up to **+226%**.

The period tables (`ga4_users_period`, `meta_reach_period`) hold weekly, biweekly and monthly figures fetched from Windsor with explicit date ranges, so the platform does the deduplication. A small scheduled loader writes them (not in this repo). Its write is idempotent: it deletes exactly the (grain, period) pairs it is about to insert, so a re-run never doubles or erases a period. On top of these:

- `vw_reach_period_brand_initiative` and `vw_reach_period_brand`: exact when one campaign served the period, NULL plus an upper bound otherwise, never a sum
- `vw_users_period_brand`: by initiative, plus a single-brand branch that uses the property total for the two brands that own a whole property
- `vw_conversion_users_utm`: conversion rate on users at campaign grain, the grain the dashboard publishes at

### 7. Attribution

Our users and sessions for Brand E's Google campaign read 41% above the dashboard. Several hypotheses were tested and rejected first (thresholding, a medium filter, a broken loader). The answer was in the dashboard's filter: it uses GA4's **first-user** source and campaign, while the warehouse used session fields. With the same fields I reproduced the published **884 with 886 (0.23%)**; the session fields give 1,436. Both are correct, they answer different questions. `attribution/` holds a first-touch staging layer, a view with both bases side by side, and a `base_attribution` column on all eight contract views so the agent always knows which basis a number uses. The two scopes also return different campaign strings for the same traffic (auto-tagged name vs utm), so they can only be compared through the mapping.

### 8. Agent tables

The agent could not read views, only tables. Instead of registering 25 near-identical views, I built two tables covering all eight brands:

- `agent_daily`: one row per date, brand, channel and initiative
- `agent_period`: the same at weekly, biweekly and monthly grain, with ratios recomputed from period totals

Both carry the contract on every row: `has_funnel`, `has_leads`, `reach_is_additive`, `users_is_additive`, `base_vtr`, `base_attribution`, `brand_historical` and `data_provisional`. That last flag marks any period younger than three days, because a period is not final for about 38 hours (see below), so the agent can refuse to report an unsettled number. Types are cast explicitly so the schema does not move when a source view changes. Both are rebuilt by scheduled queries, and `qc_agent_freshness` compares each table against its source views (row count, spend, last date).

### 9. Reports (Apps Script)

Three client documents are filled from BigQuery table functions ([`apps-script/`](apps-script/)):

- **Brand A weekly report:** six sections (buttons, orientation, videos, associations, downloads, weekly dashboard and executive summary). Runs daily at 11:00 and skips Monday.
- **Brand B period report:** builds a new tab per biweekly and monthly period on the 3rd and 18th, and refreshes it daily for a week after.
- **Brand H period report:** video block, per-episode block and audio block.

Two findings drove the schedules. First, **a period is not final for about two days**: read 11 hours after the week closed, event metrics were 12 to 27% short; at 38 hours they matched the dashboard to the digit; at 7 days nothing moved. The client had reported "the numbers do not match", and the model was never wrong; it was read too early. Second, **users cannot be summed from daily rows** (6,005 summed against 5,812 true for one week), so the scripts call Windsor directly with an explicit date range for sessions and users. Every writer replaces its block instead of appending, so a re-run is safe. The scripts also fixed a total formula that had stopped extending (one column was short by exactly the newest week).

### 10. Operations and incidents

- **GA4 outage:** all GA4 tasks failed. The authorisation was fine; the property selection under it had one account ticked. Reconnecting does not re-tick boxes. Ticked the properties, reactivated 20 tasks, verified in BigQuery (freshness, zero exact duplicates), not from the connector status line.
- **A gap that `MAX(date)` did not show:** two middle days were never collected for four brands. Checking the newest date proves the newest day arrived, not that the days before it are there. Fixed with dated one-off task copies, then checked for duplicates with `COUNT(*) - COUNT(DISTINCT TO_JSON_STRING(t))`.
- **Duplicates from a backfill:** editing a task's URL re-ran its year-long backfill, which appends. 19,276 exact duplicates in one table, plus a second table written by two identical tasks. Fixed with backup, `TRUNCATE`, `INSERT SELECT DISTINCT` (a `CREATE OR REPLACE ... SELECT DISTINCT` would have dropped the partitioning and column descriptions). A "shortfall" chased for two days turned out to be this duplication.

## Queries

50 files in [`queries/`](queries/), numbered in the order they were run. Later files **replace** some objects created by earlier ones (they are migrations, built and verified next to the old definition), so run them in number order and never re-run an early brand file after its migration file. The main replacements: `26` and `33`/`34` replace parts of the brand files, `35` replaces the Google staging views, `39` replaces part of `05`, `44` is the final version of all eight contract views, `48` replaces the users and reach views from `17` and `21`, and `49`/`50` are the scheduled versions of the agent tables in `36`.

| File | What it does |
|---|---|
| **dimensions/** | |
| `01_dim_campaign.sql` | Cleaning view over the client's campaign mapping sheet: normalised `campaign_key`, inferred initiative where the sheet is blank, flagged as inferred |
| `12_dim_utm_mapping.sql` | GA4 utm to brand and initiative mapping (generated from an evidenced seed file) and `qc_utm_orphan` |
| **staging/** | |
| `31_staging_ga4_sessions_and_events.sql` | Shared session-grain and event-grain GA4 bases, session-scoped staging for Brands C, D, E, and a control on paid media rows the dashboard filters |
| `35_repoint_google_staging.sql` | Google staging for five brands moved to the new Google Ads table with `campaign_id` |
| **brand_models/** | |
| `02_brand_b_model.sql` | Brand B: staging for Google, Meta, DV360 and GA4, mart and contract view |
| `03_brand_a_model.sql` | Brand A: DV360 and GA4 traffic staging, report union, contract view, weekly orientation function |
| `05_brand_b_campaign_grain.sql` | Brand B at campaign grain: content catalogue, staging, contract view, rollups and two table functions |
| `06_brand_b_audience_geography_function.sql` | Table function that writes the audience geography sentence in Brand B's report |
| `13_brand_c_model.sql` | Brand C: Meta, Google and two-property GA4 staging, mart, contract view, rollups |
| `14_brand_d_model.sql` | Brand D: Meta and new DV360 staging, GA4 with a campaign filter, mart, contract view, rollups |
| `15_brand_e_model.sql` | Brand E: Meta, Google, GA4 staging, mart, contract view, rollups |
| `20_brand_e_staging_and_utm_fixes.sql` | Brand E GA4 staging fix, first version of the UTM complement and orphan control |
| `26_column_parity.sql` | Same columns on every brand (new users, daily reach, completed views), appended at the end for position-read reports |
| `28_brand_f_model.sql` | Brand F: full chain, reconciled against the platform catalogue |
| `29_brand_g_model.sql` | Brand G: full chain, historical flags |
| `30_brand_h_model.sql` | Brand H: DV360 only, VTR and CPV on TrueView views, rollups recomputed from totals |
| `33_migrate_brands_c_d_e_to_session_staging.sql` | Brand C, D, E marts and views moved onto session-scoped GA4 (adds users, bounce and engagement rate) |
| `34_migrate_brands_f_g_to_session_staging.sql` | Same migration for Brands F and G |
| `38_brand_h_episodes.sql` | Brand H per-episode layer: episode dimension, staging, rollup, two table functions, orphan control |
| `39_brand_b_metric_definitions.sql` | Brand B campaign layer on TrueView views, reach no longer summed, bases declared |
| `45_brand_h_audio.sql` | Brand H audio (Spotify) staging filtered to one campaign, table function, new-campaign control |
| **reach/** | |
| `16_period_users_reach_tables.sql` | Period users and reach tables and an internal consistency control |
| `17_period_users_reach_by_brand.sql` | Bridges period users and reach to brand, utm-by-property dimension, conversion views, two controls |
| `21_reach_by_period_and_brand.sql` | Reach by period at initiative and brand level, exact or NULL with an upper bound, and the "what summing would have published" control |
| `24_user_conversion_rate.sql` | Conversion rate on users at campaign and initiative grain, and the control that showed the loader is not thresholded |
| `48_period_users_reach_single_brand_properties.sql` | Final users and reach by brand, with property totals for the two single-brand properties |
| **attribution/** | |
| `41_first_touch_attribution.sql` | First-user GA4 staging, both scopes compared, divergence and freshness controls |
| `43_attribution_brand_e.sql` | Both attribution bases as columns on one row; reproduces the dashboard figure |
| `44_attribution_basis_on_contract_views.sql` | Final contract views for all eight brands with `base_attribution` declared |
| **rollups/** | |
| `04_rollups_brand_a_brand_b.sql` | Rollup bases and weekly, biweekly and monthly views for Brands A and B |
| **agent_tables/** | |
| `36_agent_tables_and_freshness_control.sql` | First build of the two agent tables and `qc_agent_freshness` |
| `49_agent_daily_table_scheduled.sql` | Scheduled daily agent table, all eight brands, with the historical flag |
| `50_agent_period_table_scheduled.sql` | Scheduled period agent table (weekly, biweekly, monthly) |
| **discovery/** | |
| `11_discovery_six_brands.sql` | Object inventory, `campaign_id` coverage, backfill reach, shared campaign ID, DV360 by brand |
| `27_discovery_three_brands.sql` | Gates for the last three brands: is the history there, does the shared ID split, what a blank initiative costs |
| **qc_and_reconciliation/** | |
| `07_qc_brand_b.sql` | Four controls: orphan campaigns, orphan content, spend vs sessions, freshness |
| `08_validation_brand_a_brand_b.sql` | Reconciliation, ingestion health and the diagnostics that found each defect |
| `09_validation_week_33_settling.sql` | One week side by side with the report, plus the daily breakdown that proved the early read |
| `10_diagnostic_orientation_clicks.sql` | Six queries that closed an orientation clicks gap, as a decision tree |
| `18_qc_brands_c_d_e.sql` | Four controls: spend vs sessions, freshness, missing campaigns, non-additive columns |
| `19_recon_brand_e.sql` | Brand E against the dashboard, with the published baseline inline |
| `22_qc_orphan_paid_utm.sql` | The orphan utm control that gates publication: catalogue-scoped, paid sources only, plus the UTM complement |
| `23_qc_control_fixes.sql` | Two control fixes (exclude the month in progress, case-insensitive source) |
| `25_verification_after_fixes.sql` | Verification of a day's deployment and the users tests |
| `32_diagnostic_sessions_vs_events.sql` | Session table vs event table, the check that justified the migration |
| `37_verification_before_trueview_change.sql` | Read-only pre-checks before the TrueView change: coverage, drift, the defect measured |
| `40_recon_brand_c_forms_campaign.sql` | Closed a 19.9% gap on one campaign: the catalogue spend was a stale snapshot |
| `42_qc_brand_a.sql` | Four controls: freshness, incomplete week, excluded orientation rows, users above sessions |
| `46_qc_ga4_reconnection.sql` | After the GA4 outage: write times, freshness, exact duplicates |
| `47_qc_missing_periods.sql` | Expected weekly and monthly periods with no row in the users table |

Every `qc_*` view passes when it returns no rows.

## Key problems found and fixed

| Problem | Effect | Fix |
|---|---|---|
| GA4 sessions pulled with event dimensions | Sessions 1.92x high, new users always 0 | Separate session-grain and event-grain sources |
| Non-breaking spaces in Google Ads campaign names | Three joins failed silently | `NORMALIZE(..., NFKC)` in one shared key |
| Invalid Windsor field name (`total_users` instead of `totalusers`) | Accepted, null on every row, no error | Validate every field list against the API before changing a connection |
| Connections scheduled at midnight UTC | Latest day read 8 to 12% low on every brand | Moved to noon UTC |
| No backfill on one Meta connection | First 3 days of a month never fetched | Backfill added, July then matched exactly |
| Duplicate load under the wrong upsert key | Meta overstated by 45%, no error | Correct match key, dedup, compare against the dashboard |
| Hardcoded campaign lists in staging, NULL initiative on unmatched rows | Campaigns dropped; NULL split each day into two rows that the rollup filter then deleted | Catalogue join; unmapped rows fail the join and surface in QC instead |
| One GA4 property read when a brand lands on two | Brand C sessions at 19% of true | Read both properties, remove the same traffic from Brand D |
| No campaign filter on Brand D GA4 | Brand D sessions 2.3x true | Campaign and medium filter through the UTM mapping |
| DV360 staging missing for one brand | Two campaigns invisible to the model | New staging view |
| VTR and CPV on the 100% quartile | 8.42% vs 31.84% published | TrueView views, basis declared in the contract |
| Daily reach summed | Up to +226% overstated | Period tables, exact or NULL |
| `SAFE_DIVIDE(0, users)` on a brand with no lead event | Published 0% conversion instead of undefined | Metric absent when the brand has no lead event |
| A defensive filter required exact strings on fields that resolve late | A whole Sunday excluded, 89 clicks lost | Read only after the data settles; control added for excluded rows |
| Report read 11 hours after the period closed | Events 12 to 27% short | Schedules rebuilt around a 38 hour settling window, provisional flag in the agent tables |
| Shared ad account carrying four advertisers | Another advertiser's impressions in a report | Campaign filter in staging, new-campaign control |
| Repo drifted from what was deployed | One file would have failed and broken a live report | Pull the live definition from `INFORMATION_SCHEMA` before editing any view |
| Agent read a frozen copy of one brand | No correction ever reached it | Two scheduled tables for all eight brands, freshness control |

## Reconciliation

Every change was checked against an outside source before it was called done, and the record kept the client's five fields: metric and period, source compared, variance, root cause, decision.

- **Against the dashboard** where a page exists (Brands A, B, C, D, E). Ratios were recomputed from the absolutes printed next to them. That is how two dashboard defects were found before any query ran: one page divided a channel's spend by the whole brand's leads (its CPA was published 2.7x too low), and another showed more users than sessions.
- **Against the platform catalogue and raw platform tables** where no page exists (Brands F, G, H, and Brand F's older history).
- **Against the report's own published figures** for the Apps Script documents, on several closed periods.
- **Rebuilt baselines.** A "before" number goes stale as soon as anything upstream moves. When comparing an old definition to a new one, I recomputed the old logic on today's data instead of using yesterday's figure. Once this turned an apparent gain of 93 sessions and 8 leads into the real 16 and 0.

| Check | Result |
|---|---|
| Brand A July spend, 3 channels | 20.0% gap closed to 0.018% (two connector rounding differences accepted) |
| Brand A weekly report, every metric | Exact once settled (38 hours) |
| Brand B micro-events by channel and campaign | Exact; the two half-month periods sum to the month |
| Brand C July paid media | Exact |
| Brand D July paid media / sessions | Exact / within 0.62% |
| Brand E Meta spend, impressions, clicks, CTR, CPC, monthly reach | Exact, reach to the unit |
| Brand E Google | Within 0.04% |
| Brand E first-user sessions | 886 vs 884 published (0.23%) |
| Brands F and G vs catalogue | Exact on every closed campaign |
| Brand H vs client report | Exact for three months, within 0.01% for a partial month; VTR 31.84 / 32.35 / 31.39 / 25.56 exact on four periods |
| Agent tables vs source views | `qc_agent_freshness` empty |

Accepted, documented differences: GA4 thresholding of low-volume rows on the dashboard side, two connector rounding differences of a few units, and one removed campaign worth 0.2% of one brand's spend.

## Results

- All eight brands on one standard layer: staging, mapping, mart, contract view, rollups, agent tables
- Paid media reconciles on all eight brands; GA4 reconciles wherever the dashboard filter could be reproduced, and where it differs the reason is documented
- The AI agent went from a frozen copy of one brand to two scheduled tables covering all eight, with the contract (what is additive, which basis, whether the period is settled) on every row
- Campaign onboarding became a row in the client's sheet instead of a code change in eight places
- Reach and users are exact or explicitly NULL, never summed
- Three client reports filled automatically on schedules built around when the data actually settles
- 140 BigQuery objects, each defined in a numbered file, including 28 QC views where there were almost none
