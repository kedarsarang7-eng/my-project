// ============================================================================
// WhatsApp Automation Module — Consent Service Unit Tests (Task 5.3)
// ============================================================================
// Unit tests for the consent state machine, eligibility derivation,
// consent gate, and opt-out keyword detection.
//
// Requirements: 2.3, 2.4, 2.5, 2.6, 2.9, 2.10, 6.9, 13.5
// ============================================================================

import {
  CONSENT_STATES,
  DEFAULT_CONSENT_STATE,
  OPT_OUT_KEYWORDS,
  isValidConsentState,
  resolveInitialConsentState,
  isEligible,
  isTransactional,
  isNonTransactional,
  evaluateConsentGate,
  isOptOutKeyword,
  detectOptOutKeyword,
  shouldSendMessage,
  applyOptOut,
  type ConsentProfile,
} from '../consent.service';

// ── Consent State Machine ─────────────────────────────────────────────────────

describe('Consent State Machine', () => {
  describe('CONSENT_STATES', () => {
    it('contains exactly three legal values', () => {
      expect(CONSENT_STATES).toEqual(['opted_in', 'opted_out', 'pending']);
      expect(CONSENT_STATES).toHaveLength(3);
    });
  });

  describe('DEFAULT_CONSENT_STATE', () => {
    it('defaults to pending (Req 2.4)', () => {
      expect(DEFAULT_CONSENT_STATE).toBe('pending');
    });
  });

  describe('isValidConsentState', () => {
    it('accepts opted_in', () => expect(isValidConsentState('opted_in')).toBe(true));
    it('accepts opted_out', () => expect(isValidConsentState('opted_out')).toBe(true));
    it('accepts pending', () => expect(isValidConsentState('pending')).toBe(true));
    it('rejects empty string', () => expect(isValidConsentState('')).toBe(false));
    it('rejects null', () => expect(isValidConsentState(null)).toBe(false));
    it('rejects undefined', () => expect(isValidConsentState(undefined)).toBe(false));
    it('rejects number', () => expect(isValidConsentState(42)).toBe(false));
    it('rejects random string', () => expect(isValidConsentState('active')).toBe(false));
    it('rejects similar but wrong string', () => expect(isValidConsentState('opt_in')).toBe(false));
  });

  describe('resolveInitialConsentState', () => {
    it('returns pending when no explicit state provided', () => {
      expect(resolveInitialConsentState()).toBe('pending');
      expect(resolveInitialConsentState(null)).toBe('pending');
      expect(resolveInitialConsentState(undefined)).toBe('pending');
    });

    it('returns the explicit state when valid', () => {
      expect(resolveInitialConsentState('opted_in')).toBe('opted_in');
      expect(resolveInitialConsentState('opted_out')).toBe('opted_out');
      expect(resolveInitialConsentState('pending')).toBe('pending');
    });

    it('returns pending for invalid explicit state', () => {
      expect(resolveInitialConsentState('invalid' as any)).toBe('pending');
    });
  });
});

// ── Eligibility Derivation ────────────────────────────────────────────────────

describe('Eligibility Derivation', () => {
  describe('isEligible', () => {
    it('returns true for valid E.164 + opted_in (Req 2.9)', () => {
      const profile: ConsentProfile = {
        whatsappNumber: '+919876543210',
        consentState: 'opted_in',
      };
      expect(isEligible(profile)).toBe(true);
    });

    it('returns false when consent is opted_out (Req 2.10)', () => {
      const profile: ConsentProfile = {
        whatsappNumber: '+919876543210',
        consentState: 'opted_out',
      };
      expect(isEligible(profile)).toBe(false);
    });

    it('returns false when consent is pending (Req 2.10)', () => {
      const profile: ConsentProfile = {
        whatsappNumber: '+919876543210',
        consentState: 'pending',
      };
      expect(isEligible(profile)).toBe(false);
    });

    it('returns false when phone number is invalid', () => {
      const profile: ConsentProfile = {
        whatsappNumber: '9876543210', // missing + prefix
        consentState: 'opted_in',
      };
      expect(isEligible(profile)).toBe(false);
    });

    it('returns false when phone number is empty', () => {
      const profile: ConsentProfile = {
        whatsappNumber: '',
        consentState: 'opted_in',
      };
      expect(isEligible(profile)).toBe(false);
    });

    it('returns false when phone number too short', () => {
      const profile: ConsentProfile = {
        whatsappNumber: '+1234567', // 7 digits, needs 8-15
        consentState: 'opted_in',
      };
      expect(isEligible(profile)).toBe(false);
    });

    it('returns false when phone number too long', () => {
      const profile: ConsentProfile = {
        whatsappNumber: '+1234567890123456', // 16 digits, max 15
        consentState: 'opted_in',
      };
      expect(isEligible(profile)).toBe(false);
    });

    it('returns false when BOTH conditions fail', () => {
      const profile: ConsentProfile = {
        whatsappNumber: 'not-a-number',
        consentState: 'opted_out',
      };
      expect(isEligible(profile)).toBe(false);
    });
  });
});

// ── Message Category Classification ──────────────────────────────────────────

describe('Message Category Classification', () => {
  it('classifies transactional correctly', () => {
    expect(isTransactional('transactional')).toBe(true);
    expect(isTransactional('non_transactional')).toBe(false);
  });

  it('classifies non_transactional correctly', () => {
    expect(isNonTransactional('non_transactional')).toBe(true);
    expect(isNonTransactional('transactional')).toBe(false);
  });
});

// ── Consent Gate ──────────────────────────────────────────────────────────────

