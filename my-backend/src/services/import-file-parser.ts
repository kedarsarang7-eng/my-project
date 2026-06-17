// ============================================================================
// Import File Parser — Excel / CSV / OCR (Textract)
// ============================================================================
// Supports: .xlsx (exceljs), .csv (manual parse — no dep), image/PDF (Textract)
// MIME type validation is enforced here (server-side).
// Confidence threshold for Textract words: >= 0.70 (else row goes to errors).
// ============================================================================

import { configureAwsClient } from '../config/aws.config';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { logger } from '../utils/logger';
import { ImportJobError } from '../types/import.types';
import { config } from '../config/environment';

interface Block {
    BlockType?: string;
    Id?: string;
    Text?: string;
    Confidence?: number;
    RowIndex?: number;
    ColumnIndex?: number;
    Page?: number;
    Relationships?: Array<{ Type: string; Ids?: string[] }>;
    Geometry?: { BoundingBox?: { Top?: number } };
}

// TODO: add @aws-sdk/client-textract to package.json before deploy
// eslint-disable-next-line @typescript-eslint/no-require-imports
const TextractSDK = require('@aws-sdk/client-textract') as {
    TextractClient: new (opts: { region: string }) => {
        send: (cmd: unknown) => Promise<{ Blocks?: Block[] }>;
    };
    AnalyzeDocumentCommand: new (input: {
        Document: { S3Object: { Bucket: string; Name: string } };
        FeatureTypes: string[];
    }) => unknown;
    DetectDocumentTextCommand: new (input: {
        Document: { S3Object: { Bucket: string; Name: string } };
    }) => unknown;
};

const REGION = config.aws.region;
const TEXTRACT_CONFIDENCE_THRESHOLD = 0.70;

// Lazy clients
let s3: S3Client | null = null;
let _textractClient: { send: (cmd: unknown) => Promise<{ Blocks?: Block[] }> } | null = null;

function getS3(): S3Client {
    if (!s3) s3 = new S3Client(configureAwsClient({ region: REGION }));
    return s3;
}

function getTextract(): { send: (cmd: unknown) => Promise<{ Blocks?: Block[] }> } {
    if (!_textractClient) _textractClient = new TextractSDK.TextractClient({ region: REGION });
    return _textractClient;
}

// ── Supported MIME types ──────────────────────────────────────────────────────

export type ParsedRow = Record<string, string>;

export interface ParseResult {
    rows: ParsedRow[];
    errors: ImportJobError[];
    headers: string[];
}

const ALLOWED_MIME_TYPES = new Set([
    'text/csv',
    'application/csv',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/tiff',
    'application/pdf',
]);

export function validateMimeType(mimeType: string): boolean {
    return ALLOWED_MIME_TYPES.has(mimeType.toLowerCase().trim());
}

// ── Download from S3 ──────────────────────────────────────────────────────────

export async function downloadFromS3(bucket: string, key: string): Promise<Buffer> {
    const cmd = new GetObjectCommand({ Bucket: bucket, Key: key });
    const res = await getS3().send(cmd);

    if (!res.Body) throw new Error(`Empty S3 response for key: ${key}`);

    const chunks: Buffer[] = [];
    for await (const chunk of res.Body as AsyncIterable<Buffer>) {
        chunks.push(Buffer.from(chunk));
    }
    return Buffer.concat(chunks);
}

// ── CSV Parsing ───────────────────────────────────────────────────────────────
// Handles: comma, semicolon, tab delimiters; quoted fields; UTF-8 BOM; Windows CRLF.

function detectDelimiter(firstLine: string): string {
    const counts: Record<string, number> = { ',': 0, ';': 0, '\t': 0 };
    let inQuote = false;
    for (const ch of firstLine) {
        if (ch === '"') { inQuote = !inQuote; continue; }
        if (!inQuote && counts[ch] !== undefined) counts[ch]++;
    }
    return Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
}

function parseCSVLine(line: string, delimiter: string): string[] {
    const fields: string[] = [];
    let current = '';
    let inQuote = false;

    for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (ch === '"') {
            if (inQuote && line[i + 1] === '"') {
                current += '"';
                i++;
            } else {
                inQuote = !inQuote;
            }
        } else if (ch === delimiter && !inQuote) {
            fields.push(current.trim());
            current = '';
        } else {
            current += ch;
        }
    }
    fields.push(current.trim());
    return fields;
}

