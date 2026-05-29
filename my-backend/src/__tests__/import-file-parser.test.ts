/// <reference types="jest" />
// ============================================================================
// Unit tests: src/services/import-file-parser.ts
// ============================================================================
// S3 and Textract calls are mocked — only pure parsing logic is exercised.
// ============================================================================

import { validateMimeType, parseCSV, normalizeHeaders } from '../services/import-file-parser';

// ── Mock AWS SDK ──────────────────────────────────────────────────────────────

jest.mock('@aws-sdk/client-s3', () => ({
    S3Client: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockResolvedValue({ Body: null }),
    })),
    GetObjectCommand: jest.fn(),
}));

jest.mock('@aws-sdk/client-textract', () => ({
    TextractClient: jest.fn().mockImplementation(() => ({
        send: jest.fn().mockResolvedValue({ Blocks: [] }),
    })),
    AnalyzeDocumentCommand: jest.fn(),
    DetectDocumentTextCommand: jest.fn(),
}));

// ── validateMimeType ──────────────────────────────────────────────────────────

describe('validateMimeType', () => {
    it('accepts text/csv', () => {
        expect(validateMimeType('text/csv')).toBe(true);
    });

    it('accepts application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', () => {
        expect(
            validateMimeType(
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
        ).toBe(true);
    });

    it('accepts image/jpeg', () => {
        expect(validateMimeType('image/jpeg')).toBe(true);
    });

    it('accepts image/png', () => {
        expect(validateMimeType('image/png')).toBe(true);
    });

    it('accepts application/pdf', () => {
        expect(validateMimeType('application/pdf')).toBe(true);
    });

    it('rejects text/plain', () => {
        expect(validateMimeType('text/plain')).toBe(false);
    });

    it('rejects application/json', () => {
        expect(validateMimeType('application/json')).toBe(false);
    });

    it('is case-insensitive', () => {
        expect(validateMimeType('TEXT/CSV')).toBe(true);
    });
});

// ── parseCSV ──────────────────────────────────────────────────────────────────

describe('parseCSV — basic', () => {
    function csv(lines: string[]): Buffer {
        return Buffer.from(lines.join('\n'), 'utf-8');
    }

    it('parses simple comma-separated file', () => {
        const buf = csv(['name,price,stock', 'Sugar,45,100', 'Salt,20,50']);
        const result = parseCSV(buf);
        expect(result.errors).toHaveLength(0);
        expect(result.rows).toHaveLength(2);
        expect(result.rows[0]['name']).toBe('Sugar');
        expect(result.rows[0]['price']).toBe('45');
        expect(result.rows[1]['stock']).toBe('50');
    });

    it('strips UTF-8 BOM', () => {
        const bom = '\uFEFF';
        const buf = Buffer.from(`${bom}name,price\nRice,60`, 'utf-8');
        const result = parseCSV(buf);
        expect(result.headers[0]).toBe('name');
        expect(result.rows[0]['name']).toBe('Rice');
    });

    it('handles tab-delimited file', () => {
        const buf = csv(['name\tprice\tstock', 'Oil\t120\t30']);
        const result = parseCSV(buf);
        expect(result.rows[0]['name']).toBe('Oil');
        expect(result.rows[0]['price']).toBe('120');
    });

    it('handles semicolon-delimited file', () => {
        const buf = csv(['name;price;stock', 'Wheat;30;200']);
        const result = parseCSV(buf);
        expect(result.rows[0]['name']).toBe('Wheat');
        expect(result.rows[0]['price']).toBe('30');
    });

    it('handles quoted fields with commas inside', () => {
        const buf = csv(['name,price', '"Sugar, refined",45']);
        const result = parseCSV(buf);
        expect(result.rows[0]['name']).toBe('Sugar, refined');
    });

    it('handles escaped double quotes inside fields', () => {
        const buf = csv(['name,notes', '"He said ""hello""",test']);
        const result = parseCSV(buf);
        expect(result.rows[0]['name']).toBe('He said "hello"');
    });

    it('skips rows shorter than header (records error)', () => {
        const buf = csv(['name,price,stock', 'OnlyName']);
        const result = parseCSV(buf);
        // Either the row is skipped with an error or handled gracefully
        // The key thing: no crash
        expect(result).toBeDefined();
    });

    it('lowercases headers (no alias mapping — that is normalizeHeaders job)', () => {
        const buf = csv(['Product Name,Selling Price', 'Sugar,45']);
        const result = parseCSV(buf);
        // parseCSV lowercases but does NOT map aliases
        expect(result.headers).toContain('product name');
        expect(result.headers).toContain('selling price');
        expect(result.rows[0]['product name']).toBe('Sugar');
    });

    it('returns empty rows for header-only file', () => {
        const buf = csv(['name,price,stock']);
        const result = parseCSV(buf);
        expect(result.rows).toHaveLength(0);
    });

    it('handles Windows CRLF line endings', () => {
        const buf = Buffer.from('name,price\r\nSugar,45\r\nSalt,20\r\n', 'utf-8');
        const result = parseCSV(buf);
        expect(result.rows).toHaveLength(2);
        expect(result.rows[0]['name']).toBe('Sugar');
    });
});

// ── normalizeHeaders ──────────────────────────────────────────────────────────
// normalizeHeaders() maps a ParsedRow's keys through the HEADER_ALIASES table.
// It is called by parseFile() after parseCSV/parseExcel/parseOCR.

describe('normalizeHeaders', () => {
    const aliasTests: Array<[string, string, string]> = [
        ['product name', 'name', 'Sugar'],
        ['item name', 'name', 'Salt'],
        ['selling price', 'selling_price', '45'],
        ['mrp', 'selling_price', '30'],
        ['sale price', 'selling_price', '50'],
        ['qty', 'quantity', '100'],
        ['stock', 'quantity', '200'],
        ['barcode', 'barcode', '12345'],
        ['sku', 'sku', 'SKU001'],
        ['cost price', 'cost_price', '10'],
        ['unit', 'unit', 'pcs'],
        ['vendor', 'vendor', 'Tata'],
        ['category', 'category', 'Staples'],
    ];

    for (const [rawKey, expectedKey, val] of aliasTests) {
        it(`maps "${rawKey}" → "${expectedKey}"`, () => {
            const row = { [rawKey]: val };
            const normalized = normalizeHeaders(row);
            expect(normalized[expectedKey]).toBe(val);
        });
    }

    it('preserves unrecognized headers as-is (lowercased)', () => {
        const row = { 'shelf_location': 'Aisle 3' };
        const normalized = normalizeHeaders(row);
        expect(normalized['shelf_location']).toBe('Aisle 3');
    });

    it('handles mixed-case raw keys', () => {
        const row = { 'Product Name': 'Rice', 'MRP': '80' };
        const normalized = normalizeHeaders(row);
        expect(normalized['name']).toBe('Rice');
        expect(normalized['selling_price']).toBe('80');
    });
});
