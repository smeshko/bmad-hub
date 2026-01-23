---
title: Service Template
description: Step-by-step guide for creating services
author: Architecture Team
date: 2024-01-15
---

# Service Template

## When to Use

- Encapsulating business logic for a domain
- Creating reusable operations across controllers
- Abstracting external API integrations

## Quick Reference

| Aspect | Value |
|--------|-------|
| Location | `src/services/{Service}/` |
| Pattern | Interface + Implementation + Mock |
| Naming | `{Service}Service.ts`, `{Service}Service.interface.ts` |
| Conformance | Stateless, async methods |

## Directory Structure

    ```text
    src/services/{Service}/
    ├── {Service}Service.interface.ts   # Protocol/interface definition
    ├── {Service}Service.ts             # Production implementation
    ├── {Service}Service.mock.ts        # Test mock
    └── index.ts                        # Barrel export
    ```

## Code Templates

### Interface Definition

    ```typescript
    // src/services/{Service}/{Service}Service.interface.ts

    export interface {Service}ServiceInterface {
      create(data: Create{Entity}DTO): Promise<{Entity}>;
      findById(id: string): Promise<{Entity} | null>;
      update(id: string, data: Update{Entity}DTO): Promise<{Entity}>;
      delete(id: string): Promise<void>;
    }
    ```

### Implementation

    ```typescript
    // src/services/{Service}/{Service}Service.ts

    import { {Service}ServiceInterface } from './{Service}Service.interface';
    import { {Entity}Repository } from '@/repositories';

    export class {Service}Service implements {Service}ServiceInterface {
      constructor(private readonly repository: {Entity}Repository) {}

      async create(data: Create{Entity}DTO): Promise<{Entity}> {
        return this.repository.create(data);
      }

      async findById(id: string): Promise<{Entity} | null> {
        return this.repository.findById(id);
      }

      async update(id: string, data: Update{Entity}DTO): Promise<{Entity}> {
        return this.repository.update(id, data);
      }

      async delete(id: string): Promise<void> {
        await this.repository.delete(id);
      }
    }
    ```

### Mock

    ```typescript
    // src/services/{Service}/{Service}Service.mock.ts

    import { {Service}ServiceInterface } from './{Service}Service.interface';

    export class Mock{Service}Service implements {Service}ServiceInterface {
      public items: {Entity}[] = [];

      async create(data: Create{Entity}DTO): Promise<{Entity}> {
        const item = { id: 'mock-id', ...data };
        this.items.push(item);
        return item;
      }

      async findById(id: string): Promise<{Entity} | null> {
        return this.items.find(i => i.id === id) ?? null;
      }

      async update(id: string, data: Update{Entity}DTO): Promise<{Entity}> {
        const index = this.items.findIndex(i => i.id === id);
        this.items[index] = { ...this.items[index], ...data };
        return this.items[index];
      }

      async delete(id: string): Promise<void> {
        this.items = this.items.filter(i => i.id !== id);
      }

      reset(): void {
        this.items = [];
      }
    }
    ```

### Barrel Export

    ```typescript
    // src/services/{Service}/index.ts

    export * from './{Service}Service.interface';
    export * from './{Service}Service';
    export * from './{Service}Service.mock';
    ```

## Existing Patterns

### NotificationService

Location: `src/services/Notification/NotificationService.ts`

    ```typescript
    export class NotificationService implements NotificationServiceInterface {
      constructor(private readonly repository: NotificationRepository) {}

      async send(userId: string, message: string): Promise<void> {
        await this.repository.create({ userId, message });
      }
    }
    ```

## Integrations

### Service Container Registration

    ```typescript
    // src/container.ts

    container.register('{Service}Service', {
      useFactory: (c) => new {Service}Service(
        c.resolve('{Entity}Repository')
      )
    });
    ```

## Anti-Patterns to Avoid

| Anti-Pattern | Why It's Wrong | Do This Instead |
|--------------|----------------|-----------------|
| Direct DB queries | Bypasses repository | Inject repository |
| Throwing raw errors | Inconsistent handling | Use domain errors |
| Stateful services | Concurrency issues | Keep stateless |
| Constructor side effects | Hard to test | Lazy initialization |

## Checklist

- [ ] Interface defined with all public methods
- [ ] Implementation created
- [ ] Mock created for testing
- [ ] Barrel export updated
- [ ] Registered in container
- [ ] Unit tests written

## References

- [Repository Template](repository-template.md)
- [Error Template](error-template.md)
- [Architecture Overview](../architecture/overview.md)
