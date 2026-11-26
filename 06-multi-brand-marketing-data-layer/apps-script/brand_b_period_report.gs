const CONFIG = {
  SPREADSHEET_ID: 'YOUR_SPREADSHEET_ID',
  PROJECT_ID: 'your-project',
  DATASET: 'marketing',
  TZ: 'Etc/GMT+6'
};

const COLS = {
  campaignName:      'campaign',
  startDateHeader:  'start date',
  cutoffDate:   'cutoff date',
  objective:     'objective',
  budgetSpent:  'budget spent',
  impressions:  'impressions',
  reachValue:      'total reach',
  clicks:        'clicks',
  sessionCount:     'sessions',
  views:        'views',
  associations: 'association clicks',
  videoStart:   'video start clicks',
  buttonA:     'clicks on "button a"',
  buttonB:         'clicks on "button b"'
};

const MONTHS = ['january','february','march','april','may','june',
               'july','august','september','october','november','december'];

const WINDSOR_KEY   = 'API-KEY';

const DV360_ACCOUNT = 'DV360_ADVERTISER_ID';

const MANUAL_COLS = ['population', 'segmentation', 'approved budget'];

function testRun() { buildSpecific(2026, 7, 2); }

function updateAll() {
  const p = previousClosedPeriod_();
  buildOrRefresh_(p);
  if (p.isMonthEnd) buildOrRefresh_(monthlyPeriodFor_(p));
}

function buildOrRefresh_(period) {
  const exists = !!SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID)
                                 .getSheetByName(period.name);
  buildPeriodSheet(period, exists);
  Logger.log('%s - %s', period.name, exists ? 'refreshed' : 'built');
}

function buildSpecific(year, month, half) {
  buildPeriodSheet(half === 0 ? monthlyPeriod_(year, month) : biweeklyPeriod_(year, month, half));
}

function buildWeek(year, month, day) {
  buildPeriodSheet(weeklyPeriodFor_(new Date(year, month - 1, day)));
}

function buildPeriodSheet(period, refresh) {
  const rows = queryBigQuery_(
    'SELECT channel, campaign_name, objective, spend_amount, impression_count, click_count, reach_count, ' +
    '       views, session_count, clicks_associations, clicks_video_start, ' +
    '       clicks_button_a, clicks_button_b, campaign_platform ' +
    'FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.tf_brand_b_campaign`' +
    "(DATE '" + period.periodStartIso + "', DATE '" + period.periodEndIso + "') " +
    'ORDER BY channel, campaign_name'
  );

  if (rows.length === 0) {
    throw new Error('No data for ' + period.periodStartIso + ' to ' + period.periodEndIso +
                    '. Check the period has closed and the connectors have run.');
  }

  const orphans = queryBigQuery_(
    'SELECT campaign, ROUND(SUM(revenue_advertiser), 2) AS spend_amount ' +
    'FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.dv360_campaign_v2` ' +
    "WHERE date BETWEEN DATE '" + period.periodStartIso + "' AND DATE '" + period.periodEndIso + "' " +
    '  AND LOWER(campaign) LIKE "%brand b%" ' +
    '  AND campaign NOT IN (SELECT campaign_platform FROM `' +
        CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.dim_content_brand_b`) ' +
    'GROUP BY 1 HAVING SUM(revenue_advertiser) > 0'
  );
  if (orphans.length > 0) {
    throw new Error('Campaign with spend and no catalogue entry: ' +
      orphans.map(function (h) { return h[0] + ' (' + h[1] + ')'; }).join(', ') +
      '. Add it to dim_content_brand_b before building this period.');
  }

  const ss = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID);
  const existingTab = ss.getSheetByName(period.name);

  let sheet;
  if (refresh) {
    if (!existingTab) throw new Error('Nothing to refresh: "' + period.name + '" does not exist.');
    sheet = existingTab;
  } else {
    if (existingTab) {
      throw new Error('Sheet "' + period.name + '" already exists. Delete it by ' +
                      'hand if you mean to rebuild, so nothing is overwritten silently.');
    }
    const templateTab = findTemplate_(ss, period.cadence);
    if (!templateTab) throw new Error('No previous ' + period.cadence +
                                    ' tab to use as a template.');
    sheet = ss.insertSheet(period.name, ss.getNumSheets(), {template: templateTab});
  }

  const byChannel = {};
  rows.forEach(function (r) {
    const channel = r[0];
    if (!byChannel[channel]) byChannel[channel] = [];
    byChannel[channel].push(r);
  });

  const reachValue = windsorReach_(period.periodStartIso, period.periodEndIso);

  const population = {};
  queryBigQuery_(
    'SELECT campaign_name, population FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET +
    ".tf_brand_b_population`(DATE '" + period.periodStartIso + "', DATE '" + period.periodEndIso + "')"
  ).forEach(function (r) { population[r[0]] = r[1]; });

  let written = 0;
  Object.keys(byChannel).forEach(function (channel) {
    written += writeBlock_(sheet, channel, byChannel[channel], period, reachValue, population, refresh);
  });

  Logger.log('%s - %s campaign rows across %s blocks%s',
             period.name, String(written), String(Object.keys(byChannel).length),
             refresh ? ' (refreshed)' : '');
}

