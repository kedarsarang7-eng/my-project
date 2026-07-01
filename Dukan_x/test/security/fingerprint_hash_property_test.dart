// ============================================================================
// Task 4.4 — PROPERTY TEST
// Feature: offline-license-activation, Property 6: Fingerprint_Hash is
// deterministic over the bound components
// **Validates: Requirements 5.2**
// ============================================================================
// Property 6 (design.md): For any Machine_Fingerprint, the Fingerprint_Hash
//   - equals SHA256(cpuId + macAddress + hddSerial),
//   - is identical for identical (cpuId, macAddress, hddSerial) triples,
//   - changes whenever any one of those three components changes, and
//   - is independent of osType and hostname.
//
// Requirement 5.2: "THE Fingerprint_Collector SHALL compute the Fingerprint_Hash
// as SHA256 of the concatenation of cpuId, macAddress, and hddSerial."
//
// This file is the >=100-case PROPERTY test that complements the example-based
// unit tests in `machine_fingerprint_test.dart`. It exercises the four facets
// of Property 6 across many generated component strings.
//
// PBT library: dartproptest ^0.2.1.
//   `glados` is the design's first-named library, but it is unresolvable in
//   this project: every glados version depends on the standalone `test`
//   package, which conflicts with the Flutter-SDK-pinned `test_api`/`matcher`
//   and `mockito 5.4.6` constraints (see the dev_dependency note in
//   `pubspec.yaml`). `dartproptest` is the equivalent QuickCheck/Hypothesis
//   PBT library already adopted repo-wide, so this test composes cleanly with
//   `flutter_test` while still running >=100 generated cases.
//
// Run: flutter test test/security/fingerprint_hash_property_test.dart
// ============================================================================

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartproptest/dartproptest.dart';
import 'package:dukanx/core/security/device/device_fingerprint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // At least 100 iterations are required by the spec; 200 is the dartproptest
  // default and matches the other property suites in this repo.
  const int kNumRuns = 200;

  final collector = DeviceFingerprintCollector();

  // Independent reference implementation of Req 5.2. Deliberately re-derived
  // here (rather than calling the collector) so the property compares the
  // production hash against a from-scratch SHA256 of the concatenation.
  String referenceHash(String cpuId, String macAddress, String hddSerial) =>
      sha256.convert(utf8.encode(cpuId + macAddress + hddSerial)).toString();

  // Component generators. Printable ASCII (incl. empty strings) covers the
  // realistic identifier space — hex serials, colon-separated MACs, GUIDs,
  // host names — plus boundary cases like empty/whitespace components.
  Generator<String> component({int maxLength = 16}) =>
      Gen.printableAsciiString(minLength: 0, maxLength: maxLength);

  /// Forces [candidate] to differ from [original] so the "changing a component
  /// changes the hash" facet is never vacuously skipped. Appending a sentinel
  /// keeps the value arbitrary while guaranteeing inequality.
  String ensureDifferent(String candidate, String original) =>
      candidate == original ? '$original\u0001' : candidate;

  group('Feature: offline-license-activation, Property 6: Fingerprint_Hash is '
      'deterministic over the bound components', () {
    // -- Facet (a): hash == SHA256(cpuId + macAddress + hddSerial) ---------
    test(
      'Property 6 (a): Fingerprint_Hash equals SHA256(cpuId+macAddress+hddSerial) '
      'and is a 64-char lowercase hex digest',
      () {
        final held = forAll(
          (
            String cpuId,
            String macAddress,
            String hddSerial,
            String osType,
            String hostname,
          ) {
            final fp = MachineFingerprint(
              cpuId: cpuId,
              macAddress: macAddress,
              hddSerial: hddSerial,
              osType: osType,
              hostname: hostname,
            );
            final hash = collector.fingerprintHash(fp);
            return hash == referenceHash(cpuId, macAddress, hddSerial) &&
                hash.length == 64 &&
                RegExp(r'^[0-9a-f]{64}$').hasMatch(hash);
          },
          [component(), component(), component(), component(), component()],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // -- Facet (b): determinism — same triple => same hash -----------------
    test(
      'Property 6 (b): identical (cpuId, macAddress, hddSerial) triples hash '
      'identically (independent of osType/hostname)',
      () {
        final held = forAll(
          (
            String cpuId,
            String macAddress,
            String hddSerial,
            String osTypeA,
            String hostnameA,
            String osTypeB,
            String hostnameB,
          ) {
            final a = MachineFingerprint(
              cpuId: cpuId,
              macAddress: macAddress,
              hddSerial: hddSerial,
              osType: osTypeA,
              hostname: hostnameA,
            );
            final b = MachineFingerprint(
              cpuId: cpuId,
              macAddress: macAddress,
              hddSerial: hddSerial,
              osType: osTypeB,
              hostname: hostnameB,
            );
            return collector.fingerprintHash(a) == collector.fingerprintHash(b);
          },
          [
            component(),
            component(),
            component(),
            component(),
            component(),
            component(),
            component(),
          ],
          numRuns: kNumRuns,
        );
        expect(held, isTrue);
      },
    );

    // -- Facet (c): changing any of the three components changes the hash --
    test('Property 6 (c): changing cpuId, macAddress, or hddSerial (to a '
        'different value) changes the Fingerprint_Hash', () {
      final held = forAll(
        (
          String cpuId,
          String macAddress,
          String hddSerial,
          String osType,
          String hostname,
          String altCpuRaw,
          String altMacRaw,
          String altHddRaw,
        ) {
          final base = MachineFingerprint(
            cpuId: cpuId,
            macAddress: macAddress,
            hddSerial: hddSerial,
            osType: osType,
            hostname: hostname,
          );
          final baseHash = collector.fingerprintHash(base);

          // Each alternate is guaranteed to differ from the original
          // component it replaces, keeping the other two bound components
          // fixed.
          final altCpu = ensureDifferent(altCpuRaw, cpuId);
          final altMac = ensureDifferent(altMacRaw, macAddress);
          final altHdd = ensureDifferent(altHddRaw, hddSerial);

          final cpuChanged = collector.fingerprintHash(
            MachineFingerprint(
              cpuId: altCpu,
              macAddress: macAddress,
              hddSerial: hddSerial,
              osType: osType,
              hostname: hostname,
            ),
          );
          final macChanged = collector.fingerprintHash(
            MachineFingerprint(
              cpuId: cpuId,
              macAddress: altMac,
              hddSerial: hddSerial,
              osType: osType,
              hostname: hostname,
            ),
          );
          final hddChanged = collector.fingerprintHash(
            MachineFingerprint(
              cpuId: cpuId,
              macAddress: macAddress,
              hddSerial: altHdd,
              osType: osType,
              hostname: hostname,
            ),
          );

          return cpuChanged != baseHash &&
              macChanged != baseHash &&
              hddChanged != baseHash;
        },
        [
          component(),
          component(),
          component(),
          component(),
          component(),
          component(),
          component(),
          component(),
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });

    // -- Facet (d): independent of osType and hostname ---------------------
    test('Property 6 (d): changing only osType and/or hostname does NOT change '
        'the Fingerprint_Hash', () {
      final held = forAll(
        (
          String cpuId,
          String macAddress,
          String hddSerial,
          String osType,
          String hostname,
          String otherOsType,
          String otherHostname,
        ) {
          final original = MachineFingerprint(
            cpuId: cpuId,
            macAddress: macAddress,
            hddSerial: hddSerial,
            osType: osType,
            hostname: hostname,
          );
          final osAndHostChanged = MachineFingerprint(
            cpuId: cpuId,
            macAddress: macAddress,
            hddSerial: hddSerial,
            osType: otherOsType,
            hostname: otherHostname,
          );
          return collector.fingerprintHash(original) ==
              collector.fingerprintHash(osAndHostChanged);
        },
        [
          component(),
          component(),
          component(),
          component(),
          component(),
          component(),
          component(),
        ],
        numRuns: kNumRuns,
      );
      expect(held, isTrue);
    });
  });
}
