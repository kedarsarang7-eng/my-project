import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/error_handler.dart';
import '../models/campaign_model.dart';
import '../models/template_model.dart';

/// Marketing Campaign Repository
///
/// Handles local database operations for marketing campaigns
/// with offline-first architecture.
class MarketingRepository {
  final AppDatabase _db;

  MarketingRepository(this._db);

  // ============================================================================
  // CAMPAIGN OPERATIONS
  // ============================================================================

  /// Create a new campaign
  Future<RepositoryResult<CampaignModel>> createCampaign({
    required String userId,
    required String name,
    required String type,
    required String targetSegment,
    required String message,
    String? templateId,
    String? imageUrl,
    DateTime? scheduledAt,
    String? customFilterJson,
  }) async {
    try {
      final id = const Uuid().v4();
      final now = DateTime.now();

      await _db
          .into(_db.marketingCampaigns)
          .insert(
            MarketingCampaignsCompanion.insert(
              id: id,
              userId: userId,
              name: name,
              type: type,
              targetSegment: Value(targetSegment),
              message: Value(message),
              templateId: Value(templateId),
              imageUrl: Value(imageUrl),
              scheduledAt: Value(scheduledAt),
              customFilterJson: Value(customFilterJson),
              createdAt: now,
            ),
          );

      final entity = await (_db.select(
        _db.marketingCampaigns,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('Failed to create campaign');
      }

      return RepositoryResult.success(CampaignModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error creating campaign: $e');
    }
  }

  /// Get all campaigns for a user
  Future<RepositoryResult<List<CampaignModel>>> getAllCampaigns({
    required String userId,
    String? status,
  }) async {
    try {
      var query = _db.select(_db.marketingCampaigns)
        ..where((t) => t.userId.equals(userId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

      if (status != null) {
        query = query..where((t) => t.status.equals(status));
      }

      final entities = await query.get();
      return RepositoryResult.success(
        entities.map((e) => CampaignModelX.fromEntity(e)).toList(),
      );
    } catch (e) {
      return RepositoryResult.failure('Error fetching campaigns: $e');
    }
  }

  /// Get campaign by ID
  Future<RepositoryResult<CampaignModel>> getCampaignById(String id) async {
    try {
      final entity = await (_db.select(
        _db.marketingCampaigns,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (entity == null) {
        return RepositoryResult.failure('Campaign not found');
      }

      return RepositoryResult.success(CampaignModelX.fromEntity(entity));
    } catch (e) {
      return RepositoryResult.failure('Error fetching campaign: $e');
    }
  }

  /// Update campaign status
  Future<RepositoryResult<void>> updateCampaignStatus({
    required String id,
    required String status,
    int? sentCount,
    int? failedCount,
    DateTime? startedAt,
    DateTime? completedAt,
  }) async {
    try {
      await (_db.update(
        _db.marketingCampaigns,
      )..where((t) => t.id.equals(id))).write(
        MarketingCampaignsCompanion(
          status: Value(status),
          sentCount: sentCount != null
              ? Value(sentCount)
              : const Value.absent(),
          failedCount: failedCount != null
              ? Value(failedCount)
              : const Value.absent(),
          startedAt: startedAt != null
              ? Value(startedAt)
              : const Value.absent(),
          completedAt: completedAt != null
              ? Value(completedAt)
              : const Value.absent(),
          isSynced: const Value(false),
        ),
      );

      return RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure('Error updating campaign: $e');
    }
  }

  /// Get scheduled campaigns that need to run
  Future<List<CampaignModel>> getScheduledCampaigns(String userId) async {
    final now = DateTime.now();
    final entities =
        await (_db.select(_db.marketingCampaigns)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.status.equals('SCHEDULED') &
                  t.scheduledAt.isSmallerOrEqualValue(now),
            ))
            .get();
    return entities.map((e) => CampaignModelX.fromEntity(e)).toList();
  }

  // ============================================================================
  // CAMPAIGN LOG OPERATIONS
  // ============================================================================

  /// Log a message send attempt
  Future<void> logMessageSent({
    required String campaignId,
    required String customerId,
    required String channel,
    required String phone,
    required String message,
    required String status,
    String? errorMessage,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    await _db
        .into(_db.campaignLogs)
        .insert(
          CampaignLogsCompanion.insert(
            id: id,
            campaignId: campaignId,
            customerId: customerId,
            status: status, // status is required String, not Value
            sentAt: now,
            channel: Value(channel),
            phone: Value(phone),
            messageSent: Value(message),
            errorMessage: Value(errorMessage),
            scheduledAt: Value(now),
            createdAt: now,
          ),
        );
  }

  /// Get logs for a campaign
  Future<RepositoryResult<List<Map<String, dynamic>>>> getCampaignLogs(
    String campaignId,
  ) async {
    try {
      final entities =
          await (_db.select(_db.campaignLogs)
                ..where((t) => t.campaignId.equals(campaignId))
                ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
              .get();

      final logs = entities
          .map(
            (e) => {
              'id': e.id,
              'customerId': e.customerId,
              'channel': e.channel,
              'phone': e.phone,
              'status': e.status,
              'sentAt': e.sentAt,
              'errorMessage': e.errorMessage,
            },
          )
          .toList();

      return RepositoryResult.success(logs);
    } catch (e) {
      return RepositoryResult.failure('Error fetching logs: $e');
    }
  }

  // ============================================================================
  // TEMPLATE OPERATIONS
  // ============================================================================

  /// Create a message template
  Future<RepositoryResult<void>> createTemplate({
    required String userId,
    required String name,
    required String category,
    required String content,
    String? imageUrl,
    String language = 'en',
    bool isSystem = false,
  }) async {
    try {
      final id = const Uuid().v4();
      final now = DateTime.now();

      await _db
          .into(_db.messageTemplates)
          .insert(
            MessageTemplatesCompanion.insert(
              id: id,
              title: name, // Required title field
              content: content,
              type: category, // Required type field
              userId: Value(userId),
              name: Value(name),
              category: Value(category),
              imageUrl: Value(imageUrl),
              language: Value(language),
              isSystemTemplate: Value(isSystem),
              createdAt: now,
              updatedAt: now,
            ),
          );

      return RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure('Error creating template: $e');
    }
  }

  /// Get all templates for a user
  Future<RepositoryResult<List<Map<String, dynamic>>>> getTemplates(
    String userId,
  ) async {
    try {
      final entities =
          await (_db.select(_db.messageTemplates)
                ..where(
                  (t) =>
                      t.userId.equals(userId) | t.isSystemTemplate.equals(true),
                )
                ..where((t) => t.isActive.equals(true))
                ..orderBy([
                  (t) => OrderingTerm.desc(t.isSystemTemplate),
                  (t) => OrderingTerm.asc(t.name),
                ]))
              .get();

      final templates = entities
          .map(
            (e) => {
              'id': e.id,
              'name': e.name,
              'category': e.category,
              'content': e.content,
              'language': e.language,
              'isSystem': e.isSystemTemplate,
            },
          )
          .toList();

      return RepositoryResult.success(templates);
    } catch (e) {
      return RepositoryResult.failure('Error fetching templates: $e');
    }
  }

  /// Initialize system templates for a user
  Future<void> initializeSystemTemplates(String userId) async {
    for (final template in SystemTemplates.templates) {
      await createTemplate(
        userId: userId,
        name: template['name'] as String,
        category: template['category'] as String,
        content: template['content'] as String,
        language: template['language'] as String,
        isSystem: true,
      );
    }
  }
}
