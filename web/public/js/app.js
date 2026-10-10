// DisTask Web - Multi-Tenant Client Application with Auth & Isolated Webhooks
(function () {
  'use strict';

  // --- App State ---
  const state = {
    token: localStorage.getItem('distask_token') || null,
    user: null,
    authMode: 'login', // 'login' | 'register'
    requiresInviteCode: false,
    tasks: [],
    counts: { total: 0, active: 0, queue: 0, pushed: 0 },
    settings: {},
    scheduleInfo: { description: 'Loading...', timeRemaining: '' },
    selectedFilter: 'active', // 'active' | 'queue' | 'pushed' | 'all'
    selectedDay: 'all',       // 'all' | 'today' | 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat' | 'sun'
    searchQuery: '',
    isPushing: false
  };

  // --- DOM Elements ---
  const elements = {
    // Header & User Profile
    scheduleText: document.getElementById('schedule-text'),
    pushNowBtn: document.getElementById('push-now-btn'),
    pushBadgeCount: document.getElementById('push-badge-count'),
    settingsOpenBtn: document.getElementById('settings-open-btn'),
    userProfilePill: document.getElementById('user-profile-pill'),
    userDisplayName: document.getElementById('user-display-name'),
    logoutBtn: document.getElementById('logout-btn'),
    loginOpenBtn: document.getElementById('login-open-btn'),

    // Day Chips
    dayChips: document.querySelectorAll('.day-chip'),

    // Add Task Form
    addTaskForm: document.getElementById('add-task-form'),
    taskTitleInput: document.getElementById('task-title-input'),
    taskDaySelect: document.getElementById('task-day-select'),
    taskNotesInput: document.getElementById('task-notes-input'),

    // Filters & Search
    filterTabs: document.querySelectorAll('.filter-tab'),
    countActive: document.getElementById('count-active'),
    countQueue: document.getElementById('count-queue'),
    countPushed: document.getElementById('count-pushed'),
    countTotal: document.getElementById('count-total'),
    searchInput: document.getElementById('search-input'),

    // Task List & Empty State
    tasksContainer: document.getElementById('tasks-container'),
    emptyState: document.getElementById('empty-state'),
    emptyTitle: document.getElementById('empty-title'),
    emptyDescription: document.getElementById('empty-description'),

    // Discord Live Preview
    previewAuthor: document.getElementById('preview-author'),
    previewAvatar: document.getElementById('preview-avatar'),
    previewTaskCount: document.getElementById('preview-task-count'),
    discordPreviewContent: document.getElementById('discord-preview-content'),

    // Footer actions
    clearPushedBtn: document.getElementById('clear-pushed-btn'),

    // Settings Modal
    settingsModal: document.getElementById('settings-modal'),
    settingsCloseBtn: document.getElementById('settings-close-btn'),
    settingsCancelBtn: document.getElementById('settings-cancel-btn'),
    settingsSaveBtn: document.getElementById('settings-save-btn'),
    webhookUrlInput: document.getElementById('webhook-url-input'),
    botUsernameInput: document.getElementById('bot-username-input'),
    botAvatarInput: document.getElementById('bot-avatar-input'),
    testWebhookBtn: document.getElementById('test-webhook-btn'),
    testWebhookStatus: document.getElementById('test-webhook-status'),
    scheduleEnabledToggle: document.getElementById('schedule-enabled-toggle'),
    scheduleHourSelect: document.getElementById('schedule-hour-select'),
    scheduleMinuteSelect: document.getElementById('schedule-minute-select'),
    scheduleDaysSelect: document.getElementById('schedule-days-select'),
    timezoneInput: document.getElementById('timezone-input'),
    detectedTz: document.getElementById('detected-tz'),
    messageTemplateInput: document.getElementById('message-template-input'),
    includeNotesToggle: document.getElementById('include-notes-toggle'),
    clearAfterPushToggle: document.getElementById('clear-after-push-toggle'),

    // Auth Modal
    authModal: document.getElementById('auth-modal'),
    authCloseBtn: document.getElementById('auth-close-btn'),
    authTitle: document.getElementById('auth-title'),
    tabLoginBtn: document.getElementById('tab-login-btn'),
    tabRegisterBtn: document.getElementById('tab-register-btn'),
    authForm: document.getElementById('auth-form'),
    authUsernameInput: document.getElementById('auth-username-input'),
    authPasswordInput: document.getElementById('auth-password-input'),
    inviteCodeGroup: document.getElementById('invite-code-group'),
    authInviteInput: document.getElementById('auth-invite-input'),
    authErrorMsg: document.getElementById('auth-error-msg'),
    authSubmitBtn: document.getElementById('auth-submit-btn'),

    // Toast Container
    toastContainer: document.getElementById('toast-container')
  };

  // --- Toast Notifications ---
  function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;

    let icon = 'ℹ️';
    if (type === 'success') icon = '✅';
    if (type === 'error') icon = '⚠️';

    toast.innerHTML = `<span>${icon}</span><span>${escapeHtml(message)}</span>`;
    elements.toastContainer.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(10px)';
      toast.style.transition = 'all 0.3s ease';
      setTimeout(() => toast.remove(), 300);
    }, 3800);
  }

  function escapeHtml(str) {
    if (!str) return '';
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function apiUrl(endpoint) {
    const clean = endpoint.replace(/^\/(distask\/)?api\/?/, '');
    const base = window.location.pathname.includes('/distask') ? '/distask/api' : '/api';
    return `${base}/${clean}`;
  }

  // --- Authenticated Fetch Helper ---
  async function authFetch(url, options = {}) {
    if (!options.headers) options.headers = {};
    if (state.token) {
      options.headers['Authorization'] = `Bearer ${state.token}`;
    }

    const targetUrl = url.startsWith('http') ? url : apiUrl(url);
    const res = await fetch(targetUrl, options);
    if (res.status === 401) {
      logout();
      showToast('Session expired or unauthorized. Please sign in.', 'error');
      openAuthModal('login');
      throw new Error('Unauthorized');
    }
    return res;
  }

  // --- Auth Management ---
  async function checkAuth() {
    try {
      const configRes = await fetch(apiUrl('/api/auth/config'));
      const configData = await configRes.json();
      state.requiresInviteCode = !!configData.requiresInviteCode;

      if (!state.token) {
        updateAuthUI(null);
        openAuthModal(configData.hasRegisteredUsers ? 'login' : 'register');
        return false;
      }

      const res = await authFetch('/api/auth/me');
      if (res.ok) {
        const data = await res.json();
        state.user = data.user;
        updateAuthUI(state.user);
        closeAuthModal();
        return true;
      }
    } catch (_) {
      updateAuthUI(null);
      openAuthModal('login');
    }
    return false;
  }

  function updateAuthUI(user) {
    if (user) {
      elements.userDisplayName.textContent = user.displayName || user.username;
      elements.userProfilePill.classList.remove('hidden');
      elements.loginOpenBtn.classList.add('hidden');
    } else {
      elements.userProfilePill.classList.add('hidden');
      elements.loginOpenBtn.classList.remove('hidden');
      state.tasks = [];
      state.counts = { total: 0, active: 0, queue: 0, pushed: 0 };
      render();
    }
  }

  function openAuthModal(mode = 'login') {
    state.authMode = mode;
    elements.authErrorMsg.classList.add('hidden');
    elements.authErrorMsg.textContent = '';
    elements.authUsernameInput.value = '';
    elements.authPasswordInput.value = '';
    if (elements.authInviteInput) elements.authInviteInput.value = '';

    if (mode === 'login') {
      elements.authTitle.textContent = '🔐 Sign In to DisTask';
      elements.tabLoginBtn.classList.add('active');
      elements.tabRegisterBtn.classList.remove('active');
      elements.authSubmitBtn.textContent = 'Sign In';
      elements.inviteCodeGroup.classList.add('hidden');
    } else {
      elements.authTitle.textContent = '✨ Create DisTask Account';
      elements.tabRegisterBtn.classList.add('active');
      elements.tabLoginBtn.classList.remove('active');
      elements.authSubmitBtn.textContent = 'Create Account';
      elements.inviteCodeGroup.classList.remove('hidden');
    }

    elements.authModal.classList.remove('hidden');
    elements.authUsernameInput.focus();
  }

  function closeAuthModal() {
    elements.authModal.classList.add('hidden');
  }

  async function handleAuthSubmit(e) {
    e.preventDefault();
    const username = elements.authUsernameInput.value.trim();
    const password = elements.authPasswordInput.value;
    const inviteCode = elements.authInviteInput ? elements.authInviteInput.value.trim() : '';

    if (!username || !password) return;

    elements.authSubmitBtn.disabled = true;
    elements.authSubmitBtn.textContent = state.authMode === 'login' ? 'Signing in...' : 'Creating account...';
    elements.authErrorMsg.classList.add('hidden');

    const endpoint = state.authMode === 'login' ? apiUrl('/api/auth/login') : apiUrl('/api/auth/register');
    const body = { username, password };
    if (state.authMode === 'register' && inviteCode) {
      body.inviteCode = inviteCode;
    }

    try {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || 'Authentication failed');
      }

      state.token = data.token;
      state.user = data.user;
      localStorage.setItem('distask_token', data.token);

      updateAuthUI(state.user);
      closeAuthModal();
      showToast(state.authMode === 'login' ? `Welcome back, ${state.user.username}!` : `Account created! Welcome, ${state.user.username}!`, 'success');

      await fetchSettings();
      await fetchTasks();
    } catch (err) {
      elements.authErrorMsg.textContent = err.message;
      elements.authErrorMsg.classList.remove('hidden');
    } finally {
      elements.authSubmitBtn.disabled = false;
      elements.authSubmitBtn.textContent = state.authMode === 'login' ? 'Sign In' : 'Create Account';
    }
  }

  function logout() {
    state.token = null;
    state.user = null;
    localStorage.removeItem('distask_token');
    updateAuthUI(null);
    showToast('Signed out successfully.', 'info');
    openAuthModal('login');
  }

  // --- API Calls ---
  async function fetchTasks() {
    if (!state.token) return;
    try {
      const res = await authFetch('/api/tasks');
      const data = await res.json();
      state.tasks = data.tasks;
      state.counts = data.counts;
      render();
    } catch (err) {
      console.error('Failed to load tasks:', err);
    }
  }

  async function fetchSettings() {
    if (!state.token) return;
    try {
      const res = await authFetch('/api/settings');
      const data = await res.json();
      state.settings = data.settings;
      state.scheduleInfo = data.scheduleInfo;
      updateScheduleDisplay();
      updateDiscordPreview();
    } catch (err) {
      console.error('Failed to load settings:', err);
    }
  }

  async function createTask(taskData) {
    if (!state.token) {
      openAuthModal('login');
      return;
    }
    try {
      const res = await authFetch('/api/tasks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(taskData)
      });
      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.error || 'Failed to add task');
      }
      showToast('Task added to your weekly list!', 'success');
      await fetchTasks();
    } catch (err) {
      showToast(err.message, 'error');
    }
  }

  async function toggleTask(id) {
    const task = state.tasks.find(t => t.id === id);
    if (task) {
      task.isCompleted = !task.isCompleted;
      if (task.isCompleted) task.isPushed = false;
      render();
    }

    try {
      const res = await authFetch(`/api/tasks/${id}/toggle`, { method: 'PATCH' });
      if (!res.ok) throw new Error('Failed to update task');
      await fetchTasks();
      updateDiscordPreview();
    } catch (err) {
      showToast(err.message, 'error');
      await fetchTasks();
    }
  }

  async function requeueTask(id) {
    try {
      const res = await authFetch(`/api/tasks/${id}/requeue`, { method: 'PATCH' });
      if (!res.ok) throw new Error('Failed to requeue task');
      showToast('Task returned to Push Queue', 'info');
      await fetchTasks();
    } catch (err) {
      showToast(err.message, 'error');
    }
  }

  async function deleteTask(id) {
    try {
      const res = await authFetch(`/api/tasks/${id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error('Failed to delete task');
      showToast('Task deleted', 'info');
      await fetchTasks();
    } catch (err) {
      showToast(err.message, 'error');
    }
  }

  async function clearPushedTasks() {
    if (!confirm('Clear all tasks from your Pushed archive?')) return;
    try {
      const res = await authFetch('/api/tasks/clear-pushed', { method: 'POST' });
      if (!res.ok) throw new Error('Failed to clear pushed tasks');
      showToast('Pushed archive cleared', 'success');
      await fetchTasks();
    } catch (err) {
      showToast(err.message, 'error');
    }
  }

  async function triggerManualPush() {
    if (state.isPushing) return;
    const queueTasks = state.tasks.filter(t => t.isCompleted && !t.isPushed);
    if (queueTasks.length === 0) {
      showToast('Push queue is empty. Check (✓) tasks to queue them!', 'info');
      return;
    }

    state.isPushing = true;
    elements.pushNowBtn.disabled = true;
    elements.pushNowBtn.innerHTML = `<span>Pushing...</span>`;

    try {
      const res = await authFetch('/api/push', { method: 'POST' });
      const result = await res.json();
      if (!res.ok || !result.success) {
        throw new Error(result.error || 'Push failed');
      }

      if (result.skipped) {
        showToast(result.message, 'info');
      } else {
        showToast(result.message, 'success');
      }
      await fetchTasks();
      await fetchSettings();
    } catch (err) {
      showToast(`Push failed: ${err.message}`, 'error');
    } finally {
      state.isPushing = false;
      render();
    }
  }

  async function testWebhook() {
    const webhookUrl = elements.webhookUrlInput.value.trim();
    if (!webhookUrl) {
      elements.testWebhookStatus.textContent = 'Enter Webhook URL first';
      elements.testWebhookStatus.className = 'status-msg error';
      return;
    }

    elements.testWebhookBtn.disabled = true;
    elements.testWebhookStatus.textContent = 'Testing connection...';
    elements.testWebhookStatus.className = 'status-msg';

    try {
      const res = await authFetch('/api/test-webhook', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ webhookUrl })
      });
      const data = await res.json();
      if (res.ok && data.success) {
        elements.testWebhookStatus.textContent = 'Connected! Check your Discord channel.';
        elements.testWebhookStatus.className = 'status-msg success';
        showToast('Webhook verified successfully!', 'success');
      } else {
        throw new Error(data.error || 'Connection test failed');
      }
    } catch (err) {
      elements.testWebhookStatus.textContent = err.message;
      elements.testWebhookStatus.className = 'status-msg error';
    } finally {
      elements.testWebhookBtn.disabled = false;
    }
  }

  async function saveSettings() {
    const payload = {
      discordWebhookUrl: elements.webhookUrlInput.value.trim(),
      botUsername: elements.botUsernameInput.value.trim() || 'DisTask Bot',
      avatarUrl: elements.botAvatarInput.value.trim(),
      isScheduleEnabled: elements.scheduleEnabledToggle.checked,
      scheduledHour: parseInt(elements.scheduleHourSelect.value, 10),
      scheduledMinute: parseInt(elements.scheduleMinuteSelect.value, 10),
      scheduleDays: elements.scheduleDaysSelect.value,
      timezone: elements.timezoneInput.value.trim() || 'auto',
      messageTemplate: elements.messageTemplateInput.value,
      includeNotesInDiscord: elements.includeNotesToggle.checked,
      clearTasksAfterPush: elements.clearAfterPushToggle.checked
    };

    try {
      const res = await authFetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (!res.ok) throw new Error('Failed to save settings');
      const data = await res.json();
      state.settings = data.settings;
      state.scheduleInfo = data.scheduleInfo;

      showToast('Settings saved successfully for your account!', 'success');
      closeSettingsModal();
      updateScheduleDisplay();
      updateDiscordPreview();
    } catch (err) {
      showToast(err.message, 'error');
    }
  }

  // --- Filtering & Sorting ---
  function getFilteredTasks() {
    const dayMap = { 0: 'sun', 1: 'mon', 2: 'tue', 3: 'wed', 4: 'thu', 5: 'fri', 6: 'sat' };
    const todayDayCode = dayMap[new Date().getDay()];

    return state.tasks.filter(task => {
      if (state.selectedFilter === 'active' && task.isCompleted) return false;
      if (state.selectedFilter === 'queue' && (!task.isCompleted || task.isPushed)) return false;
      if (state.selectedFilter === 'pushed' && (!task.isCompleted || !task.isPushed)) return false;

      if (state.selectedDay !== 'all') {
        if (state.selectedDay === 'today') {
          if (task.dayOfWeek !== 'all' && task.dayOfWeek !== todayDayCode) return false;
        } else {
          if (task.dayOfWeek !== 'all' && task.dayOfWeek !== state.selectedDay) return false;
        }
      }

      if (state.searchQuery) {
        const q = state.searchQuery.toLowerCase();
        const titleMatch = task.title.toLowerCase().includes(q);
        const notesMatch = (task.notes || '').toLowerCase().includes(q);
        if (!titleMatch && !notesMatch) return false;
      }

      return true;
    }).sort((a, b) => {
      if (a.isCompleted !== b.isCompleted) {
        return !a.isCompleted ? -1 : 1;
      }
      if (a.isPushed !== b.isPushed) {
        return !a.isPushed ? -1 : 1;
      }
      const pOrder = { high: 3, medium: 2, low: 1 };
      if (a.priority !== b.priority) {
        return (pOrder[b.priority] || 0) - (pOrder[a.priority] || 0);
      }
      return new Date(b.createdAt) - new Date(a.createdAt);
    });
  }

  // --- Rendering UI ---
  function render() {
    const activeTasks = state.tasks.filter(t => !t.isCompleted);
    const queueTasks = state.tasks.filter(t => t.isCompleted && !t.isPushed);
    const pushedTasks = state.tasks.filter(t => t.isCompleted && t.isPushed);

    elements.countActive.textContent = activeTasks.length;
    elements.countQueue.textContent = queueTasks.length;
    elements.countPushed.textContent = pushedTasks.length;
    elements.countTotal.textContent = state.tasks.length;

    elements.pushBadgeCount.textContent = queueTasks.length;
    if (queueTasks.length > 0) {
      elements.pushNowBtn.disabled = false;
      elements.pushNowBtn.innerHTML = `
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
          <line x1="22" y1="2" x2="11" y2="13"></line>
          <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
        </svg>
        <span>Push Queue</span>
        <span class="badge-count">${queueTasks.length}</span>
      `;
    } else {
      elements.pushNowBtn.disabled = true;
      elements.pushNowBtn.innerHTML = `
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
          <line x1="22" y1="2" x2="11" y2="13"></line>
          <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
        </svg>
        <span>Queue Empty</span>
        <span class="badge-count">0</span>
      `;
    }

    const filtered = getFilteredTasks();
    elements.tasksContainer.innerHTML = '';

    if (filtered.length === 0) {
      elements.emptyState.classList.remove('hidden');
      updateEmptyStateMessage();
    } else {
      elements.emptyState.classList.add('hidden');
      filtered.forEach(task => {
        elements.tasksContainer.appendChild(createTaskElement(task));
      });
    }

    updateDiscordPreview();
  }

  function createTaskElement(task) {
    const el = document.createElement('div');
    el.className = `task-item ${task.isCompleted ? 'completed' : ''}`;
    if (task.isCompleted && !task.isPushed) el.classList.add('queue-ready');
    if (task.isCompleted && task.isPushed) el.classList.add('pushed-archive');

    const dayName = task.dayOfWeek ? task.dayOfWeek.toUpperCase() : 'ALL';

    let statusHtml = '';
    if (task.isCompleted && !task.isPushed) {
      statusHtml = `<span class="status-indicator queue">🚀 In Queue (Pushes at scheduled time)</span>`;
    } else if (task.isCompleted && task.isPushed) {
      const pushTime = task.pushedAt ? new Date(task.pushedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '';
      statusHtml = `<span class="status-indicator pushed">✓ Pushed to Discord ${pushTime}</span>`;
    }

    el.innerHTML = `
      <label class="checkbox-wrap" title="${task.isCompleted ? 'Mark active' : 'Check off task (moves to push queue)'}">
        <input type="checkbox" ${task.isCompleted ? 'checked' : ''} data-id="${task.id}">
        <div class="custom-checkbox">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>
        </div>
      </label>

      <div class="task-content">
        <div class="task-header-row">
          <span class="task-title">${escapeHtml(task.title)}</span>
          <span class="day-badge" title="Assigned day">${dayName}</span>
          <span class="priority-badge ${task.priority}">${task.priority}</span>
        </div>
        ${task.notes ? `<div class="task-notes">${escapeHtml(task.notes)}</div>` : ''}
        ${statusHtml ? `<div class="task-status-row">${statusHtml}</div>` : ''}
      </div>

      <div class="task-actions">
        ${task.isCompleted && task.isPushed ? `
          <button class="btn-task-action requeue-btn" data-id="${task.id}" title="Re-queue task to push again">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="1 4 1 10 7 10"></polyline>
              <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"></path>
            </svg>
          </button>
        ` : ''}
        <button class="btn-task-action delete delete-btn" data-id="${task.id}" title="Delete task">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="3 6 5 6 21 6"></polyline>
            <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
          </svg>
        </button>
      </div>
    `;

    const checkbox = el.querySelector('input[type="checkbox"]');
    checkbox.addEventListener('change', () => toggleTask(task.id));

    const deleteBtn = el.querySelector('.delete-btn');
    deleteBtn.addEventListener('click', () => deleteTask(task.id));

    const requeueBtn = el.querySelector('.requeue-btn');
    if (requeueBtn) {
      requeueBtn.addEventListener('click', () => requeueTask(task.id));
    }

    return el;
  }

  function updateEmptyStateMessage() {
    if (state.selectedFilter === 'queue') {
      elements.emptyTitle.textContent = 'Push queue is empty';
      elements.emptyDescription.textContent = 'Check (✓) active tasks when finished. Checked tasks automatically wait here and push to Discord at your scheduled time.';
    } else if (state.selectedFilter === 'pushed') {
      elements.emptyTitle.textContent = 'No tasks pushed yet';
      elements.emptyDescription.textContent = 'Tasks will show up here after being posted to Discord.';
    } else if (state.selectedFilter === 'active') {
      elements.emptyTitle.textContent = 'No active tasks';
      elements.emptyDescription.textContent = 'Add your tasks for this week using the input above!';
    } else {
      elements.emptyTitle.textContent = 'No tasks found';
      elements.emptyDescription.textContent = 'Try adjusting your search or weekly day filter.';
    }
  }

  function updateScheduleDisplay() {
    if (state.scheduleInfo && state.scheduleInfo.description) {
      elements.scheduleText.textContent = state.scheduleInfo.description;
    }
  }

  function updateDiscordPreview() {
    const queueTasks = state.tasks.filter(t => t.isCompleted && !t.isPushed);
    elements.previewTaskCount.textContent = `${queueTasks.length} task${queueTasks.length === 1 ? '' : 's'} in queue`;

    const botName = state.settings.botUsername || 'DisTask Bot';
    elements.previewAuthor.textContent = botName;

    const d = new Date();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const dateStr = `${months[d.getMonth()]} ${d.getDate()}`;

    if (queueTasks.length === 0) {
      elements.discordPreviewContent.textContent = "```\n" + dateStr + "\n[Queue is empty - Auto-push will skip until tasks are checked]\n```";
    } else {
      const taskLines = queueTasks.map(t => {
        let line = `- ${t.title}`;
        if (state.settings.includeNotesInDiscord && t.notes) {
          line += ` (${t.notes})`;
        }
        return line;
      }).join('\n');

      elements.discordPreviewContent.textContent = "```\n" + dateStr + "\n" + taskLines + "\n```";
    }
  }

  // --- Modal Helpers ---
  function openSettingsModal() {
    if (!state.token) {
      openAuthModal('login');
      return;
    }
    elements.webhookUrlInput.value = state.settings.discordWebhookUrl || '';
    elements.botUsernameInput.value = state.settings.botUsername || 'DisTask Bot';
    elements.botAvatarInput.value = state.settings.avatarUrl || '';
    elements.scheduleEnabledToggle.checked = state.settings.isScheduleEnabled !== false;
    elements.scheduleHourSelect.value = state.settings.scheduledHour ?? 17;
    elements.scheduleMinuteSelect.value = state.settings.scheduledMinute ?? 0;
    elements.scheduleDaysSelect.value = state.settings.scheduleDays || 'weekdaysOnly';
    elements.timezoneInput.value = state.settings.timezone || 'auto';
    elements.messageTemplateInput.value = state.settings.messageTemplate || "```\n{date}\n{tasks}\n```";
    elements.includeNotesToggle.checked = !!state.settings.includeNotesInDiscord;
    elements.clearAfterPushToggle.checked = !!state.settings.clearTasksAfterPush;

    elements.testWebhookStatus.textContent = '';
    elements.settingsModal.classList.remove('hidden');
  }

  function closeSettingsModal() {
    elements.settingsModal.classList.add('hidden');
  }

  function initTimeOptions() {
    elements.scheduleHourSelect.innerHTML = '';
    for (let h = 0; h < 24; h++) {
      const opt = document.createElement('option');
      opt.value = h;
      const displayH = h % 12 === 0 ? 12 : h % 12;
      const ampm = h < 12 ? 'AM' : 'PM';
      opt.textContent = `${String(h).padStart(2, '0')}:00 (${displayH} ${ampm})`;
      elements.scheduleHourSelect.appendChild(opt);
    }

    elements.scheduleMinuteSelect.innerHTML = '';
    for (let m = 0; m < 60; m += 5) {
      const opt = document.createElement('option');
      opt.value = m;
      opt.textContent = `:${String(m).padStart(2, '0')}`;
      elements.scheduleMinuteSelect.appendChild(opt);
    }

    try {
      const detected = Intl.DateTimeFormat().resolvedOptions().timeZone;
      elements.detectedTz.textContent = detected;
    } catch (_) {
      elements.detectedTz.textContent = 'UTC';
    }
  }

  // --- Event Listeners Setup ---
  function setupEventListeners() {
    elements.addTaskForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const title = elements.taskTitleInput.value.trim();
      if (!title) return;

      const priorityChecked = document.querySelector('input[name="priority"]:checked');
      const priority = priorityChecked ? priorityChecked.value : 'medium';
      const dayOfWeek = elements.taskDaySelect.value;
      const notes = elements.taskNotesInput.value.trim();

      createTask({ title, notes, priority, dayOfWeek });

      elements.taskTitleInput.value = '';
      elements.taskNotesInput.value = '';
      elements.taskTitleInput.focus();
    });

    elements.dayChips.forEach(chip => {
      chip.addEventListener('click', () => {
        elements.dayChips.forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        state.selectedDay = chip.dataset.day;
        render();
      });
    });

    elements.filterTabs.forEach(tab => {
      tab.addEventListener('click', () => {
        elements.filterTabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        state.selectedFilter = tab.dataset.filter;
        render();
      });
    });

    elements.searchInput.addEventListener('input', (e) => {
      state.searchQuery = e.target.value.trim();
      render();
    });

    elements.pushNowBtn.addEventListener('click', triggerManualPush);
    elements.clearPushedBtn.addEventListener('click', clearPushedTasks);

    // Settings Modal
    elements.settingsOpenBtn.addEventListener('click', openSettingsModal);
    elements.settingsCloseBtn.addEventListener('click', closeSettingsModal);
    elements.settingsCancelBtn.addEventListener('click', closeSettingsModal);
    elements.settingsSaveBtn.addEventListener('click', saveSettings);
    elements.testWebhookBtn.addEventListener('click', testWebhook);
    elements.settingsModal.addEventListener('click', (e) => {
      if (e.target === elements.settingsModal) closeSettingsModal();
    });

    // Auth Modal
    elements.loginOpenBtn.addEventListener('click', () => openAuthModal('login'));
    elements.logoutBtn.addEventListener('click', logout);
    elements.authCloseBtn.addEventListener('click', closeAuthModal);
    elements.tabLoginBtn.addEventListener('click', () => openAuthModal('login'));
    elements.tabRegisterBtn.addEventListener('click', () => openAuthModal('register'));
    elements.authForm.addEventListener('submit', handleAuthSubmit);
    elements.authModal.addEventListener('click', (e) => {
      if (e.target === elements.authModal && state.token) closeAuthModal();
    });

    // Countdown polling
    setInterval(async () => {
      if (!state.token) return;
      try {
        const res = await authFetch('/api/settings');
        const data = await res.json();
        state.scheduleInfo = data.scheduleInfo;
        updateScheduleDisplay();
      } catch (_) {}
    }, 15000);
  }

  // --- App Initialization ---
  async function init() {
    initTimeOptions();
    setupEventListeners();
    const hasAuth = await checkAuth();
    if (hasAuth) {
      await fetchSettings();
      await fetchTasks();
    }

    if ('serviceWorker' in navigator) {
      if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        // Automatically unregister any active service worker and delete cache on localhost
        navigator.serviceWorker.getRegistrations().then((registrations) => {
          for (const reg of registrations) {
            reg.unregister();
          }
        });
        if ('caches' in window) {
          caches.keys().then((keys) => keys.forEach((k) => caches.delete(k)));
        }
      } else {
        const swPath = window.location.pathname.startsWith('/distask') ? '/distask/sw.js' : '/sw.js';
        navigator.serviceWorker.register(swPath).catch(() => {});
      }
    }
  }

  init();
})();
