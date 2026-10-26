import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const here = path.dirname(fileURLToPath(import.meta.url));
// Single .env at the project root (shared with Vite, which only exposes VITE_ keys to the browser)
dotenv.config({ path: path.resolve(here, '../../.env') });
