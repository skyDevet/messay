import './lib/env.js';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { requireDb } from './middleware/auth.js';
import quotes from './routes/quotes.js';
import proformas from './routes/proformas.js';
import projects from './routes/projects.js';
import reviews from './routes/reviews.js';
import business from './routes/business.js';
import uploads from './routes/uploads.js';
import egp from './routes/egp.js';
import { bootstrap as egpBootstrap } from './egpAuth.js';

// Global safety nets: a failed eGP request must never kill the API
process.on('unhandledRejection', (err) => {
  console.error('[api] unhandled rejection:', err?.message || err);
});
process.on('uncaughtException', (err) => {
  console.error('[api] uncaught exception:', err?.message || err);
});

const app = express();
const PORT = process.env.PORT || 3001;
const origins = (process.env.CORS_ORIGIN || 'http://localhost:5173').split(',').map(s => s.trim()).filter(Boolean);

app.use(helmet());
app.use(cors({ origin: origins, credentials: true }));
app.use(morgan('dev'));
app.use(express.json({ limit: '1mb' }));

app.get('/api/health', (req, res) => res.json({ ok: true }));

// eGP routes mount BEFORE requireDb so they skip DB auth middleware
app.use('/api/egp', egp);

app.use('/api', requireDb);
app.use('/api/quotes', quotes);
app.use('/api/proformas', proformas);
app.use('/api/projects', projects);
app.use('/api/reviews', reviews);
app.use('/api/business', business);
app.use('/api/uploads', uploads);

app.use('/api', (req, res) => res.status(404).json({ error: 'Not found.' }));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[api] route error:', err?.message || err);
  if (res.headersSent) return next(err);
  res.status(500).json({ error: 'Server error: ' + (err?.message || 'unknown') });
});

egpBootstrap().then(() => {
  app.listen(PORT, () => console.log('API listening on http://localhost:' + PORT));
}).catch((e) => {
  console.error('[api] bootstrap failed:', e?.message || e);
  // Still start the server — eGP will log in on first call
  app.listen(PORT, () => console.log('API listening on http://localhost:' + PORT));
});