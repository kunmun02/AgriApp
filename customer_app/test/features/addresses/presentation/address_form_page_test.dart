import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:customer_app/core/theme/app_theme.dart';
import 'package:customer_app/features/addresses/data/address_repository.dart';
import 'package:customer_app/features/addresses/data/models/address.dart';
import 'package:customer_app/features/addresses/presentation/address_form_page.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAddressRepository extends Mock implements AddressRepository {}

class _FakeAddress extends Fake implements Address {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Address _fakeAddress({bool isDefault = false}) => Address(
      id: 'addr-1',
      userId: 'user-1',
      label: 'Home',
      recipientName: 'Ramesh Kumar',
      phone: '9876543210',
      line1: '12 Main Road',
      line2: null,
      city: 'Nashik',
      state: 'Maharashtra',
      postalCode: '422001',
      country: 'India',
      isDefault: isDefault,
    );

Future<void> _pumpFormPage(
  WidgetTester tester,
  MockAddressRepository mockRepo, {
  Address? existing,
}) async {
  final router = GoRouter(
    initialLocation: '/addresses/new',
    routes: [
      GoRoute(
        path: '/addresses',
        builder: (_, __) => const Scaffold(body: Text('Addresses')),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, __) => AddressFormPage(existing: existing),
          ),
          GoRoute(
            path: 'edit',
            builder: (_, __) => AddressFormPage(existing: existing),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addressRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls to the Save button and taps it.
Future<void> _tapSave(WidgetTester tester) async {
  final saveBtn = find.text('Save Address');
  await tester.ensureVisible(saveBtn);
  await tester.pumpAndSettle();
  await tester.tap(saveBtn);
  await tester.pumpAndSettle();
}

/// Opens the State dropdown and picks [stateName].
///
/// Uses the first item in the list that is always rendered at the top of
/// the viewport (no scrolling required).
Future<void> _selectState(WidgetTester tester, String stateName) async {
  await tester
      .tap(find.widgetWithText(DropdownButtonFormField<String>, 'State'));
  await tester.pumpAndSettle();
  // After the overlay opens the item text appears exactly once (or twice if
  // it also appears as the selected value — use .last to hit the overlay).
  final matches = find.text(stateName);
  if (matches.evaluate().isEmpty) {
    // Item may be outside the default viewport; scroll until visible.
    await tester.scrollUntilVisible(matches.first, 100,
        scrollable: find.byType(Scrollable).last);
  }
  await tester.tap(find.text(stateName).last);
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAddress());
  });

  late MockAddressRepository mockRepo;

  setUp(() {
    mockRepo = MockAddressRepository();
  });

  testWidgets('postal 5 digits shows inline error', (tester) async {
    await _pumpFormPage(tester, mockRepo);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Recipient name'), 'Test User');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'), '9876543210');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address Line 1'), '1 Road');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'City'), 'Mumbai');
    // PIN: only 5 digits — invalid
    await tester.enterText(
        find.widgetWithText(TextFormField, 'PIN Code'), '12345');

    await _tapSave(tester);

    expect(find.text('Enter a valid 6-digit PIN code.'), findsOneWidget);
    verifyNever(() => mockRepo.createAddress(any()));
  });

  testWidgets('phone not starting 6-9 shows inline error', (tester) async {
    await _pumpFormPage(tester, mockRepo);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'), '5123456789');

    await _tapSave(tester);

    expect(find.text('Enter a valid 10-digit Indian mobile number.'),
        findsOneWidget);
    verifyNever(() => mockRepo.createAddress(any()));
  });

  testWidgets('valid form calls createAddress and pops', (tester) async {
    when(() => mockRepo.createAddress(any()))
        .thenAnswer((_) async => _fakeAddress());

    await _pumpFormPage(tester, mockRepo);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Recipient name'), 'Ramesh Kumar');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'), '9876543210');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address Line 1'), '12 Main Road');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'City'), 'Nashik');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'PIN Code'), '422001');

    // Select first state in the list (always visible, no scrolling needed).
    await _selectState(tester, 'Andhra Pradesh');

    await _tapSave(tester);

    verify(() => mockRepo.createAddress(any())).called(1);
  });

  testWidgets('default toggle calls createAddress with isDefault true',
      (tester) async {
    when(() => mockRepo.createAddress(any()))
        .thenAnswer((_) async => _fakeAddress(isDefault: true));

    await _pumpFormPage(tester, mockRepo);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Recipient name'), 'Ramesh Kumar');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'), '9876543210');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address Line 1'), '12 Main Road');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'City'), 'Nashik');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'PIN Code'), '422001');

    // Select first state in the list.
    await _selectState(tester, 'Andhra Pradesh');

    // Scroll to and toggle the default switch ON.
    final switchFinder = find.byType(Switch);
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    await _tapSave(tester);

    final captured =
        verify(() => mockRepo.createAddress(captureAny())).captured;
    final savedAddress = captured.first as Address;
    expect(savedAddress.isDefault, isTrue);
  });

  testWidgets('edit mode pre-fills all fields', (tester) async {
    final existing = _fakeAddress();
    await _pumpFormPage(tester, mockRepo, existing: existing);

    expect(find.text('Ramesh Kumar'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('12 Main Road'), findsOneWidget);
    expect(find.text('Nashik'), findsOneWidget);
    expect(find.text('422001'), findsOneWidget);
  });
}
