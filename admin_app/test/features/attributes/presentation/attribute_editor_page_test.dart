import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/auth/controllers/admin_auth_controller.dart';
import 'package:admin_app/features/auth/data/admin_auth_repository.dart';
import 'package:admin_app/features/auth/data/models/profile.dart';
import 'package:admin_app/features/attributes/data/admin_attribute_repository.dart';
import 'package:admin_app/features/attributes/data/models/category_attribute.dart';
import 'package:admin_app/features/attributes/presentation/attribute_editor_page.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAdminAttributeRepository extends Mock
    implements AdminAttributeRepository {}

class MockAdminAuthRepository extends Mock implements AdminAuthRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kCategoryId = 'cat-1';
const _kAttributeId = 'attr-1';

Profile _adminProfile() => Profile(
      id: 'admin-1',
      fullName: 'Admin',
      email: 'admin@example.com',
      role: ProfileRole.admin,
      isActive: true,
      createdAt: DateTime(2024),
    );

CategoryAttribute _selectAttr() => const CategoryAttribute(
      id: _kAttributeId,
      categoryId: _kCategoryId,
      name: 'Color',
      attributeKey: 'color',
      dataType: AttributeType.select,
      options: ['Red', 'Blue'],
      isRequired: false,
      displayOrder: 0,
      isActive: true,
    );

CategoryAttribute _textAttr() => const CategoryAttribute(
      id: _kAttributeId,
      categoryId: _kCategoryId,
      name: 'Brand',
      attributeKey: 'brand',
      dataType: AttributeType.text,
      options: [],
      isRequired: true,
      displayOrder: 1,
      isActive: true,
    );

