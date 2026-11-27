import os
import gzip
import json
import time
from datetime import datetime, timedelta

import requests
from google.cloud import bigquery

PROJECT = os.environ['GCP_PROJECT']
LWA_CLIENT_ID = os.environ['SP_API_CLIENT_ID']
LWA_CLIENT_SECRET = os.environ['SP_API_CLIENT_SECRET']
REFRESH_TOKEN = os.environ['SP_API_REFRESH_TOKEN']
MARKETPLACE_ID = 'ATVPDKIKX0DER'
SP_API = 'https://sellingpartnerapi-na.amazon.com/reports/2021-06-30'

target_date = (datetime.now() - timedelta(days=2)).strftime('%Y-%m-%d')
print(f'Pulling sessions for: {target_date}')

client = bigquery.Client(project=PROJECT)

token_resp = requests.post('https://api.amazon.com/auth/o2/token', data={
    'grant_type': 'refresh_token',
    'refresh_token': REFRESH_TOKEN,
    'client_id': LWA_CLIENT_ID,
    'client_secret': LWA_CLIENT_SECRET
})
access_token = token_resp.json()['access_token']
headers = {'x-amz-access-token': access_token, 'Content-Type': 'application/json'}
print('Token OK')

report_resp = requests.post(
    f'{SP_API}/reports',
    headers=headers,
    json={
        'reportType': 'GET_SALES_AND_TRAFFIC_REPORT',
        'marketplaceIds': [MARKETPLACE_ID],
        'reportOptions': {'dateGranularity': 'DAY', 'asinGranularity': 'PARENT'},
        'dataStartTime': f'{target_date}T00:00:00Z',
        'dataEndTime': f'{target_date}T23:59:59Z'
    }
)
report_id = report_resp.json()['reportId']
print(f'Report ID: {report_id}')

for i in range(20):
    time.sleep(15)
    status_resp = requests.get(f'{SP_API}/reports/{report_id}', headers=headers)
    status = status_resp.json()['processingStatus']
    print(f'Attempt {i+1}: {status}')
    if status == 'DONE':
        doc_id = status_resp.json()['reportDocumentId']
        break
    elif status in ['FATAL', 'CANCELLED']:
        raise Exception('Report failed')

doc_resp = requests.get(f'{SP_API}/documents/{doc_id}', headers=headers)
download_url = doc_resp.json()['url']
download_resp = requests.get(download_url)
data = json.loads(gzip.decompress(download_resp.content).decode('utf-8'))
print('Report decompressed')

ingested_at = datetime.now().isoformat()
rows = []
for day_data in data['salesAndTrafficByDate']:
    sales = day_data['salesByDate']
    traffic = day_data['trafficByDate']
    rows.append({
        'ingested_at': ingested_at,
        'date': day_data['date'],
        'ordered_product_sales': sales['orderedProductSales']['amount'],
        'units_ordered': sales['unitsOrdered'],
        'total_order_items': sales['totalOrderItems'],
        'average_selling_price': sales['averageSellingPrice']['amount'],
        'units_refunded': sales['unitsRefunded'],
        'refund_rate': sales['refundRate'],
        'units_shipped': sales['unitsShipped'],
        'orders_shipped': sales['ordersShipped'],
        'shipped_product_sales': sales['shippedProductSales']['amount'],
        'page_views': traffic['pageViews'],
        'browser_page_views': traffic['browserPageViews'],
        'mobile_page_views': traffic['mobileAppPageViews'],
        'sessions': traffic['sessions'],
        'browser_sessions': traffic['browserSessions'],
        'mobile_sessions': traffic['mobileAppSessions'],
        'buy_box_percentage': traffic['buyBoxPercentage'],
        'unit_session_percentage': traffic['unitSessionPercentage'],
        'order_item_session_percentage': traffic['orderItemSessionPercentage']
    })

errors = client.insert_rows_json(f'{PROJECT}.raw.daily_amazon_traffic', rows)
if errors:
    print(f'Errors: {errors}')
else:
    print(f'Inserted {len(rows)} rows for {target_date}')
