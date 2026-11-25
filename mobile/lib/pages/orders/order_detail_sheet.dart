import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';
import 'order_form_sheet.dart';
import 'payment_sheet.dart';

Future<void> showOrderDetail(BuildContext context, int orderId) =>
    showZSheet(context, (_) => OrderDetailSheet(orderId: orderId));

class OrderDetailSheet extends ConsumerWidget {
  final int orderId;
  const OrderDetailSheet({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider).valueOrNull ?? const <GarmentOrder>[];
    final matches = orders.where((o) => o.id == orderId);
    if (matches.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Z.brandDark)));
    }
    final order = matches.first;
    final client = ref.watch(clientMapProvider)[order.clientId];
    final isAdmin = ref.watch(isAdminProvider);
    final payments = ref.watch(paymentsProvider(orderId));
    final overdue = isOverdue(order);

    Future<void> deleteOrder() async {
      final ok = await confirmDialog(context, 'Eliminar pedido',
          '¿Eliminar el pedido #${order.id}? Esta acción no se puede deshacer.');
      if (!ok) return;
      try {
        await ref.read(repoProvider).deleteOrder(order.id);
        ref.invalidate(ordersProvider);
        if (context.mounted) {
          Navigator.pop(context);
          toast(context, 'Pedido eliminado');
        }
      } catch (e) {
        if (context.mounted) toastError(context, e);
      }
    }

    Future<void> deletePayment(Payment p) async {
      final ok = await confirmDialog(context, 'Eliminar abono', '¿Eliminar el abono de ${money(p.amount)}?');
      if (!ok) return;
      try {
        await ref.read(repoProvider).deletePayment(p.id);
        ref.invalidate(ordersProvider);
        ref.invalidate(paymentsProvider(orderId));
      } catch (e) {
        if (context.mounted) toastError(context, e);
      }
    }

    return SheetScaffold(
      eyebrow: 'Detalle del pedido',
      title: 'Pedido #${order.id}',
      children: [
        Wrap(spacing: 8, runSpacing: 6, children: [
          StatusPill(order.status),
          PaymentPill(paid: !order.hasBalance && order.status != OrderStatus.cancelled),
          if (order.embroidery)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Z.soft, borderRadius: BorderRadius.circular(99)),
              child: Text('CON BORDADO',
                  style: nunito(8.5, weight: FontWeight.w800, color: Z.brandDark).copyWith(letterSpacing: .4)),
            ),
        ]),
        const SizedBox(height: 14),
        if (client != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Z.bg, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              ZAvatar(client.fullName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(client.fullName, style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
              ),
            ]),
          ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Z.bg, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Prendas', style: nunito(11, color: Z.muted)),
            const SizedBox(height: 2),
            Text(order.description, style: nunito(15, weight: FontWeight.w800, color: Z.ink)),
            const SizedBox(height: 2),
            Text('${order.quantity} × ${money(order.unitPrice)}', style: nunito(12, color: Z.body)),
            if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(order.notes!, style: nunito(12, color: Z.body)),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _Amount('Total', money(order.totalPrice)),
          const SizedBox(width: 8),
          _Amount('Abonado', money(order.amountPaid)),
          const SizedBox(width: 8),
          _Amount('Saldo', money(order.balance < 0 ? 0 : order.balance), warn: order.hasBalance),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: overdue ? Z.roseSoft : Z.soft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Icon(overdue ? Icons.warning_amber_rounded : Icons.calendar_today_rounded,
                color: overdue ? Z.rose : Z.brandDark, size: 20),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fecha de entrega', style: nunito(10, color: Z.muted)),
              Text(
                order.deliveryDate == null ? 'Sin fecha' : '${dueLabel(order)} · ${shortDate(parseDate(order.deliveryDate!))}',
                style: nunito(13, weight: FontWeight.w800, color: overdue ? Z.rose : Z.ink),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        Text('Abonos', style: display(17)),
        const SizedBox(height: 8),
        payments.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(color: Z.brandDark)),
          ),
          error: (e, _) => Text(friendlyError(e), style: nunito(12, color: Z.rose)),
          data: (list) => list.isEmpty
              ? Text('Aún no hay abonos registrados.', style: nunito(12, color: Z.muted))
              : Column(children: [
                  for (final p in list)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Z.border),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(money(p.amount), style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                            Text(
                              '${shortDate(p.paidAt)}${p.note != null && p.note!.isNotEmpty ? ' · ${p.note}' : ''}',
                              style: nunito(11, color: Z.muted),
                            ),
                          ]),
                        ),
                        if (isAdmin)
                          IconButton(
                            onPressed: () => deletePayment(p),
                            icon: const Icon(Icons.delete_outline_rounded, color: Z.rose, size: 20),
                          ),
                      ]),
                    ),
                ]),
        ),
        const SizedBox(height: 14),
        if (order.hasBalance) ...[
          ZButton(
            label: 'Registrar abono',
            icon: Icons.paid_outlined,
            onPressed: () => showZSheet(context, (_) => PaymentSheet(orderId: order.id)),
          ),
          const SizedBox(height: 10),
        ],
        ZButton(
          label: 'Editar pedido',
          secondary: true,
          icon: Icons.edit_outlined,
          onPressed: () => showZSheet(context, (_) => OrderFormSheet(initial: order)),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: deleteOrder,
              icon: const Icon(Icons.delete_outline_rounded, color: Z.rose, size: 18),
              label: Text('Eliminar pedido', style: nunito(13, weight: FontWeight.w800, color: Z.rose)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Amount extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  const _Amount(this.label, this.value, {this.warn = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: warn ? Z.roseSoft : Z.bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: nunito(10, color: Z.muted)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: nunito(14, weight: FontWeight.w800, color: warn ? Z.rose : Z.ink)),
            ),
          ]),
        ),
      );
}