export function parseCSV(buffer: Buffer): ParseResult {
    const errors: ImportJobError[] = [];

    // Strip UTF-8 BOM if present
    let text = buffer.toString('utf8');
    if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);

    // Normalize line endings (Windows CRLF, old Mac CR)
    const lines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n').filter(l => l.trim());

    if (lines.length === 0) return { rows: [], errors, headers: [] };

    const delimiter = detectDelimiter(lines[0]);
    const headers = parseCSVLine(lines[0], delimiter).map(h => h.toLowerCase().trim());

    const rows: ParsedRow[] = [];

    for (let i = 1; i < lines.length; i++) {
        const fields = parseCSVLine(lines[i], delimiter);

        if (fields.every(f => f === '')) continue; // skip blank lines

        const row: ParsedRow = {};
        headers.forEach((h, idx) => {
            row[h] = fields[idx] ?? '';
        });
        rows.push(row);
    }

    return { rows, errors, headers };
}

// ── Excel Parsing (exceljs) ───────────────────────────────────────────────────
// Assumption: exceljs is added to package.json (see serverless.yml changes).
// Reads first sheet only.

export async function parseExcel(buffer: Buffer): Promise<ParseResult> {
    const errors: ImportJobError[] = [];

    // Dynamic import — TODO: add exceljs to package.json before deploy
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const ExcelJS = require('exceljs') as { Workbook: new () => {
        xlsx: { load: (buf: Buffer) => Promise<void> };
        worksheets: Array<{ getSheetValues: () => unknown[][] }>;
    } };

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(buffer);

    const sheet = workbook.worksheets[0];
    if (!sheet) return { rows: [], errors, headers: [] };

    const allRows = sheet.getSheetValues() as (unknown[] | null)[];

    // Row 0 is undefined in exceljs (1-indexed), Row 1 = headers
    const headerRow = allRows[1] as unknown[] | null | undefined;
    if (!headerRow) return { rows: [], errors, headers: [] };

    const headers = (headerRow as unknown[])
        .slice(1) // exceljs row arrays are 1-indexed, index 0 is undefined
        .map(h => String(h ?? '').toLowerCase().trim())
        .filter(h => h !== '');

    const rows: ParsedRow[] = [];

    for (let r = 2; r < allRows.length; r++) {
        const rawRow = allRows[r];
        if (!rawRow) continue;

        const fields = (rawRow as unknown[]).slice(1);
        if (fields.every(f => f === null || f === undefined || String(f).trim() === '')) continue;

        const row: ParsedRow = {};
        headers.forEach((h, idx) => {
            const val = fields[idx];
            // Handle Date objects from Excel date cells
            if (val instanceof Date) {
                row[h] = val.toISOString().split('T')[0];
            } else if (val !== null && val !== undefined) {
                row[h] = String(val).trim();
            } else {
                row[h] = '';
            }
        });
        rows.push(row);
    }

    return { rows, errors, headers };
}

// ── OCR (AWS Textract) ────────────────────────────────────────────────────────
// Strategy:
//   1. AnalyzeDocument with TABLES feature → extract structured table cells
//   2. If no TABLE blocks found → fall back to raw LINE blocks
// Low-confidence words (< TEXTRACT_CONFIDENCE_THRESHOLD) cause the row to be
// added to errors instead of rows.

interface TextractCell {
    rowIndex: number;
    colIndex: number;
    text: string;
    confidence: number;
}

function extractTableCells(blocks: Block[]): TextractCell[] {
    const cellMap = new Map<string, Block>();
    const wordMap = new Map<string, Block>();

    for (const block of blocks) {
        if (block.BlockType === 'CELL' && block.Id) {
            cellMap.set(block.Id, block);
        }
        if ((block.BlockType === 'WORD' || block.BlockType === 'LINE') && block.Id) {
            wordMap.set(block.Id, block);
        }
    }

    const cells: TextractCell[] = [];

    for (const cell of cellMap.values()) {
        const rowIdx = cell.RowIndex ?? 0;
        const colIdx = cell.ColumnIndex ?? 0;
        const wordIds = (cell.Relationships ?? [])
            .filter(r => r.Type === 'CHILD')
            .flatMap(r => r.Ids ?? []);

        let text = '';
        let minConfidence = 1.0;

        for (const wid of wordIds) {
            const word = wordMap.get(wid);
            if (word) {
                text += (word.Text ?? '') + ' ';
                const conf = (word.Confidence ?? 100) / 100;
                if (conf < minConfidence) minConfidence = conf;
            }
        }

        cells.push({
            rowIndex: rowIdx,
            colIndex: colIdx,
            text: text.trim(),
            confidence: minConfidence,
        });
    }

    return cells;
}

