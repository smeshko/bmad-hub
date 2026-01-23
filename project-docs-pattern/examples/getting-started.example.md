---
title: Getting Started
description: Environment setup and first run guide
author: DevOps Team
date: 2024-01-10
---

# Getting Started

Get your development environment ready and run the project.

## Prerequisites

| Requirement | Version | Installation |
|-------------|---------|--------------|
| Node.js | 20+ | [nodejs.org](https://nodejs.org) |
| PostgreSQL | 15+ | `brew install postgresql@15` |
| pnpm | 8+ | `npm install -g pnpm` |

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/company/taskflow.git
cd taskflow

# 2. Install dependencies
pnpm install

# 3. Configure environment
cp .env.example .env

# 4. Setup database
pnpm db:migrate

# 5. Start application
pnpm dev
```

Server runs at `http://localhost:3000`

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection | `postgres://localhost:5432/taskflow` |
| `JWT_SECRET` | Auth token secret | `your-secret-key` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `3000` |
| `LOG_LEVEL` | Logging verbosity | `info` |

## Verification

```bash
# Run tests
pnpm test

# Health check
curl http://localhost:3000/health
```

Expected: `{"status":"ok"}`

## Common Issues

### Database connection refused

```bash
brew services start postgresql@15
```

### Port already in use

```bash
lsof -i :3000
kill -9 <PID>
```

## Next Steps

- [Architecture Overview](../architecture/overview.md)
- [Templates](../templates/)
- [Troubleshooting](troubleshooting.md)
