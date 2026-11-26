const CONFIG = {
  SPREADSHEET_ID: 'YOUR_SPREADSHEET_ID',
  PROJECT_ID:     'your-project',
  DATASET:        'marketing',
  TZ:             'Etc/GMT+6'
};

const BLOCK_VIDEO    = 'dv360';
const BLOCK_AUDIO    = 'dv360 audio';
const BLOCK_EPISODE = 'episode breakdown';

const H = {
  campaignName:   'campaign',
  startDate:  'start date',
  endDate:  'end date',
  objective:  'objective',
  population: 'population',
  segment:   'segmentation',
  approved:  'approved budget',
  spent:  'budget spent',
  impr:    'impressions',
  reachValue:   'total reach',
  clicks:     'clicks',
  q25:       'listen/ views 25%',
  q50:       'listen/ views 50%',
  q75:       'listen/ views 75%',
  q100:      'listen/ views 100%',
  cpm:       'cpm',
  cpv:       'cpv',
  cpc:       'cpc',
  vtr:       'vtr',
  ctr:       'ctr',
  ltr:       'ltr ad listen'
};

const MANUAL_COLS = [H.population, H.segment, H.approved];

const MONTHS = ['january','february','march','april','may','june',
               'july','august','september','october','november','december'];

const CAMPAIGN_NAME = 'Brand H Video In-stream';

function testRun() {
  const p = biweeklyPeriod_(2026, 8, 1);
  p.name = 'TEST ' + p.name;
  buildPeriodSheet(p, false);
  Logger.log('Written to tab ' + p.name + '. Compare it with the published figure before continuing.');
}

function updateAll() {
  const q = previousClosedPeriod_();
  buildOrRefresh_(q);
  if (q.half === 2) buildOrRefresh_(monthlyPeriod_(q.yearNum, q.monthNum));
}

function buildBiweekly(year, month, half) { buildOrRefresh_(biweeklyPeriod_(year, month, half)); }
function buildMonthly(year, month)        { buildOrRefresh_(monthlyPeriod_(year, month)); }

function buildOrRefresh_(period) {
  const ss = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID);
  buildPeriodSheet(period, !!findTab_(ss, period.name));
}

function buildPeriodSheet(period, refresh) {
  const ss = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID);

  const campaignName = queryBigQuery_(
    'SELECT * FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.tf_brand_h_campaign`' +
    "(DATE '" + period.periodStartIso + "', DATE '" + period.periodEndIso + "')");

  if (!campaignName.length || num_(campaignName[0][3]) === 0) {
    throw new Error('No data for ' + period.name +
                    '. The table returns zero rows or zero impressions, which ' +
                    'means the period has not loaded, not that no ads ran.');
  }

  const episodes = queryBigQuery_(
    'SELECT episode, sort_order, impression_count, views FROM `' +
    CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.tf_brand_h_episodes`' +
    "(DATE '" + period.periodStartIso + "', DATE '" + period.periodEndIso + "') ORDER BY sort_order");

  const audio = queryBigQuery_(
    'SELECT * FROM `' + CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.tf_brand_h_audio`' +
    "(DATE '" + period.periodStartIso + "', DATE '" + period.periodEndIso + "')");

  if (!episodes.length) {
    throw new Error('No episodes for ' + period.name + '. The connection ' +
                    'dv360-trueview-task has not loaded the period.');
  }

  const coverage = queryBigQuery_(
    'SELECT MIN(date), MAX(date) FROM `' +
    CONFIG.PROJECT_ID + '.' + CONFIG.DATASET + '.dv360_trueview_ad`');

  const fromLabel = coverage[0][0], toLabel = coverage[0][1];
  if (!fromLabel || fromLabel > period.periodStartIso || toLabel < period.periodEndIso) {
    throw new Error(
      'The episode table does not cover ' + period.name + '. It has ' +
      fromLabel + ' to ' + toLabel + ' and the period runs from ' + period.periodStartIso +
      ' to ' + period.periodEndIso + '. Writing this would report a fraction of the ' +
      'period with no warning. Wait for the backfill of ' +
      'dv360-trueview-task.');
  }

  let tab = findTab_(ss, period.name);
  if (!tab) {
    const templateTab = findTemplate_(ss, period.cadence);
    if (!templateTab) throw new Error('No previous tab for cadence ' + period.cadence + ' to copy.');
    tab = templateTab.copyTo(ss).setName(period.name);
    ss.setActiveSheet(tab);
    ss.moveActiveSheet(ss.getSheets().length);
  }

  writeVideoBlock_(tab, period, campaignName[0], refresh);
  writeAudioBlock_(tab, period, audio, refresh);
  writeChapterBlock_(tab, period, episodes, refresh);

  Logger.log((refresh ? 'Refreshed' : 'Built') + ': ' + period.name);
}