Future<void> pumpEditorPage(
  WidgetTester tester,
  MockAdminAttributeRepository mockRepo, {
  String initialLocation = '/admin/categories/$_kCategoryId/attributes/new',
}) async {
  final mockAuthRepo = MockAdminAuthRepository();

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/admin/categories/:categoryId/attributes/new',
        builder: (context, state) => AttributeEditorPage(
          categoryId: state.pathParameters['categoryId']!,
        ),
      ),
      GoRoute(
        path: '/admin/categories/:categoryId/attributes/:attributeId/edit',
        builder: (context, state) => AttributeEditorPage(
          categoryId: state.pathParameters['categoryId']!,
          attributeId: state.pathParameters['attributeId'],
        ),
      ),
      GoRoute(
        path: '/admin/categories/:categoryId/attributes',
        builder: (_, __) => const Scaffold(body: Text('Attributes list')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAttributeRepositoryProvider.overrideWithValue(mockRepo),
        adminAuthRepositoryProvider.overrideWithValue(mockAuthRepo),
        adminAuthControllerProvider.overrideWith(
          (ref) => AdminAuthController(mockAuthRepo)
            ..state = AsyncData(_adminProfile()),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAdminAttributeRepository mockRepo;

  setUpAll(() {
    // Register fallback values for all mocktail `any()` matchers.
    registerFallbackValue(AttributeType.text);
    registerFallbackValue(
      const CategoryAttribute(
        id: '',
        categoryId: '',
        name: '',
        attributeKey: '',
        dataType: AttributeType.text,
        options: [],
        isRequired: false,
        displayOrder: 0,
        isActive: true,
      ),
    );
  });

  setUp(() {
    mockRepo = MockAdminAttributeRepository();
  });

  // ── CREATE MODE ───────────────────────────────────────────────────────

  group('Create mode', () {
    testWidgets('key auto-suggests from name and is editable', (tester) async {
      await pumpEditorPage(tester, mockRepo);
      await tester.pumpAndSettle();

      // Type in name.
      await tester.enterText(find.byKey(const Key('name_field')), 'Soil Type');
      await tester.pump();

      // Key field should be pre-filled with 'soil_type'.
      final keyField = tester.widget<TextFormField>(
        find.byKey(const Key('key_field')),
      );
      expect(keyField.controller?.text, 'soil_type');

      // Key field is enabled (editable) in create mode.
      expect(keyField.enabled, isTrue);
    });

    testWidgets('SELECT with zero options blocks save with exact error',
        (tester) async {
      await pumpEditorPage(tester, mockRepo);
      await tester.pumpAndSettle();

      // Fill name.
      await tester.enterText(find.byKey(const Key('name_field')), 'Color');
      await tester.pump();

      // Choose SELECT type.
      await tester.tap(find.byKey(const Key('data_type_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SELECT').last);
      await tester.pumpAndSettle();

      // Do NOT add any options — tap Save immediately.
      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      // Inline error must appear.
      expect(find.byKey(const Key('options_required_error')), findsOneWidget);
      expect(find.text('Add at least one option.'), findsOneWidget);

      // Repository should NOT have been called.
      verifyNever(
        () => mockRepo.create(
          categoryId: any(named: 'categoryId'),
          name: any(named: 'name'),
          attributeKey: any(named: 'attributeKey'),
          dataType: any(named: 'dataType'),
          options: any(named: 'options'),
          isRequired: any(named: 'isRequired'),
          displayOrder: any(named: 'displayOrder'),
        ),
      );
    });

    testWidgets('successful create navigates back to attributes list',
        (tester) async {
      when(
        () => mockRepo.create(
          categoryId: any(named: 'categoryId'),
          name: any(named: 'name'),
          attributeKey: any(named: 'attributeKey'),
          dataType: any(named: 'dataType'),
          options: any(named: 'options'),
          isRequired: any(named: 'isRequired'),
          displayOrder: any(named: 'displayOrder'),
        ),
      ).thenAnswer(
        (_) async => const CategoryAttribute(
          id: 'new-attr',
          categoryId: _kCategoryId,
          name: 'Brand',
          attributeKey: 'brand',
          dataType: AttributeType.text,
          options: [],
          isRequired: false,
          displayOrder: 0,
          isActive: true,
        ),
      );

      await pumpEditorPage(tester, mockRepo);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('name_field')), 'Brand');
      await tester.pump();

      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Attributes list'), findsOneWidget);
    });
  });

  // ── EDIT MODE ─────────────────────────────────────────────────────────

  group('Edit mode', () {
    const editLocation =
        '/admin/categories/$_kCategoryId/attributes/$_kAttributeId/edit';

    testWidgets('key and data_type fields are disabled with helper text',
        (tester) async {
      when(() => mockRepo.fetchForCategory(_kCategoryId))
          .thenAnswer((_) async => [_textAttr()]);

      await pumpEditorPage(tester, mockRepo, initialLocation: editLocation);
      await tester.pumpAndSettle();

      // Key field is disabled.
      final keyField = tester.widget<TextFormField>(
        find.byKey(const Key('key_field')),
      );
      expect(keyField.enabled, isFalse);

      // Helper text present.
      expect(find.text('Key is locked once created'), findsOneWidget);

      // Data type dropdown is disabled (onChanged == null).
      final dropdown = tester.widget<DropdownButtonFormField<AttributeType>>(
        find.byKey(const Key('data_type_dropdown')),
      );
      expect(dropdown.onChanged, isNull);
    });

    testWidgets('existing SELECT attribute loads options', (tester) async {
      when(() => mockRepo.fetchForCategory(_kCategoryId))
          .thenAnswer((_) async => [_selectAttr()]);

      await pumpEditorPage(tester, mockRepo, initialLocation: editLocation);
      await tester.pumpAndSettle();

      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);
    });

    testWidgets('successful update navigates back to attributes list',
        (tester) async {
      when(() => mockRepo.fetchForCategory(_kCategoryId))
          .thenAnswer((_) async => [_textAttr()]);
      when(() => mockRepo.update(any())).thenAnswer((_) async => _textAttr());

      await pumpEditorPage(tester, mockRepo, initialLocation: editLocation);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Attributes list'), findsOneWidget);
    });
  });
}
