const express = require('express');
const cors = require('cors');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');
const https = require('https');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const CRON_SECRET = process.env.CRON_SECRET || null;
const SESSION_SECRET = process.env.SESSION_SECRET || 'distask-secure-auth-secret-key-2026';
const INVITE_CODE = process.env.INVITE_CODE || null; // Optional: restrict signup to friends with code

// Support Vercel KV & Upstash Redis REST
const KV_URL = process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL;
const KV_TOKEN = process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN;

app.use(cors());
app.use(express.json());

// Serve static assets for both root domain and /distask subpath
app.use(express.static(path.join(__dirname, 'public')));
app.use('/distask', express.static(path.join(__dirname, 'public')));

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  try {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  } catch (_) {}
}

const USERS_FILE = path.join(DATA_DIR, 'users.json');
const USER_DATA_FILE = path.join(DATA_DIR, 'userData.json');

// --- Helper: Atomic File Storage & KV Cloud Storage ---
function writeJsonAtomic(filePath, data) {
  try {
    const tmpPath = `${filePath}.tmp.${Date.now()}`;
    fs.writeFileSync(tmpPath, JSON.stringify(data, null, 2), 'utf8');
    fs.renameSync(tmpPath, filePath);
  } catch (err) {
    console.warn('Local file write skipped:', err.message);
  }
}

async function kvCommand(cmdArray) {
  if (!KV_URL || !KV_TOKEN) return null;
  try {
    const res = await fetch(KV_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${KV_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(cmdArray)
    });
    if (!res.ok) return null;
    const json = await res.json();
    return json.result;
  } catch (err) {
    console.error('KV Storage error:', err.message);
    return null;
  }
}

// In-Memory Multi-Tenant Cache
let usersCache = {};
let userDataCache = {};

function loadLocalUsers() {
  try {
    if (fs.existsSync(USERS_FILE)) {
      return JSON.parse(fs.readFileSync(USERS_FILE, 'utf8'));
    }
  } catch (err) {
    console.error('Error reading users.json:', err.message);
  }
  return {};
}

function loadLocalUserData() {
  try {
    if (fs.existsSync(USER_DATA_FILE)) {
      return JSON.parse(fs.readFileSync(USER_DATA_FILE, 'utf8'));
    }
  } catch (err) {
    console.error('Error reading userData.json:', err.message);
  }
  return {};
}

usersCache = loadLocalUsers();
userDataCache = loadLocalUserData();

const DEFAULT_SETTINGS = {
  discordWebhookUrl: '',
  botUsername: 'DisTask Bot',
  avatarUrl: '',
  isScheduleEnabled: true,
  scheduledHour: 17,
  scheduledMinute: 0,
  scheduleDays: 'weekdaysOnly',
  timezone: process.env.TZ || 'auto',
  dateFormat: 'MMM d',
  taskLineFormat: '- {title}',
  messageTemplate: '```\n{date}\n{tasks}\n```',
  includeNotesInDiscord: false,
  clearTasksAfterPush: false,
  lastPushedDate: null
};

function createDefaultTasks() {
  return [
    {
      id: `task-${Date.now()}-1`,
      title: 'Review weekly goals & team tasks',
      notes: 'DisTask 24/7 Cloud',
      priority: 'high',
      dayOfWeek: 'mon',
      isCompleted: false,
      completedAt: null,
      isPushed: false,
      pushedAt: null,
      createdAt: new Date().toISOString()
    },
    {
      id: `task-${Date.now()}-2`,
      title: 'Configure my Discord Webhook in Settings',
      notes: 'Paste channel webhook URL',
      priority: 'medium',
      dayOfWeek: 'all',
      isCompleted: true,
      completedAt: new Date().toISOString(),
      isPushed: false,
      pushedAt: null,
      createdAt: new Date().toISOString()
    }
  ];
}

async function syncFromCloudKV() {
  if (KV_URL && KV_TOKEN) {
    const remoteUsers = await kvCommand(['GET', 'distask_users']);
    if (remoteUsers) {
      try {
        usersCache = typeof remoteUsers === 'string' ? JSON.parse(remoteUsers) : remoteUsers;
      } catch (_) {}
    }

    const remoteData = await kvCommand(['GET', 'distask_userdata']);
    if (remoteData) {
      try {
        userDataCache = typeof remoteData === 'string' ? JSON.parse(remoteData) : remoteData;
      } catch (_) {}
    }
  }
}