function writeVideoBlock_(tab, period, d, refresh) {
  const titleRow = findBlockTitle_(tab, BLOCK_VIDEO, BLOCK_AUDIO);
  if (titleRow < 0) throw new Error('Could not find the video block.');

  const headerRow = titleRow + 1;
  const colMap      = headerMap_(tab, headerRow);
  const totalRow  = findTotalRow_(tab, headerRow);
  if (totalRow < 0) throw new Error('Could not find the Total row of the video block.');

  const rowNum = findFirstDataRow_(tab, headerRow, totalRow, col_(colMap, H.campaignName));
  breakMerges_(tab, rowNum, totalRow);

  const spent = num_(d[2]), impr = num_(d[3]), clicks = num_(d[4]);
  const q25 = num_(d[5]), q50 = num_(d[6]), q75 = num_(d[7]), q100 = num_(d[8]);
  const trueview = num_(d[9]);

  setIf_(tab, rowNum, col_(colMap, H.campaignName),  CAMPAIGN_NAME);
  setIf_(tab, rowNum, col_(colMap, H.startDate), period.periodStart);
  setIf_(tab, rowNum, col_(colMap, H.endDate), period.periodEnd);
  setIf_(tab, rowNum, col_(colMap, H.objective), d[1] ? 'CPM' : 'CPM');

  setIf_(tab, rowNum, col_(colMap, H.spent), spent);
  setIf_(tab, rowNum, col_(colMap, H.impr),   impr);
  setIf_(tab, rowNum, col_(colMap, H.clicks),    clicks);
  setIf_(tab, rowNum, col_(colMap, H.q25),      q25);
  setIf_(tab, rowNum, col_(colMap, H.q50),      q50);
  setIf_(tab, rowNum, col_(colMap, H.q75),      q75);
  setIf_(tab, rowNum, col_(colMap, H.q100),     q100);

  const colAlc = col_(colMap, H.reachValue), colImp = col_(colMap, H.impr);
  if (colAlc && colImp) {
    tab.getRange(rowNum, colAlc).setFormula('=' + colLetter_(colImp) + rowNum + '/2');
  }

  const cI = col_(colMap, H.spent), cJ = col_(colMap, H.impr), cL = col_(colMap, H.clicks);
  if (col_(colMap, H.cpm) && cI && cJ) {
    tab.getRange(rowNum, col_(colMap, H.cpm))
        .setFormula('=(' + colLetter_(cI) + rowNum + '/' + colLetter_(cJ) + rowNum + ')*1000');
  }
  if (col_(colMap, H.cpc) && cI && cL) {
    tab.getRange(rowNum, col_(colMap, H.cpc))
        .setFormula('=' + colLetter_(cI) + rowNum + '/' + colLetter_(cL) + rowNum);
  }
  setIf_(tab, rowNum, col_(colMap, H.cpv), trueview ? spent / trueview : '');
  setIf_(tab, rowNum, col_(colMap, H.vtr), impr   ? trueview / impr   : '');

  if (!refresh) {
    MANUAL_COLS.forEach(function (k) {
      const c = col_(colMap, k);
      if (c) tab.getRange(rowNum, c).clearContent();
    });
  }

  writeTotals_(tab, colMap, rowNum, totalRow - 1, totalRow);
}

