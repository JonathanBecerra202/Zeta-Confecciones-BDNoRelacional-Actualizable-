import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/pagination.dart';
import 'order_detail_sheet.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});
  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  String _query = '';
  int _page = 0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goToPage(int p) {
    setState(() => _page = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  bool _matches(GarmentOrder o, OrderFilter f) {
    switch (f) {
      case OrderFilter.todos:
        return true;
      case OrderFilter.pendiente:
        return o.status == OrderStatus.pending;
      case OrderFilter.enProceso:
        return o.status == OrderStatus.inProgress;
      case OrderFilter.entregado:
        return o.status == OrderStatus.delivered;
      case OrderFilter.cancelado:
        return o.status == OrderStatus.cancelled;
      case OrderFilter.saldo:
        return o.hasBalance;
    }
  }

  /// Mismo criterio de orden que la web: abiertos primero, luego por fecha de
  /// entrega más cercana, "En proceso" antes que "Pendiente", y más recientes.
  /// 0-2 = -2 A primero que B, 2-0=2 B primero que A
  int _compare(GarmentOrder a, GarmentOrder b) {
    int rank(GarmentOrder o) => isOpen(o) ? 0 : 2;
    if (rank(a) != rank(b)) return rank(a) - rank(b);
    final da = a.deliveryDate, db = b.deliveryDate;
    if (da != null && db == null) return -1;
    if (da == null && db != null) return 1;
    if (da != null && db != null && da != db) return da.compareTo(db);
    int prio(GarmentOrder o) => o.status == OrderStatus.inProgress ? 0 : 1;
    if (prio(a) != prio(b)) return prio(a) - prio(b);
    return b.createdAt.compareTo(a.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(orderFilterProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final clients = ref.watch(clientMapProvider);

    // Al cambiar el filtro (también desde el Inicio) se vuelve a la página 1.
    ref.listen<OrderFilter>(orderFilterProvider, (_, __) {
      if (_page != 0) setState(() => _page = 0);
    });

    return RefreshIndicator(
      color: Z.brandDark,
      onRefresh: () async {
        ref.invalidate(ordersProvider);
        await ref.read(ordersProvider.future);
      },
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          AsyncView<List<GarmentOrder>>(
            value: ordersAsync,
            onRetry: () => ref.invalidate(ordersProvider),
            builder: (orders) {
              String nameOf(GarmentOrder o) => clients[o.clientId]?.fullName ?? '—';
              final visible = orders
                  .where((o) => _matches(o, filter))
                  .where((o) => _query.trim().isEmpty || matchesSearch('${nameOf(o)} ${o.description}', _query))
                  .toList()
                ..sort(_compare); //Permite ejecutar operaciones sobre el mismo objeto.
              final pageCount = pageCountFor(visible.length);
              final page = _page >= pageCount ? pageCount - 1 : _page;
              final shown = pageSlice(visible, page);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PageTitle(
                  eyebrow: 'Producción',
                  title: 'Pedidos',
                  subtitle: '${visible.length} ${visible.length == 1 ? 'resultado' : 'resultados'} en esta vista',
                ),
                TextField(
                  onChanged: (v) => setState(() {
                    _query = v;
                    _page = 0;
                  }),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por cliente o descripción…',
                    prefixIcon: Icon(Icons.search_rounded, color: Z.muted),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: OrderFilter.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = OrderFilter.values[i];
                      final active = f == filter;
                      return GestureDetector(
                        onTap: () => ref.read(orderFilterProvider.notifier).state = f,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active ? Z.brandDark : Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: active ? Z.brandDark : Z.border),
                          ),
                          child: Text(f.label,
                              style: nunito(12, weight: FontWeight.w800, color: active ? Colors.white : Z.body)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Sin pedidos',
                    message: 'No hay pedidos que coincidan con esta vista.',
                    action: filter == OrderFilter.todos && _query.isEmpty
                        ? null
                        : SizedBox(
                            width: 200,
                            child: ZButton(
                              label: 'Limpiar filtros',
                              secondary: true,
                              onPressed: () {
                                setState(() {
                                  _query = '';
                                  _page = 0;
                                });
                                ref.read(orderFilterProvider.notifier).state = OrderFilter.todos;
                              },
                            ),
                          ),
                  )
                else ...[
                  for (final o in shown)
                    OrderPreview(
                      order: o,
                      clientName: nameOf(o),
                      alert: isOverdue(o),
                      onTap: () => showOrderDetail(context, o.id),
                    ),
                  PaginationBar(page: page, pageCount: pageCount, onChanged: _goToPage),
                ],
              ]);
            },
          ),
        ],
      ),
    );
  }
}