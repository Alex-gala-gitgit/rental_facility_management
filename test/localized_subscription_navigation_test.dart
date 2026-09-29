import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/main.dart';

void main() {
  testWidgets('Mandarin subscription copy follows the app language',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 9));
    store.updateLanguage(AppLanguage.chinese);

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Text(
              tr(context, 'Premium subscription required'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('需要高级版订阅'), findsOneWidget);
  });

  testWidgets('owner Home navigation item has a prominent center control',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigator(
            selectedIndex: 2,
            onSelected: (_) {},
            items: const [
              AppBottomNavItem(
                  icon: Icons.apartment_outlined,
                  activeIcon: Icons.apartment,
                  label: 'Properties'),
              AppBottomNavItem(
                  icon: Icons.payments_outlined,
                  activeIcon: Icons.payments,
                  label: 'Payments'),
              AppBottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  prominent: true),
              AppBottomNavItem(
                  icon: Icons.bolt_outlined,
                  activeIcon: Icons.bolt,
                  label: 'Requests'),
              AppBottomNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile'),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('prominent_home_button')), findsOneWidget);
    final control = tester.widget<AnimatedContainer>(
      find.byKey(const Key('prominent_home_button')),
    );
    expect(control.constraints?.maxWidth, 50);
    expect(control.constraints?.maxHeight, 50);
  });
}