function writeChapterBlock_(tab, period, episodes, refresh) {
  const titleRow = findBlockTitle_(tab, BLOCK_EPISODE, null);
  if (titleRow < 0) throw new Error('Could not find the EPISODE BREAKDOWN block.');

  const headerRow = titleRow + 1;
  const colMap      = headerMapEpisode_(tab, headerRow, titleRow);
  const firstRowNum   = headerRow + 1;
  const totalRow  = findChapterTotal_(tab, firstRowNum);
  if (totalRow < 0) throw new Error('Could not find the totals row of the breakdown.');

  const currentCount = totalRow - firstRowNum;
  const wanted  = episodes.length;

  breakMerges_(tab, firstRowNum, totalRow);

  if (wanted > currentCount) {
    tab.insertRowsAfter(totalRow - 1, wanted - currentCount);
    for (let i = 0; i < wanted - currentCount; i++) {
      tab.getRange(firstRowNum, 1, 1, tab.getLastColumn())
          .copyTo(tab.getRange(totalRow - 1 + i, 1), {contentsOnly: false});
    }
  } else if (wanted < currentCount) {
    tab.deleteRows(firstRowNum + wanted, currentCount - wanted);
  }

  const newTotal = firstRowNum + wanted;

  for (let i = 0; i < wanted; i++) {
    const r = firstRowNum + i, c = episodes[i];
    setIf_(tab, r, col_(colMap, H.campaignName),  c[0]);
    setIf_(tab, r, col_(colMap, H.startDate), period.periodStart);
    setIf_(tab, r, col_(colMap, H.endDate), period.periodEnd);
    setIf_(tab, r, col_(colMap, H.objective), 'CPM');
    setIf_(tab, r, col_(colMap, H.impr),   num_(c[2]));
    setIf_(tab, r, col_(colMap, H.q100),     num_(c[3]));

    const cA = col_(colMap, H.reachValue), cI = col_(colMap, H.impr);
    if (cA && cI) tab.getRange(r, cA).setFormula('=' + colLetter_(cI) + r + '/2');

    [H.q25, H.q50, H.q75].forEach(function (k) {
      const c2 = col_(colMap, k);
      if (c2) tab.getRange(r, c2).setValue('N/A');
    });
  }

  if (!refresh) {
    [H.population, H.segment, H.approved].forEach(function (k) {
      const c = col_(colMap, k);
      if (c) tab.getRange(firstRowNum, c, wanted, 1).clearContent();
    });
  }

  redoVerticalMerge_(tab, colMap, [H.population, H.segment, H.approved, H.spent, H.clicks],
                        firstRowNum, newTotal - 1);

  [H.impr, H.reachValue, H.q100].forEach(function (k) {
    const c = col_(colMap, k);
    if (!c) return;
    const L = colLetter_(c);
    tab.getRange(newTotal, c).setFormula('=SUM(' + L + firstRowNum + ':' + L + (newTotal - 1) + ')');
  });

  const cCpc = col_(colMap, H.cpc);
  if (cCpc) tab.getRange(newTotal, cCpc).clearContent();
}

