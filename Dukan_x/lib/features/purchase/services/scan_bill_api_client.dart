// ============================================================================
// Scan Bill API Client
// ============================================================================
// HTTP client for scan bill operations:
// - extractBill: Upload image, run Textract OCR
// - matchProducts: Match parsed lines to catalog
// - createEntry: Create confirmed purchase entry
// - listEntries: List purchase entries
// - getEntry: Get single entry
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/logger_service.dart';
import '../models/scan_bill_models.dart';

class ScanBillApiClient {
  final Dio _dio;
  final LoggerService _logger;

  ScanBillApiClient({Dio? dio, LoggerService? logger})
    : _dio = dio ?? DioClient.instance,
      _logger = logger ?? sl<LoggerService>();

  // API Endpoints
  static const String _extractEndpoint = '/purchase/scan-bill/extract';
  static const String _matchEndpoint = '/purchase/scan-bill/match';
  static const String _entriesEndpoint = '/purchase/entries';

  /// Extract bill from image using OCR
  ///
  /// [imageFile] - Local image file to upload
  /// [verticalType] - Business vertical (grocery, pharmacy, etc.)
  /// [onProgress] - Optional callback for upload progress
  Future<ExtractionResult> extractBill({
    required File imageFile,
    required String verticalType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      _logger.info('ScanBillApiClient: Starting bill extraction', {
        'file': imageFile.path,
        'verticalType': verticalType,
      });

      // Read image and convert to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final filename = imageFile.path.split('/').last;

      // Determine MIME type
      final extension = filename.split('.').last.toLowerCase();
      String mimeType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'pdf':
          mimeType = 'application/pdf';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      // Create data URI
      final dataUri = 'data:$mimeType;base64,$base64Image';

      final response = await _dio.post(
        _extractEndpoint,
        data: {
          'imageBase64': base64Image,
          'filename': filename,
          'verticalType': verticalType,
        },
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = sent / total;
            onProgress?.call(progress);
            _logger.debug('ScanBillApiClient: Upload progress', {
              'progress': '${(progress * 100).toStringAsFixed(1)}%',
            });
          }
        },
      );