function writeBlock_(sheet, channel, rowList, period, reachValue, population, refresh) {
  const titleRow = findBlockTitle_(sheet, channel);
  if (titleRow === -1) {

    throw new Error('Data for ' + channel + ' but no ' + channel + ' block in the ' +
                    'template. Add the block by hand, then rerun.');
  }

  const headerRow = titleRow + 1;
  let colMap = headerMap_(sheet, headerRow);
  let totalRow = findTotalRow_(sheet, headerRow);
  if (totalRow === -1) throw new Error('No Total row under the ' + channel + ' block.');

  const campaignCol = col_(colMap, COLS.campaignName);
  if (!campaignCol) throw new Error('No Campaign column in the ' + channel + ' block.');

  const firstRowNum     = findFirstDataRow_(sheet, headerRow, totalRow, campaignCol);
  const rowHeight    = sheet.getRowHeight(firstRowNum);

  const headerHeight  = sheet.getRowHeight(headerRow);

  if (!refresh && totalRow - firstRowNum > 0) {
    sheet.getRange(firstRowNum, 1, totalRow - firstRowNum, sheet.getLastColumn())
         .getMergedRanges()
         .forEach(function (r) { if (r.getRow() >= firstRowNum) r.breakApart(); });
    totalRow = findTotalRow_(sheet, headerRow);
  }

  const available = totalRow - firstRowNum;
  const required  = rowList.length;

  if (refresh) {
    if (required !== available) {
      throw new Error('Refresh aborted on ' + channel + ': the sheet has ' + available +
                      ' campaign rows and the query returns ' + required +
                      '. Delete the tab and rebuild it if the campaigns have changed.');
    }
    const inTab = sheet.getRange(firstRowNum, campaignCol, required, 1).getValues();
    for (let i = 0; i < required; i++) {
      if (norm_(inTab[i][0]) !== norm_(rowList[i][1])) {
        throw new Error('Refresh aborted on ' + channel + ': row ' + (firstRowNum + i) +
                        ' holds "' + inTab[i][0] + '" but the query returns "' +
                        rowList[i][1] + '". Rebuild the tab by hand.');
      }
    }
  }

  if (!refresh && required > available) {
    sheet.insertRowsBefore(totalRow, required - available);
    sheet.getRange(firstRowNum, 1, 1, sheet.getLastColumn())
         .copyTo(sheet.getRange(totalRow, 1, required - available, sheet.getLastColumn()),
                 SpreadsheetApp.CopyPasteType.PASTE_FORMAT, false);
  } else if (!refresh && required < available) {
    sheet.deleteRows(firstRowNum + required, available - required);
  }

  totalRow = findTotalRow_(sheet, headerRow);
  colMap     = headerMap_(sheet, headerRow);

  if (!refresh) {
    MANUAL_COLS.forEach(function (h) {
      const c = col_(colMap, h);
      if (c) sheet.getRange(firstRowNum, c, required, 1).clearContent();
    });
  }

  const startTxt = formatDateLabel_(period.periodStart);
  const cutoffTxt  = formatDateLabel_(period.periodEnd);

  const dateValues = dateCols_(sheet, headerRow);

  rowList.forEach(function (r, i) {
    const row = firstRowNum + i;
    setIf_(sheet, row, col_(colMap, COLS.campaignName),      r[1]);
    setIf_(sheet, row, dateValues[0],                     startTxt);
    setIf_(sheet, row, dateValues[1],                     cutoffTxt);
    setIf_(sheet, row, col_(colMap, COLS.objective),     r[2]);
    setIf_(sheet, row, col_(colMap, COLS.budgetSpent),  num_(r[3]));
    setIf_(sheet, row, col_(colMap, COLS.impressions),  num_(r[4]));
    setIf_(sheet, row, col_(colMap, COLS.clicks),        num_(r[5]));

    const colAlc = colAny_(colMap, COLS.reachValue);
    const reach  = reachValue[r[13]];
    setIf_(sheet, row, colAlc, reach === undefined ? 'NA' : reach);

    if (!refresh && population[r[1]]) setIf_(sheet, row, col_(colMap, 'population'), population[r[1]]);

    setIf_(sheet, row, col_(colMap, COLS.views),        r[7] === null ? 'N/A' : num_(r[7]));
    setIf_(sheet, row, col_(colMap, COLS.sessionCount),     num_(r[8]));
    setIf_(sheet, row, col_(colMap, COLS.associations), num_(r[9]));
    setIf_(sheet, row, col_(colMap, COLS.videoStart),   num_(r[10]));
    setIf_(sheet, row, col_(colMap, COLS.buttonA),     num_(r[11]));
    setIf_(sheet, row, col_(colMap, COLS.buttonB),         num_(r[12]));
  });

  [COLS.impressions, COLS.reachValue, COLS.clicks, COLS.views, COLS.sessionCount,
   COLS.associations, COLS.videoStart, COLS.buttonA, COLS.buttonB].forEach(function (k) {
    const c = colAny_(colMap, k);
    if (c) sheet.getRange(firstRowNum, c, required, 1).setNumberFormat('#,##0');
  });

  sheet.setRowHeight(headerRow, headerHeight);
  for (let i = 0; i < required; i++) sheet.setRowHeight(firstRowNum + i, rowHeight);

  writeTotals_(sheet, colMap, firstRowNum, firstRowNum + required - 1, totalRow);
  return required;
}

