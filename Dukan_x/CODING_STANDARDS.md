# DukanX Coding Standards

> Enterprise-Grade Development Guidelines  
> Version: 1.0.0

## 🚫 Forbidden Patterns

The following patterns are **strictly prohibited** and will trigger CI failures:

### 1. setState in Desktop Widgets
```dart
// ❌ FORBIDDEN - Causes MouseTracker crashes
setState(() { currentIndex = newIndex; });

// ✅ REQUIRED - Use Riverpod
ref.read(navigationControllerProvider).navigateTo(screen);
```

### 2. Direct Firestore Calls from UI
```dart
// ❌ FORBIDDEN
await FirebaseFirestore.instance.collection('users').add(data);

// ✅ REQUIRED - Use Repository
await ref.read(userRepositoryProvider).create(user);
```

### 3. Unbounded Async Without Timeout
```dart
// ❌ FORBIDDEN
final data = await fetchData();

// ✅ REQUIRED - Use safeAsync
final result = await safeAsync(
  operation: () => fetchData(),
  timeout: Duration(seconds: 30),
);
```

### 4. Throwing Exceptions in Repositories
```dart
// ❌ FORBIDDEN
throw Exception('User not found');

// ✅ REQUIRED - Return Result type
return Result.failure(AppError.notFound('User not found'));
```

### 5. Widget Rebuilds for Selection State
```dart
// ❌ FORBIDDEN - Full sidebar rebuilds
build(context) => ListView(...selectedIndex...)

// ✅ REQUIRED - Leaf widget listens
SidebarItem(isSelected: ref.watch(selectionProvider.select(...)))
```

---

## ✅ Required Patterns

### 1. Error Boundaries for All Major Sections
```dart
// Every feature's root widget
ErrorBoundary(
  onError: (error) => ErrorHandler.handle(error),
  child: YourFeatureWidget(),
)
```

### 2. Result Type for All Async Operations
```dart
Future<Result<User>> getUser(String id) async {
  try {
    final user = await _db.getUser(id);
    return Result.success(user);
  } catch (e, stack) {
    return Result.failure(ErrorHandler.createAppError(e, stack));
  }
}
```

### 3. AsyncValue for Loading States
```dart
asyncBuilder(
  state: state,
  onData: (data) => DataWidget(data),
  loading: ShimmerLoadingList(),
)
```

### 4. RepaintBoundary for Heavy Widgets
```dart
RepaintBoundary(
  child: ExpensiveChartWidget(),
)
```

### 5. Compute for Heavy Operations
```dart
// Move to isolate for > 10ms operations
final summary = await ComputeService.calculateStockSummary(products);
```

---

## 📁 Layer Architecture

```
lib/
├── core/           # Shared utilities (error, navigation, sync)
├── data/           # Repositories, data sources (NEVER import from UI)
├── domain/         # Models, entities (pure Dart, no Flutter imports)
├── features/       # Feature modules
│   └── [feature]/
│       ├── data/           # Feature-specific repos
│       ├── domain/         # Feature entities
│       └── presentation/   # Screens, widgets (UI ONLY)
└── widgets/        # Shared UI components
```

### Import Rules
- `presentation/` can import from `domain/` and `data/`
- `domain/` can import from other `domain/` only
- `data/` can import from `domain/` only
- NEVER import `presentation/` from `data/` or `domain/`

---

## 🔒 Checklist Before PR

- [ ] No `setState` calls
- [ ] All async ops use `safeAsync` or have timeout
- [ ] Heavy ops (>10ms) moved to isolate
- [ ] Error boundaries around feature roots
- [ ] Result types for all repo methods
- [ ] No direct Firestore calls from widgets
- [ ] RepaintBoundary around expensive widgets
