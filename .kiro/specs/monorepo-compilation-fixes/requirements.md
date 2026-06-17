# Requirements Document

## Introduction

This specification defines the requirements for resolving all 2087 compilation errors across a multi-package Flutter monorepo. The monorepo contains six packages (Dukan_x, dukan_restro_pwa, school_admin_app, school_student_app, school_teacher_app, school_common) with errors spanning 26 categories caused by dependency version drift, API migrations, missing generated files, and structural corruption. The fix effort must follow a strict dependency order to avoid cascade failures.

## Glossary

- **Monorepo**: The multi-package Flutter workspace containing all six application and library packages
- **Analyzer**: The `flutter analyze` static analysis tool that reports compilation errors and warnings
- **Riverpod_v2**: Version 2.x of the Riverpod state management library using code generation and new API patterns
- **StateNotifierProvider**: A deprecated Riverpod v1 provider type replaced by NotifierProvider/AsyncNotifierProvider in v2
- **Module_File**: A barrel file that re-exports symbols from a feature module for external consumption
- **ApiResponse**: A typed wrapper class around HTTP responses that exposes `.data` for accessing the response body
- **Build_Runner**: The Dart code generation tool that produces `.g.dart` and `.mocks.dart` files
- **Drift**: A reactive persistence library for Flutter that uses code generation for type-safe database access
- **web_socket_channel**: A cross-platform WebSocket library that works on both native and web targets
- **connectivity_plus**: A Flutter plugin for monitoring network connectivity that returns `List<ConnectivityResult>` in v5+
- **Fix_Batch**: A group of related fixes applied together in a single execution step

## Requirements

### Requirement 1: Zero Compilation Errors

**User Story:** As a developer, I want all six packages in the monorepo to compile without errors, so that I can build and deploy the applications.

#### Acceptance Criteria

1. WHEN `flutter analyze` is run on Dukan_x, THEN THE Analyzer SHALL report zero errors
2. WHEN `flutter analyze` is run on dukan_restro_pwa, THEN THE Analyzer SHALL report zero errors
3. WHEN `flutter analyze` is run on school_admin_app, THEN THE Analyzer SHALL report zero errors
4. WHEN `flutter analyze` is run on school_student_app, THEN THE Analyzer SHALL report zero errors
5. WHEN `flutter analyze` is run on school_teacher_app, THEN THE Analyzer SHALL report zero errors
6. WHEN `flutter analyze` is run on school_common, THEN THE Analyzer SHALL report zero errors

### Requirement 2: Riverpod v2 API Consistency

**User Story:** As a developer, I want all provider files to use the Riverpod v2 API consistently, so that state management works correctly and follows current best practices.

#### Acceptance Criteria

1. THE Monorepo SHALL use flutter_riverpod ^2.5.1 and riverpod_annotation ^2.3.5 across all packages
2. WHEN a provider file uses StateNotifierProvider, THEN THE Fix_Batch SHALL migrate it to NotifierProvider or AsyncNotifierProvider with the equivalent state type
3. WHEN a provider file references `.state` on a StateNotifier, THEN THE Fix_Batch SHALL replace it with the v2 equivalent accessor pattern
4. WHEN a provider file uses `ref.read` or `ref.watch` with a StateNotifierProvider, THEN THE Fix_Batch SHALL update the provider reference to the migrated v2 provider
5. WHEN a generated `.g.dart` file references AutoDisposeAsyncNotifier for a wrong Riverpod version, THEN THE Build_Runner SHALL regenerate the file after migration is complete

### Requirement 3: Module File Export Completeness

**User Story:** As a developer, I want all module barrel files to properly export the Override type and required symbols, so that downstream files can resolve all type references.

#### Acceptance Criteria

1. WHEN a module file is imported by a downstream file that uses the Override type, THEN THE Module_File SHALL include a re-export of `package:flutter_riverpod/flutter_riverpod.dart` or the specific Override symbol
2. WHEN a feature module defines providers, THEN THE Module_File SHALL export all provider symbols needed by consumers
3. IF a downstream file reports "Override is not a type" error, THEN THE Fix_Batch SHALL add the missing re-export to the corresponding Module_File

### Requirement 4: Firestore API Compatibility

**User Story:** As a developer, I want all Firestore operations to use the correct API for cloud_firestore ^4.x, so that database operations compile and function correctly.

#### Acceptance Criteria

