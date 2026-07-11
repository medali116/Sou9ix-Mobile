import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/activity/view/activity_log_screen.dart';
import 'package:sou9ix/features/activity/view/trash_screen.dart';
import 'package:sou9ix/features/analytics/view/analytics_screen.dart';
import 'package:sou9ix/features/caisse/view/caisse_detail_screen.dart';
import 'package:sou9ix/features/caisse/view/caisses_screen.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/shift.dart';
import 'package:sou9ix/features/expenses/view/expenses_screen.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/alerts/view/alerts_screen.dart';
import 'package:sou9ix/features/auth/view/login_screen.dart';
import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/clients/view/client_detail_screen.dart';
import 'package:sou9ix/features/clients/view/clients_screen.dart';
import 'package:sou9ix/features/employees/view/employee_detail_screen.dart';
import 'package:sou9ix/features/employees/view/employee_form_screen.dart';
import 'package:sou9ix/features/employees/view/employee_performance_screen.dart';
import 'package:sou9ix/features/employees/view/employees_screen.dart';
import 'package:sou9ix/features/sales/view/edit_sale_screen.dart';
import 'package:sou9ix/features/sales/view/history_screen.dart';
import 'package:sou9ix/features/pos/view/checkout_screen.dart';
import 'package:sou9ix/features/pos/view/scan_sale_screen.dart';
import 'package:sou9ix/features/profile/view/about_screen.dart';
import 'package:sou9ix/features/profile/view/help_center_screen.dart';
import 'package:sou9ix/features/sales/view/receipt_screen.dart';
import 'package:sou9ix/features/products/view/product_form_screen.dart';
import 'package:sou9ix/features/products/view/products_screen.dart';
import 'package:sou9ix/features/returns/view/add_return_screen.dart';
import 'package:sou9ix/features/returns/view/returns_screen.dart';
import 'package:sou9ix/core/shell/main_shell.dart';
import 'package:sou9ix/features/splash/view/splash_screen.dart';
import 'package:sou9ix/features/stats/view/statistics_screen.dart';
import 'package:sou9ix/features/stock/view/purchase_invoices_screen.dart';
import 'package:sou9ix/features/stock/view/stock_detail_screen.dart';
import 'package:sou9ix/features/stock/view/stock_receipt_screen.dart';
import 'package:sou9ix/features/suppliers/model/supplier.dart';
import 'package:sou9ix/features/suppliers/view/supplier_detail_screen.dart';
import 'package:sou9ix/features/suppliers/view/supplier_form_screen.dart';
import 'package:sou9ix/features/suppliers/view/suppliers_screen.dart';

/// Lets any screen (e.g. the persistent live-camera Caisse tab) know when
/// another route has been pushed on top of it, so it can release the
/// camera instead of holding it while it's fully hidden.
final routeObserver = RouteObserver<PageRoute<void>>();

final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: [routeObserver],
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/app', builder: (context, state) => const MainShell()),
    GoRoute(
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    // The admin's shell has no permanent Caisse tab (daily sales is a
    // Caissier job) — this lets the dashboard's "Vente" quick action still
    // reach the same scan-and-sell screen as a one-off pushed route.
    GoRoute(path: '/pos', builder: (context, state) => const ScanSaleScreen()),
    GoRoute(
      path: '/receipt',
      builder: (context, state) => ReceiptScreen(sale: state.extra as Sale),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsScreen(),
    ),
    GoRoute(
      path: '/products/new',
      builder: (context, state) => const ProductFormScreen(),
    ),
    GoRoute(
      path: '/products/edit',
      builder: (context, state) =>
          ProductFormScreen(product: state.extra as Product?),
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
      path: '/statistics',
      builder: (context, state) => const StatisticsScreen(),
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
    GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
    GoRoute(
      path: '/expenses',
      builder: (context, state) => const ExpensesScreen(),
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
    GoRoute(
      path: '/employees',
      builder: (context, state) => const EmployeesScreen(),
    ),
    GoRoute(
      path: '/employees/new',
      builder: (context, state) => const EmployeeFormScreen(),
    ),
    GoRoute(
      path: '/employees/edit',
      builder: (context, state) =>
          EmployeeFormScreen(employee: state.extra as Employee?),
    ),
    GoRoute(
      path: '/employees/detail',
      builder: (context, state) =>
          EmployeeDetailScreen(employee: state.extra as Employee),
    ),
    GoRoute(
      path: '/employees/performance',
      builder: (context, state) => const EmployeePerformanceScreen(),
    ),
    GoRoute(
      path: '/activity-log',
      builder: (context, state) => const ActivityLogScreen(),
    ),
    GoRoute(
      path: '/caisses',
      builder: (context, state) => const CaissesScreen(),
    ),
    GoRoute(
      path: '/caisses/detail',
      builder: (context, state) =>
          CaisseDetailScreen(shift: state.extra as Shift),
    ),
    GoRoute(path: '/trash', builder: (context, state) => const TrashScreen()),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
  ],
);
