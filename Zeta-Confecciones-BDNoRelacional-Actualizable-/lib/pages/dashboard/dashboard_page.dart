import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';
import '../clients/client_form_page.dart';
import '../orders/order_detail_sheet.dart';
import '../orders/order_form_sheet.dart';
import '../orders/payment_sheet.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  void _goOrders(WidgetRef ref, OrderFilter f) {
    ref.read(orderFilterProvider.notifier).state = f;
    ref.read(tabProvider.notifier).state = 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final clients = ref.watch(clientMapProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final firstName = (profile?.fullName ?? '').split(' ').first;

    Future<void> refresh() async {
      ref.invalidate(ordersProvider);
      ref.invalidate(clientsProvider);
      await ref.read(ordersProvider.future);
    }

    return RefreshIndicator(
      color: Z.brandDark,
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Eyebrow(longToday()),
                Text(firstName.isEmpty ? greeting() : '${greeting()}, $firstName', style: display(26)),
                const SizedBox(height: 5),
                Text('Así va el taller hoy.', style: nunito(13, color: Z.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          AsyncView<List<GarmentOrder>>(
            value: ordersAsync,
            onRetry: () => ref.invalidate(ordersProvider),
            builder: (orders) {
              final overdue = orders.where(isOverdue).toList()
                ..sort((a, b) => a.deliveryDate!.compareTo(b.deliveryDate!));
              final upcoming = orders
                  .where((o) => isOpen(o) && o.deliveryDate != null && !isOverdue(o))
                  .toList()
                ..sort((a, b) => a.deliveryDate!.compareTo(b.deliveryDate!));
              final stats = [
                _Stat('Pendientes', orders.where((o) => o.status == OrderStatus.pending).length,
                    Icons.schedule_rounded, Z.amberSoft, Z.amber, OrderFilter.pendiente),
                _Stat('En proceso', orders.where((o) => o.status == OrderStatus.inProgress).length,
                    Icons.layers_rounded, Z.blueSoft, Z.brandDark, OrderFilter.enProceso),
                _Stat('Entregados', orders.where((o) => o.status == OrderStatus.delivered).length,
                    Icons.check_rounded, Z.greenSoft, Z.green, OrderFilter.entregado),
                _Stat('Con saldo', orders.where((o) => o.hasBalance).length,
                    Icons.account_balance_wallet_outlined, Z.roseSoft, Z.rose, OrderFilter.saldo),
              ];
              String nameOf(GarmentOrder o) => clients[o.clientId]?.fullName ?? '—';
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GridView(
                  shrinkWrap: true, //hace que el GridView calcule su altura según el contenido que tiene, en lugar de intentar ocupar todo el espacio disponible.
                  physics: const NeverScrollableScrollPhysics(), //evita que tenga su propio desplazamiento.
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( //configuración que le indica al GridView cómo distribuir sus elementos en una cuadrícula.
                    crossAxisCount: 2, //cantidad de columnas
                    mainAxisSpacing: 10, //Espacio entre filas
                    crossAxisSpacing: 10, //Espacio entre columnas
                    mainAxisExtent: 140, //Tamaño de cada elemento
                  ),
                  children: [for (final s in stats) _StatCard(s, onTap: () => _goOrders(ref, s.filter))],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
                  child: Row(children: [
                    const Icon(Icons.shopping_bag_outlined, size: 14, color: Z.brandDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Toca un indicador para ver Pedidos con ese filtro aplicado.',
                          style: nunito(10, color: const Color(0xFF7D97A9))),
                    ),
                  ]),
                ),
                const SectionHeading(eyebrow: 'Atajos', title: 'Acciones rápidas'),
                Row(children: [
                  Expanded(
                    child: _QuickButton(
                      icon: Icons.people_alt_outlined,
                      label: 'Nuevo cliente',
                      bg: Z.soft,
                      fg: Z.brandDark,
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const ClientFormPage())),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _QuickButton(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Nuevo pedido',
                      bg: Z.roseSoft,
                      fg: Z.rose,
                      onTap: () => showZSheet(context, (_) => const OrderFormSheet()),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _QuickButton(
                      icon: Icons.paid_outlined,
                      label: 'Registrar abono',
                      bg: const Color(0xFFFFF7E9),
                      fg: const Color(0xFFC98723),
                      onTap: () => showZSheet(context, (_) => const PaymentSheet()),
                    ),
                  ),
                ]),
                if (overdue.isNotEmpty) ...[
                  SectionHeading(
                    eyebrow: 'Requieren atención',
                    title: 'Pedidos vencidos',
                    alert: true,
                    count: overdue.length,
                    // Solo se muestran los 4 más antiguos; "Ver todas" aparece si hay más.
                    actionLabel: overdue.length > 4 ? 'Ver todas' : null,
                    onAction: overdue.length > 4 ? () => _goOrders(ref, OrderFilter.todos) : null,
                  ),
                  for (final o in overdue.take(4))
                    OrderPreview(
                      order: o,
                      clientName: nameOf(o),
                      alert: true,
                      onTap: () => showOrderDetail(context, o.id),
                    ),
                ],
                SectionHeading(
                  eyebrow: 'Agenda',
                  title: 'Próximas entregas',
                  actionLabel: 'Ver todas',
                  onAction: () => _goOrders(ref, OrderFilter.todos),
                ),
                if (upcoming.isEmpty)
                  const EmptyState(
                    icon: Icons.event_available_rounded,
                    title: 'Sin entregas próximas',
                    message: 'Cuando crees pedidos con fecha de entrega aparecerán aquí.',
                  )
                else
                  for (final o in upcoming.take(3))
                    OrderPreview(order: o, clientName: nameOf(o), onTap: () => showOrderDetail(context, o.id)),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final String label;
  final int value;
  final IconData icon;
  final Color bg;
  final Color fg;
  final OrderFilter filter;
  _Stat(this.label, this.value, this.icon, this.bg, this.fg, this.filter);
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  final VoidCallback onTap;
  const _StatCard(this.stat, {required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Z.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(color: stat.bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(stat.icon, size: 18, color: stat.fg),
                ),
                const Icon(Icons.chevron_right_rounded, color: Z.arrow, size: 18),
              ]),
              const Spacer(),
              Text('${stat.value}', style: display(25)),
              Text(stat.label, style: nunito(12, weight: FontWeight.w800)),
              Text('Ver pedidos', style: nunito(10, weight: FontWeight.w700, color: Z.muted)),
            ]),
          ),
        ),
      );
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _QuickButton({required this.icon, required this.label, required this.bg, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            height: 94,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Z.border),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: nunito(10, weight: FontWeight.w800, color: Z.ink, height: 1.2)),
            ]),
          ),
        ),
      );
}