describe('Consent Gate', () => {
  describe('evaluateConsentGate', () => {
    it('allows transactional messages regardless of consent state (Req 2.5)', () => {
      expect(evaluateConsentGate('opted_in', 'transactional').allowed).toBe(true);
      expect(evaluateConsentGate('opted_out', 'transactional').allowed).toBe(true);
      expect(evaluateConsentGate('pending', 'transactional').allowed).toBe(true);
    });

    it('allows non-transactional messages when opted_in', () => {
      const result = evaluateConsentGate('opted_in', 'non_transactional');
      expect(result.allowed).toBe(true);
      expect(result.reason).toBeUndefined();
    });

    it('blocks non-transactional messages when opted_out (Req 6.9, 13.5)', () => {
      const result = evaluateConsentGate('opted_out', 'non_transactional');
      expect(result.allowed).toBe(false);
      expect(result.reason).toContain('opted out');
    });

    it('blocks non-transactional messages when pending (Req 2.5)', () => {
      const result = evaluateConsentGate('pending', 'non_transactional');
      expect(result.allowed).toBe(false);
      expect(result.reason).toContain('pending');
    });
  });

  describe('shouldSendMessage', () => {
    it('blocks when phone number is invalid regardless of category', () => {
      const profile: ConsentProfile = {
        whatsappNumber: 'invalid',
        consentState: 'opted_in',
      };
      expect(shouldSendMessage(profile, 'transactional').allowed).toBe(false);
      expect(shouldSendMessage(profile, 'non_transactional').allowed).toBe(false);
    });

    it('allows transactional with valid E.164 even if opted_out', () => {
      const profile: ConsentProfile = {
        whatsappNumber: '+919876543210',
        consentState: 'opted_out',
      };
      expect(shouldSendMessage(profile, 'transactional').allowed).toBe(true);
    });

    it('blocks non-transactional when opted_out even with valid E.164', () => {
      const profile: ConsentProfile = {
        whatsappNumber: '+919876543210',
        consentState: 'opted_out',
      };
      const result = shouldSendMessage(profile, 'non_transactional');
      expect(result.allowed).toBe(false);
    });

    it('allows non-transactional only with valid E.164 AND opted_in', () => {
      const profile: ConsentProfile = {
        whatsappNumber: '+919876543210',
        consentState: 'opted_in',
      };
      expect(shouldSendMessage(profile, 'non_transactional').allowed).toBe(true);
    });
  });
});

// ── Opt-Out Keyword Detection ─────────────────────────────────────────────────

describe('Opt-Out Keyword Detection', () => {
  describe('isOptOutKeyword', () => {
    it('detects all recognized keywords exactly', () => {
      for (const kw of OPT_OUT_KEYWORDS) {
        expect(isOptOutKeyword(kw)).toBe(true);
      }
    });

    it('is case-insensitive (Req 2.6)', () => {
      expect(isOptOutKeyword('STOP')).toBe(true);
      expect(isOptOutKeyword('Stop')).toBe(true);
      expect(isOptOutKeyword('sToP')).toBe(true);
      expect(isOptOutKeyword('UNSUBSCRIBE')).toBe(true);
      expect(isOptOutKeyword('Quit')).toBe(true);
    });

    it('trims leading and trailing whitespace (Req 2.6)', () => {
      expect(isOptOutKeyword(' STOP ')).toBe(true);
      expect(isOptOutKeyword('  stop  ')).toBe(true);
      expect(isOptOutKeyword('\tstop\n')).toBe(true);
      expect(isOptOutKeyword('   UNSUBSCRIBE   ')).toBe(true);
      expect(isOptOutKeyword(' opt out ')).toBe(true);
    });

    it('rejects non-keyword messages', () => {
      expect(isOptOutKeyword('hello')).toBe(false);
      expect(isOptOutKeyword('please stop sending')).toBe(false);
      expect(isOptOutKeyword('I want to stop')).toBe(false);
      expect(isOptOutKeyword('stopped')).toBe(false);
    });

    it('rejects empty and whitespace-only strings', () => {
      expect(isOptOutKeyword('')).toBe(false);
      expect(isOptOutKeyword('   ')).toBe(false);
      expect(isOptOutKeyword('\t\n')).toBe(false);
    });
  });

  describe('detectOptOutKeyword', () => {
    it('returns the matched keyword when found', () => {
      expect(detectOptOutKeyword(' STOP ')).toBe('stop');
      expect(detectOptOutKeyword('Cancel')).toBe('cancel');
      expect(detectOptOutKeyword('  OPT OUT  ')).toBe('opt out');
    });

    it('returns null when no keyword matches', () => {
      expect(detectOptOutKeyword('hello')).toBeNull();
      expect(detectOptOutKeyword('')).toBeNull();
      expect(detectOptOutKeyword('   ')).toBeNull();
    });
  });
});

// ── Consent State Transition ──────────────────────────────────────────────────

describe('applyOptOut', () => {
  it('transitions to opted_out when opt-out keyword detected', () => {
    expect(applyOptOut('opted_in', 'STOP')).toBe('opted_out');
    expect(applyOptOut('pending', 'stop')).toBe('opted_out');
    expect(applyOptOut('opted_out', 'stop')).toBe('opted_out');
  });

  it('preserves current state when no keyword detected', () => {
    expect(applyOptOut('opted_in', 'hello')).toBe('opted_in');
    expect(applyOptOut('pending', 'how are you')).toBe('pending');
    expect(applyOptOut('opted_out', 'hi there')).toBe('opted_out');
  });
});
