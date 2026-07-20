// Creates the demo Firebase Auth accounts + their studentRegistry + users docs
// directly via the Admin SDK. Idempotent: re-running updates instead of failing.
//
//   node create_demo_accounts.js
//
const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const auth = admin.auth();
const db = admin.firestore();

const PASSWORD = "Demo1234!";

const accounts = [
  {
    email: "admin.demo@intidemo.com",
    name: "Admin Demo",
    role: "admin",
    studentId: "ADMIN001",
    programme: "Staff",
    year: "-",
  },
  {
    email: "ali.rahman@intidemo.com",
    name: "Ali Rahman",
    role: "student",
    studentId: "I24026254",
    programme: "BCSI",
    year: "Year 3",
  },
  {
    email: "aisha.tan@intidemo.com",
    name: "Aisha Tan",
    role: "student",
    studentId: "I24026255",
    programme: "BTDS",
    year: "Year 3",
  },
  {
    email: "ben.wong@intidemo.com",
    name: "Ben Wong",
    role: "student",
    studentId: "I24026256",
    programme: "BCSI",
    year: "Year 3",
  },
  {
    email: "priya.kaur@intidemo.com",
    name: "Priya Kaur",
    role: "student",
    studentId: "I24026257",
    programme: "BTDS",
    year: "Year 3",
  },
];

async function ensureAuthUser(acc) {
  try {
    const existing = await auth.getUserByEmail(acc.email);
    // Reset password so you always know it.
    await auth.updateUser(existing.uid, {
      password: PASSWORD,
      displayName: acc.name,
    });
    return existing.uid;
  } catch (e) {
    if (e.code === "auth/user-not-found") {
      const created = await auth.createUser({
        email: acc.email,
        password: PASSWORD,
        displayName: acc.name,
        emailVerified: true,
      });
      return created.uid;
    }
    throw e;
  }
}

async function run() {
  for (const acc of accounts) {
    const email = acc.email.toLowerCase();
    const uid = await ensureAuthUser(acc);

    // studentRegistry (keyed by email) — pre-approval + role source of truth.
    await db.collection("studentRegistry").doc(email).set(
      {
        email,
        name: acc.name,
        role: acc.role,
        studentId: acc.studentId,
        programme: acc.programme,
        year: acc.year,
        demo: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // users/{uid} — profile the app reads after login.
    await db.collection("users").doc(uid).set(
      {
        name: acc.name,
        email,
        studentId: acc.studentId,
        programme: acc.programme,
        year: acc.year,
        role: acc.role,
        source: "admin_seed",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    console.log(`OK  ${acc.role.padEnd(7)}  ${email}  (uid ${uid})`);
  }

  console.log("\nAll accounts ready. Password for every account: " + PASSWORD);
  process.exit(0);
}

run().catch((e) => {
  console.error("FAILED:", e);
  process.exit(1);
});
