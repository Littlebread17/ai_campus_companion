/**
 * Imports the provided JUN2026 timetable for waimeng@gmail.com and removes
 * old starter/demo academic records from Firestore.
 *
 * Usage:
 *   $env:WAIMENG_PASSWORD="..."
 *   node import_waimeng_timetable.js
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const auth = admin.auth();
const now = admin.firestore.FieldValue.serverTimestamp();

const email = process.env.WAIMENG_EMAIL || "waimeng@gmail.com";
const password = process.env.WAIMENG_PASSWORD;

const profile = {
  name: "waimeng",
  email,
  studentId: "I24027537",
  programme: "BCSI Bachelor of Computer Science (Hons)",
  major: "GEN General",
  school: "GBL110 Information Technology",
  session: "JUN2026",
  modeOfStudy: "Full Time",
  year: "2",
  semester: "5",
  role: "student",
  updatedAt: now,
};

const timetable = [
  {
    courseCode: "ITM3207",
    courseName: "Information Technology Project Management",
    lecturer: "Muhammad Na'im Fikri bin Jamaluddin",
    section: "6G1",
    day: "Monday",
    startTime: "10:00",
    endTime: "11:00",
    room: "B2-L01",
    type: "lecture",
  },
  {
    courseCode: "ITM3206",
    courseName: "Software Engineering",
    lecturer: "MEI YOON LAI",
    section: "6G1",
    day: "Monday",
    startTime: "11:00",
    endTime: "12:00",
    room: "B2-L01",
    type: "lecture",
  },
  {
    courseCode: "ITM3206",
    courseName: "Software Engineering",
    lecturer: "MEI YOON LAI",
    section: "6G1",
    day: "Monday",
    startTime: "12:00",
    endTime: "14:00",
    room: "A2-06",
    type: "lecture",
  },
  {
    courseCode: "ITM3206",
    courseName: "Software Engineering",
    lecturer: "MEI YOON LAI",
    section: "6G1",
    day: "Monday",
    startTime: "14:00",
    endTime: "16:00",
    room: "A2-08",
    type: "tutorial",
  },
  {
    courseCode: "MPU3203",
    courseName: "Integrity and Anti Corruption Course",
    lecturer: "Raja Zaeiful Zarin bin Raja Ahmad Nizam",
    section: "6D",
    day: "Wednesday",
    startTime: "08:00",
    endTime: "10:00",
    room: "RC4-07",
    type: "lecture",
  },
  {
    courseCode: "ITM3207",
    courseName: "Information Technology Project Management",
    lecturer: "Muhammad Na'im Fikri bin Jamaluddin",
    section: "6G1",
    day: "Wednesday",
    startTime: "10:00",
    endTime: "12:00",
    room: "B2-L01",
    type: "lecture",
  },
  {
    courseCode: "ITM3206",
    courseName: "Software Engineering",
    lecturer: "MEI YOON LAI",
    section: "6G1",
    day: "Thursday",
    startTime: "10:00",
    endTime: "12:00",
    room: "B3-12",
    type: "lecture",
  },
  {
    courseCode: "ITM3207",
    courseName: "Information Technology Project Management",
    lecturer: "Muhammad Na'im Fikri bin Jamaluddin",
    section: "6G1",
    day: "Friday",
    startTime: "15:00",
    endTime: "17:00",
    room: "A3-CL2",
    type: "practical",
  },
];

async function ensureUser() {
  try {
    const user = await auth.getUserByEmail(email);
    const updates = { displayName: profile.name };
    if (password) updates.password = password;
    await auth.updateUser(user.uid, updates);
    return user.uid;
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    if (!password) {
      throw new Error("Set WAIMENG_PASSWORD before creating the user.");
    }
    const user = await auth.createUser({
      email,
      password,
      displayName: profile.name,
      emailVerified: true,
    });
    return user.uid;
  }
}

async function deleteQuery(snapshot, batch) {
  for (const doc of snapshot.docs) batch.delete(doc.ref);
}

async function cleanupDemoData(batch) {
  for (const [collection, id] of [
    ["announcements", "announcement_001"],
    ["announcements", "announcement_002"],
    ["resources", "resource_001"],
    ["resources", "resource_002"],
    ["reminders", "reminder_001"],
    ["events", "event_001"],
    ["chatHistory", "chat_001"],
    ["users", "sample_student_001"],
    ["users", "sample_admin_001"],
  ]) {
    batch.delete(db.collection(collection).doc(id));
  }

  await deleteQuery(
    await db.collection("timetable").where("userId", "==", "sample_student_001").get(),
    batch,
  );

  const demoTitles = new Set([
    "ITM3206 Test This Friday",
    "Library Opening Hours Update",
    "ITM3206 Course Outline",
    "Academic Calendar 2026",
    "ITM3206 Test",
    "Career Fair 2026",
  ]);
  for (const collection of ["announcements", "resources", "reminders", "events"]) {
    const snapshot = await db.collection(collection).get();
    for (const doc of snapshot.docs) {
      if (demoTitles.has((doc.data().title || "").toString())) {
        batch.delete(doc.ref);
      }
    }
  }
}

async function replaceTimetable(uid, batch) {
  await deleteQuery(
    await db.collection("timetable").where("userId", "==", uid).get(),
    batch,
  );

  for (const entry of timetable) {
    batch.set(db.collection("timetable").doc(), {
      ...entry,
      userId: uid,
      createdAt: now,
      updatedAt: now,
    });
  }
}

async function main() {
  const uid = await ensureUser();
  const batch = db.batch();

  batch.set(db.collection("users").doc(uid), {
    ...profile,
    createdAt: now,
  }, { merge: true });

  await cleanupDemoData(batch);
  await replaceTimetable(uid, batch);
  await batch.commit();

  console.log(`Updated ${email} (${uid}) with ${timetable.length} timetable rows.`);
  console.log("Removed old starter academic/demo records.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
