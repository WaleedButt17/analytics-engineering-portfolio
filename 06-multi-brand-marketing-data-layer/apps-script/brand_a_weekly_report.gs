const CONFIG = {
  SPREADSHEET_ID: 'YOUR_SPREADSHEET_ID',
  PROJECT_ID: 'your-project',
  DATASET: 'marketing',
  TZ: 'Etc/GMT+6'
};

const WINDSOR_KEY = 'API-KEY';
const GA4_BRAND_A  = 'googleanalytics4__ga4_property_A';

function updateAll() {
  const dow = Number(Utilities.formatDate(new Date(), CONFIG.TZ, 'u'));
  if (dow === 1) {
    Logger.log('Monday: skipped. The week that just closed has not settled yet.');
    return;
  }

  updateButtons();
  updateOrientation();
  updateVideos();
  updateAssociations();
  updateDownloads();
  updateWeeklyDashboard();
  updateExecutiveSummary();
}

function updateButtons() {
  runBlockSheet_({
    sheet: 'Segmentation Buttons',
    fn: 'tf_brand_a_weekly_buttons',
    select: 'source_medium, campaign, button, clicks',
    cols: 7,
    noun: 'buttons',
    row: function (r, i, total, label) {

      return [i + 1, r[0], r[1], r[2], Number(r[3]), label, Number(r[3]) / total];
    },
    totalRow: function (sheet, row, total) {
      sheet.getRange(row, 4).setValue('WEEK TOTAL');
      sheet.getRange(row, 5).setValue(total);
      sheet.getRange(row, 7).setValue(1);
    }
  });
}

function updateOrientation() {
  runBlockSheet_({
    sheet: 'Orientation Clicks',

    fn: 'tf_brand_a_weekly_orientation_v2',
    select: 'source_medium, campaign, click_origin, clicks',
    cols: 6,
    noun: 'orientation',
    row: function (r, i, total, label) {
      return [i + 1, r[0], r[1], r[2], Number(r[3]), label];
    },
    totalRow: function (sheet, row, total) {
      sheet.getRange(row, 4).setValue('WEEK TOTAL');
      sheet.getRange(row, 5).setValue(total);
    }
  });
}

function updateVideos() {
  const week = previousCompletedWeek_();

  const rows = queryBigQuery_(
    'SELECT video_title, progress_0, progress_10, progress_25, progress_50, progress_75, progress_100 ' +
    'FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.tf_brand_a_weekly_videos`' +
    "(DATE '" + week.startIso + "', DATE '" + week.endIso + "') " +
    'ORDER BY progress_0 DESC'
  );
  if (rows.length === 0) throw new Error('Videos: no rows for ' + week.startIso);

  const sheet = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID)
                              .getSheetByName('Videos and Associations');

  const boundary = findRowStartingWith_(sheet, 1, 'CLICKS ON ASSOCIATIONS');
  if (boundary === -1) throw new Error('Cannot find the CLICKS ON ASSOCIATIONS heading.');

  const weekCol = sheet.getRange(1, 2, boundary - 1, 1).getValues();
  for (let i = weekCol.length - 1; i >= 0; i--) {
    if (String(weekCol[i][0]).trim() === week.label) sheet.deleteRow(i + 1);
  }

  const insertAt = findRowStartingWith_(sheet, 1, 'CLICKS ON ASSOCIATIONS');
  const n = rows.length;
  sheet.insertRowsBefore(insertAt, n);

  const body = rows.map(function (r) {
    return [r[0], week.label].concat(r.slice(1).map(function (v) {
      return Number(v) === 0 ? '-' : Number(v);
    }));
  });
  sheet.getRange(insertAt, 1, n, 8).setValues(body);

  sheet.getRange(insertAt - 1, 1, 1, 8)
       .copyTo(sheet.getRange(insertAt, 1, n, 8),
               SpreadsheetApp.CopyPasteType.PASTE_FORMAT, false);

  Logger.log('Videos - %s: %s rows', week.label, String(n));
}

