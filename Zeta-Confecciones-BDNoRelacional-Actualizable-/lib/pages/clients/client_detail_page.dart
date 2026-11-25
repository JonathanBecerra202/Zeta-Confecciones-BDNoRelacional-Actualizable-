import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';
import '../orders/order_detail_sheet.dart';
import '../orders/order_form_sheet.dart';
import 'client_form_page.dart';
import 'measurement_sheet.dart';

class ClientDetailPage extends ConsumerStatefulWidget {
  final int clientId;
  const ClientDetailPage({super.key, required this.clientId});
  @override
  ConsumerState<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends ConsumerState<ClientDetailPage> {
  bool _historyOpen = false;

  Future<void> _toggleActive(Client c) async {
    try {
      await ref.read(repoProvider).updateClient(c.id, {'active': !c.active});
      ref.invalidate(clientsProvider);
      if (mounted) toast(context, c.active ? 'Cliente desactivado' : 'Cliente activado');
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider).valueOrNull ?? const <Client>[];
    final found = clients.where((c) => c.id == widget.clientId);
    if (found.isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Z.bg, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: Z.brandDark)),
      );
    }
    final client = found.first;
    final depById = {
      for (final d in ref.watch(departmentsProvider).valueOrNull ?? const <Department>[]) d.id: d
    };
    final orgById = {
      for (final o in ref.watch(organizationsProvider).valueOrNull ?? const <Organization>[]) o.id: o
    };
    final dep = client.departmentId == null ? null : depById[client.departmentId];
    final org = dep == null ? null : orgById[dep.organizationId];
    final ordersAsync = ref.watch(ordersProvider);
    final measAsync = ref.watch(measurementsProvider(client.id));
    final myOrders = (ordersAsync.valueOrNull ?? const <GarmentOrder>[])
        .where((o) => o.clientId == client.id)
        .toList();
    final balance = myOrders.where((o) => o.hasBalance).fold<double>(0, (s, o) => s + o.balance);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Z.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Z.ink),
        title: Text('Ficha del cliente', style: nunito(14, weight: FontWeight.w800, color: Z.brandDark)),
      ),
      body: RefreshIndicator(
        color: Z.brandDark,
        onRefresh: () async {
          ref.invalidate(ordersProvider);
          ref.invalidate(measurementsProvider(client.id));
          await ref.read(ordersProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
          children: [
            Text(client.fullName, style: display(25)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Z.border),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ZAvatar(client.fullName, size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: client.active ? Z.greenSoft : const Color(0xFFF1F1F1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(client.active ? 'Activo' : 'Inactivo',
                          style: nunito(10, weight: FontWeight.w800,
                              color: client.active ? Z.green : const Color(0xFF777777))),
                    ),
                    const SizedBox(height: 8),
                    if (org != null) _InfoLine(Icons.apartment_rounded, org.name),
                    if (dep != null) _InfoLine(Icons.account_tree_outlined, dep.name),
                    if (client.phone != null && client.phone!.isNotEmpty)
                      _InfoLine(Icons.phone_outlined, client.phone!),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => ClientFormPage(initial: client))),
                  icon: const Icon(Icons.edit_outlined, color: Z.brandDark),
                  style: IconButton.styleFrom(backgroundColor: Z.soft),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Z.brandDark, Z.brand]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Saldo total pendiente', style: nunito(12, color: const Color(0xCCFFFFFF))),
                    const SizedBox(height: 2),
                    Text(money(balance), style: display(26, color: Colors.white)),
                  ]),
                ),
                const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 30),
              ]),
            ),
            // ---- Medidas ----
            _SubHeader(
              eyebrow: 'Medidas',
              title: 'Última toma',
              trailing: _SmallAction(
                label: 'Nueva toma',
                onTap: () => showZSheet(context, (_) => MeasurementSheet(client: client)),
              ),
            ),
            AsyncView<List<Measurement>>(
              value: measAsync,
              onRetry: () => ref.invalidate(measurementsProvider(client.id)),
              builder: (list) {
                if (list.isEmpty) {
                  return const _MiniEmpty(Icons.straighten_rounded, 'Aún no hay medidas registradas.');
                }
                final latest = list.first;
                final filled = measureFields.where((f) => latest.values[f.key] != null).length;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Z.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.straighten_rounded, color: Z.brandDark, size: 20),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(shortDate(latest.takenAt), style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                          Text('$filled medidas registradas', style: nunito(11, color: Z.muted)),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      MeasureGrid(latest),
                      if (latest.notes != null && latest.notes!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(latest.notes!, style: nunito(12)),
                      ],
                    ]),
                  ),
                  if (list.length > 1) ...[
                    TextButton(
                      onPressed: () => setState(() => _historyOpen = !_historyOpen),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Ver historial (${list.length - 1} anteriores)',
                            style: nunito(12, weight: FontWeight.w800, color: Z.brandDark)),
                        Icon(_historyOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: Z.brandDark),
                      ]),
                    ),
                    if (_historyOpen)
                      for (final m in list.skip(1))
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Z.bg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Z.border),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(shortDate(m.takenAt), style: nunito(13, weight: FontWeight.w800, color: Z.ink)),
                            const SizedBox(height: 8),
                            MeasureGrid(m),
                            if (m.notes != null && m.notes!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(m.notes!, style: nunito(12)),
                            ],
                          ]),
                        ),
                  ],
                ]);
              },
            ),
            // ---- Pedidos ----
            _SubHeader(
              eyebrow: 'Producción',
              title: 'Pedidos (${myOrders.length})',
              trailing: _SmallAction(
                label: 'Nuevo pedido',
                onTap: () => showZSheet(context, (_) => OrderFormSheet(clientId: client.id)),
              ),
            ),
            if (ordersAsync.isLoading && myOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: Z.brandDark)),
              )
            else if (myOrders.isEmpty)
              const _MiniEmpty(Icons.shopping_bag_outlined, 'Este cliente aún no tiene pedidos.')
            else
              for (final o in myOrders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => showOrderDetail(context, o.id),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Z.border),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Pedido #${o.id}', style: nunito(10.5, weight: FontWeight.w800, color: Z.brandDark)),
                              Text(o.description, style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                              Text(money(o.totalPrice), style: nunito(12, weight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 6, runSpacing: 4, children: [
                                StatusPill(o.status),
                                PaymentPill(paid: !o.hasBalance && o.status != OrderStatus.cancelled),
                              ]),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Z.arrow),
                        ]),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 18),
            ZButton(
              label: client.active ? 'Desactivar cliente' : 'Activar cliente',
              secondary: true,
              icon: client.active ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined,
              onPressed: () => _toggleActive(client),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 15, color: Z.brandDark),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: nunito(12, weight: FontWeight.w700))),
        ]),
      );
}

/// Botón compacto de las cabeceras de sección: ocupa solo lo que necesita,
/// así no se desborda en pantallas angostas.
class _SmallAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(label, style: nunito(13, weight: FontWeight.w800, color: Z.brandDark)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Z.brandDark,
          backgroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          side: const BorderSide(color: Z.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

class _SubHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget trailing;
  const _SubHeader({required this.eyebrow, required this.title, required this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow(eyebrow),
              Text(title, style: display(18)),
            ]),
          ),
          trailing,
        ]),
      );
}

class _MiniEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniEmpty(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Z.soft, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(icon, color: Z.brandDark, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: nunito(12, weight: FontWeight.w700))),
        ]),
      );
}