async function persistUsers() {
  writeJsonAtomic(USERS_FILE, usersCache);
  if (KV_URL && KV_TOKEN) {
    await kvCommand(['SET', 'distask_users', JSON.stringify(usersCache)]);
  }
}

async function persistUserData() {
  writeJsonAtomic(USER_DATA_FILE, userDataCache);
  if (KV_URL && KV_TOKEN) {
    await kvCommand(['SET', 'distask_userdata', JSON.stringify(userDataCache)]);
  }
}

function getUserStore(userId) {
  if (!userDataCache[userId]) {
    userDataCache[userId] = {
      tasks: createDefaultTasks(),
      settings: { ...DEFAULT_SETTINGS }
    };
  }
  return userDataCache[userId];
}

// --- Cryptographic Security & Password Hashing ---
function hashPassword(password, salt) {
  return crypto.pbkdf2Sync(password, salt, 10000, 64, 'sha512').toString('hex');
}

function createToken(userId) {
  const expiresAt = Date.now() + 30 * 24 * 60 * 60 * 1000; // 30 days
  const data = `${userId}:${expiresAt}`;
  const sig = crypto.createHmac('sha256', SESSION_SECRET).update(data).digest('hex');
  return Buffer.from(`${data}:${sig}`).toString('base64');
}

function verifyToken(token) {
  try {
    const raw = Buffer.from(token, 'base64').toString('utf8');
    const [userId, expiresAtStr, sig] = raw.split(':');
    const expiresAt = parseInt(expiresAtStr, 10);
    if (isNaN(expiresAt) || Date.now() > expiresAt) return null;

    const expectedSig = crypto.createHmac('sha256', SESSION_SECRET).update(`${userId}:${expiresAtStr}`).digest('hex');
    if (crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expectedSig))) {
      return userId;
    }
  } catch (_) {}
  return null;
}

// --- Auth Middleware ---
async function requireAuth(req, res, next) {
  if (process.env.VERCEL) {
    await syncFromCloudKV();
  }

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required. Please sign in.' });
  }

  const token = authHeader.substring(7);
  const userId = verifyToken(token);
  if (!userId) {
    return res.status(401).json({ error: 'Session expired or invalid. Please sign in again.' });
  }

  const user = Object.values(usersCache).find(u => u.id === userId);
  if (!user) {
    return res.status(401).json({ error: 'User account not found.' });
  }

  req.userId = userId;
  req.user = user;
  next();
}

// --- Helper: Date & Discord Formatting ---
function formatDateWithPattern(date, pattern, timeZone) {
  const d = new Date(date);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const month = months[d.getMonth()];
  const day = d.getDate();
  if (pattern === 'YYYY-MM-DD') return d.toISOString().split('T')[0];
  return `${month} ${day}`;
}

function formatTime(date, timeZone) {
  const options = {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone: timeZone === 'auto' ? undefined : timeZone
  };
  return new Intl.DateTimeFormat('en-US', options).format(date);
}

function sanitizeBotUsername(raw) {
  let name = (raw || '').trim();
  if (!name) return 'DisTask Bot';
  if (name.toLowerCase().includes('discord')) {
    name = name.replace(/discord/gi, 'Task');
  }
  name = name.replace(/@everyone/g, 'everyone').replace(/@here/g, 'here');
  return name.trim() || 'DisTask Bot';
}

function sanitizeAvatarUrl(raw) {
  const trimmed = (raw || '').trim();
  if (trimmed.startsWith('https://') && /\.(png|jpg|jpeg|webp)$/i.test(trimmed)) {
    return trimmed;
  }
  return undefined;
}

function formatDiscordTasksMessage(tasks, settings) {
  const dateStr = formatDateWithPattern(new Date(), settings.dateFormat, settings.timezone);
  const timeStr = formatTime(new Date(), settings.timezone);
  const taskFormat = (settings.taskLineFormat || '- {title}').trim();

  const taskLines = tasks.map((task, index) => {
    let line = taskFormat
      .replace(/{title}/g, task.title)
      .replace(/{index}/g, `${index + 1}`)
      .replace(/{priority}/g, task.priority || 'medium');

    const cleanNotes = (task.notes || '').trim();
    if (line.includes('{notes}')) {
      line = line.replace(/{notes}/g, cleanNotes);
    } else if (settings.includeNotesInDiscord && cleanNotes) {
      line += ` (${cleanNotes})`;
    }
    return line;
  });

  const tasksBlock = taskLines.join('\n');
  let template = (settings.messageTemplate || '```\n{date}\n{tasks}\n```').trim();

  return template
    .replace(/{date}/g, dateStr)
    .replace(/{time}/g, timeStr)
    .replace(/{tasks}/g, tasksBlock)
    .replace(/{count}/g, `${tasks.length}`)
    .replace(/{username}/g, settings.botUsername || 'DisTask Bot');
}

