function scoreProducts() {
  const ss  = SpreadsheetApp.getActiveSpreadsheet();
  const ui  = SpreadsheetApp.getUi();

  const aSheet     = ss.getSheetByName("Supplier A Raw");
  const bSheet     = ss.getSheetByName("Supplier B Raw");
  const outSheet   = ss.getSheetByName("Top 15");
  const aOutSheet  = ss.getSheetByName("Supplier A Top");
  const bOutSheet  = ss.getSheetByName("Supplier B Top");

  if (!aSheet || !bSheet || !outSheet || !aOutSheet || !bOutSheet) {
    ui.alert("Missing tabs. Need: 'Supplier A Raw', 'Supplier B Raw', 'Top 15', 'Supplier A Top', 'Supplier B Top'");
    return;
  }

  var keywordResp = ui.prompt(
    "🔍 Keyword Force-Include (Optional)",
    "Enter keywords to force-include products (comma separated).\nExample: bee, butterfly, mushroom\n\nLeave blank to skip.",
    ui.ButtonSet.OK_CANCEL
  );
  if (keywordResp.getSelectedButton() === ui.Button.CANCEL) return;

  var keywords = [];
  var rawInput = keywordResp.getResponseText().trim();
  if (rawInput !== "") {
    keywords = rawInput.split(",")
      .map(function(k){ return k.trim().toLowerCase(); })
      .filter(function(k){ return k.length > 0; });
  }

  const aData = aSheet.getDataRange().getValues();
  const aHdrs = aData[0];
  const A = {
    sku          : aHdrs.indexOf("Name"),
    name         : aHdrs.indexOf("Display Name"),
    cost         : aHdrs.findIndex(h => h.toString().includes("Carton Price") || h.toString().includes("Sold in Box/ Carton Price")),
    msrp         : aHdrs.findIndex(h => h.toString().includes("Carton MAP") || h.toString().includes("MAP")),
    stock        : aHdrs.indexOf("Available"),
    freightOnly  : aHdrs.indexOf("Freight Only"),
    discontinued : aHdrs.indexOf("Discontinued"),
    func         : aHdrs.indexOf("Function"),
    theme        : aHdrs.indexOf("Theme"),
    material     : aHdrs.indexOf("Material"),
    color        : aHdrs.indexOf("Color"),
    copy         : aHdrs.indexOf("Product Copy"),
    construction : aHdrs.indexOf("Construction"),
  };

  const bData = bSheet.getDataRange().getValues();
  const bHdrs = bData[0];
  const B = {
    sku      : bHdrs.indexOf("Vendor SKU"),
    name     : bHdrs.indexOf("Web Title"),
    cost     : bHdrs.indexOf("Dropship Freight Included Price"),
    msrp     : bHdrs.indexOf("MSRP"),
    stock    : bHdrs.indexOf("New Avail"),
    category : bHdrs.indexOf("Product Category"),
    style    : bHdrs.indexOf("Style"),
    material : bHdrs.indexOf("Item Materials"),
    color    : bHdrs.indexOf("Color"),
    copy     : bHdrs.indexOf("Marketing Copy"),
    setOf    : bHdrs.indexOf("Set of"),
  };

  if (keywords.length > 0) {
    var previewLines = ["Keywords entered: " + keywords.join(", "), ""];

    keywords.forEach(function(kw) {
      var aMatches = [];
      var bMatches = [];

      for (var i = 1; i < aData.length; i++) {
        var n = (aData[i][A.name] || "").toString().toLowerCase();
        if (n.indexOf(kw) !== -1) aMatches.push((aData[i][A.name] || "").toString().substring(0, 45));
      }
      for (var j = 1; j < bData.length; j++) {
        var mn = (bData[j][B.name] || "").toString().toLowerCase();
        if (mn.indexOf(kw) !== -1) bMatches.push((bData[j][B.name] || "").toString().substring(0, 45));
      }

      var total = aMatches.length + bMatches.length;
      previewLines.push("\"" + kw + "\" → " + total + " match" + (total !== 1 ? "es" : ""));
      if (aMatches.length > 0) {
        previewLines.push("  Supplier A (" + aMatches.length + "): " + aMatches.slice(0, 3).join(", ") + (aMatches.length > 3 ? " ..." : ""));
      }
      if (bMatches.length > 0) {
        previewLines.push("  Supplier B (" + bMatches.length + "): " + bMatches.slice(0, 3).join(", ") + (bMatches.length > 3 ? " ..." : ""));
      }
      if (total === 0) {
        previewLines.push("  ⚠️ No matches, possible typo");
      }
      previewLines.push("");
    });

    previewLines.push("Click OK to run scoring or Cancel to re-enter keywords.");

    var confirm = ui.alert(
      "🔍 Keyword Preview",
      previewLines.join("\n"),
      ui.ButtonSet.OK_CANCEL
    );
    if (confirm !== ui.Button.OK) return;
  }

  var FURN_KW = ["furniture","chair","bench","stool","table","shelf","shelving",
                 "cabinet","console","display furniture","accent chair",
                 "dining chair","side table","coffee table","accent table","console table"];

  function isFurniture(func) {
    var f = (func || "").toString().toLowerCase();
    return FURN_KW.some(function(k){ return f.indexOf(k) !== -1; });
  }

  function getPool(func, msrp) {
    if (isFurniture(func)) return "furniture";
    if (msrp >= 150) return "bigticket";
    return "accessory";
  }

  function matchesKeyword(productName) {
    if (keywords.length === 0) return false;
    var n = (productName || "").toString().toLowerCase();
    return keywords.some(function(k){ return n.indexOf(k) !== -1; });
  }

  function calcMarginPct(cost, msrp) {
    if (!msrp || msrp === 0) return 0;
    return Math.round((msrp - cost) / msrp * 100 * 10) / 10;
  }

  function grossMarginScore(cost, msrp) {
    if (!msrp || msrp === 0) return 0;
    var pct = Math.max(0, Math.min(65, (msrp - cost) / msrp * 100));
    return Math.round(pct / 65 * 18 * 100) / 100;
  }

  function absDollarScore(cost, msrp) {
    var d = msrp - cost;
    if (d >= 80) return 12;
    if (d >= 60) return 10;
    if (d >= 40) return 8;
    if (d >= 25) return 6;
    if (d >= 15) return 4;
    return 2;
  }

  function priceScore(msrp, pool) {
    if (pool === "furniture") {
      if (msrp >= 150 && msrp <= 800) return 12;
      if ((msrp >= 80 && msrp < 150) || (msrp > 800 && msrp <= 1200)) return 9;
      if (msrp > 1200) return 5;
      return 6;
    } else if (pool === "bigticket") {
      if (msrp >= 150 && msrp <= 400) return 12;
      if ((msrp >= 100 && msrp < 150) || (msrp > 400 && msrp <= 600)) return 9;
      if (msrp > 600) return 5;
      return 6;
    } else {
      if (msrp >= 40  && msrp <= 150) return 12;
      if (msrp >= 25  && msrp <  40)  return 9;
      if (msrp > 150  && msrp <= 250) return 9;
      if (msrp >= 15  && msrp <  25)  return 5;
      if (msrp > 250  && msrp <= 400) return 5;
      return 2;
    }
  }

  function availScore(stock, pool) {
    if (pool === "furniture") {
      if (stock >= 20) return 6;
      if (stock >= 10) return 4;
      return 2;
    } else {
      if (stock >= 100) return 10;
      if (stock >= 50)  return 8;
      if (stock >= 20)  return 6;
      if (stock >= 10)  return 4;
      return 2;
    }
  }

  function reorderScore(stock, pool) {
    if (pool === "furniture") return 3;
    if (stock >= 300) return 10;
    if (stock >= 150) return 8;
    if (stock >= 75)  return 5;
    if (stock >= 30)  return 3;
    return 1;
  }

  function categoryScore(cat) {
    if (!cat) return 3;
    var c = cat.toString().toLowerCase();
    var high = ["decor","vase","candleholder","planter","faux","wall dec","lantern",
                "mirror","tray","bowl","basket","wreath","garland","stem","spray",
                "botanica","sculptural","furniture","shelf","shelving","display",
                "cabinet","console"];
    var med  = ["garden","novelty","serving","tabletop","candle","pots",
                "chair","bench","stool","table","lamp"];
    if (high.some(function(k){ return c.indexOf(k) !== -1; })) return 10;
    if (med.some(function(k){  return c.indexOf(k) !== -1; })) return 6;
    return 3;
  }

  function setSizeScoreByName(productName) {
    var name = (productName || "").toString().toLowerCase();
    if (name.match(/set of (4|5|6|7|8|9|\d{2})/)) return 8;
    if (name.match(/set of 3/))               return 7;
    if (name.match(/set of 2/))               return 6;
    if (name.match(/bundle|pack of|pair of/)) return 5;
    return 5;
  }

  function setSizeScoreByField(setOfVal, productName) {
    if (setOfVal && !isNaN(parseFloat(setOfVal))) {
      var qty = parseFloat(setOfVal);
      if (qty >= 4) return 8;
      if (qty === 3) return 7;
      if (qty === 2) return 6;
    }
    return setSizeScoreByName(productName);
  }

  function multiFuncScore(category, productName) {
    var combined = ((category || "") + " " + (productName || "")).toString().toLowerCase();
    var pairs = [
      ["planter","vase"],["tray","serving"],["storage","display"],
      ["basket","planter"],["vase","planter"],["bowl","tray"],
      ["lantern","planter"],["shelf","display"],["holder","vase"],
      ["console","shelf"],["bench","storage"],["table","shelf"]
    ];
    for (var i = 0; i < pairs.length; i++) {
      if (combined.indexOf(pairs[i][0]) !== -1 && combined.indexOf(pairs[i][1]) !== -1) return 7;
    }
    var versatile = ["multi","multipurpose","versatile","2-in-1","dual"];
    if (versatile.some(function(k){ return combined.indexOf(k) !== -1; })) return 7;
    var broad = ["tray","basket","bowl","planter","lantern","shelf","display","console"];
    if (broad.some(function(k){ return combined.indexOf(k) !== -1; })) return 4;
    return 1;
  }

  function handmadeScore(copy, construction, material, productName) {
    var combined = [copy, construction, material, productName]
      .map(function(v){ return (v || "").toString().toLowerCase(); }).join(" ");
    var strong = ["handcrafted","hand-crafted","hand crafted","hand-woven","hand woven",
                  "handwoven","hand-painted","hand painted","handpainted",
                  "skilled artisan","artisan","hand-made","handmade"];
    var medium = ["natural material","natural fiber","rattan","seagrass","jute",
                  "wicker","bamboo","reclaimed","recycled glass","recycled metal",
                  "hand-blown","terracotta","clay","teak","mango wood","acacia",
                  "recycled wood","iron"];
    if (strong.some(function(k){ return combined.indexOf(k) !== -1; })) return 8;
    if (medium.some(function(k){ return combined.indexOf(k) !== -1; })) return 5;
    return 1;
  }

  function trendScore(productName, category, theme, material) {
    var combined = [productName, category, theme, material]
      .map(function(v){ return (v || "").toString().toLowerCase(); }).join(" ");
    var kw = ["coastal","sculptural","textured","organic","terracotta","rattan",
              "seagrass","wabi","japandi","boho","arch","curved","mushroom","dried",
              "pampas","linen","stone","marble","travertine","boucle","checkered",
              "abstract","earthy","neutral","minimalist","industrial","transitional",
              "mid-century","contemporary","modern"];
    var hits = kw.filter(function(k){ return combined.indexOf(k) !== -1; }).length;
    if (hits >= 3) return 5;
    if (hits === 2) return 4;
    if (hits === 1) return 2;
    return 0;
  }

  function getTier(score) {
    if (score >= 72) return "🟢 STRONG BUY";
    if (score >= 58) return "🟡 CONSIDER";
    return "🔴 LOW PRIORITY";
  }

  function scoreSupplierA(cost, msrp, stock, func, theme, mat, name, copy, cons, pool) {
    var mSc  = grossMarginScore(cost, msrp);
    var abSc = absDollarScore(cost, msrp);
    var pSc  = priceScore(msrp, pool);
    var aSc  = availScore(stock, pool);
    var rSc  = reorderScore(stock, pool);
    var cSc  = categoryScore(func);
    var sSc  = setSizeScoreByName(name);
    var mfSc = multiFuncScore(func, name);
    var hSc  = handmadeScore(copy, cons, mat, name);
    var tSc  = trendScore(name, func, theme, mat);
    var tot  = Math.round((mSc+abSc+pSc+aSc+rSc+cSc+sSc+mfSc+hSc+tSc)*100)/100;
    return [mSc, abSc, pSc, aSc, rSc, cSc, sSc, mfSc, hSc, tSc, tot];
  }

  function scoreSupplierB(cost, msrp, stock, cat, style, mat, name, copy, setOf, pool) {
    var mSc  = grossMarginScore(cost, msrp);
    var abSc = absDollarScore(cost, msrp);
    var pSc  = priceScore(msrp, pool);
    var aSc  = availScore(stock, pool);
    var rSc  = reorderScore(stock, pool);
    var cSc  = categoryScore(cat);
    var sSc  = setSizeScoreByField(setOf, name);
    var mfSc = multiFuncScore(cat, name);
    var hSc  = handmadeScore(copy, "", mat, name);
    var tSc  = trendScore(name, cat, style, mat);
    var tot  = Math.round((mSc+abSc+pSc+aSc+rSc+cSc+sSc+mfSc+hSc+tSc)*100)/100;
    return [mSc, abSc, pSc, aSc, rSc, cSc, sSc, mfSc, hSc, tSc, tot];
  }

  function writeSheet(ws, headers, rows) {
    ws.clearContents();
    ws.clearFormats();
    var nc = headers.length;
    ws.getRange(1, 1, 1, nc).setValues([headers]).setFontWeight("bold");
    ws.setRowHeight(1, 22);
    ws.setFrozenRows(1);
    if (rows.length === 0) return;
    ws.getRange(2, 1, rows.length, nc).setValues(rows);
    ws.getRange(2, 4, rows.length, 1).setNumberFormat("#,##0.00");
    ws.getRange(2, 5, rows.length, 1).setNumberFormat("#,##0.00");
    ws.getRange(2, 6, rows.length, 1).setNumberFormat("0.0");
    ws.getRange(2, 7, rows.length, 1).setNumberFormat("#,##0.00");
    ws.getRange(2, 8, rows.length, 1).setNumberFormat("#,##0");
    ws.setColumnWidth(3, 266);
    for (var i = 0; i < rows.length; i++) ws.setRowHeight(i + 2, 18);
  }

  var aScored = [];

  for (var i = 1; i < aData.length; i++) {
    var row  = aData[i];
    var sku  = (row[A.sku]  || "").toString();
    var name = (row[A.name] || "").toString();
    if (!sku && !name) continue;

    var cost  = parseFloat(row[A.cost])  || 0;
    var msrp  = parseFloat(row[A.msrp])  || 0;
    var stock = parseFloat(row[A.stock]) || 0;
    var disc  = (row[A.discontinued] || "").toString().trim().toUpperCase();
    var frt   = (row[A.freightOnly]  || "").toString().trim().toUpperCase();
    var func  = (row[A.func]         || "").toString();
    var theme = (row[A.theme]        || "").toString();
    var mat   = (row[A.material]     || "").toString();
    var col   = (row[A.color]        || "").toString();
    var copy  = (A.copy >= 0         ? row[A.copy]         : "") || "";
    var cons  = (A.construction >= 0 ? row[A.construction] : "") || "";
    var pool  = getPool(func, msrp);
    var furn  = (pool === "furniture");

    var discFail  = disc === "YES";
    var frtFail   = !furn && frt === "YES";
    var stockFail = furn ? stock < 5 : stock <= 0;
    var costFail  = cost <= 0;
    var msrpFail  = msrp <= 0;
    var eligible  = !discFail && !frtFail && !stockFail && !costFail && !msrpFail;
    var eligLabel = eligible ? "✅ INCLUDE" : "❌ EXCLUDE";

    var reason = "";
    if      (discFail)  reason = "Discontinued";
    else if (frtFail)   reason = "Freight Only";
    else if (stockFail) reason = furn ? "Stock < 5 units" : "Zero Stock";
    else if (costFail)  reason = "Missing Cost";
    else if (msrpFail)  reason = "Missing MSRP";

    var sc = eligible
      ? scoreSupplierA(cost, msrp, stock, func, theme, mat, name, copy, cons, pool)
      : ["","","","","","","","","","",""];

    aScored.push([
      "Supplier A", sku, name.substring(0, 60),
      cost, msrp, calcMarginPct(cost, msrp),
      eligible ? (msrp - cost) : "",
      stock, func, theme, mat, col,
      name.substring(0, 60),
      eligLabel, reason,
      sc[0],sc[1],sc[2],sc[3],sc[4],
      sc[5],sc[6],sc[7],sc[8],sc[9],
      sc[10], sc[10] !== "" ? getTier(sc[10]) : "",
      pool
    ]);
  }

  aScored.sort(function(a, b) {
    if (a[13]==="✅ INCLUDE" && b[13]!=="✅ INCLUDE") return -1;
    if (a[13]!=="✅ INCLUDE" && b[13]==="✅ INCLUDE") return 1;
    return (b[25]||0) - (a[25]||0);
  });

  var bScored = [];

  for (var j = 1; j < bData.length; j++) {
    var mrow  = bData[j];
    var msku  = (mrow[B.sku]  || "").toString();
    var mname = (mrow[B.name] || "").toString();
    if (!msku && !mname) continue;

    var mcost  = parseFloat(mrow[B.cost])  || 0;
    var mmsrp  = parseFloat(mrow[B.msrp])  || 0;
    var mstock = parseFloat(mrow[B.stock]) || 0;
    var mcat   = (mrow[B.category] || "").toString();
    var mstyle = (mrow[B.style]    || "").toString();
    var mmat   = (mrow[B.material] || "").toString();
    var mcol   = (mrow[B.color]    || "").toString();
    var mcopy  = (B.copy  >= 0 ? mrow[B.copy]  : "") || "";
    var msetOf = (B.setOf >= 0 ? mrow[B.setOf] : 1)  || 1;
    var mpool  = mmsrp >= 150 ? "bigticket" : "accessory";
    var melig  = mstock > 0 && mcost > 0 && mmsrp > 0;
    var meligL = melig ? "✅ INCLUDE" : "❌ EXCLUDE";
    var mreason = !mstock ? "Zero Stock" : !mcost ? "Missing Cost" : !mmsrp ? "Missing MSRP" : "";

    var msc = melig
      ? scoreSupplierB(mcost, mmsrp, mstock, mcat, mstyle, mmat, mname, mcopy, msetOf, mpool)
      : ["","","","","","","","","","",""];

    bScored.push([
      "Supplier B", msku, mname.substring(0, 60),
      mcost, mmsrp, calcMarginPct(mcost, mmsrp),
      melig ? (mmsrp - mcost) : "",
      mstock, mcat, mstyle, mmat, mcol,
      mname.substring(0, 60),
      meligL, mreason,
      msc[0],msc[1],msc[2],msc[3],msc[4],
      msc[5],msc[6],msc[7],msc[8],msc[9],
      msc[10], msc[10] !== "" ? getTier(msc[10]) : "",
      mpool
    ]);
  }

  bScored.sort(function(a, b) {
    if (a[13]==="✅ INCLUDE" && b[13]!=="✅ INCLUDE") return -1;
    if (a[13]!=="✅ INCLUDE" && b[13]==="✅ INCLUDE") return 1;
    return (b[25]||0) - (a[25]||0);
  });

  var aEligible  = aScored.filter(function(r){ return r[13]==="✅ INCLUDE"; });
  var aFurniture = aEligible.filter(function(r){ return r[27]==="furniture"; });
  var aOther     = aEligible.filter(function(r){ return r[27]!=="furniture"; });

  aFurniture.sort(function(a,b){ return (b[25]||0)-(a[25]||0); });
  aOther.sort(function(a,b){ return (b[25]||0)-(a[25]||0); });

  var aKeyword = aOther.filter(function(r){ return matchesKeyword(r[2]); });
  var aMerit   = aOther.filter(function(r){ return !matchesKeyword(r[2]); });

  aKeyword.sort(function(a,b){ return (b[25]||0)-(a[25]||0); });
  aMerit.sort(function(a,b){ return (b[25]||0)-(a[25]||0); });

  var aTop5Furn    = aFurniture.slice(0, 5);
  var aTop5Keyword = aKeyword.slice(0, 5);
  var meritSlots   = 15 - aTop5Furn.length - aTop5Keyword.length;
  var aTopMerit    = aMerit.slice(0, meritSlots);

  aTop5Keyword = aTop5Keyword.map(function(r){
    var rw = r.slice();
    rw[27] = rw[27] + " | keyword match";
    return rw;
  });

  var aTop15 = aTop5Furn.concat(aTop5Keyword).concat(aTopMerit);
  aTop15.sort(function(a,b){ return (b[25]||0)-(a[25]||0); });

  var bEligible = bScored.filter(function(r){ return r[13]==="✅ INCLUDE"; });
  bEligible.sort(function(a,b){ return (b[25]||0)-(a[25]||0); });

  var bKeyword = bEligible.filter(function(r){ return matchesKeyword(r[2]); });
  var bMerit   = bEligible.filter(function(r){ return !matchesKeyword(r[2]); });

  bKeyword.sort(function(a,b){ return (b[25]||0)-(a[25]||0); });
  bMerit.sort(function(a,b){ return (b[25]||0)-(a[25]||0); });

  var bTop5Keyword = bKeyword.slice(0, 5);
  var bMeritSlots  = 15 - bTop5Keyword.length;
  var bTopMerit    = bMerit.slice(0, bMeritSlots);

  bTop5Keyword = bTop5Keyword.map(function(r){
    var rw = r.slice();
    rw[27] = rw[27] + " | keyword match";
    return rw;
  });

  var bTop15 = bTop5Keyword.concat(bTopMerit);
  bTop15.sort(function(a,b){ return (b[25]||0)-(a[25]||0); });

  var top15 = aTop15.concat(bTop15);

  var hdrs = [
    "Supplier","SKU","Product Name","Cost","MSRP","Margin %","Abs $ Margin","Stock",
    "Category","Theme","Material","Color","Set Size",
    "Eligible","Reason",
    "Margin Sc","Abs$ Sc","Price Sc","Avail Sc","Reorder Sc",
    "Cat Sc","Set Sc","MultiFunc Sc","Handmade Sc","Trend Sc",
    "TOTAL","TIER","Pool"
  ];

  writeSheet(aOutSheet, hdrs, aScored);
  writeSheet(bOutSheet, hdrs, bScored);
  writeSheet(outSheet,  hdrs, top15);

  var kwSummary = keywords.length > 0
    ? "\nKeywords: " + keywords.join(", ") + "\n" +
      "  Supplier A keyword matches: " + aTop5Keyword.length + "\n" +
      "  Supplier B keyword matches: " + bTop5Keyword.length
    : "\nNo keywords, pure merit scoring.";

  ui.alert(
    "✅ Done! Scoring v3.6\n\n" +
    "Supplier A Top 15:\n" +
    "  🪑 Furniture: " + aTop5Furn.length + "\n" +
    "  🔍 Keyword matches: " + aTop5Keyword.length + "\n" +
    "  🏠 Merit: " + aTopMerit.length + "\n\n" +
    "Supplier B Top 15:\n" +
    "  🔍 Keyword matches: " + bTop5Keyword.length + "\n" +
    "  🏠 Merit: " + bTopMerit.length +
    kwSummary
  );
}

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu("🏆 Product Scoring")
    .addItem("Run Scoring → Generate All Tabs", "scoreProducts")
    .addToUi();
}
