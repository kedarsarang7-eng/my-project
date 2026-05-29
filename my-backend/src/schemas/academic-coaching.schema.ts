// ============================================================================
// ACADEMIC COACHING — ZOD VALIDATION SCHEMAS
// ============================================================================
// Single source of truth for all AC input validation
// ============================================================================

import { z } from 'zod';

// ── Common Validators ─────────────────────────────────────────────────────

const uuid = z.string().regex(/^[A-Z0-9]{16}$/);
const phone = z.string().regex(/^\+?[0-9]{10,15}$/);
const email = z.string().email();
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const timestamp = z.string().datetime();
const paisa = z.number().int().min(0);

// ── Enums ───────────────────────────────────────────────────────────────────

export const StudentStatusEnum = z.enum(['active', 'inactive', 'graduated', 'transferred']);
export const BatchStatusEnum = z.enum(['upcoming', 'active', 'completed']);
export const BatchTypeEnum = z.enum(['regular', 'crash', 'online', 'weekend']);
export const FeeStatusEnum = z.enum(['pending', 'partial', 'paid', 'overdue']);
export const AttendanceStatusEnum = z.enum(['present', 'absent', 'leave']);
export const EmploymentTypeEnum = z.enum(['fullTime', 'partTime', 'visiting']);
export const ExamTypeEnum = z.enum(['internal', 'mock', 'unitTest', 'final', 'quiz']);
export const MaterialTypeEnum = z.enum(['notes', 'practicePaper', 'solution', 'videoLink', 'reference']);
export const PaymentMethodEnum = z.enum(['cash', 'upi', 'card', 'cheque', 'bankTransfer', 'online']);
export const LeaveTypeEnum = z.enum(['sick', 'casual', 'emergency', 'other']);
export const LeaveStatusEnum = z.enum(['pending', 'approved', 'rejected']);

// ── Student Schemas ─────────────────────────────────────────────────────────

export const CreateStudentSchema = z.object({
  firstName: z.string().min(1).max(100),
  lastName: z.string().min(1).max(100),
  dob: date.optional(),
  gender: z.enum(['male', 'female', 'other']).optional(),
  phone: phone,
  parentPhone: phone.optional(),
  parentName: z.string().max(100).optional(),
  email: email.optional(),
  address: z.string().max(500).optional(),
  schoolName: z.string().max(100).optional(),
  currentClass: z.string().max(50).optional(),
  board: z.string().max(50).optional(),
  enrolledCourseIds: z.array(z.string()).default([]),
  enrolledBatchIds: z.array(z.string()).default([]),
  photoS3Key: z.string().optional(),
  referralSource: z.string().max(100).optional(),
  branchId: z.string().optional(),
  status: StudentStatusEnum.default('active'),
  notes: z.string().max(1000).optional(),
});

export const UpdateStudentSchema = CreateStudentSchema.partial().extend({
  id: z.string().min(1),
});

export const TransferStudentSchema = z.object({
  fromBatchId: z.string().min(1),
  toBatchId: z.string().min(1),
  transferDate: date.optional(),
  reason: z.string().max(500).optional(),
});

export const BulkImportStudentsSchema = z.object({
  students: z.array(CreateStudentSchema).min(1).max(100),
});

// ── Batch Schemas ──────────────────────────────────────────────────────────

export const ScheduleSlotSchema = z.object({
  dayOfWeek: z.number().int().min(0).max(6),
  startTime: z.string().regex(/^\d{2}:\d{2}$/),
  endTime: z.string().regex(/^\d{2}:\d{2}$/),
  room: z.string().max(50).optional(),
});

export const CreateBatchSchema = z.object({
  name: z.string().min(1).max(100),
  courseId: z.string().optional(),
  branchId: z.string().optional(),
  batchCode: z.string().max(20).optional(),
  schedule: z.array(ScheduleSlotSchema).default([]),
  startDate: date.optional(),
  endDate: date.optional(),
  maxCapacity: z.number().int().min(1).max(500).default(30),
  status: BatchStatusEnum.default('upcoming'),
  batchType: BatchTypeEnum.default('regular'),
});

export const UpdateBatchSchema = CreateBatchSchema.partial().extend({
  id: z.string().min(1),
});

// ── Course Schemas ─────────────────────────────────────────────────────────

export const CreateCourseSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  subjects: z.array(z.string()).default([]),
  durationWeeks: z.number().int().min(1).optional(),
  feeAmountPaisa: paisa.optional(),
  isActive: z.boolean().default(true),
});

