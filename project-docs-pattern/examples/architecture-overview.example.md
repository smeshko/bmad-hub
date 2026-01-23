---
title: Architecture Overview
description: High-level system architecture and design patterns
author: Tech Lead
date: 2024-01-15
---

# Architecture Overview

TaskFlow is a task management API built with a layered architecture emphasizing testability and maintainability.

## System Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  Controllers │  │   Routers   │  │  Middleware │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│                       Domain Layer                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Services  │  │   Entities  │  │    Errors   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│                        Data Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Repositories│  │    Models   │  │  Migrations │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│                    Infrastructure Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  Database   │  │    Cache    │  │  External   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

## Layer Responsibilities

| Layer | Responsibility | Key Components |
|-------|---------------|----------------|
| Presentation | HTTP handling, validation, serialization | Controllers, Routers, Middleware |
| Domain | Business logic, entity definitions | Services, Entities, Errors |
| Data | Persistence, queries, migrations | Repositories, Models, Migrations |
| Infrastructure | External integrations, connections | Database, Cache, External APIs |

## Key Patterns

### Dependency Injection

All services injected via protocols for testability:

```swift
protocol TaskServiceProtocol {
    func create(_ task: CreateTaskDTO) async throws -> Task
}
```

### Repository Pattern

Data access abstracted behind repositories:

```swift
protocol TaskRepositoryProtocol {
    func save(_ task: Task) async throws
    func findById(_ id: UUID) async throws -> Task?
}
```

## Module Structure

```text
Modules/{Module}/
├── {Module}Module.swift       # Registration
├── {Module}Router.swift       # Routes
├── Controllers/
├── Services/
├── Repositories/
└── Models/
```

## Data Flow

```text
Request → Router → Controller → Service → Repository → Database
                                    ↓
Response ← Controller ← Service ← Entity
```

## Related Documentation

- [Technical Architecture](technical-architecture.md)
- [ADRs](adrs/)
- [API Contracts](../reference/api-contracts.md)
