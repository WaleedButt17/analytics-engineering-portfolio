import os
import gzip
import json
from datetime import datetime, timedelta

import requests
from google.cloud import bigquery

PROJECT = os.environ['GCP_PROJECT']
CLIENT_ID = os.environ['ADS_API_CLIENT_ID']
CLIENT_SECRET = os.environ['ADS_API_CLIENT_SECRET']
REFRESH_TOKEN = os.environ['ADS_API_REFRESH_TOKEN']
PROFILE_ID = os.environ['ADS_API_PROFILE_ID']

yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
print(f'Processing date: {yesterday}')

client = bigquery.Client(project=PROJECT)

existing = list(client.query(f"""
    SELECT COUNT(*) as cnt
    FROM `{PROJECT}.raw.daily_amazon_ads`
    WHERE report_date = '{yesterday}'
""").result())

if existing[0].cnt > 0:
    print(f'Data already exists for {yesterday}, skipping')
else:
    queue = list(client.query(f"""
        SELECT report_id, download_url
        FROM `{PROJECT}.raw.amazon_ads_report_queue`
        WHERE report_date = '{yesterday}'
        AND status = 'READY'
        ORDER BY created_at DESC
        LIMIT 1
    """).result())

    if not queue:
        print(f'No READY report for {yesterday}, the status check may not have run yet')
    else:
        report_id = queue[0].report_id
        download_url = queue[0].download_url
        print(f'Found READY report: {report_id}')

        download_response = requests.get(download_url)

        if download_response.status_code != 200:
            print('URL expired, fetching a fresh URL from the Amazon Ads API')
            token_response = requests.post('https://api.amazon.com/auth/o2/token', data={
                'grant_type': 'refresh_token',
                'refresh_token': REFRESH_TOKEN,
                'client_id': CLIENT_ID,
                'client_secret': CLIENT_SECRET
            })
            access_token = token_response.json()['access_token']
            headers = {
                'Amazon-Advertising-API-ClientId': CLIENT_ID,
                'Amazon-Advertising-API-Scope': PROFILE_ID,
                'Authorization': f'Bearer {access_token}'
            }
            status_response = requests.get(
                f'https://advertising-api.amazon.com/reporting/reports/{report_id}',
                headers=headers
            )
            download_url = status_response.json()['url']
            download_response = requests.get(download_url)
            print('Fresh URL obtained')

        decompressed = gzip.decompress(download_response.content)
        records = json.loads(decompressed.decode('utf-8'))
        print(f'Records: {len(records)}')

        rows = []
        for r in records:
            rows.append({
                'report_date': yesterday,
                'campaign_id': str(r.get('campaignId', '')),
                'campaign_name': r.get('campaignName', ''),
                'impressions': int(r.get('impressions', 0)),
                'clicks': int(r.get('clicks', 0)),
                'cost': float(r.get('cost', 0)),
                'purchases_1d': int(r.get('purchases1d', 0)),
                'purchases_7d': int(r.get('purchases7d', 0)),
                'purchases_14d': int(r.get('purchases14d', 0)),
                'sales_1d': float(r.get('sales1d', 0)),
                'sales_7d': float(r.get('sales7d', 0)),
                'sales_14d': float(r.get('sales14d', 0)),
                'ingested_at': datetime.now().isoformat()
            })

        errors = client.insert_rows_json(f'{PROJECT}.raw.daily_amazon_ads', rows)
        if errors:
            print(f'BQ errors: {errors}')
        else:
            print(f'Inserted {len(rows)} rows successfully')

        done_rows = [{
            'report_date': yesterday,
            'report_id': report_id,
            'status': 'DONE',
            'download_url': '',
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat()
        }]
        client.insert_rows_json(f'{PROJECT}.raw.amazon_ads_report_queue', done_rows)
        print('Queue updated to DONE')
