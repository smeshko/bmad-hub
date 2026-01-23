---
title: Data Models Reference
description: Domain entities, DTOs, and database models
author: Architecture Team
date: 2024-01-15
---

# Data Models Reference

Complete catalog of domain entities, DTOs, and database models.

## Domain Entities

### User

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Primary identifier |
| `email` | `String` | Unique email address |
| `name` | `String` | Display name |
| `createdAt` | `Date` | Account creation timestamp |

### Task

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Primary identifier |
| `title` | `String` | Task title |
| `description` | `String?` | Optional description |
| `status` | `TaskStatus` | Current status |
| `userId` | `UUID` | Owner reference |
| `dueDate` | `Date?` | Optional due date |

### TaskStatus (Enum)

| Value | Description |
|-------|-------------|
| `pending` | Not started |
| `inProgress` | Currently active |
| `completed` | Finished |
| `cancelled` | Abandoned |

## DTOs

### CreateTaskDTO

```typescript
interface CreateTaskDTO {
  title: string;
  description?: string;
  dueDate?: string; // ISO 8601
}
```

### TaskResponseDTO

```typescript
interface TaskResponseDTO {
  id: string;
  title: string;
  description: string | null;
  status: TaskStatus;
  dueDate: string | null;
  createdAt: string;
}
```

## Database Schema

### users

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PRIMARY KEY |
| `email` | `varchar(255)` | UNIQUE, NOT NULL |
| `name` | `varchar(255)` | NOT NULL |
| `password_hash` | `varchar(255)` | NOT NULL |
| `created_at` | `timestamp` | NOT NULL |

### tasks

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | `uuid` | PRIMARY KEY |
| `title` | `varchar(255)` | NOT NULL |
| `description` | `text` | |
| `status` | `varchar(50)` | NOT NULL |
| `user_id` | `uuid` | FOREIGN KEY → users.id |
| `due_date` | `timestamp` | |
| `created_at` | `timestamp` | NOT NULL |

## Naming Conventions

| Context | Convention | Example |
|---------|------------|---------|
| Database tables | snake_case, plural | `user_tasks` |
| Database columns | snake_case | `created_at` |
| Entity properties | camelCase | `createdAt` |
| DTOs | PascalCase + suffix | `CreateTaskDTO` |

## Related Documentation

- [API Contracts](api-contracts.md)
- [Migration Template](../templates/migration-template.md)
