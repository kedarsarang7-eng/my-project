import 'package:flutter_test/flutter_test.dart';
import 'package:dukanx/features/mobile_shop/widgets/performance/filter_state_controller.dart';

void main() {
  group('MapFilterState', () {
    test('empty state has no active filters', () {
      const state = MapFilterState.empty();
      expect(state.hasActiveFilters, isFalse);
      expect(state.filters, isEmpty);
    });

    test('state with values has active filters', () {
      const state = MapFilterState({'status': 'active', 'type': 'service'});
      expect(state.hasActiveFilters, isTrue);
      expect(state.filters, hasLength(2));
    });

    test('get retrieves typed value by key', () {
      const state = MapFilterState({'count': 5, 'name': 'test'});
      expect(state.get<int>('count'), 5);
      expect(state.get<String>('name'), 'test');
      expect(state.get<String>('missing'), isNull);
    });

    test('copyWith adds or updates a filter', () {
      const state = MapFilterState({'a': 1});
      final updated = state.copyWith('b', 2);
      expect(updated.filters, {'a': 1, 'b': 2});

      final overwritten = updated.copyWith('a', 10);
      expect(overwritten.filters, {'a': 10, 'b': 2});
    });

    test('copyWith with null removes the filter', () {
      const state = MapFilterState({'a': 1, 'b': 2});
      final reduced = state.copyWith('a', null);
      expect(reduced.filters, {'b': 2});
    });

    test('without removes a filter key', () {
      const state = MapFilterState({'status': 'active', 'type': 'job'});
      final result = state.without('status');
      expect(result.filters, {'type': 'job'});
    });

    test('equality works correctly', () {
      const state1 = MapFilterState({'a': 1, 'b': 'hello'});
      const state2 = MapFilterState({'a': 1, 'b': 'hello'});
      const state3 = MapFilterState({'a': 1, 'b': 'world'});

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
      expect(state1.hashCode, state2.hashCode);
    });
  });

  group('FilterStateController', () {
    test('initializes with provided state', () {
      final controller = FilterStateController(
        initialState: const MapFilterState({'status': 'active'}),
      );
      expect(controller.state.get<String>('status'), 'active');
      expect(controller.hasActiveFilters, isTrue);
      controller.dispose();
    });

    test('updateState only notifies on actual change', () {
      int notifications = 0;
      final changedStates = <MapFilterState>[];

      final controller = FilterStateController(
        initialState: const MapFilterState({'status': 'active'}),
        onFilterChanged: (state) => changedStates.add(state),
      );
      controller.addListener(() => notifications++);

      // Same state — should not notify.
      final changed1 = controller.updateState(
        const MapFilterState({'status': 'active'}),
      );
      expect(changed1, isFalse);
      expect(notifications, 0);
      expect(changedStates, isEmpty);

      // Different state — should notify.
      final changed2 = controller.updateState(
        const MapFilterState({'status': 'completed'}),
      );
      expect(changed2, isTrue);
      expect(notifications, 1);
      expect(changedStates, hasLength(1));
      expect(changedStates.first.get<String>('status'), 'completed');

      controller.dispose();
    });

    test('reset returns to default state', () {
      int notifications = 0;
      final controller = FilterStateController(
        initialState: const MapFilterState({'x': 1}),
      );
      controller.addListener(() => notifications++);

      final changed = controller.reset(const MapFilterState.empty());
      expect(changed, isTrue);
      expect(controller.hasActiveFilters, isFalse);
      expect(notifications, 1);

      // Reset again to same — no notification.
      final notChanged = controller.reset(const MapFilterState.empty());
      expect(notChanged, isFalse);
      expect(notifications, 1);

      controller.dispose();
    });

    test('prevents full-list rescan on same tab reselection', () {
      int loadCalled = 0;
      final controller = FilterStateController(
        initialState: const MapFilterState({'tab': 'active'}),
        onFilterChanged: (_) => loadCalled++,
      );

      // User taps "active" tab again — same state.
      controller.updateState(const MapFilterState({'tab': 'active'}));
      expect(loadCalled, 0);

      // User switches to "completed" tab — different state.
      controller.updateState(const MapFilterState({'tab': 'completed'}));
      expect(loadCalled, 1);

      // User taps "completed" tab again — same state.
      controller.updateState(const MapFilterState({'tab': 'completed'}));
      expect(loadCalled, 1);

      controller.dispose();
    });
  });
}