function updateAssociations() {
  const week = previousCompletedWeek_();

  const rows = queryBigQuery_(
    'SELECT SUM(clicks_assoc_org_1), SUM(clicks_assoc_org_2), SUM(clicks_assoc_org_3), ' +
    '       SUM(clicks_assoc_org_4), SUM(clicks_assoc_org_5) ' +
    'FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.vw_brand_a_rollup_weekly_v3` ' +
    "WHERE period_start = DATE '" + week.startIso + "'"
  );
  if (rows.length === 0 || rows[0][0] === null) {
    throw new Error('Associations: no data for ' + week.startIso);
  }

  const v = rows[0].map(Number);
  const total = v.reduce(function (a, b) { return a + b; }, 0);

  const sheet = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID)
                              .getSheetByName('Videos and Associations');

  const totalRow = findRowStartingWith_(sheet, 1, 'CUMULATIVE TOTAL');
  if (totalRow === -1) throw new Error('Cannot find CUMULATIVE TOTAL.');

  const label = week.label + ': ' + week.range.replace(/\/\d{4}$/, '');
  const existing = findRowStartingWith_(sheet, 1, week.label + ':');

  let target;
  if (existing !== -1 && existing < totalRow) {
    target = existing;
  } else {
    sheet.insertRowsBefore(totalRow, 1);
    target = totalRow;
    sheet.getRange(target - 1, 1, 1, 8)
         .copyTo(sheet.getRange(target, 1, 1, 8),
                 SpreadsheetApp.CopyPasteType.PASTE_FORMAT, false);
  }

  sheet.getRange(target, 1, 1, 8)
       .setValues([[label, v[0], v[1], v[2], v[3], v[4], 0, total]]);

  const totalNow  = findRowStartingWith_(sheet, 1, 'CUMULATIVE TOTAL');
  const firstData = firstAssociationsRow_(sheet, totalNow);
  const lastData  = totalNow - 1;
  ['B', 'C', 'D', 'E', 'F', 'G', 'H'].forEach(function (col) {
    sheet.getRange(col + totalNow)
         .setFormula('=SUM(' + col + firstData + ':' + col + lastData + ')');
  });

  Logger.log('Associations - %s: total %s', week.label, formatNumber_(total));
}

function updateDownloads() {
  const week = previousCompletedWeek_();

  const rows = queryBigQuery_(
    'SELECT file_name, link_url, SUM(event_count) AS events_cte ' +
    'FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.ga4_brand_a_downloads` ' +
    "WHERE date BETWEEN DATE '" + week.startIso + "' AND DATE '" + week.endIso + "' " +
    "  AND event_name = 'file_download' " +
    'GROUP BY 1, 2 ORDER BY events_cte DESC'
  );
  if (rows.length === 0) throw new Error('Downloads: no rows for ' + week.startIso);

  const total = rows.reduce(function (s, r) { return s + Number(r[2]); }, 0);

  const sheet = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID)
                              .getSheetByName('Videos and Associations');

  const marker = 'FILE DOWNLOADS - ' + week.label;
  removeDownloadBlock_(sheet, marker);

  const template = findLastDownload_(sheet);
  const startRow = sheet.getLastRow() + 2;
  const n = rows.length;

  sheet.getRange(startRow, 1).setValue(marker + ' (' + total + ' total events)');
  sheet.getRange(startRow + 1, 1, 1, 4)
       .setValues([['#', 'File Name', 'Link (partial)', 'Events']]);

  const body = rows.map(function (r, i) { return [i + 1, r[0], r[1], Number(r[2])]; });
  sheet.getRange(startRow + 2, 1, n, 4).setValues(body);

  const totalRow = startRow + 2 + n;
  sheet.getRange(totalRow, 2).setValue('TOTAL');
  sheet.getRange(totalRow, 4).setValue(total);

  if (template) {
    const fmt = SpreadsheetApp.CopyPasteType.PASTE_FORMAT;
    sheet.getRange(template.headerRow, 1, 1, 4)
         .copyTo(sheet.getRange(startRow, 1, 1, 4), fmt, false);
    sheet.getRange(template.headerRow + 1, 1, 1, 4)
         .copyTo(sheet.getRange(startRow + 1, 1, 1, 4), fmt, false);
    sheet.getRange(template.firstDataRow, 1, 1, 4)
         .copyTo(sheet.getRange(startRow + 2, 1, n, 4), fmt, false);
    sheet.getRange(template.totalRow, 1, 1, 4)
         .copyTo(sheet.getRange(totalRow, 1, 1, 4), fmt, false);
  }

  Logger.log('Downloads - %s: %s files, %s events', week.label, String(n), String(total));
}

