// Reproduction + regression test for D5 idempotency-key support on the
// central HTTP client (clauses 2.10 + 2.19 of `bugfix.md`).
//
// On F (no idempotencyKey parameter) sync-handler retries can duplicate
// writes server-side. On F' the central `ApiClient.post/put/patch/delete`
// each accept an `idempotencyKey` parameter that is sent as the
// `Idempotency-Key` header — every call site downstream inherits dedupe
// semantics by passing the key through.
//
// This test does not spin up a real HTTP transport (that would require
// DotEnv + auth bootstrapping). Instead it asserts the *surface* of the
// API at compile time: each method tear-off accepts `idempotencyKey:`.
// If the parameter is removed the test file will not compile.

import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/api/api_client.dart';

void main() {
  group('ApiClient idempotency surface (D5)', () {
    test('post / put / patch / delete accept idempotencyKey parameter', () {
      // The closures below only compile when the named parameter exists.
      // We never invoke them — that would need a real HTTP transport.
      //
      // ignore: avoid_init_to_null, unused_local_variable
      Future<ApiResponse<Map<String, dynamic>>> postSurface(
        ApiClient a,
        String p, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
        bool requireAuth = true,
        String? idempotencyKey,
      }) => a.post(
        p,
        body: body,
        headers: headers,
        requireAuth: requireAuth,
        idempotencyKey: idempotencyKey,
      );

      // ignore: unused_local_variable
      Future<ApiResponse<Map<String, dynamic>>> putSurface(
        ApiClient a,
        String p, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
        bool requireAuth = true,
        String? idempotencyKey,
      }) => a.put(
        p,
        body: body,
        headers: headers,
        requireAuth: requireAuth,
        idempotencyKey: idempotencyKey,
      );

      // ignore: unused_local_variable
      Future<ApiResponse<Map<String, dynamic>>> patchSurface(
        ApiClient a,
        String p, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
        bool requireAuth = true,
        String? idempotencyKey,
      }) => a.patch(
        p,
        body: body,
        headers: headers,
        requireAuth: requireAuth,
        idempotencyKey: idempotencyKey,
      );

      // ignore: unused_local_variable
      Future<ApiResponse<Map<String, dynamic>>> deleteSurface(
        ApiClient a,
        String p, {
        Map<String, String>? headers,
        bool requireAuth = true,
        String? idempotencyKey,
      }) => a.delete(
        p,
        headers: headers,
        requireAuth: requireAuth,
        idempotencyKey: idempotencyKey,
      );

      // If the file compiled, the surface is correct.
      expect(true, isTrue);
    });
  });
}
