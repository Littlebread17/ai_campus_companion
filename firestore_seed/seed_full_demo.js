// Full realistic demo seeding for all 5 accounts, via the Admin SDK.
// Idempotent: re-running deletes prior seeded rows and rewrites them.
//
//   node seed_full_demo.js
//
const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();
const auth = admin.auth();
const FV = admin.firestore.FieldValue;
const TS = admin.firestore.Timestamp;

const baseCode = (c) => c.split(".")[0].toUpperCase();
const pad = (n) => String(n).padStart(2, "0");
const dstr = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

// ---- course catalog -------------------------------------------------------
const COURSES = {
  "BDS3403.1DS1.JAN2026": { name: "Machine Learning", day: "Wednesday", start: "11:00", end: "13:00", room: "A3-07", lecturer: "Dr Tan" },
  "IBM4202.8G1.AUG2025": { name: "Web Programming", day: "Thursday", start: "10:00", end: "12:00", room: "Lab 5", lecturer: "Ms Wong" },
  "FYP4203.1G1.JAN2026": { name: "Final Year Project I", day: "Monday", start: "14:00", end: "16:00", room: "A3-F02", lecturer: "Dr Sarasvathi" },
  "MPU3206.1C.JAN2026": { name: "Community Service", day: "Friday", start: "15:00", end: "17:00", room: "LT A", lecturer: "Mr Ahmad" },
  "PRG4201.1G1.JAN2026": { name: "Concurrent & Real-Time Systems", day: "Monday", start: "09:00", end: "11:00", room: "A3-05", lecturer: "Dr Sarasvathi" },
  "PRG4205.8G1.AUG2025": { name: "ERP Programming", day: "Tuesday", start: "14:00", end: "16:00", room: "Lab 2", lecturer: "Dr Chen" },
  "BDS3405.1DS1.JAN2026": { name: "Deep Learning", day: "Tuesday", start: "09:00", end: "11:00", room: "A3-09", lecturer: "Dr Lim" },
  "BDS3407.1DS1.JAN2026": { name: "Big Data Analytics", day: "Thursday", start: "14:00", end: "16:00", room: "A3-09", lecturer: "Dr Lim" },
};

const CORE = ["BDS3403.1DS1.JAN2026", "IBM4202.8G1.AUG2025", "FYP4203.1G1.JAN2026", "MPU3206.1C.JAN2026"];
const BCSI_ELECTIVES = ["PRG4201.1G1.JAN2026", "PRG4205.8G1.AUG2025"];
const BTDS_ELECTIVES = ["BDS3405.1DS1.JAN2026", "BDS3407.1DS1.JAN2026"];

const STUDENTS = [
  { email: "ali.rahman@intidemo.com", name: "Ali Rahman", prog: "BCSI", electives: BCSI_ELECTIVES, cgpa: "high" },
  { email: "aisha.tan@intidemo.com", name: "Aisha Tan", prog: "BTDS", electives: BTDS_ELECTIVES, cgpa: "good" },
  { email: "ben.wong@intidemo.com", name: "Ben Wong", prog: "BCSI", electives: BCSI_ELECTIVES, cgpa: "mid" },
  { email: "priya.kaur@intidemo.com", name: "Priya Kaur", prog: "BTDS", electives: BTDS_ELECTIVES, cgpa: "low" },
];
const ADMIN_EMAIL = "admin.demo@intidemo.com";

// ---- helpers --------------------------------------------------------------
function hash(s) {
  let h = 0;
  for (const c of s) h = (h * 31 + c.charCodeAt(0)) & 0x7fffffff;
  return h;
}
function semStart(term) {
  const months = { JAN: 0, FEB: 1, MAR: 2, APR: 3, MAY: 4, JUN: 5, JUL: 6, AUG: 7, SEP: 8, OCT: 9, NOV: 10, DEC: 11 };
  const m = months[term.slice(0, 3)] ?? 0;
  const y = parseInt(term.slice(3));
  let d = new Date(y, m, 1);
  while (d.getDay() !== 1) d = new Date(d.getTime() + 86400000);
  return d;
}
function termOf(fullCode) {
  const parts = fullCode.split(".");
  const last = parts[parts.length - 1].toUpperCase();
  return /^[A-Z]{3}\d{4}$/.test(last) ? last : "JAN2026";
}
async function deleteWhere(coll, field, val, field2, val2) {
  let q = db.collection(coll).where(field, "==", val);
  if (field2) q = q.where(field2, "==", val2);
  const snap = await q.get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  if (snap.size) await batch.commit();
}
async function clearSubcollection(ref) {
  const snap = await ref.get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  if (snap.size) await batch.commit();
}