function tableCellsToRows(cells: TextractCell[]): { headers: string[]; rows: ParsedRow[]; lowConfidenceRows: number[] } {
    if (cells.length === 0) return { headers: [], rows: [], lowConfidenceRows: [] };

    // Build matrix: max row x max col
    const maxRow = Math.max(...cells.map(c => c.rowIndex));
    const maxCol = Math.max(...cells.map(c => c.colIndex));

    const matrix: Array<Array<{ text: string; confidence: number }>> = Array.from(
        { length: maxRow + 1 },
        () => Array.from({ length: maxCol + 1 }, () => ({ text: '', confidence: 1.0 })),
    );

    for (const cell of cells) {
        matrix[cell.rowIndex][cell.colIndex] = { text: cell.text, confidence: cell.confidence };
    }

    // Row 1 = headers
    const headers = matrix[1]?.slice(1).map(c => c.text.toLowerCase().trim()) ?? [];
    const rows: ParsedRow[] = [];
    const lowConfidenceRows: number[] = [];

    for (let r = 2; r <= maxRow; r++) {
        const rowCells = matrix[r]?.slice(1) ?? [];
        if (rowCells.every(c => c.text === '')) continue;

        const minConf = Math.min(...rowCells.map(c => c.confidence));
        if (minConf < TEXTRACT_CONFIDENCE_THRESHOLD) {
            lowConfidenceRows.push(r - 2); // 0-indexed row
            continue;
        }

        const row: ParsedRow = {};
        headers.forEach((h, idx) => { row[h] = rowCells[idx]?.text ?? ''; });
        rows.push(row);
    }

    return { headers, rows, lowConfidenceRows };
}

function lineBlocksToRows(blocks: Block[]): { headers: string[]; rows: ParsedRow[]; lowConfidenceRows: number[] } {
    const lines = blocks
        .filter((b: Block) => b.BlockType === 'LINE')
        .sort((a: Block, b: Block) => (a.Page ?? 1) - (b.Page ?? 1) || (a.Geometry?.BoundingBox?.Top ?? 0) - (b.Geometry?.BoundingBox?.Top ?? 0));

    // Heuristic: first line = header; split on whitespace or common delimiters
    const lineTexts = lines.map(l => l.Text ?? '');
    if (lineTexts.length === 0) return { headers: [], rows: [], lowConfidenceRows: [] };

    const delimiters = ['|', '\t', ','];
    let bestDelimiter = ' ';
    let maxCount = 0;

    for (const d of delimiters) {
        const count = (lineTexts[0].match(new RegExp(escapeRegex(d), 'g')) ?? []).length;
        if (count > maxCount) { maxCount = count; bestDelimiter = d; }
    }

    const split = (line: string) => bestDelimiter === ' '
        ? line.trim().split(/\s{2,}/) // split on 2+ spaces for space-separated tables
        : line.split(bestDelimiter).map(s => s.trim());

    const headers = split(lineTexts[0]).map(h => h.toLowerCase().trim());
    const rows: ParsedRow[] = [];
    const lowConfidenceRows: number[] = [];

    for (let i = 1; i < lineTexts.length; i++) {
        const fields = split(lineTexts[i]);
        // Check confidence of the corresponding LINE block
        const conf = (lines[i].Confidence ?? 100) / 100;
        if (conf < TEXTRACT_CONFIDENCE_THRESHOLD) {
            lowConfidenceRows.push(i - 1);
            continue;
        }
        const row: ParsedRow = {};
        headers.forEach((h, idx) => { row[h] = fields[idx] ?? ''; });
        rows.push(row);
    }

    return { headers, rows, lowConfidenceRows };
}

