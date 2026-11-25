import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';

/// Registrar un abono. Si no se pasa `orderId`, se elige entre los pedidos con saldo.
class PaymentSheet extends ConsumerStatefulWidget {
  final int? orderId;
  const PaymentSheet({super.key, this.orderId});

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  int? _orderId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _orderId = widget.orderId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(GarmentOrder? order) async {
    final amount = parseMoney(_amount.text) ?? 0;
    if (order == null) {
      setState(() => _error = 'Selecciona un pedido.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Ingresa un valor de abono válido.');
      return;
    }
    if (amount > order.balance) {
      setState(() => _error = 'El abono no puede superar el saldo disponible.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(repoProvider).createPayment(
            orderId: order.id,
            amount: amount,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      ref.invalidate(ordersProvider);
      ref.invalidate(paymentsProvider(order.id));
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Abono registrado correctamente');
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = (ref.watch(ordersProvider).valueOrNull ?? const <GarmentOrder>[])
        .where((o) => o.hasBalance || o.id == widget.orderId)
        .toList();
    final clients = ref.watch(clientMapProvider);
    final selected = orders.where((o) => o.id == _orderId).isEmpty
        ? null
        : orders.firstWhere((o) => o.id == _orderId);
    final amount = parseMoney(_amount.text) ?? 0;
    final tooMuch = selected != null && amount > selected.balance;

    return SheetScaffold(
      eyebrow: 'Acción rápida',
      title: 'Registrar abono',
      children: [
        if (orders.isEmpty)
          const EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Todo al día',
            message: 'No hay pedidos con saldo pendiente.',
          )
        else ...[
          ZField(
            label: 'Pedido',
            child: DropdownButtonFormField<int>(
              value: selected?.id,
              isExpanded: true,
              hint: const Text('Seleccionar pedido'),
              items: [
                for (final o in orders)
                  DropdownMenuItem(
                    value: o.id,
                    child: Text('#${o.id} · ${clients[o.clientId]?.fullName ?? '—'}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: widget.orderId != null
                  ? null
                  : (v) => setState(() {
                        _orderId = v;
                        _amount.clear();
                      }),
            ),
          ),
          if (selected != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Z.soft, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Text('Saldo disponible', style: nunito(12, weight: FontWeight.w700)),
                const Spacer(),
                Text(money(selected.balance), style: nunito(15, weight: FontWeight.w800, color: Z.ink)),
              ]),
            ),
          ZField(
            label: 'Valor del abono',
            child: TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0',
                prefixText: '\$ ',
                errorText: tooMuch ? 'El abono no puede superar el saldo disponible.' : null,
              ),
            ),
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextButton(
                onPressed: () => setState(() => _amount.text = moneyField(selected.balance)),
                child: Text('Pagar saldo completo', style: nunito(12, weight: FontWeight.w800, color: Z.brandDark)),
              ),
            ),
          ZField(
            label: 'Nota (opcional)',
            child: TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Ej. Adelanto, primera cuota'),
            ),
          ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Z.roseSoft, borderRadius: BorderRadius.circular(14)),
              child: Text(_error!, style: nunito(12, weight: FontWeight.w700, color: Z.rose)),
            ),
          ZButton(
            label: 'Guardar',
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: tooMuch ? null : () => _save(selected),
          ),
        ],
      ],
    );
  }
}