export const UpdateCourseSchema = CreateCourseSchema.partial().extend({
  id: z.string().min(1),
});

// ── Fee Schemas ────────────────────────────────────────────────────────────

export const CreateInvoiceSchema = z.object({
  studentId: z.string().min(1),
  batchId: z.string().optional(),
  courseId: z.string().optional(),
  items: z.array(z.object({
    description: z.string().min(1),
    amountPaisa: paisa,
  })).min(1),
  totalAmountPaisa: paisa,
  dueDate: date,
  notes: z.string().max(500).optional(),
});

export const RecordPaymentSchema = z.object({
  invoiceId: z.string().min(1),
  amountPaisa: paisa,
  method: PaymentMethodEnum,
  transactionId: z.string().max(100).optional(),
  notes: z.string().max(500).optional(),
  paidAt: timestamp.optional(),
});

export const BulkGenerateInvoicesSchema = z.object({
  batchId: z.string().optional(),
  courseId: z.string().optional(),
  amountPaisa: paisa,
  dueDate: date,
  description: z.string().min(1),
});

// ── Attendance Schemas ─────────────────────────────────────────────────────

export const MarkAttendanceSchema = z.object({
  batchId: z.string().min(1),
  date: date,
  records: z.record(z.string(), AttendanceStatusEnum),
  periodNumber: z.number().int().min(1).max(10).optional(), // For period-wise
});

export const AttendanceReportQuerySchema = z.object({
  batchId: z.string().optional(),
  studentId: z.string().optional(),
  fromDate: date,
  toDate: date,
});

// ── Faculty Schemas ────────────────────────────────────────────────────────

export const SalaryStructureSchema = z.object({
  type: z.enum(['fixed', 'per_class', 'hybrid']),
  fixedAmountPaisa: paisa.optional(),
  perClassRatePaisa: paisa.optional(),
});

export const CreateFacultySchema = z.object({
  firstName: z.string().min(1).max(100),
  lastName: z.string().min(1).max(100),
  phone: phone,
  email: email.optional(),
  specialization: z.string().max(100).optional(),
  employmentType: EmploymentTypeEnum.default('fullTime'),
  salaryStructure: SalaryStructureSchema.optional(),
  isActive: z.boolean().default(true),
  joiningDate: date.optional(),
});

export const UpdateFacultySchema = CreateFacultySchema.partial().extend({
  id: z.string().min(1),
});

export const MarkFacultyAttendanceSchema = z.object({
  facultyId: z.string().min(1),
  date: date,
  isPresent: z.boolean(),
  classesTaken: z.number().int().min(0).default(0),
  notes: z.string().max(200).optional(),
});

// ── Leave Management Schemas ─────────────────────────────────────────────

export const ApplyLeaveSchema = z.object({
  personType: z.enum(['student', 'faculty', 'staff']),
  personId: z.string().min(1),
  leaveType: LeaveTypeEnum,
  fromDate: date,
  toDate: date,
  reason: z.string().min(1).max(500),
  attachmentS3Key: z.string().optional(),
});

export const ApproveLeaveSchema = z.object({
  leaveId: z.string().min(1),
  approved: z.boolean(),
  remarks: z.string().max(500).optional(),
});

// ── Exam Schemas ───────────────────────────────────────────────────────────

export const CreateExamSchema = z.object({
  name: z.string().min(1).max(100),
  examType: ExamTypeEnum,
  courseId: z.string().optional(),
  batchIds: z.array(z.string()).default([]),
  subject: z.string().min(1),
  maxMarks: z.number().int().min(1),
  passingMarks: z.number().int().min(0),
  examDate: date,
  startTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  durationMinutes: z.number().int().min(15).optional(),
  venue: z.string().max(100).optional(),
});

export const UpdateExamSchema = CreateExamSchema.partial().extend({
  id: z.string().min(1),
});

export const UploadResultsSchema = z.object({
  examId: z.string().min(1),
  results: z.array(z.object({
    studentId: z.string().min(1),
    marksObtained: z.number().min(0),
    grade: z.string().max(5).optional(),
    remarks: z.string().max(200).optional(),
  })).min(1),
});

// ── Timetable Schemas ──────────────────────────────────────────────────────

export const CreateTimetableSlotSchema = z.object({
  batchId: z.string().min(1),
  facultyId: z.string().min(1),
  courseId: z.string().optional(),
  subject: z.string().min(1),
  dayOfWeek: z.number().int().min(0).max(6),
  startTime: z.string().regex(/^\d{2}:\d{2}$/),
  endTime: z.string().regex(/^\d{2}:\d{2}$/),
  room: z.string().max(50).optional(),
  isRecurring: z.boolean().default(true),
  effectiveFrom: date,
  effectiveTo: date.optional(),
});

