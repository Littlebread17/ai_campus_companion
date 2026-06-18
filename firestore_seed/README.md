# AI Campus Companion Firestore Seed Script

This script creates starter Firestore collections and sample documents for:

- users
- announcements
- resources
- timetable
- reminders
- locations
- events
- chatHistory
- agentActions

## How to use

1. Install Node.js.
2. Open Firebase Console.
3. Go to Project Settings > Service Accounts.
4. Generate a new private key.
5. Download the JSON file.
6. Rename it to:

serviceAccountKey.json

7. Put it in this folder.
8. Open terminal in this folder.
9. Run:

npm install

10. Run:

npm run seed

## Important

Do not upload serviceAccountKey.json to GitHub.
Keep it private.
