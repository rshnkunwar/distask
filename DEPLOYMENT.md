# 🌐 DisTask Cloud Deployment & Vercel Custom Domain Guide

DisTask is now ready to run **24/7 in the cloud** without requiring your computer to be open. You can access it from your phone, tablet, or any browser, manage your weekly tasks, and let Vercel handle the automated daily Discord push!

---

## ⚡ Option 1: Deploy Directly to Vercel with Your Custom Domain (Recommended)

Since your domain is already hosted/managed on Vercel, deploying here gives you:
- **Instant Subdomain Setup** (e.g. `tasks.yourdomain.com` or `todo.yourdomain.com`) with zero DNS configuration.
- **Automated 24/7 Daily Push** via **Vercel Cron** (`vercel.json`).
- **Free Persistent Storage** via **Vercel KV / Upstash Redis** (1-click in Vercel).
- **Mobile PWA** (Add to Home Screen on iOS/Android for a native app experience).

---

### Step 1: Push Your Code to GitHub

Commit and push the new web code to your repository:

```bash
git add .
git commit -m "Add DisTask Web 24/7 with Vercel support & weekly planner"
git push origin main
```

---

### Step 2: Import into Vercel

1. Go to your [Vercel Dashboard](https://vercel.com/dashboard).
2. Click **"Add New..."** > **"Project"**.
3. Select your GitHub repository (`distask`).
4. Keep the default settings (Root directory `./`, Framework Preset: `Other`).
5. Click **"Deploy"**.

---

### Step 3: Attach Free Persistent Storage (Vercel KV)

To ensure your weekly tasks persist permanently in the cloud:

1. In your newly created Vercel project, go to the **Storage** tab.
2. Click **"Create Database"** > Select **"KV"** (Powered by Upstash).
3. Click **"Continue"**, choose your region, and click **"Create"**.
4. In the database view, click **"Connect Project"** and select your `distask` project.
5. Vercel automatically injects `KV_REST_API_URL` and `KV_REST_API_TOKEN` into your environment variables.
6. Trigger a **Redeploy** (Deployments > Latest > Redeploy) to apply the storage.

---

### Step 4: Attach Your Custom Domain

Because your root domain is already on Vercel, setting up a subdomain is instant:

1. In your project, go to **Settings** > **Domains**.
2. Type your desired subdomain (e.g., `tasks.yourdomain.com` or `distask.yourdomain.com`).
3. Click **Add**.
4. Vercel will automatically configure the SSL certificate and DNS routing within 30 seconds!

> **Alternative: Host under a subpath (e.g. `yourdomain.com/tasks`)**
> If you prefer accessing it at `yourdomain.com/tasks` instead of a subdomain, open your main website's `vercel.json` (or `next.config.js`) and add a rewrite rule:
> ```json
> {
>   "rewrites": [
>     { "source": "/tasks/:match*", "destination": "https://YOUR-DISTASK-APP.vercel.app/:match*" }
>   ]
> }
> ```

---

### Step 5: Configure Discord Webhook & Schedule

1. Open `https://tasks.yourdomain.com` on your computer or phone.
2. Click ⚙️ **Settings**.
3. Paste your Discord Webhook URL.
4. Set your target push time (e.g., `17:00` / 5:00 PM) and choose **Weekdays Only** or **Every Day**.
5. Click **Send Test Webhook** to confirm the connection, then click **Save Settings**.

---

## 📱 How to Use from Your Phone (Zero Computer Needed!)

1. **Add to Home Screen (PWA)**:
   - **iPhone (Safari)**: Open `https://tasks.yourdomain.com`, tap the **Share** button, and tap **"Add to Home Screen"**.
   - **Android (Chrome)**: Open the URL, tap the **⋮** menu, and tap **"Install App"** / **"Add to Home screen"**.
2. **Weekly Planning**:
   - On Monday (or anytime), add all your tasks for the week using the **Day** dropdown (`Mon`, `Tue`, `Wed`, etc.) and set priorities.
   - Filter by day chips (`Mon`, `Tue`, etc.) to see each day's agenda.
3. **Checking Off Tasks**:
   - Throughout the week, whenever you finish a task, tap its checkbox (`✓`).
   - Checked tasks immediately move to the **Push Queue**.
4. **Automated Discord Push ("Strict Guarantee")**:
   - At your scheduled time (e.g. 5:00 PM), Vercel Cron automatically checks your queue.
   - **If you checked tasks**: DisTask formats them into the clean code block and posts them to your Discord channel!
   - **If no tasks were checked**: DisTask skips pushing entirely (**"no push required"**).
   - You can also tap **"Push Queue"** at any time to push immediately on-demand.

---

## 🔒 Security & Multi-User Support for Friends

You can host **one single instance** (e.g., `tasks.yourdomain.com`) and securely share it with your friends!

### How Multi-User Isolation Works
1. **Private Accounts**:
   - Each friend creates their own account (username + password).
   - Passwords are encrypted with cryptographic PBKDF2 hashing.
   - All API routes are protected by signed session tokens.
2. **Dedicated Webhooks per Friend**:
   - Each friend enters their **own personal Discord Webhook URL** and chooses their own scheduled push time and timezone.
   - Friend A cannot see, edit, or push to Friend B's channel.
3. **Automated Multi-User Cron**:
   - At cron time (e.g., 5:00 PM), the cloud scheduler loops through each user independently.
   - For each user: if they have checked tasks, it pushes to *their* channel. If they have 0 checked tasks, it skips them without sending any message.

### Protecting Your Site with an Invite Code
To prevent strangers or internet bots from creating accounts on your public domain, you can set an **Invite Code**:

1. In your Vercel Project, go to **Settings > Environment Variables**.
2. Add:
   - **`INVITE_CODE`**: e.g., `my-friends-only-2026`
   - **`SESSION_SECRET`**: (Optional) a random long string for session signing.
3. Click **Save** and trigger a redeploy.
4. Now, anyone attempting to sign up must provide your invite code to create an account!