function writeTotals_(tab, colMap, firstRowNum, lastOne, totalRow) {
  [H.approved, H.spent, H.impr, H.reachValue, H.clicks,
   H.q25, H.q50, H.q75, H.q100].forEach(function (k) {
    const c = col_(colMap, k);
    if (!c) return;
    const L = colLetter_(c);
    tab.getRange(totalRow, c).setFormula('=SUM(' + L + firstRowNum + ':' + L + lastOne + ')');
  });

  const cI = col_(colMap, H.spent), cJ = col_(colMap, H.impr), cL = col_(colMap, H.clicks);
  const T = totalRow;
  if (col_(colMap, H.cpm) && cI && cJ) {
    tab.getRange(T, col_(colMap, H.cpm))
        .setFormula('=(' + colLetter_(cI) + T + '/' + colLetter_(cJ) + T + ')*1000');
  }
  if (col_(colMap, H.cpc) && cI && cL) {
    tab.getRange(T, col_(colMap, H.cpc))
        .setFormula('=' + colLetter_(cI) + T + '/' + colLetter_(cL) + T);
  }
  [H.cpv, H.vtr].forEach(function (k) {
    const c = col_(colMap, k);
    if (!c) return;
    tab.getRange(T, c).setFormula('=' + colLetter_(c) + firstRowNum);
    tab.getRange(firstRowNum, c).copyTo(tab.getRange(T, c), {formatOnly: true});
  });
}

function clearAudioBlock_(tab, period) {
  const titleRow = findBlockTitle_(tab, BLOCK_AUDIO, null);
  if (titleRow < 0) return;

  const headerRow = titleRow + 1;
  const colMap      = headerMap_(tab, headerRow);
  const totalRow  = findTotalRow_(tab, headerRow);
  if (totalRow < 0) return;

  const firstRowNum = findFirstDataRow_(tab, headerRow, totalRow, col_(colMap, H.campaignName));
  breakMerges_(tab, firstRowNum, totalRow);

  for (let r = firstRowNum; r <= totalRow; r++) {
    Object.keys(colMap).forEach(function (k) {
      if (k.indexOf(H.campaignName) === 0) return;
      if (k.indexOf('date') === 0)   return;
      tab.getRange(r, colMap[k]).clearContent();
    });
    if (r < totalRow) {
      setIf_(tab, r, col_(colMap, H.startDate), period.periodStart);
      setIf_(tab, r, col_(colMap, H.endDate), period.periodEnd);
    }
  }
}