function updateWeeklyDashboard() {
  const week = previousCompletedWeek_();
  const d = weekMetrics_(week);

  const sheet = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID)
                              .getSheetByName('Weekly Dashboard');
  const totalRow = findRowStartingWith_(sheet, 1, 'PERIOD TOTAL');
  if (totalRow === -1) throw new Error('Cannot find PERIOD TOTAL.');

  const label = week.label + ': ' + week.range;
  const existing = findRowStartingWith_(sheet, 1, week.label + ':');

  let target;
  if (existing !== -1 && existing < totalRow) {
    target = existing;
  } else {
    sheet.insertRowsBefore(totalRow, 1);
    target = totalRow;
    sheet.getRange(target - 1, 1, 1, 11)
         .copyTo(sheet.getRange(target, 1, 1, 11),
                 SpreadsheetApp.CopyPasteType.PASTE_FORMAT, false);
  }

  const prevSessions = Number(sheet.getRange(target - 1, 2).getValue());
  const variation = prevSessions > 0 ? (d.sessions - prevSessions) / prevSessions : 'N/D';

  sheet.getRange(target, 1, 1, 11).setValues([[
    label, d.sessions, d.users, variation,
    d.segment1, d.segment2, d.orientation,
    d.leads, d.org1, d.org2,
    'Actual data ✓ Full week (' + week.range + ')'
  ]]);

  const totalNow  = findRowStartingWith_(sheet, 1, 'PERIOD TOTAL');
  const firstData = 4;
  const lastData  = totalNow - 1;
  ['B', 'C', 'E', 'F', 'G', 'H', 'I', 'J'].forEach(function (col) {
    sheet.getRange(col + totalNow)
         .setFormula('=SUM(' + col + firstData + ':' + col + lastData + ')');
  });

  const firstLabel = String(sheet.getRange(firstData, 1).getValue());
  const fromLabel = (firstLabel.match(/(\d{2}\/\d{2})/) || ['', ''])[1];
  const toLabel = week.range.split(' - ')[1] || week.range;
  const weekFrom = (firstLabel.match(/Week\s+(\d+)/) || ['', ''])[1];
  if (fromLabel && weekFrom) {
    sheet.getRange(totalNow, 1)
         .setValue('PERIOD TOTAL  ' + fromLabel + '-' + toLabel + ' \u2605');
    sheet.getRange(totalNow, 11)
         .setValue('Official Looker total Week ' + weekFrom + ' to ' +
                   week.label.replace('Week ', ''));
  }

  Logger.log('Weekly Dashboard - %s: %s sessions, %s users',
             week.label, formatNumber_(d.sessions), formatNumber_(d.users));
}

function updateExecutiveSummary() {
  const week = previousCompletedWeek_();
  const d = weekMetrics_(week);

  const sheet = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID)
                              .getSheetByName('Executive Summary');
  if (!sheet) throw new Error('Sheet not found: Executive Summary');

  const HEADER_ROW = 5;
  const FIRST_KPI  = 6;
  const LAST_KPI   = 14;
  const fmt = SpreadsheetApp.CopyPasteType.PASTE_FORMAT;

  const headers = sheet.getRange(HEADER_ROW, 1, 1, sheet.getLastColumn()).getValues()[0];
  let totalCol = -1, existingCol = -1;
  for (let i = 0; i < headers.length; i++) {
    const v = String(headers[i]).trim();
    if (totalCol === -1 && v.indexOf('TOTAL') === 0) totalCol = i + 1;
    if (v.indexOf(week.label) === 0) existingCol = i + 1;
  }
  if (totalCol === -1) throw new Error('Cannot find the TOTAL column in row ' + HEADER_ROW + '.');

  let target;
  if (existingCol !== -1 && existingCol < totalCol) {
    target = existingCol;
  } else {
    sheet.insertColumnBefore(totalCol);
    target = totalCol;
    sheet.getRange(HEADER_ROW, target - 1, LAST_KPI - HEADER_ROW + 1, 1)
         .copyTo(sheet.getRange(HEADER_ROW, target, LAST_KPI - HEADER_ROW + 1, 1), fmt, false);
  }

  const shortRange = week.range.replace(/\/\d{4}$/, '').replace(' - ', '-');
  sheet.getRange(HEADER_ROW, target).setValue(week.label + '\n(' + shortRange + ')');

  sheet.getRange(FIRST_KPI, target, 9, 1).setValues([
    [d.sessions],
    [d.users],
    [d.orientation],
    [d.segment1 + d.segment2],
    [d.segment1],
    [d.segment2],
    [d.leads],
    [d.org1],
    [d.org2]
  ]);

  const headers2 = sheet.getRange(HEADER_ROW, 1, 1, sheet.getLastColumn()).getValues()[0];
  let newTotalCol = -1;
  for (let i = 0; i < headers2.length; i++) {
    if (String(headers2[i]).trim().indexOf('TOTAL') === 0) { newTotalCol = i + 1; break; }
  }
  const first = colLetter_(2);
  const last  = colLetter_(newTotalCol - 1);
  for (let r = FIRST_KPI; r <= LAST_KPI; r++) {
    sheet.getRange(r, newTotalCol).setFormula('=SUM(' + first + r + ':' + last + r + ')');
  }

  const weekNum = week.label.replace('Week ', '');
  const today = Utilities.formatDate(new Date(), CONFIG.TZ, 'dd/MM/yyyy');
  sheet.getRange(2, 1).setValue(
    'Source: BigQuery + Windsor  |  Week 22-' + weekNum + '  |  Updated: ' + today
  );
  sheet.getRange(4, 1).setValue('CUMULATIVE CAMPAIGN KPIS - WEEK 22 TO ' + weekNum);

  Logger.log('Executive Summary - %s: column %s', week.label, colLetter_(target));
}

