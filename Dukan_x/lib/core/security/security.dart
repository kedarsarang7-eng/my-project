// ============================================================================
// PIN-RESISTANT SECURITY - BARREL EXPORT
// ============================================================================
// Exports all PIN-resistant security layer components.
// ============================================================================

// Device Binding
export 'device/device_fingerprint.dart';
export 'device/trusted_device_service.dart';

// Time Lock
export 'time_lock/time_lock_service.dart';

// Dual Control
export 'dual_control/dual_control_service.dart';

// Safe Mode
export 'safe_mode/safe_mode_service.dart';

// Local_Store tamper detection → read-only forensic mode (Task 18.2, Req 17.12)
export 'store/store_forensic_gate.dart';
export 'store/store_tamper_detector.dart';
export 'store/local_store_auth_probe.dart';

// Context Intelligence
export 'context/session_context_service.dart';

// Unified Authority
export 'owner_authority_service.dart';

// Existing Security (from previous implementation)
export 'models/security_settings.dart';
export 'models/pin_protected_actions.dart';
export 'models/bill_state.dart';
export 'services/owner_pin_service.dart';
export 'services/pin_verification_service.dart';
export 'services/fraud_detection_service.dart';
export 'services/cash_closing_service.dart';
