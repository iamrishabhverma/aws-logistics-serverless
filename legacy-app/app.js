const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
// Read PORT from environment variable (Render assigns this), default to 3000 for local dev
const PORT = process.env.PORT || 3000;
const SHIPMENTS_FILE = path.join(__dirname, 'shipments.json');

// Base directory for templates and static files (repo root)
const BASE_DIR = path.join(__dirname, '..');
const VIEWS_DIR = path.join(BASE_DIR, 'views');
const PUBLIC_DIR = path.join(BASE_DIR, 'public');
  
// In-memory fallback for persistent storage (useful when file system is ephemeral like Render)
let shipmentsInMemory = [];

app.set('view engine', 'ejs');
app.set('views', VIEWS_DIR);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(PUBLIC_DIR));

const readShipments = () => {
  try {
    // Try to read from file first
    const data = fs.readFileSync(SHIPMENTS_FILE, 'utf8');
    shipmentsInMemory = JSON.parse(data);
    return shipmentsInMemory;
  } catch (err) {
    // File doesn't exist or can't be read; use in-memory data
    // This is important for Render.com where the filesystem is ephemeral
    return shipmentsInMemory;
  }
};

const writeShipments = (shipments) => {
  shipmentsInMemory = shipments;
  try {
    // Try to write to file (may fail on Render's ephemeral filesystem, but that's OK)
    fs.writeFileSync(SHIPMENTS_FILE, JSON.stringify(shipments, null, 2));
    console.log(`✓ Wrote ${shipments.length} shipment(s) to ${SHIPMENTS_FILE}`);
  } catch (err) {
    console.warn('Could not write to file (ephemeral filesystem?), using in-memory storage');
    console.warn('Error:', err.message);
    // Data persists in memory for this session
  }
};

// Optional: commit the updated shipments.json back to GitHub.
// Controlled by env var `GIT_PUSH=true`. Requires `GITHUB_TOKEN` and `GITHUB_REPO` (owner/repo).
const { spawnSync } = require('child_process');

const gitCommitAndPush = () => {
  if (process.env.GIT_PUSH !== 'true') return;
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPO; // e.g. 'iamrishabhverma/aws-logistics-modernization'
  if (!token || !repo) {
    console.warn('GIT_PUSH enabled but GITHUB_TOKEN or GITHUB_REPO not set — skipping push');
    return;
  }

  try {
    const remote = `https://${token}@github.com/${repo}.git`;
    const name = process.env.GIT_COMMIT_NAME || 'render-automated-commit';
    const email = process.env.GIT_COMMIT_EMAIL || 'render@localhost';

    spawnSync('git', ['config', 'user.email', email]);
    spawnSync('git', ['config', 'user.name', name]);

    // Stage the shipments file (use path relative to repo root)
    // Ensure we use a path that Git recognizes; app runs from project root on Render
    const addResult = spawnSync('git', ['add', SHIPMENTS_FILE]);
    if (addResult.status !== 0) {
      console.warn('git add failed:', addResult.stderr && addResult.stderr.toString());
    }

    const commitResult = spawnSync('git', ['commit', '-m', 'Persist shipments.json from app']);
    if (commitResult.status !== 0) {
      const stderr = commitResult.stderr && commitResult.stderr.toString();
      // If there's nothing to commit, skip push
      if (stderr && stderr.includes('nothing to commit')) {
        return;
      }
      console.warn('git commit failed:', stderr);
    }

    // Push using token-authenticated remote URL
    const pushResult = spawnSync('git', ['push', remote, 'HEAD:main']);
    if (pushResult.status !== 0) {
      console.warn('git push failed:', pushResult.stderr && pushResult.stderr.toString());
    }
  } catch (err) {
    console.warn('gitCommitAndPush failed:', err && err.message);
  }
};


app.get('/', (req, res) => {
  const shipments = readShipments();
  res.render('index', { shipments });
});

app.get('/new', (req, res) => res.render('new'));

app.post('/shipments', (req, res) => {
  const { trackingId, status, origin, destination } = req.body;
  if (!trackingId || !status) return res.status(400).send('Required fields missing');

  const shipments = readShipments();
  const newShipment = {
    id: shipments.length + 1,
    trackingId,
    status,
    origin: origin || 'Unknown',
    destination: destination || 'Unknown',
    createdAt: new Date().toISOString()
  };
  shipments.push(newShipment);
  writeShipments(shipments);
  gitCommitAndPush(); // Trigger git push if GIT_PUSH=true
  res.redirect('/');
});

app.get('/api/shipments', (req, res) => res.json(readShipments()));

app.listen(PORT, () => console.log(`Legacy app running at http://localhost:${PORT}`));