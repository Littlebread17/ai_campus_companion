Firebase Functions - IU Digital Hub 3-Day Sync

Purpose:
Fetch public links from IU Digital Hub and save them to Firestore collections:
- webResources
- resources

Recommended schedule:
- This project uses every 3 days: 2:00 AM Asia/Kuala_Lumpur on */3 calendar days.
- Do not fetch too often because the website is not your server.

Important:
- Only fetch public pages.
- Do not scrape login-protected content.
- Do not store private student data.
- If INTI provides an official API later, use the official API instead.

Commands:
firebase init functions
cd functions
npm install
firebase deploy --only functions

Scheduled functions may require Blaze billing because they use Cloud Scheduler/Cloud Functions.