function validateWebhookUrl(urlStr) {
  const trimmed = (urlStr || '').trim();
  if (!trimmed) {
    return { isValid: false, error: 'Webhook URL cannot be empty.' };
  }
  try {
    const parsed = new URL(trimmed);
    const host = parsed.hostname.toLowerCase();
    if (!host.includes('discord.com') && !host.includes('discordapp.com')) {
      return { isValid: false, error: 'URL must be a valid Discord webhook URL (discord.com).' };
    }
    if (!parsed.pathname.includes('/api/webhooks/')) {
      return { isValid: false, error: 'URL must follow Discord webhook format: /api/webhooks/<id>/<token>' };
    }
    return { isValid: true, error: null };
  } catch (err) {
    return { isValid: false, error: 'Invalid URL format.' };
  }
}

async function sendDiscordWebhook(webhookUrl, payload) {
  const validation = validateWebhookUrl(webhookUrl);
  if (!validation.isValid) {
    throw new Error(validation.error);
  }

  const url = new URL(webhookUrl);
  const postData = JSON.stringify(payload);

  return new Promise((resolve, reject) => {
    const req = https.request(
      url,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
          'User-Agent': 'DisTask-Web/1.0'
        }
      },
      (res) => {
        let body = '';
        res.on('data', (chunk) => { body += chunk; });
        res.on('end', () => {
          if (res.statusCode === 200 || res.statusCode === 204) {
            resolve({ statusCode: res.statusCode, body });
          } else {
            reject(new Error(`Discord returned HTTP ${res.statusCode}: ${body || 'Unknown error'}`));
          }
        });
      }
    );

    req.on('error', (err) => {
      reject(new Error(`Network error sending to Discord: ${err.message}`));
    });

    req.write(postData);
    req.end();
  });
}

// --- Per-User Push Execution ---
async function executePushForUser(userId, { isAutomated = false }) {
  const userStore = getUserStore(userId);
  const settings = userStore.settings;
  const targetTasks = userStore.tasks.filter(t => t.isCompleted && !t.isPushed);

  if (targetTasks.length === 0) {
    return {
      success: true,
      skipped: true,
      message: 'Push queue is empty. No checked tasks to push.',
      taskCount: 0
    };
  }

  const validation = validateWebhookUrl(settings.discordWebhookUrl);
  if (!validation.isValid) {
    throw new Error(validation.error || 'Discord Webhook URL is not configured.');
  }

  const messageContent = formatDiscordTasksMessage(targetTasks, settings);
  const payload = {
    content: messageContent,
    username: sanitizeBotUsername(settings.botUsername)
  };
  const avatar = sanitizeAvatarUrl(settings.avatarUrl);
  if (avatar) payload.avatar_url = avatar;

  await sendDiscordWebhook(settings.discordWebhookUrl, payload);

  const now = new Date().toISOString();
  const targetIds = new Set(targetTasks.map(t => t.id));

  userStore.tasks = userStore.tasks.map(task => {
    if (targetIds.has(task.id)) {
      return {
        ...task,
        isPushed: true,
        pushedAt: now
      };
    }
    return task;
  });

  if (settings.clearTasksAfterPush) {
    userStore.tasks = userStore.tasks.filter(t => !targetIds.has(t.id));
  }

  userStore.settings.lastPushedDate = now;
  await persistUserData();

  return {
    success: true,
    skipped: false,
    message: `Successfully pushed ${targetTasks.length} task${targetTasks.length === 1 ? '' : 's'} to Discord!`,
    taskCount: targetTasks.length
  };
}