// ── Material Schemas ───────────────────────────────────────────────────────

export const CreateMaterialSchema = z.object({
  title: z.string().min(1).max(200),
  description: z.string().max(500).optional(),
  materialType: MaterialTypeEnum,
  courseId: z.string().optional(),
  batchId: z.string().optional(),
  fileS3Key: z.string().optional(),
  externalUrl: z.string().url().optional(),
  isPublic: z.boolean().default(false),
});

export const UpdateMaterialSchema = CreateMaterialSchema.partial().extend({
  id: z.string().min(1),
});

// ── Notification Schemas ──────────────────────────────────────────────────

export const SendNotificationSchema = z.object({
  recipientType: z.enum(['student', 'parent', 'faculty', 'batch', 'course', 'all']),
  recipientIds: z.array(z.string()).optional(),
  batchId: z.string().optional(),
  courseId: z.string().optional(),
  channels: z.array(z.enum(['sms', 'email', 'whatsapp', 'push'])).min(1),
  templateId: z.string().optional(),
  subject: z.string().max(200).optional(),
  message: z.string().min(1).max(2000),
  variables: z.record(z.string(), z.string()).optional(),
  scheduleAt: timestamp.optional(),
});

// ── Certificate Schemas ─────────────────────────────────────────────────────

export const GenerateCertificateSchema = z.object({
  studentId: z.string().min(1),
  type: z.enum(['course_completion', 'achievement', 'attendance', 'ranking', 'transfer']),
  templateId: z.string().max(50).optional(),
  issueDate: date.optional(),
  expiryDate: date.optional(),
  metadata: z.record(z.string(), z.any()).optional(),
});

export const BulkGenerateCertificatesSchema = z.object({
  studentIds: z.array(z.string()).min(1).max(50),
  type: z.enum(['course_completion', 'achievement', 'attendance', 'ranking']),
  templateId: z.string().optional(),
  courseId: z.string().optional(),
  issueDate: date.optional(),
});

// ── Admission Portal Schemas ────────────────────────────────────────────────

export const AdmissionApplicationSchema = z.object({
  // Personal Details
  firstName: z.string().min(1).max(100),
  lastName: z.string().min(1).max(100),
  dob: date,
  gender: z.enum(['male', 'female', 'other']),
  phone: phone,
  email: email,
  address: z.string().min(1).max(500),
  
  // Parent/Guardian Details
  parentName: z.string().min(1).max(100),
  parentPhone: phone,
  parentEmail: email.optional(),
  parentOccupation: z.string().max(100).optional(),
  
  // Academic Background
  previousSchool: z.string().max(100).optional(),
  lastClass: z.string().max(50).optional(),
  percentageOrGrade: z.string().max(20).optional(),
  
  // Course Interest
  interestedCourseId: z.string().min(1),
  preferredBatchType: BatchTypeEnum.default('regular'),
  
  // Documents (S3 keys)
  documents: z.array(z.object({
    type: z.enum(['photo', 'birth_certificate', 'marksheet', 'tc', 'id_proof', 'other']),
    s3Key: z.string().min(1),
    originalName: z.string().optional(),
  })).optional(),
  
  // Additional
  howDidYouHear: z.string().max(100).optional(),
  specialNeeds: z.string().max(500).optional(),
  remarks: z.string().max(500).optional(),
});

export const UpdateApplicationStatusSchema = z.object({
  applicationId: z.string().min(1),
  status: z.enum([
    'submitted', 'under_review', 'documents_pending', 
    'shortlisted', 'interview_scheduled', 'interviewed',
    'admitted', 'rejected', 'waitlisted'
  ]),
  remarks: z.string().max(500).optional(),
  interviewDate: timestamp.optional(),
  interviewVenue: z.string().max(100).optional(),
});

// ── Lesson Plan Schemas ────────────────────────────────────────────────────

