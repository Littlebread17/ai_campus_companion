/**
 * AI Campus Companion - Firestore Seed Script
 * Author: Hoh Wen Hao FYP Development
 *
 * This script creates starter Firestore collections and sample documents:
 * users, announcements, resources, timetable, reminders, locations,
 * events, chatHistory, agentActions
 *
 * IMPORTANT:
 * 1. Do NOT upload serviceAccountKey.json to GitHub.
 * 2. Keep serviceAccountKey.json private.
 * 3. Run this script only from your own computer.
 */

const admin = require("firebase-admin");

// Put your downloaded Firebase service account file in the same folder.
// Rename it to: serviceAccountKey.json
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function seedDatabase() {
  console.log("Starting Firestore database seed...");

  const now = admin.firestore.FieldValue.serverTimestamp();

  // =========================
  // 1. Users Collection
  // =========================
  await db.collection("users").doc("sample_student_001").set({
    name: "Hoh Wen Hao",
    email: "haohoh837@gmail.com",
    studentId: "I24026253",
    programme: "Bachelor of Computer Science",
    year: "Final Year",
    role: "student",
    createdAt: now,
  });

  await db.collection("users").doc("sample_admin_001").set({
    name: "Admin User",
    email: "admin@inti.edu.my",
    studentId: "",
    programme: "",
    year: "",
    role: "admin",
    createdAt: now,
  });

  // =========================
  // 2. Announcements Collection
  // =========================
  await db.collection("announcements").doc("announcement_001").set({
    title: "ITM3206 Test This Friday",
    description: "The ITM3206 test will be held this Friday at 10:00 AM.",
    category: "Exam",
    priority: "high",
    targetProgramme: "Computer Science",
    createdBy: "sample_admin_001",
    createdAt: now,
    expiredAt: "2026-06-20T23:59:00",
  });

  await db.collection("announcements").doc("announcement_002").set({
    title: "Library Opening Hours Update",
    description: "The library will open from 8:00 AM to 8:00 PM this week.",
    category: "Campus",
    priority: "medium",
    targetProgramme: "All",
    createdBy: "sample_admin_001",
    createdAt: now,
    expiredAt: "2026-06-30T23:59:00",
  });

  // =========================
  // 3. Resources Collection
  // =========================
  await db.collection("resources").doc("resource_001").set({
    title: "ITM3206 Course Outline",
    description: "Course outline for ITM3206 Mobile Application Development.",
    category: "Course Outline",
    courseCode: "ITM3206",
    fileUrl: "",
    linkUrl: "https://example.com/itm3206-course-outline",
    uploadedBy: "sample_admin_001",
    createdAt: now,
  });

  await db.collection("resources").doc("resource_002").set({
    title: "Academic Calendar 2026",
    description: "Academic calendar for the 2026 session.",
    category: "Academic Calendar",
    courseCode: "",
    fileUrl: "",
    linkUrl: "https://example.com/academic-calendar-2026",
    uploadedBy: "sample_admin_001",
    createdAt: now,
  });

  // =========================
  // 4. Locations Collection
  // =========================
  await db.collection("locations").doc("location_finance_office").set({
    name: "Finance Office",
    keywords: ["finance", "payment", "fees", "finance office"],
    building: "Block A",
    level: "Level 1",
    room: "A-105",
    description: "Office for payment and finance-related matters.",
    directionText:
      "Enter Block A through the main lobby, turn left, and walk straight to Room A-105.",
    imageUrl: "",
    mapUrl: "",
    createdAt: now,
  });

  await db.collection("locations").doc("location_library").set({
    name: "Library",
    keywords: ["library", "books", "study area", "quiet room"],
    building: "Library Block",
    level: "Level 1",
    room: "Library Main Entrance",
    description: "Main university library and study area.",
    directionText:
      "Walk from the main entrance toward the Library Block. The library entrance is on Level 1.",
    imageUrl: "",
    mapUrl: "",
    createdAt: now,
  });

  await db.collection("locations").doc("location_block_a_302").set({
    name: "Room A-302",
    keywords: ["a302", "a-302", "block a room 302", "room a302"],
    building: "Block A",
    level: "Level 3",
    room: "A-302",
    description: "Classroom located at Block A, Level 3.",
    directionText:
      "Enter Block A, take the stairs or lift to Level 3, then follow the corridor to Room A-302.",
    imageUrl: "",
    mapUrl: "",
    createdAt: now,
  });

  // =========================
  // 5. Timetable Collection
  // =========================
  await db.collection("timetable").doc("timetable_001").set({
    userId: "sample_student_001",
    courseCode: "ITM3206",
    courseName: "Mobile Application Development",
    lecturer: "Ms Sarasvathi",
    day: "Friday",
    startTime: "10:00",
    endTime: "12:00",
    locationId: "location_block_a_302",
    room: "A-302",
    createdAt: now,
  });

  await db.collection("timetable").doc("timetable_002").set({
    userId: "sample_student_001",
    courseCode: "FYP4203",
    courseName: "Final Year Project",
    lecturer: "Ms Sarasvathi",
    day: "Monday",
    startTime: "14:00",
    endTime: "16:00",
    locationId: "location_library",
    room: "Library Discussion Room",
    createdAt: now,
  });

  // =========================
  // 6. Reminders Collection
  // =========================
  await db.collection("reminders").doc("reminder_001").set({
    userId: "sample_student_001",
    title: "ITM3206 Test",
    description: "Prepare for ITM3206 test.",
    courseCode: "ITM3206",
    reminderDate: "2026-06-19",
    reminderTime: "09:00",
    status: "active",
    createdBy: "ai_agent",
    createdAt: now,
  });

  // =========================
  // 7. Events Collection
  // =========================
  await db.collection("events").doc("event_001").set({
    title: "Career Fair 2026",
    description: "Career fair for students to meet companies and explore internship opportunities.",
    category: "Career",
    eventDate: "2026-06-25",
    startTime: "10:00",
    endTime: "16:00",
    locationId: "location_library",
    createdBy: "sample_admin_001",
    createdAt: now,
  });

  // =========================
  // 8. AI Agent Actions Collection
  // =========================
  const agentActions = [
    {
      id: "create_reminder",
      actionName: "create_reminder",
      description: "Allows AI Agent to create a student reminder.",
      enabled: true,
    },
    {
      id: "search_resource",
      actionName: "search_resource",
      description: "Allows AI Agent to search academic resources.",
      enabled: true,
    },
    {
      id: "get_timetable",
      actionName: "get_timetable",
      description: "Allows AI Agent to retrieve timetable information.",
      enabled: true,
    },
    {
      id: "get_location",
      actionName: "get_location",
      description: "Allows AI Agent to retrieve campus location guidance.",
      enabled: true,
    },
    {
      id: "get_announcements",
      actionName: "get_announcements",
      description: "Allows AI Agent to retrieve announcements.",
      enabled: true,
    },
    {
      id: "get_events",
      actionName: "get_events",
      description: "Allows AI Agent to retrieve event information.",
      enabled: true,
    },
    {
      id: "general_chat",
      actionName: "general_chat",
      description: "General non-campus questions are disabled.",
      enabled: false,
    },
  ];

  for (const action of agentActions) {
    await db.collection("agentActions").doc(action.id).set({
      actionName: action.actionName,
      description: action.description,
      enabled: action.enabled,
      createdAt: now,
    });
  }

  // =========================
  // 9. Chat History Collection
  // =========================
  await db.collection("chatHistory").doc("chat_001").set({
    userId: "sample_student_001",
    userMessage: "Remind me this Friday got ITM3206 test.",
    detectedIntent: "create_reminder",
    agentAction: "create_reminder",
    aiResponse: "Reminder created for ITM3206 test this Friday.",
    createdAt: now,
  });

  console.log("Firestore database seed completed successfully.");
}

seedDatabase()
  .then(() => {
    console.log("Done.");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Error seeding Firestore:", error);
    process.exit(1);
  });
