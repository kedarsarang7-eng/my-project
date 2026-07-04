// ============================================================================
// Staff Module — Sandboxed AST Formula Evaluator (Task 10.1)
// ============================================================================
// Parses custom performance/commission formulas to an AST via `jsep`, validates
// against a function whitelist and enforced complexity limits, then interprets
// the AST with our own tree-walking evaluator. ABSOLUTELY no eval() / new
// Function() / Function constructor or any dynamic code execution mechanism.
//
// AD-5 — SANDBOXED AST FORMULA EVALUATOR
// ───────────────────────────────────────
// - parse(formula)       → jsep AST (Expression)
// - validate(ast)        → { ok: true } | { ok: false, error: string }
// - evaluate(ast, ctx)   → number (deterministic)
//
// SECURITY INVARIANTS:
//   1. Only whitelisted functions can be called (FUNCTION_WHITELIST).
//   2. Complexity is bounded (max nodes + max depth) to prevent DoS.
//   3. Unknown node types, operators, or identifiers → FORMULA_REJECTED.
//   4. The evaluator is deterministic: same inputs → same output.
//
// Requirements: 7.4 (sandboxed AST evaluator with whitelist + limits),
//               7.5 (no eval/new Function),
//               7.6 (reject non-whitelisted or over-complex with FORMULA_REJECTED).
// ============================================================================

import jsep from 'jsep';
import { AppError } from '../../../utils/errors';

// ── Types ─────────────────────────────────────────────────────────────────────

/** The result of AST validation. */
export type ValidationResult =
    | { ok: true }
    | { ok: false; error: string };

/** Context map supplying variable values during evaluation. */
export type FormulaContext = Record<string, number>;

// Re-export the jsep Expression type for external use.
export type FormulaAST = jsep.Expression;

// ── Configuration ─────────────────────────────────────────────────────────────

/**
 * Whitelisted functions that can be called in formulas.
 * Each maps to a pure Math function or a safe numeric utility.
 */
export const FUNCTION_WHITELIST: Record<string, (...args: number[]) => number> = {
    // Basic math
    abs: Math.abs,
    ceil: Math.ceil,
    floor: Math.floor,
    round: Math.round,
    trunc: Math.trunc,
    sign: Math.sign,

    // Powers and roots
    sqrt: Math.sqrt,
    cbrt: Math.cbrt,
    pow: Math.pow,

    // Min / max / clamp
    min: Math.min,
    max: Math.max,
    clamp: (value: number, lo: number, hi: number) => Math.min(Math.max(value, lo), hi),

    // Logarithms
    log: Math.log,
    log2: Math.log2,
    log10: Math.log10,

    // Trigonometry (useful for seasonal commission curves)
    sin: Math.sin,
    cos: Math.cos,
    tan: Math.tan,
};

/** Maximum number of AST nodes allowed in a single formula. */
export const MAX_NODES = 100;

/** Maximum AST depth (nesting level) allowed. */
export const MAX_DEPTH = 15;

/** Allowed binary operators. */
const ALLOWED_BINARY_OPS = new Set(['+', '-', '*', '/', '%', '**']);

/** Allowed unary operators. */
const ALLOWED_UNARY_OPS = new Set(['-', '+']);

// ── Error code ────────────────────────────────────────────────────────────────

const FORMULA_REJECTED_CODE = 'FORMULA_REJECTED';

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Parse a formula string into a jsep AST.
 *
 * @param formula - The formula string (e.g. "base_salary * 0.1 + max(bonus, 500)")
 * @returns The parsed AST
 * @throws AppError with FORMULA_REJECTED if the formula is syntactically invalid
 */
export function parse(formula: string): FormulaAST {
    if (typeof formula !== 'string' || formula.trim().length === 0) {
        throw new AppError(
            FORMULA_REJECTED_CODE,
            'Formula must be a non-empty string',
        );
    }

    try {
        const ast = jsep(formula);
        return ast;
    } catch (err) {
        throw new AppError(
            FORMULA_REJECTED_CODE,
            `Formula syntax error: ${(err as Error).message}`,
        );
    }
}

/**
 * Validate a parsed AST against the function whitelist and complexity limits.
 *
 * @param ast - The parsed formula AST
 * @returns Validation result (ok or descriptive error)
 */
