// ============================================================================
// ACADEMIC COACHING — LIBRARY MANAGEMENT MODULE
// ============================================================================
// Book catalog, issue/return, fines, reservations
// ============================================================================

import { authorizedHandler } from '../middleware/handler-wrapper';
import { UserRole, BusinessType } from '../types/tenant.types';
import { FeatureKey } from '../config/plan-feature-registry';
import * as response from '../utils/response';
import { logger } from '../utils/logger';
import {
  Keys,
  putItem,
  getItem,
  updateItem,
  deleteItem,
  queryAllItems,
} from '../config/dynamodb.config';
import { z } from 'zod';
import {
  CreateBookSchema,
  IssueBookSchema,
  ReturnBookSchema,
} from '../schemas/academic-coaching.schema';

const AC_LIBRARY_OPTS = {
  requiredBusinessType: BusinessType.SCHOOL_ERP,
  requiredFeature: FeatureKey.AC_MATERIAL_MANAGEMENT,
};

function uid(): string {
  return Math.random().toString(36).substring(2, 18).toUpperCase();
}

function now(): string {
  return new Date().toISOString();
}

// ============================================================================
// BOOK CATALOG
// ============================================================================

/**
 * GET /ac/library/books
 * List all books with filters
 */
export const listBooks = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let books = await queryAllItems(pk, 'AC_BOOK#');

    // Apply filters
    if (p.category) books = books.filter((b: any) => b.category === p.category);
    if (p.subject) books = books.filter((b: any) => b.subject === p.subject);
    if (p.search) {
      const s = p.search.toLowerCase();
      books = books.filter((b: any) =>
        (b.title || '').toLowerCase().includes(s) ||
        (b.authors || []).some((a: string) => a.toLowerCase().includes(s)) ||
        (b.isbn || '').includes(s)
      );
    }
    if (p.available === 'true') {
      books = books.filter((b: any) => (b.availableCopies || 0) > 0);
    }

    // Sort by title
    books.sort((a: any, b: any) => (a.title || '').localeCompare(b.title || ''));

    const page = Math.max(1, parseInt(p.page || '1', 10));
    const limit = Math.min(parseInt(p.limit || '20', 10), 100);
    const total = books.length;
    const paged = books.slice((page - 1) * limit, page * limit);

    return response.paginated(paged, total, page, limit);
  },
  AC_LIBRARY_OPTS,
);

/**
 * GET /ac/library/books/{id}
 * Get book details
 */
export const getBook = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Book ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const book = await getItem(pk, `AC_BOOK#${id}`);
    
    if (!book) return response.notFound('Book not found');

    // Get current issues
    const issues = await queryAllItems(pk, 'AC_BOOK_ISSUE#', {
      filterExpression: 'bookId = :bookId AND #status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: { ':bookId': id, ':status': 'issued' },
    });

    // Get reservations
    const reservations = await queryAllItems(pk, 'AC_BOOK_RESERVATION#', {
      filterExpression: 'bookId = :bookId AND #status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: { ':bookId': id, ':status': 'active' },
    });

    return response.success({ ...book, currentIssues: issues, reservations });
  },
  AC_LIBRARY_OPTS,
);

/**
 * POST /ac/library/books
 * Add new book
 */
export const createBook = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = CreateBookSchema.parse(body);

    const id = uid();
    const pk = Keys.tenantPK(auth.tenantId);
    const ts = now();

    const book = {
      PK: pk,
      SK: `AC_BOOK#${id}`,
      GSI1PK: validated.isbn ? `AC_BOOK_ISBN#${auth.tenantId}#${validated.isbn}` : null,
      GSI1SK: ts,
      id,
      ...validated,
      availableCopies: validated.totalCopies,
      issuedCount: 0,
      createdAt: ts,
      updatedAt: ts,
    };

    if (!book.GSI1PK) delete (book as any).GSI1PK;

    await putItem(book);

    logger.info('Book added', { tenantId: auth.tenantId, bookId: id, title: validated.title });

    return response.success(book, 201);
  },
  AC_LIBRARY_OPTS,
);

/**
 * PUT /ac/library/books/{id}
 * Update book
 */
export const updateBook = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Book ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const updates = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_BOOK#${id}`);
    
    if (!existing) return response.notFound('Book not found');

    const ts = now();

    // Calculate available copies if total changed
    if (updates.totalCopies !== undefined) {
      const diff = updates.totalCopies - (existing.totalCopies || 0);
      updates.availableCopies = (existing.availableCopies || 0) + diff;
    }

    await updateItem(pk, `AC_BOOK#${id}`, {
      updateExpression: 'SET #updates = :updates, #updatedAt = :updatedAt',
      expressionAttributeNames: { '#updates': 'updates', '#updatedAt': 'updatedAt' },
      expressionAttributeValues: { ':updates': updates, ':updatedAt': ts },
    });

    return response.success({ id, ...updates, updatedAt: ts });
  },
  AC_LIBRARY_OPTS,
);

/**
 * DELETE /ac/library/books/{id}
 * Delete book
 */
