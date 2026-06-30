const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const cheerio = require("cheerio");

admin.initializeApp();
const db = admin.firestore();
const IU_DIGITAL_HUB_URL = "https://sites.google.com/student.newinti.edu.my/iudigitalhub/";

exports.syncIUDigitalHubEvery3Days = onSchedule({
  schedule: "0 2 */3 * *",
  timeZone: "Asia/Kuala_Lumpur",
  region: "asia-southeast1",
  timeoutSeconds: 120,
  memory: "256MiB",
}, async () => {
  logger.info("Starting IU Digital Hub 3-day sync...");
  await syncIUDigitalHub();
  logger.info("IU Digital Hub 3-day sync completed.");
});

exports.sendStudentNotification = onDocumentCreated({
  document: "notifications/{notificationId}",
  region: "asia-southeast1",
}, async (event) => {
  const data = event.data && event.data.data();
  if (!data || data.audience !== "students") return;
  const title = data.title || "AI Campus Companion";
  const body = data.body || "You have a new campus update.";
  await admin.messaging().send({
    topic: "students",
    notification: { title, body },
    data: {
      type: String(data.type || "general"),
      eventId: String(data.eventId || ""),
      notificationId: String(event.params.notificationId || ""),
    },
  });
  logger.info(`Sent student notification: ${title}`);
});

async function syncIUDigitalHub() {
  const response = await axios.get(IU_DIGITAL_HUB_URL, { timeout: 30000, headers: { "User-Agent": "AI-Campus-Companion-FYP/1.0" }});
  const $ = cheerio.load(response.data);
  const links = [];
  $("a").each((_, element) => {
    const title = cleanText($(element).text());
    const href = $(element).attr("href");
    if (!title || !href) return;
    const absoluteUrl = makeAbsoluteUrl(href);
    if (!absoluteUrl.startsWith("http")) return;
    links.push({ title, url: absoluteUrl, source: "IU Digital Hub", sourceUrl: IU_DIGITAL_HUB_URL, category: guessCategory(title), lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(), isPublicWebResource: true });
  });
  const uniqueLinks = removeDuplicates(links);
  const batch = db.batch();
  uniqueLinks.forEach((item) => {
    const docId = slugify(item.title + "-" + item.url).slice(0, 120);
    batch.set(db.collection("webResources").doc(docId), item, { merge: true });
    batch.set(db.collection("resources").doc(`iu-digital-hub-${docId}`), {
      title: item.title,
      description: `Synced from IU Digital Hub: ${item.sourceUrl}`,
      category: item.category,
      courseCode: "",
      fileUrl: "",
      linkUrl: item.url,
      uploadedBy: "iu_digital_hub_sync",
      source: item.source,
      sourceUrl: item.sourceUrl,
      isPublicWebResource: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });
  batch.set(db.collection("syncLogs").doc(), {
    source: "IU Digital Hub",
    sourceUrl: IU_DIGITAL_HUB_URL,
    totalLinks: uniqueLinks.length,
    syncedAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "success",
    cadence: "every_3_days",
  });
  await batch.commit();
  logger.info(`Saved ${uniqueLinks.length} IU Digital Hub links to Firestore.`);
}
function cleanText(value){ return String(value || "").replace(/\s+/g," ").trim(); }
function makeAbsoluteUrl(href){ if(href.startsWith("http")) return href; if(href.startsWith("/")) return "https://sites.google.com" + href; return href; }
function removeDuplicates(items){ const seen = new Set(); const output=[]; for(const item of items){ const key=item.title.toLowerCase()+"|"+item.url; if(!seen.has(key)){ seen.add(key); output.push(item); } } return output; }
function slugify(text){ return text.toLowerCase().replace(/https?:\/\//g,"").replace(/[^a-z0-9]+/g,"-").replace(/^-+|-+$/g,""); }
function guessCategory(title){ const lower=title.toLowerCase(); if(lower.includes("exam")) return "Exam"; if(lower.includes("calendar")) return "Academic Calendar"; if(lower.includes("form")) return "Forms"; if(lower.includes("canvas")) return "Canvas"; if(lower.includes("library")||lower.includes("ebook")) return "Library"; if(lower.includes("finance")) return "Finance"; if(lower.includes("career")||lower.includes("internship")) return "Career"; if(lower.includes("orientation")) return "Orientation"; if(lower.includes("student service")) return "Student Services"; return "General"; }
