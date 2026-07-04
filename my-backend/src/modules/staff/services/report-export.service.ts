// ============================================================================
// Staff Module — Report Export Service (Task 13.2)
// ============================================================================
// Supports Excel (xlsx via exceljs), PDF (via pdfkit), and CSV export formats.
// Print export is handled client-side (the backend provides PDF or raw data).
//
// Each export function accepts a generic ReportData shape (title, headers, rows)
// and returns a Buffer with the appropriate Content-Type. The handler picks the
// format based on the ?format= query parameter.
//
// Requirements: 9.6 (export reports in Excel, PDF, CSV, and Print formats).
// ============================================================================

import ExcelJS from 'exceljs';
import PDFDocument from 'pdfkit';

// ── Types ───────────────────────────────────────────────────────────────────

export interface ReportColumn {
    /** Column header label. */
    header: string;
    /** Key in the row data object (or index for array rows). */
    key: string;
    /** Optional column width for Excel (characters). */
    width?: number;
}

export interface ReportData {
    /** Report title (used in PDF header, Excel sheet name). */
    title: string;
    /** Column definitions. */
    columns: ReportColumn[];
    /** Data rows — each row is a Record keyed by column.key. */
    rows: Record<string, unknown>[];
    /** Optional metadata (business name, generated date, filters applied). */
    meta?: {
        businessName?: string;
        generatedAt?: string;
        filters?: Record<string, string>;
    };
}

export type ExportFormat = 'excel' | 'pdf' | 'csv' | 'json';

export interface ExportResult {
    /** The binary content of the export. */
    buffer: Buffer;
    /** MIME content type for the response. */
    contentType: string;
    /** Suggested filename for Content-Disposition. */
    filename: string;
}

// ── CSV Export ──────────────────────────────────────────────────────────────

function escapeCsvCell(value: unknown): string {
    const raw = String(value ?? '');
    if (raw.includes(',') || raw.includes('"') || raw.includes('\n') || raw.includes('\r')) {
        return `"${raw.replace(/"/g, '""')}"`;
    }
    return raw;
}

export function exportCsv(data: ReportData): ExportResult {
    const headerLine = data.columns.map((c) => escapeCsvCell(c.header)).join(',');
    const bodyLines = data.rows.map((row) =>
        data.columns.map((c) => escapeCsvCell(row[c.key])).join(','),
    );
    const csv = [headerLine, ...bodyLines].join('\n') + '\n';
    const buffer = Buffer.from(csv, 'utf-8');

    const safeName = data.title.replace(/[^a-zA-Z0-9_-]/g, '_').toLowerCase();
    return {
        buffer,
        contentType: 'text/csv; charset=utf-8',
        filename: `${safeName}.csv`,
    };
}

// ── Excel Export ────────────────────────────────────────────────────────────

export async function exportExcel(data: ReportData): Promise<ExportResult> {
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'DukanX Staff Module';
    workbook.created = new Date();

    const sheetName = data.title.substring(0, 31); // Excel sheet name limit
    const worksheet = workbook.addWorksheet(sheetName);

    // Define columns
    worksheet.columns = data.columns.map((col) => ({
        header: col.header,
        key: col.key,
        width: col.width ?? 18,
    }));

    // Style header row
    const headerRow = worksheet.getRow(1);
    headerRow.font = { bold: true };
    headerRow.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FF4472C4' },
    };
    headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };

    // Add data rows
    for (const row of data.rows) {
        const values: Record<string, unknown> = {};
        for (const col of data.columns) {
            values[col.key] = row[col.key] ?? '';
        }
        worksheet.addRow(values);
    }

    // Auto-filter on the header row
    if (data.columns.length > 0) {
        worksheet.autoFilter = {
            from: { row: 1, column: 1 },
            to: { row: 1, column: data.columns.length },
        };
    }

    const arrayBuffer = await workbook.xlsx.writeBuffer();
    const buffer = Buffer.from(arrayBuffer);

    const safeName = data.title.replace(/[^a-zA-Z0-9_-]/g, '_').toLowerCase();
    return {
        buffer,
        contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        filename: `${safeName}.xlsx`,
    };
}

// ── PDF Export ──────────────────────────────────────────────────────────────

