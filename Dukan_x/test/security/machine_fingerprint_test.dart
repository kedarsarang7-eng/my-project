// Tests for MachineFingerprint + Fingerprint_Collector same-machine logic.
//
// Feature: offline-license-activation (task 4.1)
// Covers Requirements:
//   5.1 — Machine_Fingerprint carries cpuId, macAddress, hddSerial, osType, hostname
//   6.1 — same machine iff at most one of the five components differs
//   6.2 — two or more differing components => new machine (reactivation)
//   5.2 — Fingerprint_Hash = SHA256(cpuId + macAddress + hddSerial) (task 4.2)

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/core/security/device/device_fingerprint.dart';

void main() {
  // Canonical baseline fingerprint reused across cases.
  const base = MachineFingerprint(
    cpuId: 'CPU-123',
    macAddress: 'AA:BB:CC:DD:EE:FF',
    hddSerial: 'HDD-789',
    osType: 'windows',
    hostname: 'SHOP-PC',
  );

  final collector = DeviceFingerprintCollector();

  group('MachineFingerprint model (Req 5.1)', () {
    test('exposes the five license-binding components in canonical order', () {
      expect(base.components, [
        'CPU-123',
        'AA:BB:CC:DD:EE:FF',
        'HDD-789',
        'windows',
        'SHOP-PC',
      ]);
    });

    test('round-trips through toMap/fromMap', () {
      final restored = MachineFingerprint.fromMap(base.toMap());
      expect(restored, base);
    });

    test('fromMap tolerates missing keys by defaulting to empty strings', () {
      final fp = MachineFingerprint.fromMap(const {'cpuId': 'X'});
      expect(fp.cpuId, 'X');
      expect(fp.macAddress, '');
      expect(fp.hddSerial, '');
      expect(fp.osType, '');
      expect(fp.hostname, '');
    });

    test('value equality and hashCode are component-based', () {
      const copy = MachineFingerprint(
        cpuId: 'CPU-123',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        hddSerial: 'HDD-789',
        osType: 'windows',
        hostname: 'SHOP-PC',
      );
      expect(copy, base);
      expect(copy.hashCode, base.hashCode);
    });

    test('toString masks raw hardware identifiers (Req 17.10)', () {
      final text = base.toString();
      expect(text, isNot(contains('CPU-123')));
      expect(text, isNot(contains('HDD-789')));
      expect(text, contains('windows')); // osType is non-sensitive
    });
  });

  group('differingComponentCount', () {
    test('is zero for identical fingerprints', () {
      expect(base.differingComponentCount(base), 0);
    });

    test('counts each differing component exactly once', () {
      const other = MachineFingerprint(
        cpuId: 'CPU-999', // differs
        macAddress: 'AA:BB:CC:DD:EE:FF',
        hddSerial: 'HDD-000', // differs
        osType: 'windows',
        hostname: 'OTHER-PC', // differs
      );
      expect(base.differingComponentCount(other), 3);
    });

    test('is symmetric', () {
      const other = MachineFingerprint(
        cpuId: 'CPU-999',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        hddSerial: 'HDD-789',
        osType: 'windows',
        hostname: 'SHOP-PC',
      );
      expect(
        base.differingComponentCount(other),
        other.differingComponentCount(base),
      );
    });
  });

  group('isSameMachine (Req 6.1 / 6.2)', () {
    test('identical fingerprints are the same machine', () {
      expect(collector.isSameMachine(base, base), isTrue);
    });

    test(
      'exactly one differing component is tolerated as the same machine',
      () {
        const oneDiff = MachineFingerprint(
          cpuId: 'CPU-123',
          macAddress: 'AA:BB:CC:DD:EE:FF',
          hddSerial: 'HDD-REPLACED', // single replaced part
          osType: 'windows',
          hostname: 'SHOP-PC',
        );
        expect(base.differingComponentCount(oneDiff), 1);
        expect(collector.isSameMachine(base, oneDiff), isTrue);
      },
    );

    test('two differing components require reactivation (new machine)', () {
      const twoDiff = MachineFingerprint(
        cpuId: 'CPU-NEW',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        hddSerial: 'HDD-REPLACED',
        osType: 'windows',
        hostname: 'SHOP-PC',
      );
      expect(base.differingComponentCount(twoDiff), 2);
      expect(collector.isSameMachine(base, twoDiff), isFalse);
    });

    test('completely different machine is not the same machine', () {
      const fresh = MachineFingerprint(
        cpuId: 'X',
        macAddress: 'Y',
        hddSerial: 'Z',
        osType: 'linux',
        hostname: 'LAPTOP',
      );
      expect(collector.isSameMachine(base, fresh), isFalse);
    });

    test('same-machine decision is symmetric for one drifted component', () {
      const oneDiff = MachineFingerprint(
        cpuId: 'CPU-123',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        hddSerial: 'HDD-REPLACED',
        osType: 'windows',
        hostname: 'SHOP-PC',
      );
      expect(
        collector.isSameMachine(base, oneDiff),
        collector.isSameMachine(oneDiff, base),
      );
    });
  });

  group('fingerprintHash (Req 5.2 — delivered by task 4.2)', () {
    // Reference: SHA256(cpuId + macAddress + hddSerial), osType/hostname excluded.
    String expectedHash(MachineFingerprint fp) => sha256
        .convert(utf8.encode(fp.cpuId + fp.macAddress + fp.hddSerial))
        .toString();

    test('computes SHA256 of cpuId + macAddress + hddSerial', () {
      expect(collector.fingerprintHash(base), expectedHash(base));
    });

    test('produces a 64-char lowercase hex SHA256 digest', () {
      final hash = collector.fingerprintHash(base);
      expect(hash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(hash), isTrue);
    });

    test('is deterministic — identical fingerprints hash identically', () {
      const copy = MachineFingerprint(
        cpuId: 'CPU-123',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        hddSerial: 'HDD-789',
        osType: 'windows',
        hostname: 'SHOP-PC',
      );
      expect(collector.fingerprintHash(copy), collector.fingerprintHash(base));
    });

    test('changes when cpuId changes', () {
      const other = MachineFingerprint(
        cpuId: 'CPU-CHANGED',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        hddSerial: 'HDD-789',
        osType: 'windows',
        hostname: 'SHOP-PC',
      );
      expect(
        collector.fingerprintHash(other),
        isNot(collector.fingerprintHash(base)),
      );
    });

    test('changes when macAddress changes', () {
      const other = MachineFingerprint(
        cpuId: 'CPU-123',
        macAddress: '11:22:33:44:55:66',
        hddSerial: 'HDD-789',
        osType: 'windows',
        hostname: 'SHOP-PC',
      );
      expect(
        collector.fingerprintHash(other),
        isNot(collector.fingerprintHash(base)),
      );
    });

    test('changes when hddSerial changes', () {
      const other = MachineFingerprint(
        cpuId: 'CPU-123',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        hddSerial: 'HDD-REPLACED',
        osType: 'windows',
        hostname: 'SHOP-PC',
      );
      expect(
        collector.fingerprintHash(other),
        isNot(collector.fingerprintHash(base)),
      );
    });

    test('is independent of osType and hostname', () {
      const differentOsAndHost = MachineFingerprint(
        cpuId: 'CPU-123',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        hddSerial: 'HDD-789',
        osType: 'linux', // differs
        hostname: 'OTHER-PC', // differs
      );
      expect(
        collector.fingerprintHash(differentOsAndHost),
        collector.fingerprintHash(base),
      );
    });
  });
}