function writeAudioBlock_(tab, period, rowList, refresh) {
  const titleRow = findBlockTitle_(tab, BLOCK_AUDIO, null);
  if (titleRow < 0) return;

  const headerRow = titleRow + 1;
  const colMap      = headerMap_(tab, headerRow);
  const totalRow  = findTotalRow_(tab, headerRow);
  if (totalRow < 0) return;

  const rowNum = findFirstDataRow_(tab, headerRow, totalRow, col_(colMap, H.campaignName));
  breakMerges_(tab, rowNum, totalRow);

  if (!rowList.length) {
    for (let r = rowNum; r <= totalRow; r++) {
      Object.keys(colMap).forEach(function (k) {
        if (k.indexOf(H.campaignName) === 0) return;
        tab.getRange(r, colMap[k]).clearContent();
      });
    }
    setIf_(tab, rowNum, col_(colMap, H.startDate), period.periodStart);
    setIf_(tab, rowNum, col_(colMap, H.endDate), period.periodEnd);
    return;
  }

  const d = rowList[0];
  const impr = num_(d[1]), clicks = num_(d[2]);

  setIf_(tab, rowNum, col_(colMap, H.campaignName),  'Brand H Audio');
  setIf_(tab, rowNum, col_(colMap, H.startDate), period.periodStart);
  setIf_(tab, rowNum, col_(colMap, H.endDate), period.periodEnd);
  setIf_(tab, rowNum, col_(colMap, H.objective), 'CPM');
  setIf_(tab, rowNum, col_(colMap, H.impr),   impr);
  setIf_(tab, rowNum, col_(colMap, H.clicks),    clicks);
  setIf_(tab, rowNum, col_(colMap, H.q25),      num_(d[3]));
  setIf_(tab, rowNum, col_(colMap, H.q50),      num_(d[4]));
  setIf_(tab, rowNum, col_(colMap, H.q75),      num_(d[5]));
  setIf_(tab, rowNum, col_(colMap, H.q100),     num_(d[6]));

  const colAlc = col_(colMap, H.reachValue), colImp = col_(colMap, H.impr);
  if (colAlc && colImp) {
    tab.getRange(rowNum, colAlc).setFormula('=' + colLetter_(colImp) + rowNum + '/2');
  }

  setIf_(tab, rowNum, col_(colMap, H.ctr), impr ? clicks / impr : '');
  setIf_(tab, rowNum, col_(colMap, H.ltr), impr ? num_(d[6]) / impr : '');

  [H.spent, H.approved].forEach(function (k) {
    const c = col_(colMap, k);
    if (c) tab.getRange(rowNum, c).clearContent();
  });

  [H.cpm, H.cpc].forEach(function (k) {
    const c = col_(colMap, k);
    if (c) tab.getRange(rowNum, c).clearContent();
  });

  if (!refresh) {
    [H.population, H.segment].forEach(function (k) {
      const c = col_(colMap, k);
      if (c) tab.getRange(rowNum, c).clearContent();
    });
  }

  [H.impr, H.reachValue, H.clicks, H.q25, H.q50, H.q75, H.q100].forEach(function (k) {
    const c = col_(colMap, k);
    if (!c) return;
    const L = colLetter_(c);
    tab.getRange(totalRow, c).setFormula('=SUM(' + L + rowNum + ':' + L + (totalRow - 1) + ')');
  });
  [H.spent, H.approved, H.cpm, H.cpc].forEach(function (k) {
    const c = col_(colMap, k);
    if (c) tab.getRange(totalRow, c).clearContent();
  });
  [H.ctr, H.ltr].forEach(function (k) {
    const c = col_(colMap, k);
    if (!c) return;
    tab.getRange(totalRow, c).setFormula('=' + colLetter_(c) + rowNum);
    tab.getRange(rowNum, c).copyTo(tab.getRange(totalRow, c), {formatOnly: true});
  });
}

function findBlockTitle_(tab, labelPrefix, exclude) {
  const vals = tab.getRange(1, 1, tab.getLastRow(), tab.getLastColumn()).getValues();
  for (let i = 0; i < vals.length; i++) {
    for (let j = 0; j < vals[i].length; j++) {
      const v = norm_(vals[i][j]);
      if (!v || v.indexOf(labelPrefix) !== 0) continue;
      if (exclude && v.indexOf(exclude) === 0) continue;
      return i + 1;
    }
  }
  return -1;
}

function headerMap_(tab, headerRow) {
  const vals = tab.getRange(headerRow, 1, 1, tab.getLastColumn()).getValues()[0];
  const m = {};
  for (let i = 0; i < vals.length; i++) {
    const k = norm_(vals[i]);
    if (k && !m[k]) m[k] = i + 1;
  }
  return m;
}

function headerMapEpisode_(tab, headerRow, titleRow) {
  const ownMap = headerMap_(tab, headerRow);
  const aboveMap = headerMap_(tab, findBlockTitle_(tab, BLOCK_VIDEO, BLOCK_AUDIO) + 1);
  [H.campaignName, H.startDate, H.endDate, H.objective,
   H.population, H.segment, H.approved, H.spent, H.clicks, H.cpc].forEach(function (k) {
    if (!ownMap[k] && aboveMap[k]) ownMap[k] = aboveMap[k];
  });
  return ownMap;
}

function findFirstDataRow_(tab, headerRow, totalRow, campaignCol) {
  const n = totalRow - headerRow - 1;
  if (n < 1 || !campaignCol) return headerRow + 1;
  const vals = tab.getRange(headerRow + 1, campaignCol, n, 1).getValues();
  for (let i = 0; i < vals.length; i++) {
    if (String(vals[i][0]).trim() !== '') return headerRow + 1 + i;
  }
  return headerRow + 1;
}