function weekMetrics_(week) {

  const w = windsorTotals_(week.startIso, week.endIso, GA4_BRAND_A);

  const buttons = queryBigQuery_(
    'SELECT button, SUM(clicks) FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET +
    ".tf_brand_a_weekly_buttons`(DATE '" + week.startIso + "', DATE '" + week.endIso + "') " +
    'GROUP BY button'
  );
  let segment1 = 0, segment2 = 0;
  buttons.forEach(function (r) {
    if (r[0] === 'segment_1')     segment1 = Number(r[1]);
    if (r[0] === 'segment_2') segment2 = Number(r[1]);
  });

  const orient = queryBigQuery_(
    'SELECT SUM(clicks) FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET +
    ".tf_brand_a_weekly_orientation_v2`(DATE '" + week.startIso + "', DATE '" + week.endIso + "')"
  );

  const rollup = queryBigQuery_(
    'SELECT SUM(leads), SUM(clicks_assoc_org_1), SUM(clicks_assoc_org_2) ' +
    'FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.vw_brand_a_rollup_weekly_v3` ' +
    "WHERE period_start = DATE '" + week.startIso + "'"
  );

  return {
    sessions:      Number(w.sessions),
    users:         Number(w.totalusers),
    newUsers:      Number(w.newusers),
    segment1:      segment1,
    segment2: segment2,
    orientation:   Number(orient[0][0]),
    leads:         Number(rollup[0][0]),
    org1:          Number(rollup[0][1]),
    org2:          Number(rollup[0][2])
  };
}

function windsorTotals_(startIso, endIso, account) {
  const url = 'WINDSOR_CONNECTORS_ENDPOINT/all'
    + '?api_key=' + WINDSOR_KEY
    + '&date_from=' + startIso
    + '&date_to=' + endIso
    + '&fields=totalusers,newusers,sessions'
    + '&select_accounts=' + account;

  const res = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  if (res.getResponseCode() !== 200) {
    throw new Error('Windsor returned ' + res.getResponseCode() + ': ' + res.getContentText());
  }
  const rows = JSON.parse(res.getContentText()).data;
  if (!rows || rows.length !== 1) {
    throw new Error('Expected one row from Windsor, got ' + (rows ? rows.length : 0));
  }
  return rows[0];
}

function runBlockSheet_(spec) {
  const week = previousCompletedWeek_();

  const rows = queryBigQuery_(
    'SELECT ' + spec.select + ' ' +
    'FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.' + spec.fn + '`' +
    "(DATE '" + week.startIso + "', DATE '" + week.endIso + "') " +
    'ORDER BY clicks DESC'
  );

  if (rows.length === 0) {
    throw new Error(spec.sheet + ': no rows for ' + week.startIso + ' to ' + week.endIso +
                    '. Check the date is a Monday and the data has loaded.');
  }

  const total = rows.reduce(function (s, r) { return s + Number(r[3]); }, 0);
  writeBlock_(spec, week, rows, total);
  Logger.log('%s - %s: %s rows, %s clicks',
             spec.sheet, week.label, String(rows.length), formatNumber_(total));
}

