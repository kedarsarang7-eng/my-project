// ============================================================================
// CIRCUIT BREAKER - Fault tolerance for third-party APIs
// ============================================================================

import { info, error, warn } from './logger.mjs';

const CIRCUIT_STATES = {
  CLOSED: 'CLOSED',       // Normal operation
  OPEN: 'OPEN',           // Failing, rejecting requests
  HALF_OPEN: 'HALF_OPEN',  // Testing if service recovered
};

class CircuitBreaker {
  constructor(name, options = {}) {
    this.name = name;
    this.failureThreshold = options.failureThreshold || 5;
    this.resetTimeout = options.resetTimeout || 30000;  // 30 seconds
    this.monitoringPeriod = options.monitoringPeriod || 60000;  // 1 minute
    
    this.state = CIRCUIT_STATES.CLOSED;
    this.failures = 0;
    this.lastFailureTime = null;
    this.nextAttemptTime = null;
    this.successCount = 0;
    
    // Failure tracking within monitoring period
    this.recentFailures = [];
  }
  
  /**
   * Execute function with circuit breaker protection
   */
  async execute(fn, context = {}) {
    this._cleanupOldFailures();
    
    // Check if circuit is open
    if (this.state === CIRCUIT_STATES.OPEN) {
      if (Date.now() < this.nextAttemptTime) {
        const remainingMs = this.nextAttemptTime - Date.now();
        error(`Circuit breaker OPEN for ${this.name}`, new Error(`Circuit open, retry after ${remainingMs}ms`), {
          circuitState: this.state,
          remainingMs,
          failures: this.failures,
        });
        throw new Error(`Circuit breaker OPEN for ${this.name}: Too many failures. Retry after ${Math.ceil(remainingMs/1000)}s`);
      }
      
      // Move to half-open to test recovery
      this.state = CIRCUIT_STATES.HALF_OPEN;
      info(`Circuit breaker HALF_OPEN for ${this.name} - testing recovery`);
    }
    
    try {
      const result = await fn();
      this._onSuccess();
      return result;
    } catch (err) {
      this._onFailure();
      throw err;
    }
  }
  
  /**
   * Handle successful execution
   */
  _onSuccess() {
    if (this.state === CIRCUIT_STATES.HALF_OPEN) {
      this.successCount++;
      
      // Require consecutive successes to close circuit
      if (this.successCount >= 3) {
        this._closeCircuit();
      }
    } else {
      // In closed state, just track success
      this.successCount++;
    }
  }
  
  /**
   * Handle failed execution
   */
  _onFailure() {
    this.failures++;
    this.lastFailureTime = Date.now();
    this.recentFailures.push(Date.now());
    this.successCount = 0;
    
    // Check if threshold exceeded
    if (this.recentFailures.length >= this.failureThreshold) {
      this._openCircuit();
    }
  }
  
  /**
   * Open the circuit
   */
  _openCircuit() {
    this.state = CIRCUIT_STATES.OPEN;
    this.nextAttemptTime = Date.now() + this.resetTimeout;
    
    warn(`Circuit breaker OPENED for ${this.name}`, {
      failures: this.failures,
      resetAt: new Date(this.nextAttemptTime).toISOString(),
    });
  }
  
  /**
   * Close the circuit
   */
  _closeCircuit() {
    this.state = CIRCUIT_STATES.CLOSED;
    this.failures = 0;
    this.recentFailures = [];
    this.successCount = 0;
    
    info(`Circuit breaker CLOSED for ${this.name} - service recovered`);
  }
  
  /**
   * Clean up old failures outside monitoring period
   */
  _cleanupOldFailures() {
    const cutoff = Date.now() - this.monitoringPeriod;
    this.recentFailures = this.recentFailures.filter(t => t > cutoff);
  }
  
  /**
   * Get current circuit state
   */
  getState() {
    return {
      name: this.name,
      state: this.state,
      failures: this.failures,
      recentFailureCount: this.recentFailures.length,
      lastFailureTime: this.lastFailureTime,
      nextAttemptTime: this.nextAttemptTime,
      successCount: this.successCount,
    };
  }
  
  /**
   * Force circuit to closed state (admin override)
   */
  reset() {
    this._closeCircuit();
    info(`Circuit breaker RESET for ${this.name}`);
  }
}

// Circuit breaker instances for specific services
const circuitBreakers = new Map();

/**
 * Get or create circuit breaker for a service
 */
export function getCircuitBreaker(name, options) {
  if (!circuitBreakers.has(name)) {
    circuitBreakers.set(name, new CircuitBreaker(name, options));
  }
  return circuitBreakers.get(name);
}

/**
 * Execute with circuit breaker protection
 */
export async function withCircuitBreaker(name, fn, options = {}, context = {}) {
  const breaker = getCircuitBreaker(name, options);
  return breaker.execute(fn, context);
}

/**
 * Payment gateway circuit breaker (stricter settings)
 */
export async function withPaymentGatewayBreaker(fn, context = {}) {
  return withCircuitBreaker(
    'PaymentGateway',
    fn,
    {
      failureThreshold: 3,      // Lower threshold for payments
      resetTimeout: 60000,       // 1 minute before retry
      monitoringPeriod: 120000,  // 2 minute monitoring window
    },
    context
  );
}

/**
 * External API circuit breaker (standard settings)
 */
export async function withExternalAPIBreaker(serviceName, fn, context = {}) {
  return withCircuitBreaker(
    `ExternalAPI:${serviceName}`,
    fn,
    {
      failureThreshold: 5,
      resetTimeout: 30000,
      monitoringPeriod: 60000,
    },
    context
  );
}

/**
 * Get all circuit breaker states (for health checks)
 */
export function getAllCircuitBreakerStates() {
  const states = {};
  for (const [name, breaker] of circuitBreakers) {
    states[name] = breaker.getState();
  }
  return states;
}

/**
 * Reset all circuit breakers
 */
export function resetAllCircuitBreakers() {
  for (const breaker of circuitBreakers.values()) {
    breaker.reset();
  }
}