function findFirstDataRow_(sheet, headerRow, totalRow, campaignCol) {
  const n = totalRow - headerRow - 1;
  if (n < 1) return headerRow + 1;
  const vals = sheet.getRange(headerRow + 1, campaignCol, n, 1).getValues();
  for (let i = 0; i < vals.length; i++) {
    if (String(vals[i][0]).trim() !== '') return headerRow + 1 + i;
  }
  return headerRow + 1;
}

function colAny_(colMap, keys) {
  const list = Array.isArray(keys) ? keys : [keys];
  for (let i = 0; i < list.length; i++) {
    const c = col_(colMap, list[i]);
    if (c) return c;
  }
  return null;
}

function col_(colMap, key) {
  if (colMap[key]) return colMap[key];
  const ks = Object.keys(colMap);
  for (let i = 0; i < ks.length; i++) {
    if (ks[i].indexOf(key) === 0) return colMap[ks[i]];
  }
  return null;
}

function writeTotals_(sheet, colMap, firstRowNum, lastOne, totalRow) {

  const summable = [COLS.budgetSpent, COLS.impressions, COLS.clicks,
                    COLS.views, COLS.sessionCount, COLS.associations, COLS.videoStart,
                    COLS.buttonA, COLS.buttonB];
  summable.forEach(function (k) {
    const col = colAny_(colMap, k);
    if (!col) return;
    const L = colLetter_(col);
    sheet.getRange(totalRow, col).setFormula('=SUM(' + L + firstRowNum + ':' + L + lastOne + ')');
  });

  const colReach = colAny_(colMap, COLS.reachValue);
  if (colReach) sheet.getRange(totalRow, colReach).setValue('NA');
}

