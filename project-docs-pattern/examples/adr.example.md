---
title: "ADR-001: Repository Pattern for Data Access"
status: Accepted
date: 2024-01-10
---

# ADR-001: Repository Pattern for Data Access

## Status

Accepted

## Context

We need a consistent approach to data access across the application. Direct database queries in services lead to:

- Tight coupling to database implementation
- Difficult unit testing (requires database)
- Duplicated query logic across services
- Hard to optimize queries centrally

## Decision

We will use the Repository Pattern:

- Each entity has a dedicated repository
- Repositories implement a protocol/interface
- Services depend on repository interfaces
- Mock repositories used in unit tests

  ```typescript
  // Interface
  interface TaskRepository {
    findById(id: string): Promise<Task | null>;
    save(task: Task): Promise<void>;
  }
  
  // Implementation
  class PostgresTaskRepository implements TaskRepository {
    async findById(id: string): Promise<Task | null> {
      return this.db.query('SELECT * FROM tasks WHERE id = $1', [id]);
    }
  }
  ```

## Consequences

### Positive

- Services are testable without database
- Query logic centralized and reusable
- Easy to swap database implementations
- Clear separation of concerns

### Negative

- Additional abstraction layer
- More files to maintain
- Simple queries may feel over-engineered

### Neutral

- Team must learn repository pattern
- Existing code needs refactoring

## Related

- [Architecture Overview](../overview.md)
- [Repository Template](../../templates/repository-template.md)