function getNextPushInfo(settings) {
  if (!settings.isScheduleEnabled) {
    return {
      description: 'Scheduled auto-push is paused',
      timeRemaining: 'Disabled',
      nextDate: null
    };
  }

  const now = new Date();
  const tz = settings.timezone === 'auto' ? undefined : settings.timezone;

  let target = new Date();
  target.setHours(settings.scheduledHour, settings.scheduledMinute, 0, 0);

  if (target <= now) {
    target.setDate(target.getDate() + 1);
  }

  if (settings.scheduleDays === 'weekdaysOnly') {
    while (target.getDay() === 0 || target.getDay() === 6) {
      target.setDate(target.getDate() + 1);
    }
  }

  const diffMs = target - now;
  const diffMinutes = Math.max(1, Math.floor(diffMs / (1000 * 60)));
  const days = Math.floor(diffMinutes / (60 * 24));
  const hours = Math.floor((diffMinutes % (60 * 24)) / 60);
  const minutes = diffMinutes % 60;

  const parts = [];
  if (days > 0) parts.push(`${days}d`);
  if (hours > 0) parts.push(`${hours}h`);
  parts.push(`${minutes}m`);
  const timeRemaining = parts.join(' ');

  const isToday = target.toDateString() === now.toDateString();
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const isTomorrow = target.toDateString() === tomorrow.toDateString();

  let dayLabel = target.toLocaleDateString('en-US', { weekday: 'long', timeZone: tz });
  if (isToday) dayLabel = 'Today';
  else if (isTomorrow) dayLabel = 'Tomorrow';

  return {
    description: `${dayLabel} at ${formatTime(target, tz)} (in ${timeRemaining})`,
    timeRemaining,
    nextDate: target.toISOString()
  };
}

// --- Multi-User Cron Processor ---
async function runScheduledCronChecks() {
  await syncFromCloudKV();
  const now = new Date();
  const userList = Object.values(usersCache);
  const results = [];

  for (const user of userList) {
    const userStore = getUserStore(user.id);
    const settings = userStore.settings;

    if (!settings.isScheduleEnabled || !settings.discordWebhookUrl) continue;

    let currentHour = now.getHours();
    let currentMinute = now.getMinutes();

    if (settings.timezone && settings.timezone !== 'auto') {
      try {
        const parts = new Intl.DateTimeFormat('en-US', {
          timeZone: settings.timezone,
          hour: 'numeric',
          minute: 'numeric',
          hour12: false
        }).formatToParts(now);
        currentHour = parseInt(parts.find(p => p.type === 'hour')?.value || '0', 10);
        currentMinute = parseInt(parts.find(p => p.type === 'minute')?.value || '0', 10);
      } catch (_) {}
    }

    if (currentHour !== settings.scheduledHour || currentMinute !== settings.scheduledMinute) {
      continue;
    }

    if (settings.scheduleDays === 'weekdaysOnly') {
      const day = now.getDay();
      if (day === 0 || day === 6) continue;
    }

    if (settings.lastPushedDate) {
      const last = new Date(settings.lastPushedDate);
      if (last.toDateString() === now.toDateString()) continue;
    }

    try {
      const res = await executePushForUser(user.id, { isAutomated: true });
      results.push({ user: user.username, ...res });
    } catch (err) {
      console.error(`[DisTask Cron] Push error for user ${user.username}:`, err.message);
    }
  }

  return results;
}

if (!process.env.VERCEL) {
  cron.schedule('* * * * *', async () => {
    try {
      await runScheduledCronChecks();
    } catch (err) {
      console.error('[DisTask Cron Worker] Error:', err.message);
    }
  });
}

// ==================== API ROUTER (MOUNTED ON BOTH /api AND /distask/api) ====================
const apiRouter = express.Router();