function findBlockTitle_(sheet, channel) {
  const last = sheet.getLastRow();
  const vals = sheet.getRange(1, 1, last, sheet.getLastColumn()).getValues();
  for (let i = 0; i < vals.length; i++) {
    for (let j = 0; j < vals[i].length; j++) {
      if (norm_(vals[i][j]) === norm_(channel)) return i + 1;
    }
  }
  return -1;
}

function headerMap_(sheet, headerRow) {
  const vals = sheet.getRange(headerRow, 1, 1, sheet.getLastColumn()).getValues()[0];
  const m = {};
  for (let i = 0; i < vals.length; i++) {
    const k = norm_(vals[i]);
    if (k) m[k] = i + 1;
  }
  return m;
}

function findTotalRow_(sheet, headerRow) {
  const last = sheet.getLastRow();
  const vals = sheet.getRange(1, 1, last, sheet.getLastColumn()).getValues();
  const titles = ['dv360', 'google', 'meta'];

  for (let i = headerRow; i < vals.length; i++) {
    for (let j = 0; j < vals[i].length; j++) {
      const v = norm_(vals[i][j]);
      if (!v) continue;
      if (v.indexOf('total') === 0) return i + 1;
      if (titles.indexOf(v) !== -1) return -1;
    }
  }
  return -1;
}

function findTemplate_(ss, cadence) {
  const tabs = ss.getSheets();
  const keyName = {weeklyLabel: 'weekly', biweeklyLabel: 'biweekly', monthlyLabel: 'monthly'}[cadence];

  for (let i = tabs.length - 1; i >= 0; i--) {
    const n = norm_(tabs[i].getName());
    if (n.indexOf(keyName) !== -1) return tabs[i];
  }
  if (cadence === 'weekly') return findTemplate_(ss, 'biweekly');
  return null;
}

function setIf_(sheet, row, col, value) {
  if (col) sheet.getRange(row, col).setValue(value);
}

function dateCols_(sheet, headerRow) {
  const vals = sheet.getRange(headerRow, 1, 1, sheet.getLastColumn()).getValues()[0];
  const cols = [];
  for (let i = 0; i < vals.length; i++) {
    if (norm_(vals[i]).indexOf('date') === 0) cols.push(i + 1);
  }
  return [cols[0] || null, cols[1] || null];
}

function previousClosedPeriod_() {
  const today = new Date();
  const y = Number(Utilities.formatDate(today, CONFIG.TZ, 'yyyy'));
  const m = Number(Utilities.formatDate(today, CONFIG.TZ, 'MM'));
  const d = Number(Utilities.formatDate(today, CONFIG.TZ, 'dd'));

  if (d >= 16) return biweeklyPeriod_(y, m, 1);
  const pm = m === 1 ? 12 : m - 1;
  const py = m === 1 ? y - 1 : y;
  return biweeklyPeriod_(py, pm, 2);
}

function biweeklyPeriod_(y, m, half) {
  const periodStart = half === 1 ? new Date(y, m - 1, 1) : new Date(y, m - 1, 16);
  const periodEnd    = half === 1 ? new Date(y, m - 1, 15) : new Date(y, m, 0);
  return {
    periodStart: periodStart, periodEnd: periodEnd,
    periodStartIso: iso_(periodStart), periodEndIso: iso_(periodEnd),
    name: 'Biweekly cutoff - ' + (half === 1 ? '1-15 ' : '16-31 ') + MONTHS[m - 1] + ' ' + y,
    cadence: 'biweekly',
    isMonthEnd: half === 2,
    yearNum: y, monthNum: m
  };
}

