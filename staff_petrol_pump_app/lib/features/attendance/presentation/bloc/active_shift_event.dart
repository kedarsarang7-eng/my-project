// ============================================================================
// ACTIVE SHIFT EVENTS
// ============================================================================

import 'package:equatable/equatable.dart';

abstract class ActiveShiftEvent extends Equatable {
  const ActiveShiftEvent();

  @override
  List<Object?> get props => [];
}

/// Load active shift data
class LoadActiveShift extends ActiveShiftEvent {
  final String shiftId;

  const LoadActiveShift({required this.shiftId});

  @override
  List<Object?> get props => [shiftId];
}

/// Refresh shift statistics
class RefreshShiftStats extends ActiveShiftEvent {
  const RefreshShiftStats();
}

/// Record a new transaction
class RecordTransaction extends ActiveShiftEvent {
  final String fuelType;
  final double litres;
  final double amount;
  final String paymentMethod;

  const RecordTransaction({
    required this.fuelType,
    required this.litres,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  List<Object?> get props => [fuelType, litres, amount, paymentMethod];
}

/// End the current shift
class EndShift extends ActiveShiftEvent {
  final String shiftId;

  const EndShift({required this.shiftId});

  @override
  List<Object?> get props => [shiftId];
}

/// Real-time update received via WebSocket
class RealTimeUpdateReceived extends ActiveShiftEvent {
  final String eventType;
  final Map<String, dynamic> payload;

  const RealTimeUpdateReceived({
    required this.eventType,
    required this.payload,
  });

  @override
  List<Object?> get props => [eventType, payload];
}
