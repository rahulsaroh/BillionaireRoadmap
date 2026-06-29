# Sahyadri Quarter App

This document outlines the business opportunity, regulatory constraints, technical architecture, and execution roadmap for the Government Quarters & Guest House management website and app.

---

## 1. Executive Summary & Feasibility
- **Opportunity**: Digitizing quarters management (240+ quarters across 3 buildings) and guest house booking for the Central Audit Department (PAG, Audit) in Mumbai.
- **Problem**: Administrative bottlenecks from managing bookings and complaints via spreadsheets or paper registers.
- **Compliance Constraint (CCS Conduct Rules, 1964)**:
  - *Conflict of Interest*: As a central government employee, direct commercial invoicing to your own department is prohibited under Rule 15.
  - *Mitigation Paths*:
    1. **Honorarium Route (FR 46b)**: Pitch as an internal innovation for a one-time merit reward (justifiable range: ₹50,000 to ₹1,00,000).
    2. **Career Portfolio Play**: Build as a gold-standard production app to showcase on a resume for a transition into software engineering.
    3. **Pro-Bono / Tender Setup**: Build the prototype pro-bono for your department to earn a formal commendation letter, then use that case study to license the software to other government entities through your brother's business entity (avoiding conflict of interest).

---

## 2. Technical Architecture (Cloudflare Serverless Stack)
Cloudflare is selected for hosting due to its robust free tier, security defaults, data localization (Mumbai servers), and ease of integration.

- **Frontend**: Flutter Web hosted on **Cloudflare Pages**.
- **Backend API**: **Cloudflare Workers** using the Hono framework.
- **Database**: **Cloudflare D1** (Serverless SQLite).

---

## 3. Database Schema (Cloudflare D1 SQL)

### `schema.sql`
```sql
-- Users Table
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    designation TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    role TEXT CHECK(role IN ('resident', 'admin')) NOT NULL
);

-- Quarters Table
CREATE TABLE quarters (
    id TEXT PRIMARY KEY,
    building_name TEXT NOT NULL,
    quarter_number TEXT NOT NULL,
    status TEXT CHECK(status IN ('occupied', 'vacant', 'under_maintenance')) NOT NULL
);

-- Complaints Table
CREATE TABLE complaints (
    id TEXT PRIMARY KEY,
    resident_id TEXT NOT NULL,
    quarter_id TEXT NOT NULL,
    category TEXT CHECK(category IN ('civil', 'electrical', 'plumbing')) NOT NULL,
    description TEXT NOT NULL,
    status TEXT CHECK(status IN ('pending', 'in_progress', 'resolved')) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (resident_id) REFERENCES users(id),
    FOREIGN KEY (quarter_id) REFERENCES quarters(id)
);

-- Guest House Bookings Table
CREATE TABLE guest_house_bookings (
    id TEXT PRIMARY KEY,
    applicant_id TEXT NOT NULL,
    room_number TEXT NOT NULL,
    check_in TEXT NOT NULL,
    check_out TEXT NOT NULL,
    status TEXT CHECK(status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
    FOREIGN KEY (applicant_id) REFERENCES users(id)
);
```

### `seed.sql`
```sql
-- Seed Data
INSERT INTO users (id, name, designation, email, role) VALUES 
('u1', 'Rahul Saroh', 'Auditor', 'rahulsaroh007@gmail.com', 'resident'),
('u2', 'Amit Kumar', 'Sr. Auditor', 'amit@gov.in', 'resident'),
('a1', 'PAG Admin', 'Estate Manager', 'admin@gov.in', 'admin');

INSERT INTO quarters (id, building_name, quarter_number, status) VALUES
('q1', 'Building A', '101', 'occupied'),
('q2', 'Building A', '102', 'vacant'),
('q3', 'Building B', '201', 'occupied'),
('q4', 'Building B', '202', 'under_maintenance'),
('q5', 'Building C', '301', 'vacant');

INSERT INTO complaints (id, resident_id, quarter_id, category, description, status) VALUES
('c1', 'u1', 'q1', 'plumbing', 'Water leakage in kitchen sink.', 'pending'),
('c2', 'u2', 'q3', 'electrical', 'Short circuit in bedroom fan switch.', 'in_progress');
```

---

## 4. Serverless Backend (Cloudflare Workers with Hono)

