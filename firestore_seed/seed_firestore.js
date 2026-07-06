/**
 * AI Campus Companion - Firestore Seed Script
 *
 * This seed keeps only neutral app infrastructure. It intentionally does not
 * create demo users, announcements, resources, timetable rows, reminders,
 * events, or chat history because those records should come from real users,
 * admin actions, uploads, or approved event proposals.
 *
 * IMPORTANT:
 * 1. Do NOT upload serviceAccountKey.json to GitHub.
 * 2. Keep serviceAccountKey.json private.
 * 3. Run this script only from your own computer.
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function seedDatabase() {
  console.log("Starting infrastructure seed...");

  const now = admin.firestore.FieldValue.serverTimestamp();
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

  const batch = db.batch();
  for (const action of agentActions) {
    batch.set(db.collection("agentActions").doc(action.id), {
      actionName: action.actionName,
      description: action.description,
      enabled: action.enabled,
      updatedAt: now,
    }, { merge: true });
  }
  await batch.commit();

  console.log("Infrastructure seed completed successfully.");
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
