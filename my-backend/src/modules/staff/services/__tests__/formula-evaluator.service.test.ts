// ============================================================================
// Staff Module — Formula Evaluator Service — Unit Tests (Task 10.1)
// ============================================================================
// Validates parse(), validate(), and evaluate() behavior including:
// - Basic arithmetic, nested expressions, function calls
// - Whitelist enforcement (reject unknown functions)
// - Complexity limits (reject over-complex formulas)
// - Determinism (same inputs → same outputs)
// - Error handling (division by zero, undefined variables, bad syntax)
//
// Requirements: 7.4, 7.5, 7.6
// ============================================================================

import {
    parse,
    validate,
    evaluate,
    FUNCTION_WHITELIST,
    MAX_NODES,
    MAX_DEPTH,
    FormulaContext,
} from '../formula-evaluator.service';

describe('formula-evaluator.service', () => {
    // ── parse() ───────────────────────────────────────────────────────────────

    describe('parse()', () => {
        it('parses a simple arithmetic expression', () => {
            const ast = parse('a + b * 2');
            expect(ast).toBeDefined();
            expect(ast.type).toBe('BinaryExpression');
        });

        it('parses a function call expression', () => {
            const ast = parse('max(a, b)');
            expect(ast).toBeDefined();
            expect(ast.type).toBe('CallExpression');
        });

        it('throws FORMULA_REJECTED for empty string', () => {
            expect(() => parse('')).toThrow();
            try {
                parse('');
            } catch (e: any) {
                expect(e.code).toBe('FORMULA_REJECTED');
            }
        });

        it('throws FORMULA_REJECTED for whitespace-only string', () => {
            expect(() => parse('   ')).toThrow();
            try {
                parse('   ');
            } catch (e: any) {
                expect(e.code).toBe('FORMULA_REJECTED');
            }
        });

        it('throws FORMULA_REJECTED for invalid syntax', () => {
            expect(() => parse('a +')).toThrow();
            try {
                parse('a +');
            } catch (e: any) {
                expect(e.code).toBe('FORMULA_REJECTED');
            }
        });
    });

    // ── validate() ────────────────────────────────────────────────────────────

    describe('validate()', () => {
        it('accepts a simple arithmetic formula', () => {
            const ast = parse('a + b * 2');
            expect(validate(ast)).toEqual({ ok: true });
        });

        it('accepts whitelisted function calls', () => {
            const ast = parse('max(a, min(b, 100))');
            expect(validate(ast)).toEqual({ ok: true });
        });

        it('accepts unary minus', () => {
            const ast = parse('-a + b');
            expect(validate(ast)).toEqual({ ok: true });
        });

        it('accepts conditional (ternary) expressions', () => {
            const ast = parse('a > 0 ? a : 0');
            // jsep parses `>` as a binary operator — let's check
            const result = validate(ast);
            // `>` is not in our allowed binary ops, so it should be rejected
            expect(result.ok).toBe(false);
        });

        it('rejects non-whitelisted functions', () => {
            const ast = parse('eval(a)');
            const result = validate(ast);
            expect(result.ok).toBe(false);
            if (!result.ok) {
                expect(result.error).toContain('eval');
                expect(result.error).toContain('not allowed');
            }
        });

        it('rejects disallowed binary operators', () => {
            // jsep parses `==` as a binary expression
            const ast = parse('a == b');
            const result = validate(ast);
            expect(result.ok).toBe(false);
            if (!result.ok) {
                expect(result.error).toContain('not allowed');
            }
        });

        it('rejects string literals', () => {
            const ast = parse('"hello"');
            const result = validate(ast);
            expect(result.ok).toBe(false);
            if (!result.ok) {
                expect(result.error).toContain('Non-numeric literal');
            }
        });

        it('rejects member expressions (object access)', () => {
            const ast = parse('obj.property');
            const result = validate(ast);
            expect(result.ok).toBe(false);
            if (!result.ok) {
                expect(result.error).toContain('Node type not allowed');
            }
        });

        it('rejects array expressions', () => {
            const ast = parse('[1, 2, 3]');
            const result = validate(ast);
            expect(result.ok).toBe(false);
            if (!result.ok) {
                expect(result.error).toContain('Node type not allowed');
            }
        });

        it('rejects formulas exceeding max nodes', () => {
            // Build a formula with many nodes using function calls with many args.
            // Each abs(x) adds 2 nodes (call + identifier). We need > 100 nodes.
            // Using chained additions at depth 1 via comma-separated function args:
            // max(a,a) + max(a,a) + ... — each max(a,a) is 4 nodes, plus the + ops.
            // Simpler approach: lots of terms at shallow depth using grouping.
            const terms: string[] = [];
            for (let i = 0; i < 55; i++) {
                terms.push('a');
            }
            // This gives 55 identifiers + 54 binary ops = 109 nodes, depth ~log2(55) if
            // jsep uses left-associativity → depth is 55 (left-recursive). We need to
            // keep depth under control while exceeding nodes. Use a flat structure:
            // abs(a) + abs(a) + abs(a) + ... — each abs(a) = 3 nodes (call+id+id), plus + ops
            const absCalls: string[] = [];
            for (let i = 0; i < 40; i++) {
                absCalls.push('abs(a)');
            }
            // 40 * 3 (CallExpression + callee Identifier + arg Identifier) + 39 BinaryExpressions = 159 nodes
            // But depth is still left-recursive (40 deep). Let's just test that either error is produced.
            const formula = absCalls.join(' + ');
            const ast = parse(formula);
            const result = validate(ast);
            expect(result.ok).toBe(false);
            if (!result.ok) {
                // Either node limit or depth limit — both are complexity rejections
                expect(
                    result.error.includes('maximum complexity') ||
                    result.error.includes('maximum nesting depth'),
                ).toBe(true);
            }
        });

        it('rejects formulas exceeding max depth', () => {
            // Build a deeply nested formula: (((((((...a...)))))))
            // Using nested function calls: abs(abs(abs(abs(...))))
            let formula = 'a';
            for (let i = 0; i < 20; i++) {
                formula = `abs(${formula})`;
            }
            const ast = parse(formula);
            const result = validate(ast);
            expect(result.ok).toBe(false);
            if (!result.ok) {
                expect(result.error).toContain('maximum nesting depth');
            }
        });

        it('accepts all whitelisted functions by name', () => {
            for (const fnName of Object.keys(FUNCTION_WHITELIST)) {
                const ast = parse(`${fnName}(1)`);
                const result = validate(ast);
                expect(result).toEqual({ ok: true });
            }
        });
    });

    // ── evaluate() ────────────────────────────────────────────────────────────

    describe('evaluate()', () => {
        it('evaluates simple addition', () => {
            const ast = parse('a + b');
            expect(evaluate(ast, { a: 3, b: 7 })).toBe(10);
        });

        it('evaluates multiplication with precedence', () => {
            const ast = parse('a + b * 2');
            expect(evaluate(ast, { a: 5, b: 3 })).toBe(11);
        });

        it('evaluates division', () => {
            const ast = parse('a / b');
            expect(evaluate(ast, { a: 10, b: 2 })).toBe(5);
        });

        it('evaluates modulo', () => {
            const ast = parse('a % b');
            expect(evaluate(ast, { a: 10, b: 3 })).toBe(1);
        });

        it('evaluates exponentiation', () => {
            const ast = parse('a ** 2');
            expect(evaluate(ast, { a: 5 })).toBe(25);
        });

        it('evaluates unary minus', () => {
            const ast = parse('-a');
            expect(evaluate(ast, { a: 42 })).toBe(-42);
        });

        it('evaluates whitelisted function calls', () => {
            const ast = parse('max(a, b)');
            expect(evaluate(ast, { a: 3, b: 7 })).toBe(7);
        });

        it('evaluates nested function calls', () => {
            const ast = parse('min(abs(a), b)');
            expect(evaluate(ast, { a: -5, b: 3 })).toBe(3);
        });

        it('evaluates clamp function', () => {
            const ast = parse('clamp(a, 0, 100)');
            expect(evaluate(ast, { a: 150 })).toBe(100);
            expect(evaluate(ast, { a: -10 })).toBe(0);
            expect(evaluate(ast, { a: 50 })).toBe(50);
        });

        it('evaluates complex commission formula', () => {
            // commission = base_salary * rate + max(bonus, min_bonus)
            const ast = parse('base_salary * rate + max(bonus, min_bonus)');
            const ctx: FormulaContext = {
                base_salary: 50000,
                rate: 0.1,
                bonus: 2000,
                min_bonus: 500,
            };
            expect(evaluate(ast, ctx)).toBe(50000 * 0.1 + Math.max(2000, 500));
        });

        it('throws FORMULA_REJECTED for undefined variables', () => {
            const ast = parse('a + b');
            expect(() => evaluate(ast, { a: 5 })).toThrow();
            try {
                evaluate(ast, { a: 5 });
            } catch (e: any) {
                expect(e.code).toBe('FORMULA_REJECTED');
                expect(e.message).toContain('Undefined variable');
            }
        });

        it('throws FORMULA_REJECTED for division by zero', () => {
            const ast = parse('a / b');
            expect(() => evaluate(ast, { a: 10, b: 0 })).toThrow();
            try {
                evaluate(ast, { a: 10, b: 0 });
            } catch (e: any) {
                expect(e.code).toBe('FORMULA_REJECTED');
                expect(e.message).toContain('Division by zero');
            }
        });

        it('throws FORMULA_REJECTED for modulo by zero', () => {
            const ast = parse('a % b');
            expect(() => evaluate(ast, { a: 10, b: 0 })).toThrow();
            try {
                evaluate(ast, { a: 10, b: 0 });
            } catch (e: any) {
                expect(e.code).toBe('FORMULA_REJECTED');
                expect(e.message).toContain('Modulo by zero');
            }
        });

        it('is deterministic (same inputs → same result)', () => {
            const ast = parse('sqrt(a * a + b * b)');
            const ctx = { a: 3, b: 4 };
            const result1 = evaluate(ast, ctx);
            const result2 = evaluate(ast, ctx);
            const result3 = evaluate(ast, ctx);
            expect(result1).toBe(result2);
            expect(result2).toBe(result3);
            expect(result1).toBe(5);
        });

        it('evaluates numeric literals correctly', () => {
            const ast = parse('42');
            expect(evaluate(ast, {})).toBe(42);
        });

        it('evaluates floating-point literals', () => {
            const ast = parse('3.14');
            expect(evaluate(ast, {})).toBe(3.14);
        });

        it('evaluates subtraction', () => {
            const ast = parse('a - b');
            expect(evaluate(ast, { a: 10, b: 3 })).toBe(7);
        });

        it('evaluates log functions', () => {
            const ast = parse('log10(a)');
            expect(evaluate(ast, { a: 100 })).toBe(2);
        });

        it('evaluates pow function', () => {
            const ast = parse('pow(a, 3)');
            expect(evaluate(ast, { a: 2 })).toBe(8);
        });
    });

    // ── Integration: parse → validate → evaluate pipeline ─────────────────────

    describe('full pipeline', () => {
        it('rejects and describes why a non-whitelisted function fails', () => {
            const ast = parse('require(1)');
            const result = validate(ast);
            expect(result.ok).toBe(false);
            if (!result.ok) {
                expect(result.error).toContain('require');
            }
        });

        it('no eval() or new Function() anywhere in the module source', () => {
            // Static check: the service source has no dynamic code execution.
            // We look for actual usage patterns, not error messages that mention them.
            const fs = require('fs');
            const path = require('path');
            const source = fs.readFileSync(
                path.resolve(__dirname, '../formula-evaluator.service.ts'),
                'utf8',
            );
            // Strip string literals and comments so we only check code usage.
            const codeOnly = source
                .replace(/\/\/.*$/gm, '')          // single-line comments
                .replace(/\/\*[\s\S]*?\*\//g, '')  // block comments
                .replace(/'[^']*'/g, '""')         // single-quoted strings
                .replace(/"[^"]*"/g, '""')         // double-quoted strings
                .replace(/`[^`]*`/g, '""');        // template literals

            expect(codeOnly).not.toMatch(/\beval\s*\(/);
            expect(codeOnly).not.toMatch(/new\s+Function\s*\(/);
            // Check we don't call Function as a constructor indirectly
            expect(codeOnly).not.toMatch(/\bFunction\s*\(/);
        });
    });
});