function findTotalRow_(tab, headerRow) {
  const vals = tab.getRange(1, 1, tab.getLastRow(), tab.getLastColumn()).getValues();
  for (let i = headerRow; i < vals.length; i++) {
    for (let j = 0; j < vals[i].length; j++) {
      const v = norm_(vals[i][j]);
      if (!v) continue;
      if (v.indexOf('total') === 0) return i + 1;
      if (v.indexOf('dv360') === 0 || v.indexOf('breakdown') === 0) return -1;
    }
  }
  return -1;
}

function findChapterTotal_(tab, firstRowNum) {
  const last = tab.getLastRow();
  const vals = tab.getRange(firstRowNum, 2, last - firstRowNum + 1, 1).getValues();
  for (let i = 0; i < vals.length; i++) {
    const v = norm_(vals[i][0]);
    if (v.indexOf('episode') !== 0 && v.indexOf('chapter') !== 0) return firstRowNum + i;
  }
  return -1;
}

function breakMerges_(tab, fromLabel, toLabel) {
  tab.getRange(fromLabel, 1, Math.max(1, toLabel - fromLabel + 1), tab.getLastColumn())
      .getMergedRanges().forEach(function (r) { r.breakApart(); });
}

function redoVerticalMerge_(tab, colMap, keyNames, fromLabel, toLabel) {
  if (toLabel <= fromLabel) return;
  keyNames.forEach(function (k) {
    const c = colMap[k];
    if (c) tab.getRange(fromLabel, c, toLabel - fromLabel + 1, 1).merge();
  });
}

function setIf_(tab, row, col, value) {
  if (col) tab.getRange(row, col).setValue(value);
}

function findTab_(ss, name) {
  const tabs = ss.getSheets();
  for (let i = 0; i < tabs.length; i++) {
    if (norm_(tabs[i].getName()) === norm_(name)) return tabs[i];
  }
  return null;
}

function findTemplate_(ss, cadence) {
  const tabs = ss.getSheets();
  for (let i = tabs.length - 1; i >= 0; i--) {
    const n = norm_(tabs[i].getName());
    if (n.indexOf('segmentation') === 0 || n.indexOf('test') === 0) continue;
    const isMonthly = n.indexOf('monthly') === 0;
    if (cadence === 'monthly' ? isMonthly : (!isMonthly && n.indexOf(' to ') !== -1)) {
      return tabs[i];
    }
  }
  return null;
}

function previousClosedPeriod_() {
  const today = new Date();
  const y = Number(Utilities.formatDate(today, CONFIG.TZ, 'yyyy'));
  const m = Number(Utilities.formatDate(today, CONFIG.TZ, 'MM'));
  const d = Number(Utilities.formatDate(today, CONFIG.TZ, 'dd'));
  if (d >= 16) return biweeklyPeriod_(y, m, 1);
  const pm = m === 1 ? 12 : m - 1, py = m === 1 ? y - 1 : y;
  return biweeklyPeriod_(py, pm, 2);
}

function biweeklyPeriod_(y, m, half) {
  const periodStart = half === 1 ? new Date(y, m - 1, 1)  : new Date(y, m - 1, 16);
  const periodEnd    = half === 1 ? new Date(y, m - 1, 15) : new Date(y, m, 0);
  const monthNum    = MONTHS[m - 1];
  const name = half === 1
    ? '1 to 15 ' + ep_(monthNum)
    : '16 to ' + periodEnd.getDate() + ' of ' + ep_(monthNum);
  return {cadence: 'biweekly', yearNum: y, monthNum: m, half: half,
          periodStart: periodStart, periodEnd: periodEnd, periodStartIso: iso_(periodStart), periodEndIso: iso_(periodEnd),
          name: name};
}