// ---- per-student data -----------------------------------------------------
const ASSESSMENTS = [["Assignment", 5, "23:59"], ["Class Test", 9, "10:00"], ["Individual Assignment", 12, "23:59"]];

async function seedStudent(uid, s) {
  const courses = [...CORE, ...s.electives];

  // timetable
  await deleteWhere("timetable", "userId", uid, "demo", true);
  for (const code of courses) {
    const c = COURSES[code];
    await db.collection("timetable").add({
      userId: uid, courseCode: code, courseName: c.name, day: c.day,
      startTime: c.start, endTime: c.end, room: c.room, lecturer: c.lecturer,
      type: "class", demo: true, createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp(),
    });
  }

  // reminders (assessments, marked auto so they show in course Due Dates)
  await deleteWhere("reminders", "userId", uid, "demo", true);
  await deleteWhere("reminders", "userId", uid, "auto", true);
  for (const code of courses) {
    const bc = baseCode(code);
    const start = semStart(termOf(code));
    const off = hash(bc) % 5;
    for (const [label, week, time] of ASSESSMENTS) {
      const d = new Date(start.getTime() + ((week - 1) * 7 + off) * 86400000);
      await db.collection("reminders").add({
        userId: uid, title: `${bc} ${label}`,
        description: `${label} for ${COURSES[code].name}.`,
        courseCode: bc, reminderDate: dstr(d), reminderTime: time,
        status: "active", type: label.toLowerCase().includes("test") ? "test" : "assignment",
        auto: true, createdBy: "seed", createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp(),
      });
    }
  }

  // grades (different CGPA per student)
  await deleteWhere("grades", "userId", uid, "demo", true);
  const gp = { A: 4, "A-": 3.67, "B+": 3.33, B: 3, "B-": 2.67, "C+": 2.33, C: 2 };
  const profiles = {
    high: ["A", "A-", "A", "A-", "A", "A-", "A", "B+", "A", "A-", "A", "A"],
    good: ["A-", "B+", "A", "A-", "B+", "A-", "A-", "B+", "A", "A-", "B+", "A-"],
    mid: ["B+", "B", "B+", "B-", "B", "B+", "B", "B-", "B+", "B", "C+", "B"],
    low: ["B-", "C+", "B-", "C", "C+", "B-", "C", "C+", "B-", "C", "C+", "C"],
  };
  const past = [
    { code: "PRG3101", name: "Introduction to Programming", sem: "AUG2024", cr: 3 },
    { code: "BDS3201", name: "Database Systems", sem: "AUG2024", cr: 3 },
    { code: "MPU3113", name: "Malaysian Studies", sem: "AUG2024", cr: 3 },
    { code: "BUS3301", name: "Business Communication", sem: "AUG2024", cr: 3 },
    { code: "PRG3202", name: "Data Structures", sem: "JAN2025", cr: 3 },
    { code: "BDS3302", name: "Statistics for Data Science", sem: "JAN2025", cr: 3 },
    { code: "PRG3303", name: "Object-Oriented Programming", sem: "JAN2025", cr: 3 },
    { code: "MTH3101", name: "Discrete Mathematics", sem: "JAN2025", cr: 3 },
    { code: "BDS3401", name: "Data Mining", sem: "AUG2025", cr: 3 },
    { code: "PRG3401", name: "Software Engineering", sem: "AUG2025", cr: 3 },
    { code: "SEC3101", name: "Cybersecurity Foundations", sem: "AUG2025", cr: 3 },
    { code: "MPU3222", name: "Ethnic Relations", sem: "AUG2025", cr: 2 },
  ];
  const grades = profiles[s.cgpa];
  for (let i = 0; i < past.length; i++) {
    const g = grades[i];
    await db.collection("grades").add({
      userId: uid, courseCode: past[i].code, courseName: past[i].name,
      semester: past[i].sem, grade: g, gradePoint: gp[g], creditHours: past[i].cr,
      demo: true, createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp(),
    });
  }

  // a couple of personal reminders + calendar events
  await deleteWhere("reminders", "userId", uid, "demo", true);
  const today = new Date();
  const soon = new Date(today.getTime() + 2 * 86400000);
  await db.collection("reminders").add({
    userId: uid, title: "Prepare ML project slides", description: "For the group presentation.",
    courseCode: "BDS3403", reminderDate: dstr(soon), reminderTime: "21:00",
    status: "active", createdBy: "demo", demo: true, createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp(),
  });

  await deleteWhere("calendarEvents", "userId", uid, "demo", true);
  await db.collection("calendarEvents").add({
    userId: uid, title: "ML study group", date: dstr(today), startTime: "19:00", endTime: "21:00",
    location: "Library Level 2", type: "study", courseCode: "BDS3403", notes: "Revise week 3-4.",
    demo: true, createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp(),
  });
  await db.collection("calendarEvents").add({
    userId: uid, title: "FYP supervisor meeting", date: dstr(soon), startTime: "10:30", endTime: "11:00",
    location: "A3-F02", type: "meeting", courseCode: "FYP4203", notes: "Progress update.",
    demo: true, createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp(),
  });

  console.log(`  student seeded: ${s.name} (${courses.length} courses)`);
}