1. THE Monorepo SHALL use cloud_firestore ^4.17.0 or higher across all packages
2. WHEN a Firestore query uses `.reference` on a DocumentSnapshot, THEN THE Fix_Batch SHALL replace it with `.ref` (the v4 accessor)
3. WHEN a Firestore query uses `startAfterDocument`, THEN THE Fix_Batch SHALL verify the method signature matches the cloud_firestore ^4.x API
4. WHEN a Firestore query uses `.count()`, THEN THE Fix_Batch SHALL ensure it uses the `AggregateQuery` API from cloud_firestore ^4.x
5. WHEN a Firestore query uses `isNotEqualTo` in a where clause, THEN THE Fix_Batch SHALL use the correct named parameter syntax for cloud_firestore ^4.x

### Requirement 5: Cross-Platform WebSocket Compatibility

**User Story:** As a developer, I want WebSocket usage to work on both native and web platforms, so that real-time features function across all deployment targets.

#### Acceptance Criteria

1. THE Monorepo SHALL use web_socket_channel ^2.4.5 for all WebSocket operations
2. WHEN a file imports `dart:io` for WebSocket, THEN THE Fix_Batch SHALL replace it with the web_socket_channel package import
3. WHEN a WebSocket connection is created using `WebSocket.connect()` from dart:io, THEN THE Fix_Batch SHALL replace it with `WebSocketChannel.connect()` from web_socket_channel
4. IF a file uses conditional imports for platform-specific WebSocket, THEN THE Fix_Batch SHALL consolidate to the single cross-platform web_socket_channel implementation

### Requirement 6: Test File Compilation

**User Story:** As a developer, I want all test files to compile with correct mock signatures, so that the test suite can be executed.

#### Acceptance Criteria

1. WHEN a test file imports a `.mocks.dart` file, THEN THE Build_Runner SHALL have generated that file with correct mock class signatures
2. WHEN a mock class signature does not match its interface due to API changes, THEN THE Fix_Batch SHALL update the `@GenerateMocks` annotation to match the current interface
3. IF a test file has structural corruption (duplicated definitions, malformed syntax), THEN THE Fix_Batch SHALL repair the file structure while preserving test logic
4. WHEN a test file depends on cloud_functions or cloud_firestore, THEN THE package pubspec.yaml SHALL include those packages in dev_dependencies
5. WHEN Build_Runner is executed after all source fixes, THEN THE Build_Runner SHALL generate all `.mocks.dart` files without errors

### Requirement 7: Generated File Currency

**User Story:** As a developer, I want all generated files (.g.dart, .mocks.dart) to be up to date with current source code, so that generated code matches the interfaces it implements.

#### Acceptance Criteria

1. WHEN all source code fixes are complete, THEN THE Build_Runner SHALL be executed to regenerate all `.g.dart` files
2. WHEN all source code fixes are complete, THEN THE Build_Runner SHALL be executed to regenerate all `.mocks.dart` files
3. WHEN a `.g.dart` file references AutoDisposeAsyncNotifier, THEN THE generated code SHALL match the Riverpod v2 code generation output
4. IF Build_Runner reports generation errors after execution, THEN THE Fix_Batch SHALL resolve the source issues and re-run generation

### Requirement 8: Code Cleanliness

**User Story:** As a developer, I want no unused imports or unnecessary casts to remain in the codebase, so that the code is clean and maintainable.

#### Acceptance Criteria

1. WHEN `flutter analyze` is run with default lint rules, THEN THE Analyzer SHALL report zero warnings for unused imports
2. WHEN `flutter analyze` is run with default lint rules, THEN THE Analyzer SHALL report zero warnings for unnecessary casts
3. WHEN a file contains an import that is no longer referenced after fixes, THEN THE Fix_Batch SHALL remove that import
4. WHEN a file contains a cast that is no longer needed after type corrections, THEN THE Fix_Batch SHALL remove that cast

### Requirement 9: Dependency Order Execution

**User Story:** As a developer, I want fixes to be applied in dependency order, so that earlier fixes do not create new errors that block later fixes.

#### Acceptance Criteria

1. THE Fix_Batch SHALL update all pubspec.yaml files before any source code modifications
2. THE Fix_Batch SHALL run `flutter pub get` in each package after pubspec updates and before source fixes
3. THE Fix_Batch SHALL complete Riverpod v2 migration before fixing provider-dependent code (ApiResponse, Firestore, Auth)
4. THE Fix_Batch SHALL complete all source code fixes before running Build_Runner for code generation
5. THE Fix_Batch SHALL complete code generation before performing unused import cleanup
6. THE Fix_Batch SHALL run `flutter analyze` as the final verification step after all fixes and generation are complete

### Requirement 10: Dependency Version Alignment

**User Story:** As a developer, I want all packages to use compatible dependency versions, so that there are no version conflicts during resolution.

#### Acceptance Criteria

