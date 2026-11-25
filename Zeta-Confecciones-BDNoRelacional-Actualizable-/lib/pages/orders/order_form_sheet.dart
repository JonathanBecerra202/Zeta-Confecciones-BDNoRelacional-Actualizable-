import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/client_picker_sheet.dart';
import '../../widgets/common.dart';

/// Crear o editar un pedido.
/// - Nuevo desde un cliente: `OrderFormSheet(clientId: ...)`.
/// - Nuevo desde acciones rápidas: sin parámetros (se elige el cliente).
/// - Editar: `OrderFormSheet(initial: pedido)`.
class OrderFormSheet extends ConsumerStatefulWidget {
  final int? clientId;
  final GarmentOrder? initial;
  const OrderFormSheet({super.key, this.clientId, this.initial});

  @override
  ConsumerState<OrderFormSheet> createState() => _OrderFormSheetState();
}

class _OrderFormSheetState extends ConsumerState<OrderFormSheet> {
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  late final TextEditingController _notes;
  int? _clientId;
  int? _measurementId;
  DateTime? _delivery;
  bool _embroidery = false;
  OrderStatus _status = OrderStatus.pending;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final o = widget.initial;
    _clientId = o?.clientId ?? widget.clientId;
    _description = TextEditingController(text: o?.description ?? '');
    _quantity = TextEditingController(text: '${o?.quantity ?? 1}');
    _price = TextEditingController(text: o == null ? '' : moneyField(o.unitPrice));
    _notes = TextEditingController(text: o?.notes ?? '');
    _measurementId = o?.measurementId;
    _embroidery = o?.embroidery ?? false;
    _status = o?.status ?? OrderStatus.pending;
    _delivery = o?.deliveryDate == null ? null : parseDate(o!.deliveryDate!);
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = today();
    final first = (_delivery != null && _delivery!.isBefore(now)) ? _delivery! : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _delivery ?? now,
      firstDate: first,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _delivery = picked);
  }

  Future<void> _pickClient() async {
    final id = await showZSheet<int>(context, (_) => ClientPickerSheet(selectedId: _clientId));
    if (id != null) {
      setState(() {
        _clientId = id;
        _measurementId = null; // las medidas pertenecen al cliente anterior
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    final unit = parseMoney(_price.text);
    final qty = int.tryParse(_quantity.text.trim()) ?? 0;
    if (_clientId == null) {
      setState(() => _error = 'Selecciona un cliente.');
      return;
    }
    if (_description.text.trim().isEmpty) {
      setState(() => _error = 'La descripción es obligatoria.');
      return;
    }
    if (qty <= 0) {
      setState(() => _error = 'La cantidad debe ser mayor a cero.');
      return;
    }
    final isAdmin = ref.read(isAdminProvider);
    final priceLocked = _editing && !isAdmin;
    if (!priceLocked && (unit == null || unit <= 0)) {
      setState(() => _error = 'Ingresa un precio unitario válido.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final payload = <String, dynamic>{
        'description': _description.text.trim(),
        'quantity': qty,
        'delivery_date': _delivery == null ? null : isoDate(_delivery!),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'measurement_id': _measurementId,
        'embroidery': _embroidery,
      };
      final repo = ref.read(repoProvider);
      if (_editing) {
        payload['status'] = _status.db;
        if (!priceLocked) payload['unit_price'] = unit;
        await repo.updateOrder(widget.initial!.id, payload);
      } else {
        payload['unit_price'] = unit;
        payload['client_id'] = _clientId;
        await repo.createOrder(payload);
      }
      ref.invalidate(ordersProvider);
      if (mounted) {
        Navigator.pop(context);
        toast(context, _editing ? 'Pedido actualizado correctamente' : 'Pedido creado correctamente');
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final priceLocked = _editing && !isAdmin;
    final measurements = _clientId == null
        ? const <Measurement>[]
        : (ref.watch(measurementsProvider(_clientId!)).valueOrNull ?? const <Measurement>[]);
    final qty = int.tryParse(_quantity.text.trim()) ?? 0;
    final unit = parseMoney(_price.text) ?? 0;

    return SheetScaffold(
      eyebrow: _editing ? 'Actualizar pedido' : 'Nuevo registro',
      title: _editing ? 'Editar pedido #${widget.initial!.id}' : 'Nuevo pedido',
      children: [
        if (widget.clientId == null && !_editing)
          ZField(
            label: 'Cliente *',
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickClient,
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.search_rounded, color: Z.muted),
                ),
                child: Text(
                  ref.watch(clientMapProvider)[_clientId]?.fullName ?? 'Buscar y seleccionar cliente',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: nunito(14, color: _clientId == null ? Z.muted : Z.ink),
                ),
              ),
            ),
          ),
        ZField(
          label: 'Descripción *',
          child: TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Prendas y detalles'),
          ),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ZField(
              label: 'Cantidad *',
              child: TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                // Solo dígitos, sin ceros a la izquierda: no se puede escribir 0 ni negativos.
                inputFormatters: [_PositiveIntFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '1',
                  errorText: qty < 1 ? 'Mínimo 1' : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ZField(
              label: 'Precio unitario *',
              child: TextField(
                controller: _price,
                enabled: !priceLocked,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: '0', prefixText: '\$ '),
              ),
            ),
          ),
        ]),
        if (priceLocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Solo un administrador puede cambiar el precio unitario.',
                style: nunito(11, color: Z.muted)),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Z.soft, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Text('Total del pedido', style: nunito(12, weight: FontWeight.w700)),
            const Spacer(),
            Text(
              money(priceLocked ? (widget.initial!.unitPrice * qty) : (qty * unit)),
              style: nunito(15, weight: FontWeight.w800, color: Z.ink),
            ),
          ]),
        ),
        ZField(
          label: 'Fecha de entrega',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                suffixIcon: _delivery == null
                    ? const Icon(Icons.calendar_today_rounded, size: 18, color: Z.muted)
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: Z.muted),
                        onPressed: () => setState(() => _delivery = null),
                      ),
              ),
              child: Text(
                _delivery == null ? 'Sin fecha' : shortDate(_delivery!),
                style: nunito(14, color: _delivery == null ? Z.muted : Z.ink),
              ),
            ),
          ),
        ),
        if (_clientId != null)
          ZField(
            label: 'Medidas asociadas',
            child: DropdownButtonFormField<int?>(
              value: measurements.any((m) => m.id == _measurementId) ? _measurementId : null,
              isExpanded: true,
              hint: Text(measurements.isEmpty ? 'El cliente no tiene medidas' : 'Sin medidas asociadas'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Sin medidas asociadas')),
                for (final m in measurements)
                  DropdownMenuItem<int?>(value: m.id, child: Text('Toma del ${shortDate(m.takenAt)}')),
              ],
              onChanged: (v) => setState(() => _measurementId = v),
            ),
          ),
        if (_editing)
          ZField(
            label: 'Estado del pedido',
            child: DropdownButtonFormField<OrderStatus>(
              value: _status,
              isExpanded: true,
              items: [
                for (final s in OrderStatus.values) DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
          ),
        ZField(
          label: 'Observaciones',
          child: TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Detalles de confección, logo, colores…'),
          ),
        ),
        SwitchListTile(
          value: _embroidery,
          onChanged: (v) => setState(() => _embroidery = v),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          activeColor: Z.brandDark,
          title: Text('Lleva bordado', style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
        ),
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Z.roseSoft, borderRadius: BorderRadius.circular(14)),
            child: Text(_error!, style: nunito(12, weight: FontWeight.w700, color: Z.rose)),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ZButton(label: 'Cancelar', secondary: true, onPressed: () => Navigator.pop(context))),
          const SizedBox(width: 10),
          Expanded(
            child: ZButton(
              label: _editing ? 'Guardar cambios' : 'Crear pedido',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _save,
            ),
          ),
        ]),
      ],
    );
  }
}

/// Acepta solo números enteros positivos (quita ceros iniciales y signos).
class _PositiveIntFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var t = newValue.text.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0+'), '');
    if (t.length > 4) t = t.substring(0, 4);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