// ---- shared course materials (once per course) ----------------------------
async function seedMaterials() {
  await deleteWhere("resources", "demo", true, "category", "Course Material");
  const titles = ["Course Outline", "Tutorial Questions", "Past Year Papers", "Week 1 Notes", "Week 2 Notes", "Week 3 Notes"];
  let n = 0;
  for (const code of Object.keys(COURSES)) {
    const bc = baseCode(code);
    for (const t of titles) {
      await db.collection("resources").add({
        title: `${bc} - ${t}`, description: `${t} for ${COURSES[code].name}.`,
        category: "Course Material", courseCode: bc, linkUrl: "", fileUrl: "",
        uploadedBy: "admin", demo: true, createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp(),
      });
      n++;
    }
  }
  console.log(`  course materials: ${n}`);
}

// ---- shared announcements / events / notifications / resources / locations
async function seedShared(adminUid) {
  const anns = [
    { id: "ann_1", title: "PRG4201 class cancelled Monday", description: "Monday PRG4201 lecture is cancelled due to a departmental meeting. A replacement will be announced.", category: "Class Update", priority: "high", targetProgramme: "BCSI", courseCode: "PRG4201" },
    { id: "ann_2", title: "Machine Learning group list released", description: "Group allocations for BDS3403 project are posted. Check the Materials tab.", category: "Course", priority: "normal", targetProgramme: "All", courseCode: "BDS3403" },
    { id: "ann_3", title: "Final exam schedule Jan 2026", description: "The Jan 2026 final examination timetable is now available under Resources.", category: "Exam", priority: "high", targetProgramme: "All", courseCode: "" },
    { id: "ann_4", title: "Public holiday: Chinese New Year", description: "Campus closed 17-18 February 2026. Classes resume 19 February.", category: "General", priority: "normal", targetProgramme: "All", courseCode: "" },
    { id: "ann_5", title: "Web Programming assignment brief", description: "Assignment 1 brief uploaded. Due next Thursday 23:59.", category: "Assignment", priority: "normal", targetProgramme: "All", courseCode: "IBM4202" },
    { id: "ann_6", title: "FYP progress presentation", description: "Final Year students present progress in week 8. Slot booking opens Monday.", category: "FYP", priority: "high", targetProgramme: "All", courseCode: "FYP4203" },
    { id: "ann_7", title: "Library extended hours during exam week", description: "The LRC stays open until 2 AM during exam week.", category: "General", priority: "normal", targetProgramme: "All", courseCode: "" },
    { id: "ann_8", title: "Deep Learning guest lecture", description: "Industry speaker session for BDS3405 this Friday, 3 PM, A3-09.", category: "Course", priority: "normal", targetProgramme: "BTDS", courseCode: "BDS3405" },
  ];
  for (const a of anns) {
    const id = a.id; delete a.id;
    await db.collection("announcements").doc(id).set({ ...a, createdBy: adminUid, source: "admin", demo: true, expiredAt: "", createdAt: FV.serverTimestamp() }, { merge: true });
  }

  const now = new Date();
  const evs = [
    { id: "ev_1", title: "INTI Virtual Career Fair 2026", description: "Meet 30+ employers from Malaysia and abroad.", days: 5, startTime: "09:00", endTime: "17:00", venue: "Library", clubName: "Career Services", posterUrl: "asset:assets/images/event_posters/career_fair_2026.png" },
    { id: "ev_2", title: "AI & Data Science Workshop", description: "Hands-on session with industry ML practitioners.", days: 10, startTime: "14:00", endTime: "17:00", venue: "A3-05", clubName: "FDSIT", posterUrl: "asset:assets/images/event_posters/ai_data_science_workshop.png" },
    { id: "ev_3", title: "Freshers Orientation Day", description: "Welcome session for the new intake.", days: 14, startTime: "10:00", endTime: "13:00", venue: "Lecture Theatre 1", clubName: "Student Affairs", posterUrl: "asset:assets/images/event_posters/freshers_orientation_day.png" },
    { id: "ev_4", title: "Inter-Faculty Sports Day", description: "Football, basketball, badminton and more.", days: 21, startTime: "08:00", endTime: "18:00", venue: "Sports Complex", clubName: "Sports Club", posterUrl: "asset:assets/images/event_posters/inter_faculty_sports_day.png" },
    { id: "ev_5", title: "Guest talk: Startups in Malaysia", description: "Panel with local founders and investors.", days: 28, startTime: "15:00", endTime: "17:00", venue: "LT A", clubName: "Entrepreneurs Club", posterUrl: "asset:assets/images/event_posters/startups_in_malaysia.png" },
  ];
  for (const e of evs) {
    const id = e.id; const days = e.days; delete e.id; delete e.days;
    await db.collection("events").doc(id).set({ ...e, eventDate: dstr(new Date(now.getTime() + days * 86400000)), status: "published", createdBy: adminUid, sourceProposalId: "", demo: true, createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp() }, { merge: true });
  }

  const notifs = [
    { id: "nt_1", title: "PRG4201 class cancelled", body: "Monday lecture is cancelled.", type: "announcement" },
    { id: "nt_2", title: "ML tutorial due today", body: "Upload the regression exercise before 23:59.", type: "reminder" },
    { id: "nt_3", title: "Career Fair 2026", body: "Meet 30+ employers next week.", type: "event" },
    { id: "nt_4", title: "BDS3403 group list released", body: "Check the Materials tab for your group.", type: "announcement" },
    { id: "nt_5", title: "FYP supervisor meeting tomorrow", body: "10:30 at A3-F02.", type: "reminder" },
    { id: "nt_6", title: "Web Programming quiz open", body: "Chapter 2 quiz on Canvas until Sunday.", type: "announcement" },
  ];
  for (const n of notifs) {
    const id = n.id; delete n.id;
    await db.collection("notifications").doc(id).set({ ...n, audience: "students", demo: true, readBy: [], createdAt: FV.serverTimestamp() }, { merge: true });
  }

  const res = [
    { id: "res_1", title: "Canvas LMS student portal", description: "Submit assignments and access materials.", category: "Learning", courseCode: "", linkUrl: "https://newinti.instructure.com" },
    { id: "res_2", title: "IU Digital Hub - Academic Calendar", description: "Semester dates and exam periods.", category: "Academic Calendar", courseCode: "", linkUrl: "https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/academic-calendar" },
    { id: "res_3", title: "Past year exam papers", description: "Archive of previous exams.", category: "Exam", courseCode: "", linkUrl: "https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/past-year-examination-papers" },
    { id: "res_4", title: "Student handbook", description: "Programme and code of conduct.", category: "Handbook", courseCode: "", linkUrl: "https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/handbook" },
    { id: "res_5", title: "FYP report template", description: "Word template for all FYP students.", category: "FYP", courseCode: "FYP4203", linkUrl: "" },
  ];
  for (const r of res) {
    const id = r.id; delete r.id;
    await db.collection("resources").doc(id).set({ ...r, fileUrl: "", uploadedBy: adminUid, demo: true, createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp() }, { merge: true });
  }

  const locs = [
    { id: "loc_1", name: "Supervisor Office - Dr Sarasvathi", building: "Academic Block A", level: "Level 3", room: "A3-F02", category: "Office", directionText: "Go to Academic Block A; take the lift to Level 3; follow the corridor to A3-F02.", keywords: ["sarasvathi", "fyp", "supervisor", "a3-f02"] },
    { id: "loc_2", name: "Cafeteria", building: "Student Centre", level: "Ground Floor", room: "Cafeteria", category: "Facility", directionText: "Go to Student Centre; enter the main entrance; cafeteria is on the ground floor.", keywords: ["food", "cafeteria", "canteen"] },
    { id: "loc_3", name: "Finance Office", building: "Academic Block D", level: "Level 1", room: "Finance", category: "Support", directionText: "Head to Academic Block D Level 1; finance counter is next to admissions.", keywords: ["finance", "fee", "payment"] },
  ];
  for (const l of locs) {
    const id = l.id; delete l.id;
    await db.collection("locations").doc(id).set({ ...l, demo: true, createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp() }, { merge: true });
  }
  console.log(`  shared: ${anns.length} announcements, ${evs.length} events, ${notifs.length} notifications, ${res.length} resources, ${locs.length} locations`);
}