export const deleteBook = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER],
  async (event, _ctx, auth) => {
    const id = event.pathParameters?.id;
    if (!id) return response.badRequest('Book ID required');

    const pk = Keys.tenantPK(auth.tenantId);
    const existing = await getItem<any>(pk, `AC_BOOK#${id}`);
    
    if (!existing) return response.notFound('Book not found');

    // Check if any copies are issued
    if ((existing.issuedCount || 0) > 0) {
      return response.error(400, 'BOOK_ISSUED', 'Cannot delete book with issued copies');
    }

    await deleteItem(pk, `AC_BOOK#${id}`);

    return response.success({ id, deleted: true });
  },
  AC_LIBRARY_OPTS,
);

// ============================================================================
// BOOK ISSUE & RETURN
// ============================================================================

/**
 * POST /ac/library/issues
 * Issue book to member
 */
export const issueBook = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const validated = IssueBookSchema.parse(body);

    const pk = Keys.tenantPK(auth.tenantId);

    // Check book availability
    const book = await getItem<any>(pk, `AC_BOOK#${validated.bookId}`);
    if (!book) return response.notFound('Book not found');
    if ((book.availableCopies || 0) <= 0) {
      return response.error(400, 'NO_COPIES', 'No copies available for issue');
    }

    // Check if member already has this book
    const existingIssues = await queryAllItems(pk, 'AC_BOOK_ISSUE#', {
      filterExpression: 'bookId = :bookId AND memberId = :memberId AND #status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: {
        ':bookId': validated.bookId,
        ':memberId': validated.memberId,
        ':status': 'issued',
      },
    });

    if (existingIssues.length > 0) {
      return response.error(400, 'ALREADY_ISSUED', 'Member already has this book issued');
    }

    // Check member's current issue count
    const memberIssues = await queryAllItems(pk, 'AC_BOOK_ISSUE#', {
      filterExpression: 'memberId = :memberId AND #status = :status',
      expressionAttributeNames: { '#status': 'status' },
      expressionAttributeValues: { ':memberId': validated.memberId, ':status': 'issued' },
    });

    const maxBooks = validated.memberType === 'student' ? 3 : 5;
    if (memberIssues.length >= maxBooks) {
      return response.error(400, 'LIMIT_EXCEEDED', `Maximum ${maxBooks} books can be issued`);
    }

    const id = uid();
    const ts = now();

    // Calculate due date (14 days from issue)
    const dueDate = new Date(validated.issueDate);
    dueDate.setDate(dueDate.getDate() + 14);

    const issue = {
      PK: pk,
      SK: `AC_BOOK_ISSUE#${id}`,
      GSI1PK: `AC_ISSUE_BY_MEMBER#${auth.tenantId}#${validated.memberType}#${validated.memberId}`,
      GSI1SK: ts,
      id,
      ...validated,
      dueDate: dueDate.toISOString().split('T')[0],
      status: 'issued',
      returnedDate: null,
      fineAmountPaisa: 0,
      createdAt: ts,
    };

    await putItem(issue);

    // Update book availability
    await updateItem(pk, `AC_BOOK#${validated.bookId}`, {
      updateExpression: 'SET #availableCopies = #availableCopies - :one, #issuedCount = #issuedCount + :one',
      expressionAttributeNames: {
        '#availableCopies': 'availableCopies',
        '#issuedCount': 'issuedCount',
      },
      expressionAttributeValues: { ':one': 1 },
    });

    logger.info('Book issued', { tenantId: auth.tenantId, issueId: id, bookId: validated.bookId });

    return response.success(issue, 201);
  },
  AC_LIBRARY_OPTS,
);

/**
 * POST /ac/library/issues/{id}/return
 * Return issued book
 */