// Registration
apiRouter.post('/auth/register', async (req, res) => {
  await syncFromCloudKV();

  const { username, password, inviteCode } = req.body;
  const cleanUsername = (username || '').trim().toLowerCase();

  if (!cleanUsername || cleanUsername.length < 3) {
    return res.status(400).json({ error: 'Username must be at least 3 characters.' });
  }

  if (!password || password.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters.' });
  }

  if (INVITE_CODE && INVITE_CODE.trim() !== '') {
    if ((inviteCode || '').trim() !== INVITE_CODE.trim()) {
      return res.status(403).json({ error: 'Invalid invite code. Ask your admin for access.' });
    }
  }

  if (usersCache[cleanUsername]) {
    return res.status(400).json({ error: 'Username already taken. Please choose another.' });
  }

  const userId = `user-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = hashPassword(password, salt);

  usersCache[cleanUsername] = {
    id: userId,
    username: cleanUsername,
    displayName: (username || '').trim(),
    salt,
    hash,
    createdAt: new Date().toISOString()
  };

  userDataCache[userId] = {
    tasks: createDefaultTasks(),
    settings: { ...DEFAULT_SETTINGS }
  };

  await persistUsers();
  await persistUserData();

  const token = createToken(userId);
  res.status(201).json({
    token,
    user: { id: userId, username: cleanUsername, displayName: (username || '').trim() }
  });
});

// Login
apiRouter.post('/auth/login', async (req, res) => {
  await syncFromCloudKV();

  const { username, password } = req.body;
  const cleanUsername = (username || '').trim().toLowerCase();

  const user = usersCache[cleanUsername];
  if (!user) {
    return res.status(401).json({ error: 'Invalid username or password.' });
  }

  const testHash = hashPassword(password || '', user.salt);
  if (!crypto.timingSafeEqual(Buffer.from(testHash), Buffer.from(user.hash))) {
    return res.status(401).json({ error: 'Invalid username or password.' });
  }

  const token = createToken(user.id);
  res.json({
    token,
    user: { id: user.id, username: user.username, displayName: user.displayName || user.username }
  });
});

// Profile & Config
apiRouter.get('/auth/me', requireAuth, (req, res) => {
  res.json({
    user: { id: req.user.id, username: req.user.username, displayName: req.user.displayName || req.user.username },
    requiresInviteCode: !!INVITE_CODE
  });
});

apiRouter.get('/auth/config', (req, res) => {
  res.json({
    requiresInviteCode: !!INVITE_CODE,
    hasRegisteredUsers: Object.keys(usersCache).length > 0
  });
});

// Tasks
apiRouter.get('/tasks', requireAuth, (req, res) => {
  const store = getUserStore(req.userId);
  const tasks = store.tasks;
  res.json({
    tasks,
    counts: {
      total: tasks.length,
      active: tasks.filter(t => !t.isCompleted).length,
      queue: tasks.filter(t => t.isCompleted && !t.isPushed).length,
      pushed: tasks.filter(t => t.isCompleted && t.isPushed).length
    }
  });
});

apiRouter.post('/tasks', requireAuth, async (req, res) => {
  const { title, notes = '', priority = 'medium', dayOfWeek = 'all' } = req.body;
  if (!title || !title.trim()) {
    return res.status(400).json({ error: 'Task title is required.' });
  }

  const store = getUserStore(req.userId);
  const newTask = {
    id: `task-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`,
    title: title.trim(),
    notes: (notes || '').trim(),
    priority: ['low', 'medium', 'high'].includes(priority) ? priority : 'medium',
    dayOfWeek: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun', 'all'].includes(dayOfWeek) ? dayOfWeek : 'all',
    isCompleted: false,
    completedAt: null,
    isPushed: false,
    pushedAt: null,
    createdAt: new Date().toISOString()
  };

  store.tasks.unshift(newTask);
  await persistUserData();
  res.status(201).json(newTask);
});

apiRouter.put('/tasks/:id', requireAuth, async (req, res) => {
  const { id } = req.params;
  const { title, notes, priority, dayOfWeek } = req.body;
  const store = getUserStore(req.userId);

  const index = store.tasks.findIndex(t => t.id === id);
  if (index === -1) {
    return res.status(404).json({ error: 'Task not found.' });
  }

  if (title !== undefined) store.tasks[index].title = title.trim();
  if (notes !== undefined) store.tasks[index].notes = (notes || '').trim();
  if (priority !== undefined) store.tasks[index].priority = priority;
  if (dayOfWeek !== undefined) store.tasks[index].dayOfWeek = dayOfWeek;

  await persistUserData();
  res.json(store.tasks[index]);
});

apiRouter.patch('/tasks/:id/toggle', requireAuth, async (req, res) => {
  const { id } = req.params;
  const store = getUserStore(req.userId);
  const index = store.tasks.findIndex(t => t.id === id);
  if (index === -1) {
    return res.status(404).json({ error: 'Task not found.' });
  }

  const isCompleted = !store.tasks[index].isCompleted;
  store.tasks[index].isCompleted = isCompleted;

  if (isCompleted) {
    store.tasks[index].completedAt = new Date().toISOString();
    store.tasks[index].isPushed = false;
    store.tasks[index].pushedAt = null;
  } else {
    store.tasks[index].completedAt = null;
    store.tasks[index].isPushed = false;
    store.tasks[index].pushedAt = null;
  }

  await persistUserData();
  res.json(store.tasks[index]);
});

apiRouter.patch('/tasks/:id/requeue', requireAuth, async (req, res) => {
  const { id } = req.params;
  const store = getUserStore(req.userId);
  const index = store.tasks.findIndex(t => t.id === id);
  if (index === -1) {
    return res.status(404).json({ error: 'Task not found.' });
  }

  store.tasks[index].isCompleted = true;
  store.tasks[index].isPushed = false;
  store.tasks[index].pushedAt = null;

  await persistUserData();
  res.json(store.tasks[index]);
});

apiRouter.delete('/tasks/:id', requireAuth, async (req, res) => {
  const { id } = req.params;
  const store = getUserStore(req.userId);
  store.tasks = store.tasks.filter(t => t.id !== id);
  await persistUserData();
  res.json({ success: true });
});

apiRouter.post('/tasks/clear-pushed', requireAuth, async (req, res) => {
  const store = getUserStore(req.userId);
  store.tasks = store.tasks.filter(t => !(t.isCompleted && t.isPushed));
  await persistUserData();
  res.json({ success: true });
});

// Settings & Schedule
apiRouter.get('/settings', requireAuth, (req, res) => {
  const store = getUserStore(req.userId);
  const scheduleInfo = getNextPushInfo(store.settings);
  res.json({
    settings: store.settings,
    scheduleInfo
  });
});

apiRouter.post('/settings', requireAuth, async (req, res) => {
  const store = getUserStore(req.userId);
  store.settings = { ...store.settings, ...req.body };
  await persistUserData();
  const scheduleInfo = getNextPushInfo(store.settings);
  res.json({
    settings: store.settings,
    scheduleInfo
  });
});

// Manual Push to Discord
apiRouter.post('/push', requireAuth, async (req, res) => {
  try {
    const result = await executePushForUser(req.userId, { isAutomated: false });
    res.json(result);
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Test Discord Webhook
apiRouter.post('/test-webhook', requireAuth, async (req, res) => {
  const store = getUserStore(req.userId);
  const webhookUrl = (req.body.webhookUrl || store.settings.discordWebhookUrl || '').trim();
  const validation = validateWebhookUrl(webhookUrl);
  if (!validation.isValid) {
    return res.status(400).json({ success: false, error: validation.error });
  }

  const sampleTasks = [
    { title: 'Discord Webhook connection verified', priority: 'high', notes: `Account: ${req.user.username}` },
    { title: 'Weekly task tracker active', priority: 'medium', notes: 'Checked tasks push automatically' }
  ];

  const testContent = formatDiscordTasksMessage(sampleTasks, {
    ...store.settings,
    discordWebhookUrl: webhookUrl
  });

  const payload = {
    content: testContent,
    username: sanitizeBotUsername(store.settings.botUsername)
  };
  const avatar = sanitizeAvatarUrl(store.settings.avatarUrl);
  if (avatar) payload.avatar_url = avatar;

  try {
    await sendDiscordWebhook(webhookUrl, payload);
    res.json({ success: true, message: 'Test message delivered to your Discord channel!' });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Multi-User Automated Cron Trigger
apiRouter.all('/cron', async (req, res) => {
  if (CRON_SECRET) {
    const authHeader = req.headers.authorization;
    const secretQuery = req.query.secret;
    if (authHeader !== `Bearer ${CRON_SECRET}` && secretQuery !== CRON_SECRET) {
      return res.status(401).json({ error: 'Unauthorized cron trigger.' });
    }
  }

  console.log(`[DisTask Cron] Running multi-user cron checks at ${new Date().toISOString()}...`);
  try {
    const results = await runScheduledCronChecks();
    res.json({ success: true, results, executedAt: new Date().toISOString() });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Health check
apiRouter.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
    isVercel: !!process.env.VERCEL,
    userCount: Object.keys(usersCache).length,
    hasKv: !!(KV_URL && KV_TOKEN)
  });
});

// Mount router on BOTH `/api` and `/distask/api`
app.use('/api', apiRouter);
app.use('/distask/api', apiRouter);

// Serve HTML for /distask subpath
app.get(['/distask', '/distask/'], (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`🚀 DisTask Multi-User 24/7 Cloud Server running on port ${PORT}`);
    console.log(`📂 Data directory: ${DATA_DIR}`);
  });
}

module.exports = app;