function monthlyPeriod_(y, m) {
  const periodStart = new Date(y, m - 1, 1);
  const periodEnd    = new Date(y, m, 0);
  return {
    periodStart: periodStart, periodEnd: periodEnd,
    periodStartIso: iso_(periodStart), periodEndIso: iso_(periodEnd),
    name: 'Monthly cutoff - ' + MONTHS[m - 1] + ' ' + y,
    cadence: 'monthly', isMonthEnd: false, yearNum: y, monthNum: m
  };
}

function weeklyPeriodFor_(dateValue) {
  const dow = Number(Utilities.formatDate(dateValue, CONFIG.TZ, 'u'));
  const dayNum2 = 24 * 60 * 60 * 1000;
  const periodStart = new Date(dateValue.getTime() - (dow - 1) * dayNum2);
  const periodEnd    = new Date(periodStart.getTime() + 6 * dayNum2);

  const dI = Number(Utilities.formatDate(periodStart, CONFIG.TZ, 'dd'));
  const mI = Number(Utilities.formatDate(periodStart, CONFIG.TZ, 'MM'));
  const dF = Number(Utilities.formatDate(periodEnd,    CONFIG.TZ, 'dd'));
  const mF = Number(Utilities.formatDate(periodEnd,    CONFIG.TZ, 'MM'));
  const yF = Number(Utilities.formatDate(periodEnd,    CONFIG.TZ, 'yyyy'));

  const labelText = mI === mF
    ? dI + '-' + dF + ' ' + MONTHS[mI - 1]
    : dI + ' ' + MONTHS[mI - 1] + ' - ' + dF + ' ' + MONTHS[mF - 1];

  return {
    periodStart: periodStart, periodEnd: periodEnd,
    periodStartIso: iso_(periodStart), periodEndIso: iso_(periodEnd),
    name: 'Weekly cutoff - ' + labelText + ' ' + yF,
    cadence: 'weekly', isMonthEnd: false,
    yearNum: yF, monthNum: mF
  };
}

function monthlyPeriodFor_(p) { return monthlyPeriod_(p.yearNum, p.monthNum); }

function iso_(d) { return Utilities.formatDate(d, CONFIG.TZ, 'yyyy-MM-dd'); }

function formatDateLabel_(d) {
  return Number(Utilities.formatDate(d, CONFIG.TZ, 'dd')) + ' of ' +
         MONTHS[Number(Utilities.formatDate(d, CONFIG.TZ, 'MM')) - 1];
}

function windsorReach_(periodStartIso, periodEndIso) {
  const url = 'WINDSOR_CONNECTORS_ENDPOINT/dv360'
    + '?api_key=' + WINDSOR_KEY
    + '&date_from=' + periodStartIso
    + '&date_to=' + periodEndIso
    + '&fields=campaign,unique_reach_impression_reach'
    + '&select_accounts=' + DV360_ACCOUNT;

  const res = UrlFetchApp.fetch(url, {muteHttpExceptions: true});
  if (res.getResponseCode() !== 200) {
    throw new Error('Windsor returned ' + res.getResponseCode() + ' for reach: ' +
                    res.getContentText());
  }

  const body = JSON.parse(res.getContentText());
  const rows = body.data || body.rows || (Array.isArray(body) ? body : []);
  const m = {};

  rows.forEach(function (r) {
    const campaignName = r.campaign || r.Campaign || r.campaignName;
    if (!campaignName) return;
    let v = null;
    Object.keys(r).forEach(function (k) {
      const nk = k.toLowerCase().replace(/[^a-z]/g, '');
      if (v === null && nk.indexOf('reach') !== -1 && nk.indexOf('impression') !== -1) {
        v = r[k];
      }
    });
    if (v !== null && v !== '' && !isNaN(Number(v))) m[campaignName] = Number(v);
  });

  if (Object.keys(m).length === 0) {
    Logger.log('Reach returned nothing. First row was: %s',
               JSON.stringify(rows[0] || {}));
  }
  return m;
}

