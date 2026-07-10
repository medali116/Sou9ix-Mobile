import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../models/employee.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../screens/alerts/alerts_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/clients/clients_screen.dart';
import '../screens/employees/employee_detail_screen.dart';
import '../screens/employees/employee_form_screen.dart';
import '../screens/employees/employees_screen.dart';
import '../screens/history/edit_sale_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/pos/checkout_screen.dart';
import '../screens/pos/receipt_screen.dart';
import '../screens/products/product_form_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/returns/add_return_screen.dart';
import '../screens/returns/returns_screen.dart';
import '../screens/shell/main_shell.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/stats/statistics_screen.dart';
import '../screens/stock/purchase_invoices_screen.dart';
import '../screens/stock/stock_receipt_screen.dart';

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
      path: '/purchases',
      builder: (context, state) => const PurchaseInvoicesScreen(),
    ),
    GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
    GoRoute(
      path: '/returns',
      builder: (context, state) => const ReturnsScreen(),
    ),
    GoRoute(
      path: '/returns/new',
      builder: (context, state) => const AddReturnScreen(),
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
  ],
);
