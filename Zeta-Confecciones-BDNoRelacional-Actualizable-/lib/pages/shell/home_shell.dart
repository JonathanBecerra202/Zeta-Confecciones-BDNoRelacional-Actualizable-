import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../bloc/providers.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_page.dart' show BrandMark;
import '../clients/clients_page.dart';
import '../dashboard/dashboard_page.dart';
import '../more/more_page.dart';
import '../orders/orders_page.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final avatarUrl = ref.watch(myAvatarUrlProvider).valueOrNull;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _Header(
            name: profile?.fullName ?? '',
            avatarUrl: avatarUrl,
            onProfile: () => ref.read(tabProvider.notifier).state = 3,
          ),
          Expanded(
            child: IndexedStack(index: tab, children: const [
              DashboardPage(),
              ClientsPage(),
              OrdersPage(),
              MorePage(),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: _BottomNav(
        index: tab,
        onChanged: (i) => ref.read(tabProvider.notifier).state = i,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String? avatarUrl; // URL firmada de la foto (null = iniciales)
  final VoidCallback onProfile; //va a recibir una función sin parámetros y sin valor de retorno.
  const _Header({required this.name, this.avatarUrl, required this.onProfile});

  @override
  Widget build(BuildContext context) => Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: const BoxDecoration(
          color: Color(0xE6F8FCFF),
          border: Border(bottom: BorderSide(color: Color(0xB3D6EAF5))),
        ),
        child: Row(children: [
          const BrandMark(size: 39),
          const SizedBox(width: 9),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Zeta', style: display(17)),
            Text('CONFECCIONES',
                style: nunito(11, weight: FontWeight.w800, color: Z.brandDark).copyWith(letterSpacing: .9, height: 1)),
          ]),
          const Spacer(),
          GestureDetector(onTap: onProfile, child: UserAvatar(name: name.isEmpty ? 'Z' : name, url: avatarUrl, size: 42)),
        ]),
      );
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomNav({required this.index, required this.onChanged});

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Inicio'),
    (Icons.people_alt_rounded, Icons.people_alt_outlined, 'Clientes'),
    (Icons.shopping_bag_rounded, Icons.shopping_bag_outlined, 'Pedidos'),
    (Icons.grid_view_rounded, Icons.grid_view_outlined, 'Más'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Z.border)),
        boxShadow: [BoxShadow(color: Color(0x122A5877), blurRadius: 30, offset: Offset(0, -8))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: InkWell( //InkWell: detectar pulsaciones
                  onTap: () => onChanged(i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 30,
                      decoration: BoxDecoration(
                        color: index == i ? Z.soft : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(index == i ? _items[i].$1 : _items[i].$2,
                          size: 22, color: index == i ? Z.brandDark : const Color(0xFF91A7B6)),
                    ),
                    const SizedBox(height: 2),
                    Text(_items[i].$3,
                        style: nunito(10, weight: FontWeight.w800,
                            color: index == i ? Z.brandDark : const Color(0xFF91A7B6))),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}