// ---- event proposals (for the admin to review) ----------------------------
async function seedProposals(uids) {
  const rows = [
    { id: "prop_1", submittedBy: uids.ali, studentName: "Ali Rahman", title: "Coding Bootcamp 2026", clubName: "Programming Club", venue: "Lab 5", days: 12, status: "submitted", eventAdminRemark: "", mainAdminRemark: "" },
    { id: "prop_2", submittedBy: uids.aisha, studentName: "Aisha Tan", title: "Data Science Talk Series", clubName: "Data Science Society", venue: "A3-09", days: 18, status: "event_admin_checked", eventAdminRemark: "Looks good, forwarded to main admin.", mainAdminRemark: "" },
    { id: "prop_3", submittedBy: uids.ben, studentName: "Ben Wong", title: "E-Sports Tournament", clubName: "Gaming Club", venue: "Sports Complex", days: 25, status: "needs_changes", eventAdminRemark: "Please add a budget breakdown and safety plan.", mainAdminRemark: "" },
  ];
  const now = new Date();
  for (const p of rows) {
    const id = p.id; const days = p.days; delete p.id; delete p.days;
    await db.collection("eventProposals").doc(id).set({
      ...p, eventDate: dstr(new Date(now.getTime() + days * 86400000)),
      startTime: "10:00", endTime: "16:00",
      description: `${p.title} organised by ${p.clubName}.`,
      contactPerson: p.studentName, proposalPdfUrl: "", proposalFileName: "proposal.pdf",
      publishedEventId: "", demo: true, createdAt: FV.serverTimestamp(), updatedAt: FV.serverTimestamp(),
    }, { merge: true });
  }
  console.log(`  event proposals: ${rows.length}`);
}