export const CreateLessonPlanSchema = z.object({
  batchId: z.string().min(1),
  facultyId: z.string().min(1),
  subject: z.string().min(1).max(100),
  topic: z.string().min(1).max(200),
  date: date,
  durationMinutes: z.number().int().min(15).max(300),
  objectives: z.array(z.string()).min(1),
  materials: z.array(z.string()).optional(),
  teachingMethod: z.string().max(200).optional(),
  boardWork: z.string().max(1000).optional(),
  homework: z.string().max(500).optional(),
  referenceBooks: z.array(z.string()).optional(),
  attachments: z.array(z.object({
    name: z.string(),
    s3Key: z.string(),
  })).optional(),
  status: z.enum(['draft', 'submitted', 'approved']).default('draft'),
});

export const UpdateLessonPlanSchema = CreateLessonPlanSchema.partial().extend({
  id: z.string().min(1),
});

// ── Homework/Assignment Schemas ─────────────────────────────────────────────

export const CreateHomeworkSchema = z.object({
  batchId: z.string().min(1),
  facultyId: z.string().min(1),
  subject: z.string().min(1).max(100),
  title: z.string().min(1).max(200),
  description: z.string().min(1).max(2000),
  assignedDate: date,
  dueDate: date,
  maxMarks: z.number().int().min(1).optional(),
  attachments: z.array(z.object({
    name: z.string(),
    s3Key: z.string(),
  })).optional(),
  allowLateSubmission: z.boolean().default(false),
  lateSubmissionPenalty: z.number().int().min(0).max(100).optional(), // percentage
});

export const SubmitHomeworkSchema = z.object({
  homeworkId: z.string().min(1),
  studentId: z.string().min(1),
  submissionText: z.string().max(5000).optional(),
  attachments: z.array(z.object({
    name: z.string(),
    s3Key: z.string(),
  })).optional(),
  submittedAt: timestamp.optional(),
});

export const GradeHomeworkSchema = z.object({
  submissionId: z.string().min(1),
  marksObtained: z.number().min(0),
  grade: z.string().max(5).optional(),
  feedback: z.string().max(1000).optional(),
  status: z.enum(['graded', 'resubmit', 'accepted']).default('graded'),
});

// ── Library Schemas ─────────────────────────────────────────────────────────

export const CreateBookSchema = z.object({
  isbn: z.string().max(20).optional(),
  title: z.string().min(1).max(200),
  authors: z.array(z.string()).min(1),
  publisher: z.string().max(100).optional(),
  edition: z.string().max(50).optional(),
  publicationYear: z.number().int().min(1800).max(2100).optional(),
  category: z.string().max(50),
  subject: z.string().max(50).optional(),
  language: z.string().max(30).default('English'),
  totalCopies: z.number().int().min(1).default(1),
  shelfLocation: z.string().max(50).optional(),
  coverImageS3Key: z.string().optional(),
  description: z.string().max(1000).optional(),
  tags: z.array(z.string()).optional(),
});

export const IssueBookSchema = z.object({
  bookId: z.string().min(1),
  memberType: z.enum(['student', 'faculty', 'staff']),
  memberId: z.string().min(1),
  issueDate: date,
  dueDate: date,
  notes: z.string().max(200).optional(),
});

export const ReturnBookSchema = z.object({
  issueId: z.string().min(1),
  returnDate: date.optional(),
  condition: z.enum(['good', 'damaged', 'lost']).default('good'),
  fineAmountPaisa: paisa.optional(),
  notes: z.string().max(200).optional(),
});

// ── Transport Schemas ───────────────────────────────────────────────────────

export const CreateRouteSchema = z.object({
  name: z.string().min(1).max(100),
  routeCode: z.string().max(20).optional(),
  stops: z.array(z.object({
    name: z.string().min(1).max(100),
    sequence: z.number().int().min(1),
    pickupTime: z.string().regex(/^\d{2}:\d{2}$/),
    dropTime: z.string().regex(/^\d{2}:\d{2}$/),
    latitude: z.number().optional(),
    longitude: z.number().optional(),
  })).min(2),
  totalDistanceKm: z.number().positive().optional(),
  estimatedDurationMinutes: z.number().int().positive().optional(),
  isActive: z.boolean().default(true),
});

export const CreateVehicleSchema = z.object({
  registrationNumber: z.string().min(1).max(20),
  vehicleType: z.enum(['bus', 'van', 'car', 'other']),
  capacity: z.number().int().min(1).max(100),
  model: z.string().max(50).optional(),
  manufacturer: z.string().max(50).optional(),
  yearOfManufacture: z.number().int().min(1990).max(2100).optional(),
  insuranceExpiry: date.optional(),
  permitExpiry: date.optional(),
  fitnessExpiry: date.optional(),
  isActive: z.boolean().default(true),
});

