# DukanX Documentation Index

Welcome to the DukanX documentation. This document provides an overview of all available documentation.

## 📖 Core Documentation

| Document | Description |
|----------|-------------|
| [README.md](../README.md) | Project overview and getting started |
| [ARCHITECTURE.md](./architecture/ARCHITECTURE.md) | System architecture and design patterns |
| [DEPLOYMENT_GUIDE.md](./deployment/DEPLOYMENT_GUIDE.md) | Production deployment instructions |
| [SECURITY_GUIDE.md](./security/SECURITY_GUIDE.md) | Security implementation details |

## 🏗️ Architecture & Design

| Document | Description |
|----------|-------------|
| [Architecture Overview](./architecture/ARCHITECTURE.md) | High-level system architecture |
| [Data Flow](./architecture/DATA_FLOW.md) | How data flows through the application |
| [Database Schema](./architecture/SQLITE_DATABASE_SCHEMA.md) | Drift/SQLite database structure |
| [Sync Architecture](./architecture/CLOUD_SYNC_IMPLEMENTATION.md) | Offline-first sync implementation |

## 🔒 Security

| Document | Description |
|----------|-------------|
| [Security Quick Start](./security/QUICK_START_SECURITY.md) | Essential security setup |
| [App Check Setup](./security/APP_CHECK_SETUP_GUIDE.md) | Firebase App Check configuration |
| [Encryption Guide](./security/APP_CHECK_ENCRYPTED_STORAGE.md) | Data encryption implementation |

## 🚀 Deployment

| Document | Description |
|----------|-------------|
| [Deployment Checklist](./deployment/FINAL_DEPLOYMENT_CHECKLIST.md) | Pre-deployment verification |
| [Production Guide](./deployment/PRODUCTION_DEPLOYMENT_GUIDE.md) | Production environment setup |
| [Firebase Setup](./deployment/FIREBASE_SETUP.md) | Firebase configuration |

## 📱 Features

| Document | Description |
|----------|-------------|
| [Billing System](./features/BILL_MANAGEMENT_SYSTEM.md) | Invoice and billing features |
| [Customer Management](./features/CUSTOMER_PROFILE_MANAGEMENT.md) | Customer features |
| [Invoice System](./features/INVOICE_SYSTEM_COMPLETE.md) | PDF invoice generation |
| [Multi-Language](./features/MULTI_LANGUAGE_GUIDE.md) | Localization implementation |
| [Payment System](./features/PAYMENT_SYSTEM_IMPLEMENTATION.md) | Payment tracking |

## 🔧 Development

| Document | Description |
|----------|-------------|
| [Error Handling](./development/ERROR_HANDLING_GUIDE.md) | Error handling patterns |
| [Async Patterns](./development/ASYNC_ERROR_HANDLING_GUIDE.md) | Async/await best practices |
| [Testing Guide](./development/TESTING_GUIDE.md) | Test writing guidelines |

## 📋 Quick References

| Document | Description |
|----------|-------------|
| [Quick Reference Card](./reference/QUICK_REFERENCE_CARD.md) | Common commands and patterns |
| [DSA Quick Reference](./reference/SQLITE_DSA_QUICK_REFERENCE.md) | Data structure operations |
| [Invoice API Reference](./reference/INVOICE_SYSTEM_API_REFERENCE.md) | Invoice service API |

---

## 📁 Documentation Structure

```
docs/
├── INDEX.md                     # This file
├── architecture/                # Architecture documentation
│   ├── ARCHITECTURE.md
│   ├── DATA_FLOW.md
│   ├── SQLITE_DATABASE_SCHEMA.md
│   └── CLOUD_SYNC_IMPLEMENTATION.md
├── deployment/                  # Deployment guides
│   ├── DEPLOYMENT_GUIDE.md
│   ├── FIREBASE_SETUP.md
│   └── FINAL_DEPLOYMENT_CHECKLIST.md
├── features/                    # Feature documentation
│   ├── BILL_MANAGEMENT_SYSTEM.md
│   ├── CUSTOMER_PROFILE_MANAGEMENT.md
│   └── INVOICE_SYSTEM_COMPLETE.md
├── security/                    # Security documentation
│   ├── SECURITY_GUIDE.md
│   └── APP_CHECK_SETUP_GUIDE.md
├── development/                 # Development guides
│   ├── ERROR_HANDLING_GUIDE.md
│   └── TESTING_GUIDE.md
└── reference/                   # API references
    ├── QUICK_REFERENCE_CARD.md
    └── INVOICE_SYSTEM_API_REFERENCE.md
```

---

## 🔄 Keeping Docs Updated

When making changes to the codebase:

1. **Architecture changes** → Update `docs/architecture/`
2. **New features** → Add to `docs/features/`
3. **Security updates** → Update `docs/security/`
4. **API changes** → Update `docs/reference/`

---

**Last Updated**: December 26, 2025 | **Version**: 3.0.0