// ---- chat -----------------------------------------------------------------
async function addMessages(channelId, msgs, baseTime) {
  const ref = db.collection("channels").doc(channelId);
  await clearSubcollection(ref.collection("messages"));
  let t = baseTime;
  let last = null;
  for (const m of msgs) {
    t = new Date(t.getTime() + (2 + Math.floor(Math.random() * 6)) * 60000);
    await ref.collection("messages").add({
      senderId: m.uid, senderName: m.name, senderRole: m.role, text: m.text, createdAt: TS.fromDate(t),
    });
    last = m;
  }
  await ref.set({ lastMessage: last.text, lastSender: last.name, lastAt: TS.fromDate(t) }, { merge: true });
}

async function seedChat(uids) {
  const A = { uid: uids.admin, name: "Dr Tan", role: "admin" };
  const waimeng = { uid: uids.waimeng, name: "Student Waimeng", role: "student" };
  const ali = { uid: uids.ali, name: "Ali Rahman", role: "student" };
  const aisha = { uid: uids.aisha, name: "Aisha Tan", role: "student" };
  const ben = { uid: uids.ben, name: "Ben Wong", role: "student" };
  const priya = { uid: uids.priya, name: "Priya Kaur", role: "student" };
  const base = new Date(Date.now() - 2 * 86400000);

  // Remove the DM pair used by the previous demo layout.
  const legacyDm = db.collection("channels").doc("dm_" + [uids.ali, uids.aisha].sort().join("_"));
  await clearSubcollection(legacyDm.collection("messages"));
  await legacyDm.delete();

  // Course channel: Machine Learning (shared by four students and Dr Tan)
  await db.collection("channels").doc("course_BDS3403").set({
    type: "course", courseCode: "BDS3403", courseName: "Machine Learning", name: "General", open: true,
    memberIds: [uids.admin, uids.waimeng, uids.ali, uids.aisha, uids.ben],
    memberNames: {
      [uids.admin]: "Dr Tan", [uids.waimeng]: "Student Waimeng",
      [uids.ali]: "Ali Rahman", [uids.aisha]: "Aisha Tan", [uids.ben]: "Ben Wong",
    },
    createdAt: FV.serverTimestamp(),
  });
  await addMessages("course_BDS3403", [
    { ...A, text: "Welcome to Machine Learning! Assignment 1 is out — regression on the housing dataset, due in week 5." },
    { ...waimeng, text: "Good morning Dr Tan. Is the dataset already available in the course materials?" },
    { ...ali, text: "Thanks Dr Tan. Is it individual or group?" },
    { ...A, text: "Individual for Assignment 1. The project later will be in groups of 3." },
    { ...aisha, text: "Are we allowed to use scikit-learn or must we implement from scratch?" },
    { ...A, text: "scikit-learn is fine. Focus on the analysis and evaluation." },
    { ...ben, text: "Where can we get the dataset?" },
    { ...A, text: "It's in the Materials tab — Week 1 Notes has the link." },
    { ...waimeng, text: "I found it under Week 1 Notes. Thanks, Dr Tan." },
    { ...ali, text: "Anyone want to form a project group later?" },
    { ...aisha, text: "I'm in. Let's make a group chat." },
  ], base);

  // Course channel: Web Programming (a different overlapping class)
  await db.collection("channels").doc("course_IBM4202").set({
    type: "course", courseCode: "IBM4202", courseName: "Web Programming", name: "General", open: true,
    memberIds: [uids.admin, uids.waimeng, uids.ben, uids.priya],
    memberNames: {
      [uids.admin]: "Dr Tan", [uids.waimeng]: "Student Waimeng",
      [uids.ben]: "Ben Wong", [uids.priya]: "Priya Kaur",
    },
    createdAt: FV.serverTimestamp(),
  });
  await addMessages("course_IBM4202", [
    { ...A, text: "Assignment 1 brief is uploaded. Build a responsive landing page, due Thursday." },
    { ...waimeng, text: "Should the page also work on mobile screens?" },
    { ...A, text: "Yes. Please test both desktop and mobile layouts." },
    { ...ben, text: "Can we use a framework like React or must it be plain HTML/CSS?" },
    { ...A, text: "Plain HTML/CSS/JS for this one — I want to see the fundamentals." },
    { ...priya, text: "Understood, thanks!" },
  ], new Date(base.getTime() + 3600000));

  // Group chat: ML Project Group A
  await db.collection("channels").doc("group_ml_a").set({
    type: "group", courseCode: "BDS3403", name: "ML Project Group A", open: true,
    memberIds: [uids.waimeng, uids.ali, uids.aisha],
    memberNames: {
      [uids.waimeng]: "Student Waimeng", [uids.ali]: "Ali Rahman", [uids.aisha]: "Aisha Tan",
    },
    createdAt: FV.serverTimestamp(),
  });
  await addMessages("group_ml_a", [
    { ...waimeng, text: "Hi team, let's split the ML project tasks before our next class." },
    { ...ali, text: "I'll take data preprocessing." },
    { ...aisha, text: "I'll do model training and tuning." },
    { ...waimeng, text: "I'll handle evaluation and the report write-up." },
    { ...ali, text: "Great. Let's aim to finish preprocessing by this weekend." },
    { ...aisha, text: "Which model are we going with?" },
    { ...waimeng, text: "Let's compare random forest and gradient boosting." },
    { ...ali, text: "Agreed. I'll push the cleaned dataset to our shared drive tonight." },
    { ...aisha, text: "Perfect, thanks Ali!" },
  ], new Date(base.getTime() + 7200000));

  // DM: Waimeng <-> Ali
  const dm1 = "dm_" + [uids.waimeng, uids.ali].sort().join("_");
  await db.collection("channels").doc(dm1).set({
    type: "dm", open: false, memberIds: [uids.waimeng, uids.ali],
    names: { [uids.waimeng]: "Student Waimeng", [uids.ali]: "Ali Rahman" }, createdAt: FV.serverTimestamp(),
  });
  await addMessages(dm1, [
    { ...ali, text: "Hey Waimeng, did you understand question 3 of the ML tutorial?" },
    { ...waimeng, text: "Yes, it is about the bias-variance tradeoff. Want to revise together?" },
    { ...ali, text: "That would be great, thanks!" },
    { ...waimeng, text: "Let's meet at the library at 7 PM." },
  ], new Date(base.getTime() + 10800000));

  // DM: Ben <-> Priya
  const dm2 = "dm_" + [uids.ben, uids.priya].sort().join("_");
  await db.collection("channels").doc(dm2).set({
    type: "dm", open: false, memberIds: [uids.ben, uids.priya],
    names: { [uids.ben]: "Ben Wong", [uids.priya]: "Priya Kaur" }, createdAt: FV.serverTimestamp(),
  });
  await addMessages(dm2, [
    { ...ben, text: "Are you going to the career fair next week?" },
    { ...priya, text: "Yes! Planning to. You?" },
    { ...ben, text: "Same. Let's go together." },
  ], new Date(base.getTime() + 14400000));

  // DM: Aisha <-> Ben
  const dm3 = "dm_" + [uids.aisha, uids.ben].sort().join("_");
  await db.collection("channels").doc(dm3).set({
    type: "dm", open: false, memberIds: [uids.aisha, uids.ben],
    names: { [uids.aisha]: "Aisha Tan", [uids.ben]: "Ben Wong" }, createdAt: FV.serverTimestamp(),
  });
  await addMessages(dm3, [
    { ...aisha, text: "Hi Ben, can you review the mobile layout before submission?" },
    { ...ben, text: "Sure. Send me the link and I will test it tonight." },
    { ...aisha, text: "Thank you! I have shared it in our drive." },
  ], new Date(base.getTime() + 18000000));

  console.log("  chat: 2 course channels, 1 group, 3 DMs");
}

