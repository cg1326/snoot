# Snoot: Your Dog's Care Guide

Most dog owners know their pet's routine cold. The problem is communicating it, as pet sitters get a wall of texts, a rushed verbal handoff, or a notes app screenshot that's already out of date.

Snoot is an iOS app for building a shareable dog care guide. One link covers feeding, walks, behavior, health, and medications. The sitter opens it in any browser, no app required. When they arrive, they log the visit, and the owner gets a notification. Paid features allow access to live updates between the owner and the sitter, family access for the owner, and sitter-enabled visit logs that are immediately viewable by the owner.

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/snoot-your-dogs-care-guide/id6767620183)

<div style="display:flex; gap:10px;">
  <img width="150" alt="Group 5" src="https://github.com/user-attachments/assets/07ad97b3-fb7b-4b4a-8e83-e98b9e58e0a5" />
  <img width="150" alt="Group 12" src="https://github.com/user-attachments/assets/20faaa6a-a2af-44c6-bddf-ea67fcc4a9e2" />
  <img width="150" alt="Group 10" src="https://github.com/user-attachments/assets/837e326d-8849-418b-bef9-8db0e1a1cdf9" />
  <img width="150" alt="Group 11" src="https://github.com/user-attachments/assets/1541b05f-abc5-4a21-a7a2-5864b5873d59" />
  <img width="150" alt="Group 9" src="https://github.com/user-attachments/assets/62195086-2fc8-4b44-920c-0ae7eeae3828" />
</div>

## What it does

**Care guide builder.** Step-by-step onboarding covers the basics, feeding schedule, walk routine, behavioral quirks, health needs, and bedtime. Each section is editable anytime.

**Shareable sitter links.** Generate a link that opens a read-only care guide in the browser. Share via text, AirDrop, or copy. No account or app install required for the sitter.

**Visit logging.** Sitters log visits directly from the care guide link. The owner gets a push notification when the visit is logged.

**Family access.** Add family members as editors (can update the guide) or viewers (read-only access to the guide and visit history).

**PDF export.** Export the care guide as a PDF for sitters who prefer a printed copy.

## Snoot Pro

Sitter links, visit logging, notifications, and family access are behind a subscription. PDF export is free.

Monthly ($3.99/mo) and yearly ($24.99/yr) plans available.

## Why not Rover or Wag?

Those apps solve the "who." Finding someone trustworthy to watch your dog is its own whole thing, and they're good at it.
But once you have your person, i.e., the neighbor who's met your dog, your friend who's watched her before, your cousin who owes you a favor, Rover becomes irrelevant. What you're left with is a  very long message thread every single time you leave town.

Where's the food? How much? Does she get a walk before bed or after? What's the vet's number? Is she allowed on the couch? (She's going to get on the couch regardless, but still.)

Snoot is for the part where you're answering a bunch of those one off questions. Build your dog's profile once: routine, feeding schedule, medications, emergency contacts, the couch policy, and share it as a link. Your sitter doesn't need to download anything and you don't need to repeat yourself.

## Tech stack

- SwiftUI
- SwiftData
- StoreKit 2
- Supabase (auth, database, edge functions)
- APNs push notifications
- Vercel (sitter web view).
