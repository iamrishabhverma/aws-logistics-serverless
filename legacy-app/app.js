const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3000;
const SHIPMENTS_FILE = path.join(__dirname, 'shipments.json');

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, '../views'));  // Adjust path if needed
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static('../public'));  // Adjust path

const readShipments = () => {
  try {
    return JSON.parse(fs.readFileSync(SHIPMENTS_FILE, 'utf8'));
  } catch (err) {
    return [];
  }
};

const writeShipments = (shipments) => {
  fs.writeFileSync(SHIPMENTS_FILE, JSON.stringify(shipments, null, 2));
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