// ---- run ------------------------------------------------------------------
async function uidFor(email) {
  return (await auth.getUserByEmail(email)).uid;
}

async function run() {
  const uids = {
    admin: await uidFor(ADMIN_EMAIL),
    waimeng: await uidFor("waimeng@gmail.com"),
    ali: await uidFor("ali.rahman@intidemo.com"),
    aisha: await uidFor("aisha.tan@intidemo.com"),
    ben: await uidFor("ben.wong@intidemo.com"),
    priya: await uidFor("priya.kaur@intidemo.com"),
  };
  console.log("Seeding students...");
  const map = { "ali.rahman@intidemo.com": uids.ali, "aisha.tan@intidemo.com": uids.aisha, "ben.wong@intidemo.com": uids.ben, "priya.kaur@intidemo.com": uids.priya };
  for (const s of STUDENTS) await seedStudent(map[s.email], s);

  console.log("Seeding materials...");
  await seedMaterials();
  console.log("Seeding shared content...");
  await seedShared(uids.admin);
  console.log("Seeding event proposals...");
  await seedProposals(uids);
  console.log("Seeding chat...");
  await seedChat(uids);

  console.log("\nDONE. All accounts populated. Password: Demo1234!");
  process.exit(0);
}
run().catch((e) => { console.error("FAILED:", e); process.exit(1); });
