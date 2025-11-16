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
  } catch (err) {
    console.warn('Could not write to file (ephemeral filesystem?), using in-memory storage');
    // Data persists in memory for this session
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
  res.redirect('/');
});

app.get('/api/shipments', (req, res) => res.json(readShipments()));

app.listen(PORT, () => console.log(`Legacy app running at http://localhost:${PORT}`));