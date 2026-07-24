/// MobileShop API — Abstract Interface (Dart)
///
/// Versioned tenant-scoped API contract for all MobileShop domain operations.
/// All routes are under `/api/v1/mobile-shop`.
///
/// Requirements: 6.3–6.4, 6.15–6.18, 12.4–12.5, 12.9
library;

import '../auth/tenant_context.dart';
import '../models/confirmation_models.dart';
import '../models/sync_models.dart';
import 'api_result.dart';
import 'mobile_endpoint.dart';

/// DTO for a mobile sale request.
typedef MobileSaleDto = Map<String, dynamic>;

/// DTO for a sale outcome response.
typedef SaleOutcomeDto = MutationOutcome<Map<String, dynamic>>;

/// DTO for push batch request.
typedef PushBatchDto = PushBatchRequest;

/// DTO for push result.
typedef PushResultDto = PushBatchResponse;

/// DTO for pull request.
typedef PullRequestDto = PullRequest;

/// DTO for pull page response.
typedef PullPageDto = PullResponse;

/// DTO for server hint (WebSocket).
typedef MobileServerHintDto = ServerHint;

/// Abstract API interface for the MobileShop domain.
///
/// Implementations handle HTTP transport, authentication headers,
/// correlation, idempotency, versioning, and confirmation validation.
abstract interface class MobileShopApi {
  /// Finalize a mobile device sale.
  ///
  /// Sends operation ID, fingerprint, expected versions, and full sale payload.
  /// Returns typed outcome with authoritative confirmation when committed.
  Future<ApiResult<SaleOutcomeDto>> finalizeSale(MobileSaleDto request);

  /// Push a batch of queued offline mutations to the server.
  ///
  /// Each mutation carries its own operation ID and fingerprint.
  Future<ApiResult<PushResultDto>> push(PushBatchDto request);

  /// Pull a page of change events from the server.
  ///
  /// Uses continuation token for pagination; limit is bounded by config.
  Future<ApiResult<PullPageDto>> pull(PullRequestDto request);

  /// Subscribe to real-time server hints via WebSocket.
  ///
  /// Yields minimal invalidation hints that trigger bounded pull.
  /// The stream completes on disconnect or tenant switch.
  Stream<MobileServerHintDto> subscribe(TenantContext context);

  /// Execute an arbitrary typed endpoint command.
  ///
  /// Provides extensibility for domain-specific endpoints beyond
  /// sale/push/pull without adding methods to this interface.
  Future<ApiResult<T>> command<T>(MobileEndpoint<T> endpoint);
}