function previousCompletedWeek_() {
  const now = new Date();
  const dow = Number(Utilities.formatDate(now, CONFIG.TZ, 'u'));
  const day = 24 * 60 * 60 * 1000;
  const thisMonday = new Date(now.getTime() - (dow - 1) * day);
  const start = new Date(thisMonday.getTime() - 7 * day);
  const end = new Date(start.getTime() + 6 * day);

  return {
    startIso: Utilities.formatDate(start, CONFIG.TZ, 'yyyy-MM-dd'),
    endIso: Utilities.formatDate(end, CONFIG.TZ, 'yyyy-MM-dd'),
    label: 'Week ' + isoWeek_(start),
    range: Utilities.formatDate(start, CONFIG.TZ, 'dd/MM') + ' - ' +
           Utilities.formatDate(end, CONFIG.TZ, 'dd/MM/yyyy')
  };
}

function isoWeek_(d) {
  const p = Utilities.formatDate(d, CONFIG.TZ, 'yyyy-MM-dd').split('-');
  const dt = new Date(Date.UTC(Number(p[0]), Number(p[1]) - 1, Number(p[2])));
  const dayNum = dt.getUTCDay() || 7;
  dt.setUTCDate(dt.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(dt.getUTCFullYear(), 0, 1));
  return Math.ceil(((dt - yearStart) / (24 * 60 * 60 * 1000) + 1) / 7);
}

function queryBigQuery_(sql) {
  let job = BigQuery.Jobs.query({ query: sql, useLegacySql: false }, CONFIG.PROJECT_ID);
  const jobId = job.jobReference.jobId;

  while (!job.jobComplete) {
    Utilities.sleep(1000);
    job = BigQuery.Jobs.getQueryResults(CONFIG.PROJECT_ID, jobId);
  }

  let out = (job.rows || []).slice();
  let token = job.pageToken;
  while (token) {
    const page = BigQuery.Jobs.getQueryResults(CONFIG.PROJECT_ID, jobId, { pageToken: token });
    out = out.concat(page.rows || []);
    token = page.pageToken;
  }

  return out.map(function (r) { return r.f.map(function (c) { return c.v; }); });
}

function writeBlock_(spec, week, rows, total) {
  const sheet = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID).getSheetByName(spec.sheet);
  if (!sheet) throw new Error('Sheet not found: ' + spec.sheet);

  const marker = '▌ ' + week.label + ':';
  removeExistingBlock_(sheet, marker);

  const template = findLastBlock_(sheet);
  const startRow = sheet.getLastRow() + 2;
  const n = rows.length;

  sheet.getRange(startRow, 1).setValue(
    marker + ' ' + week.range + '  -  Total ' + spec.noun + ': ' +
    formatNumber_(total) + ' clicks'
  );

  const body = rows.map(function (r, i) { return spec.row(r, i, total, week.label); });
  sheet.getRange(startRow + 1, 1, n, spec.cols).setValues(body);

  const totalRow = startRow + 1 + n;
  spec.totalRow(sheet, totalRow, total);

  if (template) copyFormatting_(sheet, template, startRow, n, totalRow, spec.cols);
}

function removeExistingBlock_(sheet, marker) {
  const last = sheet.getLastRow();
  if (last < 1) return;

  const colA = sheet.getRange(1, 1, last, 1).getValues();
  let headerRow = -1;
  for (let i = 0; i < colA.length; i++) {
    if (String(colA[i][0]).indexOf(marker) === 0) { headerRow = i + 1; break; }
  }
  if (headerRow === -1) return;

  const colD = sheet.getRange(1, 4, last, 1).getValues();
  let endRow = headerRow;
  for (let i = headerRow; i < colD.length; i++) {
    if (String(colD[i][0]).trim() === 'WEEK TOTAL') { endRow = i + 1; break; }
  }

  if (endRow < sheet.getLastRow()) endRow += 1;
  sheet.deleteRows(headerRow, endRow - headerRow + 1);
}

