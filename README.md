# snoot

Most dog owners know their pet's routine cold. The problem is communicating it, as pet sitters get a wall of texts, a rushed verbal handoff, or a notes app screenshot that's already out of date.

Snoot is an iOS app for building a shareable dog care guide. One link covers feeding, walks, behavior, health, and medications. The sitter opens it in any browser, no app required. When they arrive, they log the visit, and the owner gets a notification.

[Download on the App Store](https://apps.apple.com/us/app/snoot-your-dogs-care-guide/id6767620183)

<table>
  <tr>
    <td><img width="200" alt="Group 5" src="https://github.com/user-attachments/assets/07ad97b3-fb7b-4b4a-8e83-e98b9e58e0a5" /></td>
    <td><img width="200" alt="Group 12" src="https://github.com/user-attachments/assets/20faaa6a-a2af-44c6-bddf-ea67fcc4a9e2" /></td>
    <td><img width="200" alt="Group 10" src="https://github.com/user-attachments/assets/de6efa50-4d1b-4325-97b4-e779c0326fd9" /></td>
    <td><img width="200" alt="Group 11" src="https://github.com/user-attachments/assets/1541b05f-abc5-4a21-a7a2-5864b5873d59" /></td>
    <td><img width="200" alt="Group 9" src="https://github.com/user-attachments/assets/62195086-2fc8-4b44-920c-0ae7eeae3828" /></td>
  </tr>
</table>

## What it does

**Care guide builder.** Step-by-step onboarding covers the basics, feeding schedule, walk routine, behavioral quirks, health needs, and bedtime. Each section is editable anytime.

**Shareable sitter links.** Generate a link that opens a read-only care guide in the browser. Share via text, AirDrop, or copy. No account or app install required for the sitter.

**Visit logging.** Sitters log visits directly from the care guide link. The owner gets a push notification when the visit is logged.

**Family access.** Add family members as editors (can update the guide) or viewers (read-only access to the guide and visit history).

**PDF export.** Export the care guide as a PDF for sitters who prefer a printed copy.

## Snoot Pro

Sitter links, visit logging, notifications, and family access are behind a subscription. PDF export is free.

Monthly ($3.99/mo) and yearly ($24.99/yr) plans available.

## Tech

SwiftUI, SwiftData, StoreKit 2, Supabase (auth, database, edge functions), APNs push notifications, Vercel (sitter web view).