      if (response.statusCode == 200) {
        _logger.info('ScanBillApiClient: Extraction successful');
        return ExtractionResult.fromJson(response.data);
      } else {
        throw Exception('Extraction failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _logger.error('ScanBillApiClient: Extraction failed', {
        'error': e.message,
        'response': e.response?.data,
      });
      throw _handleDioError(e, 'Failed to extract bill from image');
    } catch (e, stackTrace) {
      _logger.error('ScanBillApiClient: Unexpected error during extraction', {
        'error': e.toString(),
      }, stackTrace);
      throw Exception('Failed to extract bill: $e');
    }
  }

  /// Extract bill from multiple images (for multi-page bills)
  Future<ExtractionResult> extractBillMulti({
    required List<File> imageFiles,
    required String verticalType,
    void Function(double progress, int current, int total)? onProgress,
  }) async {
    try {
      _logger.info('ScanBillApiClient: Starting multi-image extraction', {
        'imageCount': imageFiles.length,
        'verticalType': verticalType,
      });

      // Convert all images to base64
      final base64Images = <String>[];
      for (int i = 0; i < imageFiles.length; i++) {
        final bytes = await imageFiles[i].readAsBytes();
        base64Images.add(base64Encode(bytes));
        onProgress?.call((i + 1) / imageFiles.length, i + 1, imageFiles.length);
        _logger.debug(
          'Converted image ${i + 1}/${imageFiles.length} to base64',
        );
      }

      final response = await _dio.post(
        _extractEndpoint,
        data: {
          'imageBase64List': base64Images,
          'verticalType': verticalType,
          'isMultiPage': imageFiles.length > 1,
        },
        options: Options(
          sendTimeout: const Duration(
            minutes: 5,
          ), // Longer timeout for multi-image
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      if (response.statusCode == 200) {
        _logger.info('ScanBillApiClient: Multi-image extraction successful');
        return ExtractionResult.fromJson(response.data);
      } else {
        throw Exception(
          'Multi-image extraction failed: ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      _logger.error('ScanBillApiClient: Multi-image extraction failed', {
        'error': e.message,
        'response': e.response?.data,
      });
      throw _handleDioError(e, 'Failed to extract bill from multiple images');
    } catch (e, stackTrace) {
      _logger.error(
        'ScanBillApiClient: Unexpected error during multi-image extraction',
        {'error': e.toString()},
        stackTrace,
      );
      throw Exception('Failed to extract bill from multiple images: $e');
    }
  }

  /// Match parsed lines to product catalog
  ///
  /// [rid] - Request ID from extraction
  /// [parsedLines] - Lines extracted from OCR
  /// [verticalType] - Business vertical
  /// [supplierName] - Optional supplier name for better matching
  Future<MatchResultResponse> matchProducts({
    required String rid,
    required List<ParsedLineItem> parsedLines,
    required String verticalType,
    String? supplierName,
  }) async {
    try {
      _logger.info('ScanBillApiClient: Matching products', {
        'rid': rid,
        'lineCount': parsedLines.length,
      });

      final response = await _dio.post(
        _matchEndpoint,
        data: {
          'rid': rid,
          'parsedLines': parsedLines.map((e) => e.toJson()).toList(),
          'verticalType': verticalType,
          'supplierName': supplierName,
        },
      );

      if (response.statusCode == 200) {
        _logger.info('ScanBillApiClient: Matching successful');
        return MatchResultResponse.fromJson(response.data);
      } else {
        throw Exception('Matching failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _logger.error('ScanBillApiClient: Matching failed', {
        'error': e.message,
        'response': e.response?.data,
      });
      throw _handleDioError(e, 'Failed to match products');
    } catch (e, stackTrace) {
      _logger.error('ScanBillApiClient: Unexpected error during matching', {
        'error': e.toString(),
      }, stackTrace);
      throw Exception('Failed to match products: $e');
    }
  }

  /// Create confirmed purchase entry
  ///
  /// [rid] - Request ID
  /// [s3ImageKey] - S3 key for the bill image
  /// [lineItems] - Confirmed line items
  /// [supplierDetails] - Supplier and bill details
  /// [totalAmount] - Total bill amount
  /// [verticalType] - Business vertical
  Future<Map<String, dynamic>> createEntry({
    required String rid,
    required String s3ImageKey,
    required List<ReviewLineItem> lineItems,
    required SupplierDetails supplierDetails,
    required double totalAmount,
    required String verticalType,
    double? gstAmount,
  }) async {
    try {
      _logger.info('ScanBillApiClient: Creating purchase entry', {
        'rid': rid,
        'itemCount': lineItems.length,
        'totalAmount': totalAmount,
      });

      // Filter out deleted items and convert to confirmed format
      final validItems = lineItems
          .where((item) => !item.isDeleted && item.isValid)
          .map(
            (item) => {
              'productId': item.productId,
              'productName': item.productName,
              'quantity': item.quantity,
              'unit': item.unit,
              'unitPrice': item.unitPrice,
              'totalPrice': item.totalPrice,
              'hsnCode': item.hsnCode,
              'batchNo': item.batchNo,
              'expiryDate': item.expiryDate,
              'isNewProduct': item.isNewProduct,
              'newProductData': item.newProductData?.toJson(),
            },
          )
          .toList();

      final response = await _dio.post(
        _entriesEndpoint,
        data: {
          'rid': rid,
          'supplierId': supplierDetails.supplierId,
          'supplierName': supplierDetails.supplierName,
          'billNumber': supplierDetails.billNumber,
          'billDate':
              supplierDetails.billDate?.toIso8601String() ??
              DateTime.now().toIso8601String(),
          'billImageS3Key': s3ImageKey,
          'lineItems': validItems,
          'totalAmount': totalAmount,
          'gstAmount': gstAmount,
          'paymentStatus': supplierDetails.paymentStatus,
          'verticalType': verticalType,
          'idempotencyKey': rid, // Use RID as idempotency key
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _logger.info('ScanBillApiClient: Entry created successfully');
        return response.data;
      } else {
        throw Exception('Entry creation failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _logger.error('ScanBillApiClient: Entry creation failed', {
        'error': e.message,
        'response': e.response?.data,
      });
      throw _handleDioError(e, 'Failed to create purchase entry');
    } catch (e, stackTrace) {
      _logger.error(
        'ScanBillApiClient: Unexpected error during entry creation',
        {'error': e.toString()},
        stackTrace,
      );
      throw Exception('Failed to create entry: $e');
    }
  }

  /// Create confirmed purchase entry from model (for offline queue sync)
  Future<Map<String, dynamic>> createPurchaseEntry({
    required PurchaseEntry entry,
    required List<File> imageFiles,
  }) async {
    return createEntry(
      rid: entry.rid,
      s3ImageKey: entry.billImageS3Key,
      lineItems: entry.lineItems.map((item) => ReviewLineItem(
        id: item['id'] ?? '',
        productId: item['productId'],
        productName: item['productName'] ?? '',
        quantity: (item['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: item['unit'] ?? '',
        unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0.0,
        totalPrice: (item['totalPrice'] as num?)?.toDouble() ?? 0.0,
        hsnCode: item['hsnCode'],
        batchNo: item['batchNo'],
        expiryDate: item['expiryDate'],
        isNewProduct: item['isNewProduct'] ?? false,
      )).toList(),
      supplierDetails: SupplierDetails(
        supplierId: entry.supplierId,
        supplierName: entry.supplierName,
        billNumber: entry.billNumber,
        billDate: DateTime.tryParse(entry.billDate),
        paymentStatus: entry.paymentStatus,
      ),
      totalAmount: entry.totalAmount,
      verticalType: entry.verticalType,
      gstAmount: entry.gstAmount,
    );
  }

  /// List purchase entries
  ///
  /// [from] - Start date (optional)
  /// [to] - End date (optional)
  /// [supplierId] - Filter by supplier (optional)
  /// [limit] - Number of entries to fetch
  /// [cursor] - Pagination cursor
  Future<Map<String, dynamic>> listEntries({
    DateTime? from,
    DateTime? to,
    String? supplierId,
    int limit = 50,
    String? cursor,
  }) async {
    try {
      _logger.info('ScanBillApiClient: Listing purchase entries');

      final queryParams = <String, dynamic>{'limit': limit};

      if (from != null) {
        queryParams['from'] = from.toIso8601String();
      }
      if (to != null) {
        queryParams['to'] = to.toIso8601String();
      }
      if (supplierId != null) {
        queryParams['supplierId'] = supplierId;
      }
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }

      final response = await _dio.get(
        _entriesEndpoint,
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        _logger.info('ScanBillApiClient: Entries listed successfully');
        return response.data;
      } else {
        throw Exception('List entries failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _logger.error('ScanBillApiClient: List entries failed', {
        'error': e.message,
        'response': e.response?.data,
      });
      throw _handleDioError(e, 'Failed to list purchase entries');
    } catch (e, stackTrace) {
      _logger.error('ScanBillApiClient: Unexpected error during list entries', {
        'error': e.toString(),
      }, stackTrace);
      throw Exception('Failed to list entries: $e');
    }
  }

  /// Get single purchase entry
  ///
  /// [rid] - Entry RID
  Future<Map<String, dynamic>> getEntry(String rid) async {
    try {
      _logger.info('ScanBillApiClient: Getting purchase entry', {'rid': rid});

      final response = await _dio.get('$_entriesEndpoint/$rid');

      if (response.statusCode == 200) {
        _logger.info('ScanBillApiClient: Entry retrieved successfully');
        return response.data;
      } else {
        throw Exception('Get entry failed: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      _logger.error('ScanBillApiClient: Get entry failed', {
        'error': e.message,
        'response': e.response?.data,
      });
      throw _handleDioError(e, 'Failed to get purchase entry');
    } catch (e, stackTrace) {
      _logger.error('ScanBillApiClient: Unexpected error during get entry', {
        'error': e.toString(),
      }, stackTrace);
      throw Exception('Failed to get entry: $e');
    }
  }

  /// Handle Dio errors and convert to user-friendly messages
  Exception _handleDioError(DioException error, String defaultMessage) {
    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;

      // Extract error message from response if available
      String message = defaultMessage;
      if (data is Map) {
        message = data['message'] ?? data['error'] ?? defaultMessage;
      }

      switch (statusCode) {
        case 400:
          return Exception('Invalid request: $message');
        case 401:
          return Exception('Session expired. Please log in again.');
        case 403:
          return Exception('Access denied. Contact your administrator.');
        case 404:
          return Exception('Not found: $message');
        case 429:
          return Exception('Too many requests. Please wait a moment.');
        case 500:
        case 502:
        case 503:
          return Exception('Server error. Please try again later.');
        default:
          return Exception('$message (Error $statusCode)');
      }
    }

    // Network errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return Exception('Connection timeout. Please check your internet.');
    }

    if (error.type == DioExceptionType.connectionError) {
      return Exception('No internet connection. Please check your network.');
    }

    return Exception('$defaultMessage: ${error.message}');
  }
}
