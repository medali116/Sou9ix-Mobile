import 'package:go_router/go_router.dart';

import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/alerts/view/alerts_screen.dart';
import 'package:sou9ix/caissier/features/auth/view/employee_login_screen.dart';
import 'package:sou9ix/caissier/features/auth/view/enter_shop_code_screen.dart';
import 'package:sou9ix/shared/features/clients/model/client.dart';
import 'package:sou9ix/shared/features/clients/view/client_detail_screen.dart';
import 'package:sou9ix/shared/features/clients/view/clients_screen.dart';
import 'package:sou9ix/shared/features/sales/view/edit_sale_screen.dart';
import 'package:sou9ix/shared/features/sales/view/history_screen.dart';
import 'package:sou9ix/shared/features/pos/view/checkout_screen.dart';
import 'package:sou9ix/shared/features/profile/view/about_screen.dart';
import 'package:sou9ix/shared/features/profile/view/help_center_screen.dart';
import 'package:sou9ix/shared/features/sales/view/receipt_screen.dart';
import 'package:sou9ix/caissier/features/products/view/products_screen.dart';
import 'package:sou9ix/shared/features/returns/view/add_return_screen.dart';
import 'package:sou9ix/shared/features/returns/view/returns_screen.dart';
import 'package:sou9ix/caissier/shell/main_shell.dart';
import 'package:sou9ix/caissier/features/splash/view/splash_screen.dart';
import 'package:sou9ix/shared/features/stock/view/purchase_invoices_screen.dart';
import 'package:sou9ix/shared/features/stock/view/stock_detail_screen.dart';
import 'package:sou9ix/shared/features/stock/view/stock_receipt_screen.dart';
import 'package:sou9ix/shared/features/suppliers/model/supplier.dart';
import 'package:sou9ix/shared/features/suppliers/view/supplier_detail_screen.dart';
import 'package:sou9ix/shared/features/suppliers/view/supplier_form_screen.dart';
import 'package:sou9ix/shared/features/suppliers/view/suppliers_screen.dart';
import 'package:sou9ix/shared/core/routing/route_observer.dart';

/// The Caissier app's route table. Deliberately excludes everything
/// admin-only: no `/login/admin*` (this app ships only [EmployeeLoginScreen],
/// which already rejects admin-flagged employee records), no `/pos` (the
/// admin's one-off dashboard shortcut — caissiers already have a permanent
/// Caisse tab), no `/products/new`/`/products/edit` (product creation/editing
/// is an admin capability — the shared [AlertsScreen] and [StockDetailScreen]
/// already hide their edit affordances when signed in as a caissier), and no
/// `/statistics`, `/expenses`, `/employees*`, `/activity-log`, `/trash`,
/// `/caisses*`, `/analytics`. If a caissier-reachable screen ever tries to
/// push one of these, GoRouter throws immediately in dev instead of silently
/// granting access.
final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: [routeObserver],
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    // Shown once on a device's first launch, before any login — links this
    // install to a shop by its permanent join code. See
    // EnterShopCodeScreen.
    GoRoute(
      path: '/shop-code',
      builder: (context, state) => const EnterShopCodeScreen(),
    ),
    // The Caissier app's only login — nom complet + PIN. See
    // EmployeeLoginScreen.
    GoRoute(
      path: '/login',
      builder: (context, state) => const EmployeeLoginScreen(),
    ),
    GoRoute(path: '/app', builder: (context, state) => const MainShell()),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/receipt',
      builder: (context, state) => ReceiptScreen(sale: state.extra as Sale),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsScreen(),
    ),
    GoRoute(
      path: '/clients',
      builder: (context, state) => const ClientsScreen(),
    ),
    GoRoute(
      path: '/clients/detail',
      builder: (context, state) =>
          ClientDetailScreen(client: state.extra as Client),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/history/edit',
      builder: (context, state) => EditSaleScreen(sale: state.extra as Sale),
    ),
    GoRoute(
      path: '/stock/receipt',
      builder: (context, state) => const StockReceiptScreen(),
    ),
    GoRoute(
      path: '/stock/detail',
      builder: (context, state) =>
          StockDetailScreen(product: state.extra as Product),
    ),
    GoRoute(
      path: '/purchases',
      builder: (context, state) => const PurchaseInvoicesScreen(),
    ),
    GoRoute(
      path: '/suppliers',
      builder: (context, state) => const SuppliersScreen(),
    ),
    GoRoute(
      path: '/suppliers/new',
      builder: (context, state) => const SupplierFormScreen(),
    ),
    GoRoute(
      path: '/suppliers/edit',
      builder: (context, state) =>
          SupplierFormScreen(supplier: state.extra as Supplier?),
    ),
    GoRoute(
      path: '/suppliers/detail',
      builder: (context, state) =>
          SupplierDetailScreen(supplier: state.extra as Supplier),
    ),
    GoRoute(
      path: '/alerts',
      builder: (context, state) =>
          AlertsScreen(focusCategory: state.extra as String?),
    ),
    GoRoute(
      path: '/help',
      builder: (context, state) => const HelpCenterScreen(),
    ),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
    GoRoute(
      path: '/returns',
      builder: (context, state) => const ReturnsScreen(),
    ),
    GoRoute(
      path: '/returns/new',
      builder: (context, state) =>
          AddReturnScreen(initialProduct: state.extra as Product?),
    ),
  ],
);
