# 📋 DisTask for macOS

A native macOS menu bar app that lets you track your daily tasks, check them off as you go, and automatically push your completed tasks to a Discord channel at a scheduled time every day (or manually on-demand).

Built specifically for macOS using **Swift**, **SwiftUI**, and modern macOS APIs.

---

## ✨ Features

- **Menu Bar Utility**: Runs quietly in your macOS menu bar with zero Dock clutter (`LSUIElement`).
- **Dynamic Menu Bar Badge**: Shows the number of completed tasks ready to push directly next to the menu bar icon (e.g. `[4]`).
- **Task Management**:
  - Add tasks with title, optional notes/context, and priority (**Low**, **Medium**, **High**).
  - Check / uncheck tasks with animated checkmarks and strikethroughs.
  - Filter tasks by **Active**, **Queue**, **Pushed**, or **All**.
  - Search tasks in real-time.
  - Hover actions to edit, delete, or re-queue tasks.
- **Strict Push Queue Guarantee**:
  - Only tasks currently in the Push Queue are sent.
  - Pushed tasks immediately transition to the **Pushed** archive with a timestamp (e.g. `Pushed at 17:00`).
  - Queue count and menu bar badge clear immediately.
  - Push button is disabled when the queue is empty to prevent duplicate submissions.
- **Clean Code Block Format**:
  - Posts messages wrapped in markdown code blocks:
    ```
    Oct 7
    - New designed category
    - LR fixes
    - Meeting with team
    - Bug fixes
    ```
- **Silent Background Discord Webhook Delivery**:
  - Uses Discord Webhook HTTP API for 100% reliable, instant delivery in the background without opening browser windows or stealing focus.
- **Automated Scheduling ("On Given Time")**:
  - Set your desired daily push time (e.g., `17:00` / `5:00 PM`).
  - Choose between **Every Day** or **Weekdays Only** (skips weekends).
  - Live countdown in the UI (e.g., `Today at 5:00 PM (in 1h 45m)`).
  - Prevents accidental duplicate pushes on the same calendar day.
- **Native macOS Notifications**: Banner alerts with sound whenever tasks are successfully sent.
- **Offline Persistence**: Automatically saves tasks and settings to `~/Library/Application Support/DisTask/`.

---

## 🚀 Quick Start

### 1. Launching the App

To run the pre-packaged application:
```bash
open DisTask.app
```

Alternatively, you can run it directly from source:
```bash
swift run
```

### 2. Building the App Bundle

To re-compile and bundle into `DisTask.app`:
```bash
./build_app.sh
```

You can drag `DisTask.app` into your `/Applications` folder for permanent access.

---

## ⚡ Setting Up Discord Delivery

1. In your Discord channel, go to **Channel Settings > Integrations > Webhooks**.
2. Click **New Webhook**, name it (e.g. `DisTask Bot`), and click **Copy Webhook URL**.
3. Open **DisTask** from your macOS menu bar.
4. Click ⚙️ **Settings**.
5. Paste your Webhook URL.
6. Click **"Send Test Webhook"** to confirm the connection!

---

## ⏰ Configuring the Schedule

1. Open **DisTask** from the menu bar.
2. Click ⚙️ **Settings**.
3. Under **Automated Daily Push**:
   - Toggle **Enable Scheduled Auto-Push** ON.
   - Select your target time (Hour and Minute, e.g. `17:00` / 5:00 PM).
   - Select frequency (**Every Day** or **Weekdays Only**).
4. Click **Done**.
5. The header pill will now display the live countdown to your next push!

---

## 🧪 Running Unit & E2E Tests

The project includes an end-to-end test suite:
```bash
swift test
```

---

## 📁 Storage & Configuration Location

- Tasks: `~/Library/Application Support/DisTask/tasks.json`
- Settings: `~/Library/Application Support/DisTask/settings.json`