`src/index.ts`
```typescript
import { Hono } from 'hono';
import { cors } from 'hono/cors';

type Bindings = {
  DB: D1Database;
}

const app = new Hono<{ Bindings: Bindings }>();

app.use('*', cors({
  origin: '*', // Enable for local dev testing
  allowMethods: ['GET', 'POST', 'PATCH', 'OPTIONS'],
}));

// 1. GET /api/complaints - Get all or user-specific complaints
app.get('/api/complaints', async (c) => {
  const residentId = c.req.query('resident_id');
  try {
    let query = `
      SELECT c.*, u.name as resident_name, q.building_name, q.quarter_number 
      FROM complaints c
      JOIN users u ON c.resident_id = u.id
      JOIN quarters q ON c.quarter_id = q.id
    `;
    
    let result;
    if (residentId) {
      query += " WHERE c.resident_id = ?";
      result = await c.env.DB.prepare(query).bind(residentId).all();
    } else {
      result = await c.env.DB.prepare(query).all();
    }
    return c.json(result.results);
  } catch (e: any) {
    return c.json({ error: e.message }, 500);
  }
});

// 2. POST /api/complaints - File a new complaint
app.post('/api/complaints', async (c) => {
  try {
    const { resident_id, quarter_id, category, description } = await c.req.json();
    const id = crypto.randomUUID();
    
    await c.env.DB.prepare(`
      INSERT INTO complaints (id, resident_id, quarter_id, category, description, status)
      VALUES (?, ?, ?, ?, ?, 'pending')
    `).bind(id, resident_id, quarter_id, category, description).run();
    
    return c.json({ success: true, id });
  } catch (e: any) {
    return c.json({ error: e.message }, 400);
  }
});

// 3. GET /api/guesthouse/availability - Dummy availability
app.get('/api/guesthouse/availability', async (c) => {
  return c.json([
    { room: 'Suite 1', available: true },
    { room: 'Room 101', available: false },
    { room: 'Room 102', available: true }
  ]);
});

// 4. POST /api/guesthouse/book - Book a guest house room
app.post('/api/guesthouse/book', async (c) => {
  try {
    const { applicant_id, room_number, check_in, check_out } = await c.req.json();
    const id = crypto.randomUUID();
    
    await c.env.DB.prepare(`
      INSERT INTO guest_house_bookings (id, applicant_id, room_number, check_in, check_out, status)
      VALUES (?, ?, ?, ?, ?, 'pending')
    `).bind(id, applicant_id, room_number, check_in, check_out).run();
    
    return c.json({ success: true, id });
  } catch (e: any) {
    return c.json({ error: e.message }, 400);
  }
});

// 5. PATCH /api/complaints/:id - Update complaint status (Admin)
app.patch('/api/complaints/:id', async (c) => {
  const id = c.req.param('id');
  try {
    const { status } = await c.req.json();
    await c.env.DB.prepare(`
      UPDATE complaints SET status = ? WHERE id = ?
    `).bind(status, id).run();
    
    return c.json({ success: true });
  } catch (e: any) {
    return c.json({ error: e.message }, 400);
  }
});

export default app;
```

---

## 5. Local Development Configurations

### `wrangler.toml`
```toml
name = "quarters-hub-api"
main = "src/index.ts"
compatibility_date = "2026-06-23"

[[d1_databases]]
binding = "DB"
database_name = "quarters-db"
database_id = "00000000-0000-0000-0000-000000000000"
```

### `package.json`
```json
{
  "name": "quarters-hub-api",
  "version": "1.0.0",
  "private": true,
  "description": "Backend API for the Quarters Hub app using Cloudflare Workers and D1 database",
  "main": "src/index.ts",
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "types": "wrangler types",
    "db:setup": "wrangler d1 execute quarters-db --local --file=schema.sql"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "wrangler": "^3.100.0"
  }
}
```

---

## 6. Execution Timeline & Phases

| Phase | Focus Area | Tasks | Duration |
| :--- | :--- | :--- | :--- |
| **Phase 1** | Database Architecture | Wireframe screens, define schema, seed initial local tables. | 1 Week |
| **Phase 2** | Serverless API Layer | Set up Cloudflare D1 local database, write Workers/Hono API routes. | 2 Weeks |
| **Phase 3** | Frontend Layout | Build Flutter responsive UI (Resident Form / Admin Dashboard views). | 2 Weeks |
| **Phase 4** | Integration & Launch | Bind endpoints to state variables, handle loading states, local dry run. | 1 Week |