export function validate(ast: FormulaAST): ValidationResult {
    // Count total nodes and max depth via recursive traversal.
    let nodeCount = 0;

    function walk(node: jsep.Expression, depth: number): string | null {
        nodeCount++;

        if (nodeCount > MAX_NODES) {
            return `Formula exceeds maximum complexity (${MAX_NODES} nodes)`;
        }
        if (depth > MAX_DEPTH) {
            return `Formula exceeds maximum nesting depth (${MAX_DEPTH} levels)`;
        }

        switch (node.type) {
            case 'Literal': {
                const lit = node as jsep.Literal;
                // Only allow numeric literals (and null for safety).
                if (typeof lit.value !== 'number' && lit.value !== null) {
                    return `Non-numeric literal not allowed: ${lit.raw}`;
                }
                return null;
            }

            case 'Identifier':
                // Identifiers are context variables — allowed as long as they
                // are not built-in globals (we don't resolve __proto__, etc.).
                return null;

            case 'BinaryExpression': {
                const bin = node as jsep.BinaryExpression;
                if (!ALLOWED_BINARY_OPS.has(bin.operator)) {
                    return `Binary operator not allowed: '${bin.operator}'`;
                }
                return (
                    walk(bin.left as jsep.Expression, depth + 1) ||
                    walk(bin.right as jsep.Expression, depth + 1)
                );
            }

            case 'UnaryExpression': {
                const un = node as jsep.UnaryExpression;
                if (!ALLOWED_UNARY_OPS.has(un.operator)) {
                    return `Unary operator not allowed: '${un.operator}'`;
                }
                return walk(un.argument as jsep.Expression, depth + 1);
            }

            case 'CallExpression': {
                const call = node as jsep.CallExpression;
                // Callee must be a simple Identifier naming a whitelisted function.
                if (call.callee.type !== 'Identifier') {
                    return 'Only direct function calls are allowed (no computed callees)';
                }
                const fnName = (call.callee as jsep.Identifier).name;
                if (!(fnName in FUNCTION_WHITELIST)) {
                    return `Function not allowed: '${fnName}'`;
                }
                // Validate each argument.
                for (const arg of call.arguments) {
                    const err = walk(arg as jsep.Expression, depth + 1);
                    if (err) return err;
                }
                return null;
            }

            case 'ConditionalExpression': {
                const cond = node as jsep.ConditionalExpression;
                return (
                    walk(cond.test as jsep.Expression, depth + 1) ||
                    walk(cond.consequent as jsep.Expression, depth + 1) ||
                    walk(cond.alternate as jsep.Expression, depth + 1)
                );
            }

            // MemberExpression, ArrayExpression, Compound, ThisExpression, etc.
            // are NOT allowed in safe formulas.
            default:
                return `Node type not allowed: '${node.type}'`;
        }
    }

    const error = walk(ast, 1);
    if (error) {
        return { ok: false, error };
    }
    return { ok: true };
}

/**
 * Evaluate a validated AST against a context of variable→number bindings.
 *
 * PRECONDITION: The AST MUST have passed `validate()` before calling evaluate.
 * If the AST is invalid, behavior is undefined (it may throw FORMULA_REJECTED).
 *
 * @param ast     - The validated formula AST
 * @param context - Variable bindings (e.g. { base_salary: 50000, bonus: 1000 })
 * @returns The computed numeric result (deterministic)
 * @throws AppError with FORMULA_REJECTED on evaluation errors
 */
export function evaluate(ast: FormulaAST, context: FormulaContext): number {
    const result = evalNode(ast, context);

    // Guard against NaN / Infinity propagating silently.
    if (!Number.isFinite(result)) {
        throw new AppError(
            FORMULA_REJECTED_CODE,
            `Formula produced a non-finite result: ${result}`,
        );
    }
    return result;
}

// ── Internal tree-walking evaluator ──────────────────────────────────────────

function evalNode(node: jsep.Expression, ctx: FormulaContext): number {
    switch (node.type) {
        case 'Literal': {
            const lit = node as jsep.Literal;
            if (typeof lit.value === 'number') return lit.value;
            if (lit.value === null) return 0;
            throw new AppError(
                FORMULA_REJECTED_CODE,
                `Unsupported literal: ${lit.raw}`,
            );
        }

        case 'Identifier': {
            const id = node as jsep.Identifier;
            if (!(id.name in ctx)) {
                throw new AppError(
                    FORMULA_REJECTED_CODE,
                    `Undefined variable: '${id.name}'`,
                );
            }
            const val = ctx[id.name];
            if (typeof val !== 'number') {
                throw new AppError(
                    FORMULA_REJECTED_CODE,
                    `Variable '${id.name}' must be a number`,
                );
            }
            return val;
        }

        case 'BinaryExpression': {
            const bin = node as jsep.BinaryExpression;
            const left = evalNode(bin.left as jsep.Expression, ctx);
            const right = evalNode(bin.right as jsep.Expression, ctx);
            return evalBinaryOp(bin.operator, left, right);
        }

        case 'UnaryExpression': {
            const un = node as jsep.UnaryExpression;
            const arg = evalNode(un.argument as jsep.Expression, ctx);
            if (un.operator === '-') return -arg;
            if (un.operator === '+') return +arg;
            throw new AppError(
                FORMULA_REJECTED_CODE,
                `Unsupported unary operator: '${un.operator}'`,
            );
        }

        case 'CallExpression': {
            const call = node as jsep.CallExpression;
            const fnName = (call.callee as jsep.Identifier).name;
            const fn = FUNCTION_WHITELIST[fnName];
            if (!fn) {
                throw new AppError(
                    FORMULA_REJECTED_CODE,
                    `Function not whitelisted: '${fnName}'`,
                );
            }
            const args = call.arguments.map((a) =>
                evalNode(a as jsep.Expression, ctx),
            );
            return fn(...args);
        }

        case 'ConditionalExpression': {
            const cond = node as jsep.ConditionalExpression;
            const test = evalNode(cond.test as jsep.Expression, ctx);
            // Truthy: any non-zero value.
            return test !== 0
                ? evalNode(cond.consequent as jsep.Expression, ctx)
                : evalNode(cond.alternate as jsep.Expression, ctx);
        }

        default:
            throw new AppError(
                FORMULA_REJECTED_CODE,
                `Unsupported node type during evaluation: '${node.type}'`,
            );
    }
}

function evalBinaryOp(op: string, left: number, right: number): number {
    switch (op) {
        case '+': return left + right;
        case '-': return left - right;
        case '*': return left * right;
        case '/':
            if (right === 0) {
                throw new AppError(
                    FORMULA_REJECTED_CODE,
                    'Division by zero',
                );
            }
            return left / right;
        case '%':
            if (right === 0) {
                throw new AppError(
                    FORMULA_REJECTED_CODE,
                    'Modulo by zero',
                );
            }
            return left % right;
        case '**': return left ** right;
        default:
            throw new AppError(
                FORMULA_REJECTED_CODE,
                `Unsupported binary operator: '${op}'`,
            );
    }
}