function findLastBlock_(sheet) {
  const last = sheet.getLastRow();
  if (last < 1) return null;

  const colA = sheet.getRange(1, 1, last, 1).getValues();
  let headerRow = -1;
  for (let i = colA.length - 1; i >= 0; i--) {
    if (String(colA[i][0]).indexOf('▌ ') === 0) { headerRow = i + 1; break; }
  }
  if (headerRow === -1) return null;

  const colD = sheet.getRange(1, 4, last, 1).getValues();
  let totalRow = -1;
  for (let i = headerRow; i < colD.length; i++) {
    if (String(colD[i][0]).trim() === 'WEEK TOTAL') { totalRow = i + 1; break; }
  }
  if (totalRow === -1) return null;

  return { headerRow: headerRow, firstDataRow: headerRow + 1, totalRow: totalRow };
}

function removeDownloadBlock_(sheet, marker) {
  const last = sheet.getLastRow();
  if (last < 1) return;

  const colA = sheet.getRange(1, 1, last, 1).getValues();
  let headerRow = -1;
  for (let i = 0; i < colA.length; i++) {
    if (String(colA[i][0]).indexOf(marker) === 0) { headerRow = i + 1; break; }
  }
  if (headerRow === -1) return;

  const colB = sheet.getRange(1, 2, last, 1).getValues();
  let endRow = headerRow;
  for (let i = headerRow; i < colB.length; i++) {
    if (String(colB[i][0]).trim() === 'TOTAL') { endRow = i + 1; break; }
  }

  if (endRow < sheet.getLastRow()) endRow += 1;
  sheet.deleteRows(headerRow, endRow - headerRow + 1);
}

function findLastDownload_(sheet) {
  const last = sheet.getLastRow();
  if (last < 1) return null;

  const colA = sheet.getRange(1, 1, last, 1).getValues();
  let headerRow = -1;
  for (let i = colA.length - 1; i >= 0; i--) {
    if (String(colA[i][0]).indexOf('FILE DOWNLOADS') === 0) { headerRow = i + 1; break; }
  }
  if (headerRow === -1) return null;

  const colB = sheet.getRange(1, 2, last, 1).getValues();
  let totalRow = -1;
  for (let i = headerRow; i < colB.length; i++) {
    if (String(colB[i][0]).trim() === 'TOTAL') { totalRow = i + 1; break; }
  }
  if (totalRow === -1) return null;

  return { headerRow: headerRow, firstDataRow: headerRow + 2, totalRow: totalRow };
}

function copyFormatting_(sheet, t, startRow, n, totalRow, cols) {
  const fmt = SpreadsheetApp.CopyPasteType.PASTE_FORMAT;

  sheet.getRange(t.headerRow, 1, 1, cols)
       .copyTo(sheet.getRange(startRow, 1, 1, cols), fmt, false);

  const striped = (t.totalRow - t.firstDataRow) >= 2;
  for (let i = 0; i < n; i++) {
    const src = striped ? t.firstDataRow + (i % 2) : t.firstDataRow;
    sheet.getRange(src, 1, 1, cols)
         .copyTo(sheet.getRange(startRow + 1 + i, 1, 1, cols), fmt, false);
  }

  sheet.getRange(t.totalRow, 1, 1, cols)
       .copyTo(sheet.getRange(totalRow, 1, 1, cols), fmt, false);
}

function findRowStartingWith_(sheet, col, prefix) {
  const last = sheet.getLastRow();
  if (last < 1) return -1;
  const vals = sheet.getRange(1, col, last, 1).getValues();
  for (let i = 0; i < vals.length; i++) {
    if (String(vals[i][0]).trim().indexOf(prefix) === 0) return i + 1;
  }
  return -1;
}

function firstAssociationsRow_(sheet, totalRow) {
  const head = findRowStartingWith_(sheet, 1, 'CLICKS ON ASSOCIATIONS');
  const from = head === -1 ? 1 : head + 1;
  const vals = sheet.getRange(from, 1, totalRow - from, 1).getValues();
  for (let i = 0; i < vals.length; i++) {
    if (/^Week\s+\d+/.test(String(vals[i][0]).trim())) return from + i;
  }
  throw new Error('Cannot find the first associations week row.');
}

function colLetter_(n) {
  let s = '';
  while (n > 0) {
    const m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - m - 1) / 26;
  }
  return s;
}

function formatNumber_(n) {
  return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

function createWeeklyTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'updateAll') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('updateAll')
           .timeBased()
           .everyDays(1)
           .atHour(11)
           .create();
}
