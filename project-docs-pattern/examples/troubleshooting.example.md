---
title: Troubleshooting
description: Common issues and solutions
author: DevOps Team
date: 2024-01-12
---

# Troubleshooting

Solutions for common development issues.

## Build Issues

### TypeScript compilation errors

**Symptom**: Type errors after pulling changes

**Solution**:
```bash
pnpm clean && pnpm install && pnpm build
```

### Dependency conflicts

**Symptom**: `ERESOLVE unable to resolve dependency tree`

**Solution**:
```bash
rm -rf node_modules pnpm-lock.yaml
pnpm install
```

## Database Issues

### Migration out of sync

**Symptom**: `column does not exist`

**Solution**:
```bash
pnpm db:status
pnpm db:migrate
```

### Connection pool exhausted

**Symptom**: `too many clients already`

**Solution**:
```bash
brew services restart postgresql@15
```

## Runtime Issues

### Port already in use

**Symptom**: `EADDRINUSE :::3000`

**Solution**:
```bash
lsof -i :3000
kill -9 <PID>
```

## Test Issues

### Tests timeout

**Symptom**: Tests hang after 30s

**Causes**: Database not running, unclosed handles

**Solution**:
```bash
brew services list
pnpm test --verbose
```

## Getting Help

1. Check [Architecture Overview](../architecture/overview.md)
2. Search [GitHub Issues](https://github.com/company/taskflow/issues)
3. Ask in `#dev` Slack channel