function monthlyPeriod_(y, m) {
  const periodStart = new Date(y, m - 1, 1), periodEnd = new Date(y, m, 0);
  return {cadence: 'monthly', yearNum: y, monthNum: m, half: null,
          periodStart: periodStart, periodEnd: periodEnd, periodStartIso: iso_(periodStart), periodEndIso: iso_(periodEnd),
          name: 'Monthly ' + ep_(MONTHS[m - 1])};
}

function queryBigQuery_(sql) {
  let job = BigQuery.Jobs.query({query: sql, useLegacySql: false}, CONFIG.PROJECT_ID);
  const jobId = job.jobReference.jobId;
  while (!job.jobComplete) {
    Utilities.sleep(1000);
    job = BigQuery.Jobs.getQueryResults(CONFIG.PROJECT_ID, jobId);
  }
  let out = (job.rows || []).slice(), token = job.pageToken;
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

function col_(colMap, key) {
  if (colMap[key]) return colMap[key];
  const ks = Object.keys(colMap);
  for (let i = 0; i < ks.length; i++) {
    if (ks[i].indexOf(key) === 0) return colMap[ks[i]];
  }
  return null;
}

function num_(v) { return v === null || v === '' || v === undefined ? 0 : Number(v); }
function iso_(d) { return Utilities.formatDate(d, CONFIG.TZ, 'yyyy-MM-dd'); }
function ep_(s) { return s.charAt(0).toUpperCase() + s.slice(1); }

function colLetter_(n) {
  let s = '';
  while (n > 0) { const m = (n - 1) % 26; s = String.fromCharCode(65 + m) + s; n = (n - m - 1) / 26; }
  return s;
}

function createAllTriggers() {
  ['biweeklyRun', 'monthlyRun', 'refreshRun'].forEach(deleteTrigger_);
  ScriptApp.newTrigger('biweeklyRun').timeBased().atHour(11).everyDays(1)
           .inTimezone(CONFIG.TZ).create();
  ScriptApp.newTrigger('monthlyRun').timeBased().atHour(11).everyDays(1)
           .inTimezone(CONFIG.TZ).create();
  ScriptApp.newTrigger('refreshRun').timeBased().atHour(11).everyDays(1)
           .inTimezone(CONFIG.TZ).create();
  Logger.log('Three triggers: biweekly on days 3 and 18, monthly on day 3, ' +
             'refresh on days 4-10 and 19-25.');
}

function refreshRun() {
  const today = new Date();
  const d = Number(Utilities.formatDate(today, CONFIG.TZ, 'dd'));
  if (!((d >= 4 && d <= 10) || (d >= 19 && d <= 25))) return;

  refreshIfExists_(previousClosedPeriod_());

  if (d >= 4 && d <= 10) {
    const y  = Number(Utilities.formatDate(today, CONFIG.TZ, 'yyyy'));
    const m  = Number(Utilities.formatDate(today, CONFIG.TZ, 'MM'));
    const pm = m === 1 ? 12 : m - 1;
    const py = m === 1 ? y - 1 : y;
    refreshIfExists_(monthlyPeriod_(py, pm));
  }
}

function refreshIfExists_(period) {
  const ss = SpreadsheetApp.openById(CONFIG.SPREADSHEET_ID);
  if (!findTab_(ss, period.name)) {
    Logger.log('Tab does not exist: ' + period.name +
               '. A refresh never creates tabs, it only updates existing ones.');
    return;
  }
  buildPeriodSheet(period, true);
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

function monthlyRun() {
  const d = Number(Utilities.formatDate(new Date(), CONFIG.TZ, 'dd'));
  if (d !== 3) return;
  const today = new Date();
  const y = Number(Utilities.formatDate(today, CONFIG.TZ, 'yyyy'));
  const m = Number(Utilities.formatDate(today, CONFIG.TZ, 'MM'));
  const pm = m === 1 ? 12 : m - 1, py = m === 1 ? y - 1 : y;
  buildOrRefresh_(monthlyPeriod_(py, pm));
}