1. THE Monorepo SHALL specify flutter_riverpod ^2.5.1 in all packages that use Riverpod
2. THE Monorepo SHALL specify riverpod_annotation ^2.3.5 in all packages that use Riverpod code generation
3. THE Monorepo SHALL specify cloud_firestore ^4.17.0 in all packages that use Firestore
4. THE Monorepo SHALL specify firebase_auth ^4.20.0 in all packages that use Firebase Authentication
5. THE Monorepo SHALL specify connectivity_plus ^6.0.3 in all packages that use connectivity checking
6. THE Monorepo SHALL specify web_socket_channel ^2.4.5 in all packages that use WebSocket
7. THE Monorepo SHALL specify drift ^2.18.0 in all packages that use Drift database
8. THE Monorepo SHALL specify riverpod_generator ^2.4.3 in dev_dependencies of all packages using Riverpod code generation
9. THE Monorepo SHALL specify build_runner ^2.4.9 in dev_dependencies of all packages using code generation
10. WHEN `flutter pub get` is run in any package, THEN the dependency resolver SHALL complete without version conflicts

### Requirement 11: Platform-Specific API Fixes

**User Story:** As a developer, I want all platform-specific API usages to be correct for their target platforms, so that the code compiles on all supported platforms.

#### Acceptance Criteria

1. WHEN a file uses `GoogleAuthProvider` from firebase_auth, THEN THE Fix_Batch SHALL ensure the correct import path is used
2. WHEN a file uses `signInWithPopup`, THEN THE Fix_Batch SHALL ensure it is guarded with a web platform check or conditional import
3. WHEN a file uses the `&` operator on Drift `Expression<bool>`, THEN THE Fix_Batch SHALL replace it with the `.and()` method call
4. WHEN a file uses `ConnectivityResult` from connectivity_plus v5+, THEN THE Fix_Batch SHALL handle the `List<ConnectivityResult>` return type instead of a single value
5. WHEN a file uses `HttpClient` or `consolidateHttpClientResponseBytes`, THEN THE Fix_Batch SHALL add the correct dart:io or foundation import
6. WHEN a file uses `PhoneAuthCredential` in a callback, THEN THE Fix_Batch SHALL match the current firebase_auth callback type signature

### Requirement 12: Enum and Type Completeness

**User Story:** As a developer, I want all enum values and type references to be complete, so that switch statements and type checks compile correctly.

#### Acceptance Criteria

1. WHEN a switch statement handles `StaffRole` values, THEN THE Fix_Batch SHALL add the `StaffRole.caterer` case
2. WHEN a file references `BillEntity` as a type, THEN THE Fix_Batch SHALL add the missing import for that type
3. WHEN a file references `SyncChangeRecord`, THEN THE Fix_Batch SHALL update the import to the current class name and location
4. WHEN a file uses `AuthState.user`, THEN THE Fix_Batch SHALL use the correct accessor for the refactored AuthState class
5. WHEN a file uses `.valueOrNull` on an AsyncValue, THEN THE Fix_Batch SHALL replace it with the Riverpod v2 equivalent (`.valueOrNull` or `.value`)

### Requirement 13: ApiResponse Access Pattern

**User Story:** As a developer, I want all API response handling to use the typed ApiResponse wrapper correctly, so that response data is accessed safely.

#### Acceptance Criteria

1. WHEN a file accesses an ApiResponse with bracket notation (`response['key']`), THEN THE Fix_Batch SHALL replace it with `response.data['key']`
2. WHEN a file treats an ApiResponse as a raw Map, THEN THE Fix_Batch SHALL update the access pattern to use the `.data` property first
3. THE Fix_Batch SHALL verify that all ApiResponse access patterns are consistent across the Monorepo after fixes

### Requirement 14: Script and Non-Dart File Fixes

**User Story:** As a developer, I want script files to parse correctly without Dart interpolation errors, so that tooling scripts can be executed.

#### Acceptance Criteria

1. WHEN a script file contains raw regex patterns with `$` characters, THEN THE Fix_Batch SHALL escape them or use raw string literals to prevent Dart interpolation
2. WHEN a script file has variable scoping errors where `data` is declared in the wrong scope, THEN THE Fix_Batch SHALL move the declaration to the correct scope
3. WHEN a file uses `PwaHaptics.error()`, THEN THE Fix_Batch SHALL replace it with the current method name from the PwaHaptics API

### Requirement 15: Const Expression Correctness

**User Story:** As a developer, I want const expressions to only be used where the compiler allows them, so that const evaluation errors are eliminated.

#### Acceptance Criteria

1. WHEN a widget constructor is marked `const` but contains method calls that cannot be evaluated at compile time, THEN THE Fix_Batch SHALL remove the `const` keyword from that expression
2. WHEN a `const` constructor argument includes a function invocation, THEN THE Fix_Batch SHALL remove `const` from the enclosing expression
3. THE Fix_Batch SHALL preserve `const` on expressions that are genuinely compile-time evaluable