function escapeRegex(s: string): string {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export async function parseOCR(bucket: string, key: string): Promise<ParseResult> {
    const client = getTextract();
    const errors: ImportJobError[] = [];

    // Try TABLES first
    const analyzeRes = await client.send(new TextractSDK.AnalyzeDocumentCommand({
        Document: { S3Object: { Bucket: bucket, Name: key } },
        FeatureTypes: ['TABLES'],
    })) as { Blocks?: Block[] };

    const blocks = analyzeRes.Blocks ?? [];
    const hasTable = blocks.some((b: Block) => b.BlockType === 'TABLE');

    if (hasTable) {
        const cells = extractTableCells(blocks);
        const { headers, rows, lowConfidenceRows } = tableCellsToRows(cells);

        lowConfidenceRows.forEach(rowIdx => {
            errors.push({
                rowIndex: rowIdx,
                rawData: {},
                reason: `Textract confidence below ${TEXTRACT_CONFIDENCE_THRESHOLD * 100}% — row discarded`,
            });
        });

        logger.info('[OCR] Parsed via TABLE blocks', { rows: rows.length, discarded: lowConfidenceRows.length });
        return { rows, errors, headers };
    }

    // Fallback to LINE blocks
    logger.info('[OCR] No TABLE blocks found — falling back to LINE blocks');
    const detectRes = await client.send(new TextractSDK.DetectDocumentTextCommand({
        Document: { S3Object: { Bucket: bucket, Name: key } },
    })) as { Blocks?: Block[] };

    const lineBlocks = detectRes.Blocks ?? [];
    const { headers, rows, lowConfidenceRows } = lineBlocksToRows(lineBlocks);

    lowConfidenceRows.forEach(rowIdx => {
        errors.push({
            rowIndex: rowIdx,
            rawData: {},
            reason: `Textract confidence below ${TEXTRACT_CONFIDENCE_THRESHOLD * 100}% — row discarded`,
        });
    });

    logger.info('[OCR] Parsed via LINE blocks', { rows: rows.length, discarded: lowConfidenceRows.length });
    return { rows, errors, headers };
}

// ── Header Normalization ──────────────────────────────────────────────────────
// Maps common column header variants to canonical field names.

const HEADER_ALIASES: Record<string, string> = {
    // name
    'product name': 'name', 'item name': 'name', 'product': 'name', 'item': 'name',
    'description': 'name', 'title': 'name', 'product title': 'name',
    // quantity
    'quantity': 'quantity', 'qty': 'quantity', 'stock': 'quantity', 'units': 'quantity',
    'opening stock': 'quantity', 'current stock': 'quantity', 'stock qty': 'quantity',
    // unit
    'unit': 'unit', 'uom': 'unit', 'unit of measure': 'unit', 'unit of measurement': 'unit',
    // barcode/sku
    'barcode': 'barcode', 'ean': 'barcode', 'upc': 'barcode',
    'sku': 'sku', 'item code': 'sku', 'product code': 'sku', 'code': 'sku',
    // price
    'price': 'selling_price', 'selling price': 'selling_price', 'sale price': 'selling_price',
    'mrp': 'selling_price', 'rate': 'selling_price', 'sp': 'selling_price',
    'cost': 'cost_price', 'cost price': 'cost_price', 'purchase price': 'cost_price',
    'cp': 'cost_price', 'pp': 'cost_price',
    // category
    'category': 'category', 'cat': 'category', 'dept': 'category', 'department': 'category',
    // vendor
    'vendor': 'vendor', 'supplier': 'vendor', 'brand': 'vendor', 'manufacturer': 'vendor',
};

export function normalizeHeaders(raw: ParsedRow): ParsedRow {
    const normalized: ParsedRow = {};
    for (const [key, val] of Object.entries(raw)) {
        const canonical = HEADER_ALIASES[key.toLowerCase().trim()] ?? key.toLowerCase().trim();
        normalized[canonical] = val;
    }
    return normalized;
}

// ── Master parse entry point ──────────────────────────────────────────────────

export async function parseImportFile(
    bucket: string,
    key: string,
    mimeType: string,
): Promise<ParseResult> {
    if (!validateMimeType(mimeType)) {
        throw new Error(`Unsupported MIME type: ${mimeType}`);
    }

    let result: ParseResult;

    if (mimeType === 'text/csv' || mimeType === 'application/csv') {
        const buffer = await downloadFromS3(bucket, key);
        result = parseCSV(buffer);
    } else if (
        mimeType === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
        mimeType === 'application/vnd.ms-excel'
    ) {
        const buffer = await downloadFromS3(bucket, key);
        result = await parseExcel(buffer);
    } else {
        // image/jpeg, image/png, image/tiff, application/pdf → Textract OCR
        result = await parseOCR(bucket, key);
    }

    // Normalize all row headers to canonical field names
    result.rows = result.rows.map(normalizeHeaders);

    return result;
}
