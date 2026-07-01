// ============================================================================
// GLOBAL NAVIGATION KEYS
// ============================================================================
// Centralized GlobalKeys used across the app for imperative navigation and
// scaffold messenger access. Imported by `app.dart`, `error_handlers.dart`,
// `integrity_jobs.dart`, and any service that needs out-of-context navigation
// (e.g. deep_link_service).
// ============================================================================

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> globalScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