function queryBigQuery_(sql) {
  let job = BigQuery.Jobs.query({query: sql, useLegacySql: false}, CONFIG.PROJECT_ID);
  const jobId = job.jobReference.jobId;

  while (!job.jobComplete) {
    Utilities.sleep(1000);
    job = BigQuery.Jobs.getQueryResults(CONFIG.PROJECT_ID, jobId);
  }

  let out = (job.rows || []).slice();
  let token = job.pageToken;
  while (token) {
    const page = BigQuery.Jobs.getQueryResults(CONFIG.PROJECT_ID, jobId, {pageToken: token});
    out = out.concat(page.rows || []);
    token = page.pageToken;
  }
  return out.map(function (r) { return r.f.map(function (c) { return c.v; }); });
}

function norm_(s) {
  return String(s == null ? '' : s)
    .normalize('NFKC')

    .replace(/[\u200B-\u200F\u2060\u2066-\u2069\uFEFF]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

function num_(v) { return v === null || v === '' ? 0 : Number(v); }

function colLetter_(n) {
  let s = '';
  while (n > 0) {
    const m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - m - 1) / 26;
  }
  return s;
}

function createAllTriggers() {
  createBiweeklyTrigger();
  createMonthlyTrigger();
  createRefreshTrigger();
  Logger.log('Three triggers: biweekly on the 3rd and 18th, monthly on the 3rd, ' +
             'refresh daily from day 4 to day 10 after a period closes.');
}

function createBiweeklyTrigger() {
  deleteTrigger_('biweeklyRun');
  ScriptApp.newTrigger('biweeklyRun').timeBased().everyDays(1).atHour(11).create();
}

function createMonthlyTrigger() {
  deleteTrigger_('monthlyRun');
  ScriptApp.newTrigger('monthlyRun').timeBased().everyDays(1).atHour(11).create();
}

function createRefreshTrigger() {
  deleteTrigger_('refreshRun');
  ScriptApp.newTrigger('refreshRun').timeBased().everyDays(1).atHour(11).create();
}

function deleteTrigger_(name) {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === name) ScriptApp.deleteTrigger(t);
  });
}

function biweeklyRun() {
  const d = Number(Utilities.formatDate(new Date(), CONFIG.TZ, 'dd'));
  if (d !== 3 && d !== 18) return;
  buildOrRefresh_(previousClosedPeriod_());
}

function refreshRun() {
  const dayNum2 = 24 * 60 * 60 * 1000;
  const today = new Date(iso_(new Date()) + 'T12:00:00');
  const p = previousClosedPeriod_();
  const days = Math.round((today - new Date(p.periodEndIso + 'T12:00:00')) / dayNum2);
  if (days < 4 || days > 10) return;

  refreshIfExists_(p);

  if (p.isMonthEnd) refreshIfExists_(monthlyPeriodFor_(p));
}

function refreshIfExists_(period) {
  const ss = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID);
  if (!ss.getSheetByName(period.name)) {
    Logger.log('Refresh skipped, "%s" does not exist yet.', period.name);
    return;
  }
  buildPeriodSheet(period, true);
}

function refreshNow() { buildPeriodSheet(previousClosedPeriod_(), true); }

function monthlyRun() {
  const today = new Date();
  if (Number(Utilities.formatDate(today, CONFIG.TZ, 'dd')) !== 3) return;
  const m = Number(Utilities.formatDate(today, CONFIG.TZ, 'MM'));
  const y = Number(Utilities.formatDate(today, CONFIG.TZ, 'yyyy'));
  buildOrRefresh_(monthlyPeriod_(m === 1 ? y - 1 : y, m === 1 ? 12 : m - 1));
}
