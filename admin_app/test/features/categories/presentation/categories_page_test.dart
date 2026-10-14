import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:admin_app/core/theme/app_theme.dart';
import 'package:admin_app/features/auth/controllers/admin_auth_controller.dart';
import 'package:admin_app/features/auth/data/admin_auth_repository.dart';
import 'package:admin_app/features/auth/data/models/profile.dart';
import 'package:admin_app/features/categories/data/admin_category_repository.dart';
import 'package:admin_app/features/categories/data/models/category.dart';
import 'package:admin_app/features/categories/presentation/categories_page.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAdminCategoryRepository extends Mock
    implements AdminCategoryRepository {}

class MockAdminAuthRepository extends Mock implements AdminAuthRepository {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Profile _adminProfile() => Profile(
      id: 'admin-1',
      fullName: 'Admin',
      email: 'admin@example.com',
      role: ProfileRole.admin,
      isActive: true,
      createdAt: DateTime(2024),
    );

List<Category> _twoCategories() => [
      const Category(
        id: 'cat-1',
        name: 'Seeds',
        slug: 'seeds',
        displayOrder: 1,
        isActive: true,
      ),
      const Category(
        id: 'cat-2',
        parentId: 'cat-1',
        name: 'Hybrid Seeds',
        slug: 'hybrid-seeds',
        displayOrder: 1,
        isActive: true,
      ),
    ];

Future<void> pumpCategoriesPage(
  WidgetTester tester,
  MockAdminCategoryRepository mockCatRepo,
) async {
  final router = GoRouter(
    initialLocation: '/admin/categories',
    routes: [
      GoRoute(
        path: '/admin/categories',
        builder: (_, __) => const CategoriesPage(),
      ),
      GoRoute(
        path: '/admin/categories/new',
        builder: (_, __) => const Scaffold(body: Text('New category page')),
      ),
      GoRoute(
        path: '/admin/categories/:id/edit',
        builder: (_, __) => const Scaffold(body: Text('Edit category page')),
      ),
      GoRoute(
        path: '/admin/categories/:id/attributes',
        builder: (_, __) => const Scaffold(body: Text('Attributes page')),
      ),
    ],
  );

  final mockAuthRepo = MockAdminAuthRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminCategoryRepositoryProvider.overrideWithValue(mockCatRepo),
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
  late MockAdminCategoryRepository mockCatRepo;

  setUp(() {
    mockCatRepo = MockAdminCategoryRepository();
  });

  testWidgets('shows loading then renders tree with two categories',
      (tester) async {
    when(() => mockCatRepo.fetchAll(
            includeInactive: any(named: 'includeInactive')))
        .thenAnswer((_) async => _twoCategories());

    await pumpCategoriesPage(tester, mockCatRepo);
    // Loading state.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // Both category names rendered.
    expect(find.text('Seeds'), findsOneWidget);
    expect(find.text('Hybrid Seeds'), findsOneWidget);
  });

  testWidgets('empty state shows "No categories yet"', (tester) async {
    when(() => mockCatRepo.fetchAll(
            includeInactive: any(named: 'includeInactive')))
        .thenAnswer((_) async => []);

    await pumpCategoriesPage(tester, mockCatRepo);
    await tester.pumpAndSettle();

    expect(find.text('No categories yet'), findsOneWidget);
  });

  testWidgets('error state shows Retry button', (tester) async {
    when(() => mockCatRepo.fetchAll(
            includeInactive: any(named: 'includeInactive')))
        .thenThrow(Exception('network error'));

    await pumpCategoriesPage(tester, mockCatRepo);
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('"New category" button navigates to /admin/categories/new',
      (tester) async {
    when(() => mockCatRepo.fetchAll(
            includeInactive: any(named: 'includeInactive')))
        .thenAnswer((_) async => _twoCategories());

    await pumpCategoriesPage(tester, mockCatRepo);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new_category_button')));
    await tester.pumpAndSettle();

    expect(find.text('New category page'), findsOneWidget);
  });

  testWidgets('deactivate shows confirm dialog and calls repo on confirm',
      (tester) async {
    when(() => mockCatRepo.fetchAll(
            includeInactive: any(named: 'includeInactive')))
        .thenAnswer((_) async => _twoCategories());
    when(() => mockCatRepo.deactivate(any())).thenAnswer((_) async {});
    // After deactivate, return one inactive category.
    int fetchCount = 0;
    when(() => mockCatRepo.fetchAll(
        includeInactive: any(named: 'includeInactive'))).thenAnswer((_) async {
      fetchCount++;
      if (fetchCount == 1) return _twoCategories();
      return [
        _twoCategories().first.copyWith(isActive: false),
        _twoCategories().last,
      ];
    });

    await pumpCategoriesPage(tester, mockCatRepo);
    await tester.pumpAndSettle();

    // Tap the deactivate icon on the first category (Seeds).
    final deactivateIcons = find.byIcon(Icons.block_outlined);
    expect(deactivateIcons, findsWidgets);
    await tester.tap(deactivateIcons.first);
    await tester.pumpAndSettle();

    // Confirm dialog visible.
    expect(find.text('Deactivate'), findsWidgets);
    await tester.tap(find.byKey(const Key('confirm_action')));
    await tester.pumpAndSettle();

    verify(() => mockCatRepo.deactivate('cat-1')).called(1);
  });
}
