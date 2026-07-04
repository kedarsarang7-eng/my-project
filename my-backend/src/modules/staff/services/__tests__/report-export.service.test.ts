// ============================================================================
// Staff Module — Report Export Service Tests (Task 13.2)
// ============================================================================
// Tests for CSV, Excel, PDF, and JSON export formats.
// Requirements: 9.6
// ============================================================================

import {
    exportCsv,
    exportExcel,
    exportPdf,
    exportJson,
    exportReport,
    ReportData,
} from '../report-export.service';

const sampleData: ReportData = {
    title: 'Test Employee Report',
    columns: [
        { header: 'ID', key: 'id', width: 20 },
        { header: 'Name', key: 'name', width: 25 },
        { header: 'Status', key: 'status', width: 12 },
    ],
    rows: [
        { id: 'emp-001', name: 'Alice Johnson', status: 'active' },
        { id: 'emp-002', name: 'Bob Smith', status: 'inactive' },
        { id: 'emp-003', name: 'Charlie, "The Dev"', status: 'active' },
    ],
    meta: {
        businessName: 'Test Business',
        generatedAt: '2024-01-15T10:00:00Z',
        filters: { department: 'Engineering' },
    },
};

describe('Report Export Service', () => {
    describe('exportCsv', () => {
        it('should produce a valid CSV with headers and rows', () => {
            const result = exportCsv(sampleData);
            expect(result.contentType).toBe('text/csv; charset=utf-8');
            expect(result.filename).toMatch(/\.csv$/);

            const content = result.buffer.toString('utf-8');
            const lines = content.trim().split('\n');

            // Header line
            expect(lines[0]).toBe('ID,Name,Status');
            // Row 1
            expect(lines[1]).toBe('emp-001,Alice Johnson,active');
            // Row 2
            expect(lines[2]).toBe('emp-002,Bob Smith,inactive');
            // Row 3 — contains comma and quotes, should be escaped
            expect(lines[3]).toContain('emp-003');
            expect(lines[3]).toContain('"Charlie, ""The Dev"""');
        });

        it('should handle empty rows', () => {
            const emptyData: ReportData = {
                title: 'Empty Report',
                columns: [{ header: 'A', key: 'a' }],
                rows: [],
            };
            const result = exportCsv(emptyData);
            const content = result.buffer.toString('utf-8');
            expect(content.trim()).toBe('A');
        });
    });

    describe('exportExcel', () => {
        it('should produce a valid xlsx buffer', async () => {
            const result = await exportExcel(sampleData);
            expect(result.contentType).toBe(
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            );
            expect(result.filename).toMatch(/\.xlsx$/);
            expect(result.buffer.length).toBeGreaterThan(0);

            // XLSX files start with the ZIP signature (PK header)
            expect(result.buffer[0]).toBe(0x50); // 'P'
            expect(result.buffer[1]).toBe(0x4b); // 'K'
        });
    });

    describe('exportPdf', () => {
        it('should produce a valid PDF buffer', async () => {
            const result = await exportPdf(sampleData);
            expect(result.contentType).toBe('application/pdf');
            expect(result.filename).toMatch(/\.pdf$/);
            expect(result.buffer.length).toBeGreaterThan(0);

            // PDF files start with %PDF-
            const header = result.buffer.toString('utf-8', 0, 5);
            expect(header).toBe('%PDF-');
        });
    });

    describe('exportJson', () => {
        it('should produce valid JSON with all data', () => {
            const result = exportJson(sampleData);
            expect(result.contentType).toBe('application/json');
            expect(result.filename).toMatch(/\.json$/);

            const parsed = JSON.parse(result.buffer.toString('utf-8'));
            expect(parsed.title).toBe('Test Employee Report');
            expect(parsed.rows).toHaveLength(3);
            expect(parsed.totalRows).toBe(3);
            expect(parsed.columns).toHaveLength(3);
            expect(parsed.meta?.businessName).toBe('Test Business');
        });
    });

    describe('exportReport (dispatcher)', () => {
        it('should dispatch to csv format', async () => {
            const result = await exportReport(sampleData, 'csv');
            expect(result.contentType).toBe('text/csv; charset=utf-8');
        });

        it('should dispatch to excel format', async () => {
            const result = await exportReport(sampleData, 'excel');
            expect(result.contentType).toBe(
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            );
        });

        it('should dispatch to pdf format', async () => {
            const result = await exportReport(sampleData, 'pdf');
            expect(result.contentType).toBe('application/pdf');
        });

        it('should dispatch to json format', async () => {
            const result = await exportReport(sampleData, 'json');
            expect(result.contentType).toBe('application/json');
        });

        it('should default to csv for unknown format', async () => {
            const result = await exportReport(sampleData, 'unknown' as any);
            expect(result.contentType).toBe('text/csv; charset=utf-8');
        });
    });
});