export const AssignStudentToRouteSchema = z.object({
  studentId: z.string().min(1),
  routeId: z.string().min(1),
  stopId: z.string().min(1), // References stop in route
  pickup: z.boolean().default(true),
  drop: z.boolean().default(true),
  effectiveFrom: date,
  effectiveTo: date.optional(),
});

export const CreateDriverSchema = z.object({
  firstName: z.string().min(1).max(100),
  lastName: z.string().min(1).max(100),
  phone: phone,
  licenseNumber: z.string().min(1).max(50),
  licenseExpiry: date,
  address: z.string().max(500).optional(),
  isActive: z.boolean().default(true),
});

// ── Sibling Linking Schema ─────────────────────────────────────────────────

export const LinkSiblingsSchema = z.object({
  primaryStudentId: z.string().min(1),
  siblingStudentIds: z.array(z.string()).min(1),
  relationship: z.enum(['brother', 'sister', 'step_brother', 'step_sister', 'other']).default('brother'),
});

// ── Document Vault Schema ─────────────────────────────────────────────────

export const UploadDocumentSchema = z.object({
  entityType: z.enum(['student', 'faculty', 'application']),
  entityId: z.string().min(1),
  documentType: z.enum([
    'photo', 'birth_certificate', 'marksheet', 'tc', 'id_proof',
    'address_proof', 'medical_record', 'achievement', 'other'
  ]),
  s3Key: z.string().min(1),
  originalName: z.string().max(200).optional(),
  fileSize: z.number().int().positive().optional(),
  mimeType: z.string().max(100).optional(),
  description: z.string().max(500).optional(),
  tags: z.array(z.string()).optional(),
  expiryDate: date.optional(),
  isConfidential: z.boolean().default(false),
});

// ── Notification Preferences Schema ───────────────────────────────────────

export const NotificationPreferencesSchema = z.object({
  entityType: z.enum(['student', 'faculty', 'parent']),
  entityId: z.string().min(1),
  channels: z.object({
    sms: z.boolean().default(true),
    email: z.boolean().default(true),
    whatsapp: z.boolean().default(false),
    push: z.boolean().default(true),
  }),
  eventSubscriptions: z.object({
    attendance: z.boolean().default(true),
    fee_reminder: z.boolean().default(true),
    homework: z.boolean().default(true),
    exam_result: z.boolean().default(true),
    notice: z.boolean().default(true),
    event: z.boolean().default(true),
    birthday: z.boolean().default(false),
  }),
  quietHours: z.object({
    enabled: z.boolean().default(false),
    start: z.string().regex(/^\d{2}:\d{2}$/).default('22:00'),
    end: z.string().regex(/^\d{2}:\d{2}$/).default('07:00'),
  }).optional(),
});

// ── Holiday Calendar Schema ────────────────────────────────────────────────

export const CreateHolidaySchema = z.object({
  name: z.string().min(1).max(100),
  date: date,
  type: z.enum(['national', 'religious', 'school', 'exam', 'other']),
  description: z.string().max(500).optional(),
  isRecurring: z.boolean().default(false),
  applicableTo: z.enum(['all', 'students', 'faculty', 'staff']).default('all'),
});

// ── Export Types ───────────────────────────────────────────────────────────

export type CreateStudentInput = z.infer<typeof CreateStudentSchema>;
export type UpdateStudentInput = z.infer<typeof UpdateStudentSchema>;
export type CreateBatchInput = z.infer<typeof CreateBatchSchema>;
export type CreateCourseInput = z.infer<typeof CreateCourseSchema>;
export type CreateInvoiceInput = z.infer<typeof CreateInvoiceSchema>;
export type RecordPaymentInput = z.infer<typeof RecordPaymentSchema>;
export type MarkAttendanceInput = z.infer<typeof MarkAttendanceSchema>;
export type CreateFacultyInput = z.infer<typeof CreateFacultySchema>;
export type CreateExamInput = z.infer<typeof CreateExamSchema>;
export type CreateLessonPlanInput = z.infer<typeof CreateLessonPlanSchema>;
export type CreateHomeworkInput = z.infer<typeof CreateHomeworkSchema>;
export type AdmissionApplicationInput = z.infer<typeof AdmissionApplicationSchema>;
export type CreateBookInput = z.infer<typeof CreateBookSchema>;
export type CreateRouteInput = z.infer<typeof CreateRouteSchema>;
export type CreateVehicleInput = z.infer<typeof CreateVehicleSchema>;
export type ApplyLeaveInput = z.infer<typeof ApplyLeaveSchema>;
