
import express from 'express';
import bodyParser from 'body-parser';
import { Pool } from 'pg';
import { Server } from 'socket.io';
import http from 'http';

const app = express();
app.use(bodyParser.json());

// Database connection
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'library',
  password: 'Kamau',
  port: 5432,
});

// WebSocket setup
const server = http.createServer(app);
server.keepAliveTimeout = 60000;
server.headersTimeout = 65000;

const io = new Server(server, { cors: { origin: "*" } });

io.on('connection', (socket) => {
  console.log(`Socket connected: ${socket.id}`);
  socket.on('disconnect', () => {
    console.log(`Socket disconnected: ${socket.id}`);
  });
});

// Tier mapping
const tiers = {
  20: 1,
  100: 7,
  500: 30,
  1500: 180,
  2500: 365
};

// Health check route
app.get('/ping', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: true, timestamp: new Date().toISOString() });
  } catch (err) {
    console.error('Ping DB error:', err);
    res.status(500).json({ status: 'error', db: false });
  }
});

// Get active members
app.get('/active_members', async (req, res) => {
  try {
    const now = new Date();
    const result = await pool.query(
      'SELECT full_name, phone, start_time, end_time FROM memberships WHERE end_time > $1',
      [now]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching active members:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// M-Pesa webhook
app.post('/mpesa/confirm', async (req, res) => {
  try {
    const data = req.body;
    const fullName = [data.FirstName, data.MiddleName, data.LastName].filter(Boolean).join(' ');
    const phone = data.MSISDN;
    const amount = parseFloat(data.TransAmount);

    let entryTime;
    if (data.TransTime && /^\d{14}$/.test(data.TransTime)) {
      const year = data.TransTime.substring(0, 4);
      const month = data.TransTime.substring(4, 6);
      const day = data.TransTime.substring(6, 8);
      const hour = data.TransTime.substring(8, 10);
      const minute = data.TransTime.substring(10, 12);
      const second = data.TransTime.substring(12, 14);
      entryTime = new Date(`${year}-${month}-${day}T${hour}:${minute}:${second}`);
    } else {
      entryTime = new Date();
    }

    let numPeople = 1;
    if (data.BillRefNumber && data.BillRefNumber.startsWith('GROUP_')) {
      const groupSize = parseInt(data.BillRefNumber.split('_')[1]);
      if (!isNaN(groupSize) && groupSize > 0) {
        numPeople = groupSize;
      }
    }

    const perPersonAmount = amount / numPeople;
    const durationDays = tiers[perPersonAmount] || 1;

    for (let i = 0; i < numPeople; i++) {
      const uniquePhone = `${phone}_${i}`;

      await pool.query(
        'INSERT INTO library_entries (full_name, phone, entry_time, amount) VALUES ($1, $2, $3, $4)',
        [fullName, uniquePhone, entryTime, perPersonAmount]
      );

      const existing = await pool.query(
        'SELECT end_time FROM memberships WHERE phone = $1',
        [uniquePhone]
      );

      let startTime = entryTime;
      let endTime = new Date(entryTime);
      endTime.setDate(endTime.getDate() + durationDays);

      if (existing.rows.length > 0) {
        const currentEnd = new Date(existing.rows[0].end_time);
        if (currentEnd > entryTime) {
          startTime = entryTime;
          endTime = new Date(currentEnd);
          endTime.setDate(endTime.getDate() + durationDays);
        }
        await pool.query(
          'UPDATE memberships SET full_name = $1, start_time = $2, end_time = $3, amount = $4, duration_days = $5 WHERE phone = $6',
          [fullName, startTime, endTime, perPersonAmount, durationDays, uniquePhone]
        );
      } else {
        await pool.query(
          'INSERT INTO memberships (full_name, phone, start_time, end_time, amount, duration_days) VALUES ($1, $2, $3, $4, $5, $6)',
          [fullName, uniquePhone, startTime, endTime, perPersonAmount, durationDays]
        );
      }

      io.emit('new_entry', {
        fullName,
        entryTime: entryTime.toISOString(),
        amount: perPersonAmount,
        groupSize: numPeople
      });

      io.emit('update_membership', {
        fullName,
        phone: uniquePhone,
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString()
      });
    }

    res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
  } catch (err) {
    console.error('Error processing M-Pesa webhook:', err);
    res.status(500).json({ ResultCode: 1, ResultDesc: 'Failed' });
  }
});

server.listen(3000, () => console.log('Server running on port 3000'));


