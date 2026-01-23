---
title: Testing Strategy
description: Testing approach, priorities, and patterns
author: QA Team
date: 2024-01-14
---

# Testing Strategy

Testing approach and standards for the project.

## Test Pyramid

```text
        ╱╲
       ╱  ╲        E2E (few)
      ╱────╲
     ╱      ╲      Integration (some)
    ╱────────╲
   ╱          ╲    Unit (many)
  ╱────────────╲
```

## Priority Levels

| Priority | Coverage Target | Focus |
|----------|-----------------|-------|
| P0 | 100% | Critical paths, auth, payments |
| P1 | 90%+ | Core business logic |
| P2 | 80%+ | Edge cases, error handling |
| P3 | Best effort | UI polish, minor features |

## Test Categories

### Unit Tests

- Test individual functions/methods
- Mock all dependencies
- Fast execution (<100ms per test)

```typescript
describe('TaskService', () => {
  it('creates task with valid data', async () => {
    const service = new TaskService(mockRepo);
    const task = await service.create({ title: 'Test' });
    expect(task.title).toBe('Test');
  });
});
```

### Integration Tests

- Test component interactions
- Use test database
- Reset state between tests

```typescript
describe('POST /tasks', () => {
  it('persists task to database', async () => {
    const res = await request(app)
      .post('/tasks')
      .send({ title: 'Test' });
    expect(res.status).toBe(201);
  });
});
```

## Testing Stack

| Tool | Purpose |
|------|---------|
| Jest | Test runner |
| Supertest | HTTP assertions |
| Testcontainers | Database isolation |

## Running Tests

```bash
# All tests
pnpm test

# Unit only
pnpm test:unit

# With coverage
pnpm test:coverage

# Watch mode
pnpm test:watch
```

## Coverage Requirements

| Metric | Minimum |
|--------|---------|
| Lines | 80% |
| Branches | 75% |
| Functions | 80% |

## Related Documentation

- [Service Template](../templates/service-template.md) - Includes mock patterns
- [Troubleshooting](../development/troubleshooting.md) - Test issues