export function exportPdf(data: ReportData): Promise<ExportResult> {
    return new Promise((resolve, reject) => {
        try {
            const doc = new PDFDocument({ margin: 40, size: 'A4', layout: 'landscape' });
            const chunks: Buffer[] = [];

            doc.on('data', (chunk: Buffer) => chunks.push(chunk));
            doc.on('end', () => {
                const buffer = Buffer.concat(chunks);
                const safeName = data.title.replace(/[^a-zA-Z0-9_-]/g, '_').toLowerCase();
                resolve({
                    buffer,
                    contentType: 'application/pdf',
                    filename: `${safeName}.pdf`,
                });
            });
            doc.on('error', reject);

            // Title
            doc.fontSize(16).font('Helvetica-Bold').text(data.title, { align: 'center' });
            doc.moveDown(0.5);

            // Meta info
            if (data.meta) {
                doc.fontSize(9).font('Helvetica');
                if (data.meta.businessName) {
                    doc.text(`Business: ${data.meta.businessName}`);
                }
                if (data.meta.generatedAt) {
                    doc.text(`Generated: ${data.meta.generatedAt}`);
                }
                if (data.meta.filters && Object.keys(data.meta.filters).length > 0) {
                    const filterStr = Object.entries(data.meta.filters)
                        .map(([k, v]) => `${k}: ${v}`)
                        .join(', ');
                    doc.text(`Filters: ${filterStr}`);
                }
                doc.moveDown(0.5);
            }

            // Table header
            const colCount = data.columns.length;
            const pageWidth = doc.page.width - doc.page.margins.left - doc.page.margins.right;
            const colWidth = Math.min(pageWidth / colCount, 150);

            doc.fontSize(8).font('Helvetica-Bold');
            let x = doc.page.margins.left;
            for (const col of data.columns) {
                doc.text(col.header, x, doc.y, { width: colWidth, continued: false });
                x += colWidth;
            }
            doc.moveDown(0.3);

            // Draw a separator line
            const lineY = doc.y;
            doc.moveTo(doc.page.margins.left, lineY)
                .lineTo(doc.page.margins.left + colCount * colWidth, lineY)
                .stroke();
            doc.moveDown(0.2);

            // Table rows
            doc.font('Helvetica').fontSize(7);
            for (const row of data.rows) {
                // Check if we need a new page
                if (doc.y > doc.page.height - doc.page.margins.bottom - 20) {
                    doc.addPage();
                    doc.fontSize(7).font('Helvetica');
                }

                x = doc.page.margins.left;
                const rowY = doc.y;
                for (const col of data.columns) {
                    const val = String(row[col.key] ?? '');
                    doc.text(val, x, rowY, { width: colWidth, continued: false });
                    x += colWidth;
                }
                doc.moveDown(0.1);
            }

            // Footer
            doc.moveDown(1);
            doc.fontSize(7).font('Helvetica').text(
                `Total rows: ${data.rows.length}`,
                { align: 'right' },
            );

            doc.end();
        } catch (err) {
            reject(err);
        }
    });
}

// ── JSON Export (printable data) ────────────────────────────────────────────

export function exportJson(data: ReportData): ExportResult {
    const payload = {
        title: data.title,
        meta: data.meta,
        columns: data.columns.map((c) => ({ header: c.header, key: c.key })),
        rows: data.rows,
        totalRows: data.rows.length,
    };
    const buffer = Buffer.from(JSON.stringify(payload, null, 2), 'utf-8');
    const safeName = data.title.replace(/[^a-zA-Z0-9_-]/g, '_').toLowerCase();
    return {
        buffer,
        contentType: 'application/json',
        filename: `${safeName}.json`,
    };
}

// ── Format Dispatcher ───────────────────────────────────────────────────────

/**
 * Export report data in the specified format.
 * For Print: clients use the PDF or JSON output to render a printable view.
 */
export async function exportReport(
    data: ReportData,
    format: ExportFormat,
): Promise<ExportResult> {
    switch (format) {
        case 'csv':
            return exportCsv(data);
        case 'excel':
            return exportExcel(data);
        case 'pdf':
            return exportPdf(data);
        case 'json':
            return exportJson(data);
        default:
            return exportCsv(data);
    }
}