export const returnBook = authorizedHandler(
  [UserRole.OWNER, UserRole.ADMIN, UserRole.MANAGER, UserRole.STAFF],
  async (event, _ctx, auth) => {
    const issueId = event.pathParameters?.id;
    if (!issueId) return response.badRequest('Issue ID required');

    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { returnDate, condition, notes } = body;

    const pk = Keys.tenantPK(auth.tenantId);
    const issue = await getItem<any>(pk, `AC_BOOK_ISSUE#${issueId}`);
    
    if (!issue) return response.notFound('Issue record not found');
    if (issue.status !== 'issued') {
      return response.error(400, 'ALREADY_RETURNED', 'Book already returned');
    }

    const actualReturnDate = returnDate || now().split('T')[0];

    // Calculate fine if overdue
    let fineAmountPaisa = 0;
    if (actualReturnDate > issue.dueDate) {
      const daysOverdue = Math.ceil((new Date(actualReturnDate).getTime() - new Date(issue.dueDate).getTime()) / (1000 * 60 * 60 * 24));
      fineAmountPaisa = daysOverdue * 500; // ₹5 per day
    }

    // Add damage fee if applicable
    if (condition === 'damaged') {
      fineAmountPaisa += 50000; // ₹500 damage fee
    } else if (condition === 'lost') {
      fineAmountPaisa += 100000; // ₹1000 lost fee (or book price)
    }

    const ts = now();

    await updateItem(pk, `AC_BOOK_ISSUE#${issueId}`, {
      updateExpression: 'SET #status = :status, #returnedDate = :returnedDate, #condition = :condition, #fineAmountPaisa = :fine, #notes = :notes, #updatedAt = :updatedAt',
      expressionAttributeNames: {
        '#status': 'status',
        '#returnedDate': 'returnedDate',
        '#condition': 'condition',
        '#fineAmountPaisa': 'fineAmountPaisa',
        '#notes': 'notes',
        '#updatedAt': 'updatedAt',
      },
      expressionAttributeValues: {
        ':status': 'returned',
        ':returnedDate': actualReturnDate,
        ':condition': condition || 'good',
        ':fine': fineAmountPaisa,
        ':notes': notes || '',
        ':updatedAt': ts,
      },
    });

    // Update book availability
    await updateItem(pk, `AC_BOOK#${issue.bookId}`, {
      updateExpression: 'SET #availableCopies = #availableCopies + :one, #issuedCount = #issuedCount - :one',
      expressionAttributeNames: {
        '#availableCopies': 'availableCopies',
        '#issuedCount': 'issuedCount',
      },
      expressionAttributeValues: { ':one': 1 },
    });

    logger.info('Book returned', { tenantId: auth.tenantId, issueId, fine: fineAmountPaisa });

    return response.success({
      issueId,
      returnedDate: actualReturnDate,
      fineAmount: fineAmountPaisa / 100,
      fineAmountPaisa,
      condition: condition || 'good',
    });
  },
  AC_LIBRARY_OPTS,
);

/**
 * GET /ac/library/issues
 * List book issues
 */
export const listIssues = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const p = event.queryStringParameters || {};
    const pk = Keys.tenantPK(auth.tenantId);

    let issues = await queryAllItems(pk, 'AC_BOOK_ISSUE#');

    if (p.bookId) issues = issues.filter((i: any) => i.bookId === p.bookId);
    if (p.memberId) issues = issues.filter((i: any) => i.memberId === p.memberId);
    if (p.status) issues = issues.filter((i: any) => i.status === p.status);
    if (p.overdue === 'true') {
      const today = now().split('T')[0];
      issues = issues.filter((i: any) => i.status === 'issued' && i.dueDate < today);
    }

    // Sort by issue date desc
    issues.sort((a: any, b: any) => (b.createdAt || '').localeCompare(a.createdAt || ''));

    return response.success(issues);
  },
  AC_LIBRARY_OPTS,
);

// ============================================================================
// RESERVATIONS
// ============================================================================

/**
 * POST /ac/library/reservations
 * Reserve a book
 */
export const reserveBook = authorizedHandler(
  [],
  async (event, _ctx, auth) => {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    const { bookId, memberType, memberId } = body;

    const pk = Keys.tenantPK(auth.tenantId);

    // Check if book exists
    const book = await getItem(pk, `AC_BOOK#${bookId}`);
    if (!book) return response.notFound('Book not found');

    // Check if available
    if ((book as any).availableCopies > 0) {
      return response.error(400, 'BOOK_AVAILABLE', 'Book is available for issue, no need to reserve');
    }

    const id = uid();
    const ts = now();

    const reservation = {
      PK: pk,
      SK: `AC_BOOK_RESERVATION#${id}`,
      GSI1PK: `AC_RESERVATION_BY_MEMBER#${auth.tenantId}#${memberType}#${memberId}`,
      GSI1SK: ts,
      id,
      bookId,
      memberType,
      memberId,
      status: 'active',
      reservedAt: ts,
      notifiedAt: null,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(), // 7 days
    };

    await putItem(reservation);

    return response.success(reservation, 201);
  },
  AC_LIBRARY_OPTS,
);

/**
 * GET /ac/library/dashboard
 * Library dashboard stats
 */
export const getLibraryDashboard = authorizedHandler(
  [],
  async (_event, _ctx, auth) => {
    const pk = Keys.tenantPK(auth.tenantId);

    const [books, issues] = await Promise.all([
      queryAllItems(pk, 'AC_BOOK#'),
      queryAllItems(pk, 'AC_BOOK_ISSUE#'),
    ]);

    const today = now().split('T')[0];
    const overdueIssues = issues.filter((i: any) => i.status === 'issued' && i.dueDate < today);

    const stats = {
      totalBooks: books.length,
      totalCopies: books.reduce((sum: number, b: any) => sum + (b.totalCopies || 0), 0),
      availableCopies: books.reduce((sum: number, b: any) => sum + (b.availableCopies || 0), 0),
      issuedCopies: books.reduce((sum: number, b: any) => sum + (b.issuedCount || 0), 0),
      totalIssues: issues.length,
      activeIssues: issues.filter((i: any) => i.status === 'issued').length,
      overdueIssues: overdueIssues.length,
      overdueFines: overdueIssues.reduce((sum: number, i: any) => {
        const days = Math.ceil((new Date(today).getTime() - new Date(i.dueDate).getTime()) / (1000 * 60 * 60 * 24));
        return sum + (days * 500); // ₹5 per day
      }, 0),
    };

    return response.success(stats);
  },
  AC_LIBRARY_OPTS,
);
