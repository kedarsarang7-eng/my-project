import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/bill_item.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';

class ProcessVoiceCommand implements UseCase<List<BillItem>, String> {
  final ProductsRepository repository;
  final SessionManager sessionManager;

  ProcessVoiceCommand(this.repository, this.sessionManager);

  @override
  Future<Either<Failure, List<BillItem>>> call(String command) async {
    try {
      if (!sessionManager.isAuthenticated) {
        return Left(InputFailure('User not authenticated'));
      }
      final userId = sessionManager.ownerId;
      if (userId == null) {
        return Left(InputFailure('Owner ID not found'));
      }

      final items = await _parseCommand(command, userId);
      return Right(items);
    } catch (e) {
      return Left(InputFailure(e.toString()));
    }
  }

  Future<List<BillItem>> _parseCommand(String command, String userId) async {
    // 1. Pre-process: Convert number words to digits (Hindi/Marathi/English)
    String processed = _convertNumberWords(command.toLowerCase());

    // 2. Split by numbers to isolate items
    // Regex matches a number followed by anything until the next number
    final RegExp itemRegex = RegExp(r'(\d+(?:\.\d+)?)\s*([^\d]+)');
    final matches = itemRegex.allMatches(processed);

    List<BillItem> billItems = [];

    for (final match in matches) {
      double qty = double.tryParse(match.group(1) ?? '1') ?? 1;
      String rest = match.group(2)?.trim() ?? '';

      // 3. Extract Unit and Product Name
      // Heuristic: Check for common units
      String unit = 'unit';
      String productName = rest;

      final units = [
        'kg',
        'g',
        'gm',
        'gram',
        'liter',
        'litre',
        'l',
        'ml',
        'packet',
        'pkt',
        'box',
        'piece',
        'pcs',
        'dozen',
        'dz',
      ];

      for (final u in units) {
        if (rest.startsWith('$u ')) {
          unit = u;
          productName = rest.substring(u.length).trim();
          break;
        }
      }

      // 4. Match with Product Repository
      final result = await repository.search(productName, userId: userId);

      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        final products = result.data!;
        // Simple matching logic: Pick the first exact match, or the first partial match
        final exactMatch = products
            .where((p) => p.name.toLowerCase() == productName)
            .firstOrNull;
        final matchedProduct = exactMatch ?? products.firstOrNull;

        if (matchedProduct != null) {
          billItems.add(
            BillItem(
              productId: matchedProduct.id,
              name: matchedProduct.name,
              quantity: qty,
              rate: matchedProduct.sellingPrice,
              amount: qty * matchedProduct.sellingPrice,
              unit: matchedProduct.unit,
            ),
          );
        } else {
          // Fallback if search returned items but logic filtered them out (unlikely)
          _addRawItem(billItems, productName, qty, unit);
        }
      } else {
        // No product found, create raw item
        _addRawItem(billItems, productName, qty, unit);
      }
    }

    return billItems;
  }

  void _addRawItem(List<BillItem> items, String name, double qty, String unit) {
    items.add(
      BillItem(
        productId: '',
        name: name,
        quantity: qty,
        rate: 0,
        amount: 0,
        unit: unit,
      ),
    );
  }

  String _convertNumberWords(String input) {
    // Simple basic mapping
    final map = {
      'one': '1',
      'two': '2',
      'three': '3',
      'four': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'ten': '10',
      'ek': '1',
      'do': '2',
      'teen': '3',
      'char': '4',
      'paanch': '5',
      'panch': '5',
      'che': '6',
      'saat': '7',
      'aath': '8',
      'nau': '9',
      'das': '10',
      'aadha': '0.5',
      'half': '0.5',
      'pav': '0.25',
    };

    String out = input;
    map.forEach((key, value) {
      out = out.replaceAll(RegExp(r'\b' + key + r'\b'), value);
    });
    return out;
  }
}
