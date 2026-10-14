import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/admin_auth_controller.dart';

/// Breakpoint constants matching the spec:
///  ≥ 1100 px → sidebar (permanent drawer, 200 px)
///  800–1099 px → icon NavigationRail
///  < 800 px → hamburger Drawer
const double _kSidebarBreak = 1100;
const double _kRailBreak = 800;
const double _kSidebarWidth = 200;

/// Shell that wraps every authenticated admin screen.
/// Provides the topbar + sidebar/rail/drawer navigation.
class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.child,
    required this.title,
  });

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final profile = ref.watch(adminAuthControllerProvider).value;
    final email = profile?.email ?? '';

    if (width >= _kSidebarBreak) {
      // ── Sidebar layout ─────────────────────────────────────────────
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _Sidebar(currentPath: GoRouterState.of(context).matchedLocation),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _Topbar(title: title, email: email),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (width >= _kRailBreak) {
      // ── Rail layout ────────────────────────────────────────────────
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _Rail(currentPath: GoRouterState.of(context).matchedLocation),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _Topbar(title: title, email: email),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // ── Drawer layout ──────────────────────────────────────────────
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                email,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.onPrimary),
              ),
            ),
            _LogoutButton(),
          ],
        ),
        drawer: Drawer(
          child: _SidebarContent(
              currentPath: GoRouterState.of(context).matchedLocation),
        ),
        body: child,
      );
    }
  }
}

// ── Topbar ─────────────────────────────────────────────────────────────────

class _Topbar extends ConsumerWidget {
  const _Topbar({required this.title, required this.email});
  final String title;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 56,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            email,
            style: const TextStyle(color: AppColors.onPrimary, fontSize: 13),
          ),
          const SizedBox(width: AppSpacing.md),
          _LogoutButton(),
        ],
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const Key('logout_button'),
      icon: const Icon(Icons.logout, color: AppColors.onPrimary),
      tooltip: 'Sign out',
      onPressed: () async {
        await ref.read(adminAuthControllerProvider.notifier).signOut();
        if (context.mounted) context.go('/admin/login');
      },
    );
  }
}

// ── Nav items ───────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

const _navItems = [
  // Catalog
  _NavItem(
    label: 'Categories',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category,
    path: '/admin/categories',
  ),
  _NavItem(
    label: 'Products',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    path: '/admin/products',
  ),
  _NavItem(
    label: 'Inventory',
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse,
    path: '/admin/inventory',
  ),
  // Sales
  _NavItem(
    label: 'Orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    path: '/admin/orders',
  ),
  // CRM
  _NavItem(
    label: 'Customers',
    icon: Icons.people_outlined,
    selectedIcon: Icons.people,
    path: '/admin/customers',
  ),
  // System
  _NavItem(
    label: 'Notifications',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    path: '/admin/notifications',
  ),
  _NavItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    path: '/admin/settings',
  ),
];

// ── Sidebar (≥1100 px) ──────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kSidebarWidth,
      child: Column(
        children: [
          Expanded(child: _SidebarContent(currentPath: currentPath)),
        ],
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  const _SidebarContent({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          // Dashboard link at top
          _SidebarTile(
            item: const _NavItem(
              label: 'Dashboard',
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              path: '/admin/dashboard',
            ),
            currentPath: currentPath,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child:
                Text('CATALOG', style: Theme.of(context).textTheme.bodySmall),
          ),
          ..._navItems.take(3).map(
              (item) => _SidebarTile(item: item, currentPath: currentPath)),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Text('SALES', style: Theme.of(context).textTheme.bodySmall),
          ),
          _SidebarTile(item: _navItems[3], currentPath: currentPath),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Text('CRM', style: Theme.of(context).textTheme.bodySmall),
          ),
          _SidebarTile(item: _navItems[4], currentPath: currentPath),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            child: Text('SYSTEM', style: Theme.of(context).textTheme.bodySmall),
          ),
          ..._navItems.skip(5).map(
              (item) => _SidebarTile(item: item, currentPath: currentPath)),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, required this.currentPath});
  final _NavItem item;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final selected = currentPath.startsWith(item.path);
    return ListTile(
      dense: true,
      leading: Icon(
        selected ? item.selectedIcon : item.icon,
        color: selected ? AppColors.primary : AppColors.textSecondary,
        size: 20,
      ),
      title: Text(
        item.label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      selected: selected,
      onTap: () => context.go(item.path),
    );
  }
}

// ── Rail (800–1099 px) ──────────────────────────────────────────────────────

class _Rail extends StatelessWidget {
  const _Rail({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final allItems = [
      const _NavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        path: '/admin/dashboard',
      ),
      ..._navItems,
    ];

    final selectedIndex = allItems.indexWhere(
      (item) => currentPath.startsWith(item.path),
    );

    return NavigationRail(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      labelType: NavigationRailLabelType.selected,
      onDestinationSelected: (i) => context.go(allItems[i].path),
      destinations: allItems
          .map(
            (item) => NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: Text(item.label),
            ),
          )
          .toList(),
    );
  }
}
