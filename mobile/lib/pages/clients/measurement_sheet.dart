import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';

/// Controladores de las 9 medidas, reutilizados en el formulario de cliente
/// (primera toma) y en la hoja de nueva toma.
class MeasureControllers {
  final Map<String, TextEditingController> _c = {
    for (final f in measureFields) f.key: TextEditingController(),
  };

  TextEditingController of(String key) => _c[key]!;

  bool get hasAny => _c.values.any((c) => c.text.trim().isNotEmpty);

  double? valueOf(String key) {
    final t = _c[key]!.text.trim().replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  /// Mensaje de error o null si todo está bien.
  String? validate() {
    for (final f in measureFields) {
      final t = _c[f.key]!.text.trim().replaceAll(',', '.');
      if (t.isEmpty) continue; //Si una medida está vacía, no intentamos convertirla ni validarla.
      final v = double.tryParse(t);
      if (v == null) return '${f.label}: número no válido.';
      if (v < 0) return '${f.label}: no puede ser negativo.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {for (final f in measureFields) f.key: valueOf(f.key)};

  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
  }
}

class MeasureInputs extends StatelessWidget {
  final MeasureControllers controllers;
  const MeasureInputs({super.key, required this.controllers});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) => Wrap(
      spacing: 12,
      children: [
        for (final f in measureFields)
          SizedBox(
            width: (c.maxWidth - 12) / 2 - 0.5,
            child: ZField(
              label: f.label,
              child: TextField(
                controller: controllers.of(f.key),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(hintText: '0', suffixText: 'cm'),
              ),
            ),
          ),
      ],
    ));
  }
}

class MeasureGrid extends StatelessWidget {
  final Measurement measurement;
  const MeasureGrid(this.measurement, {super.key});

  String _fmt(double? v) {
    if (v == null) return '—';
    return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in measureFields)
          Container(
            width: (c.maxWidth - 16) / 3 - 0.5,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Z.soft, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.short, style: nunito(10, color: Z.muted), overflow: TextOverflow.ellipsis),
              Text.rich(TextSpan(children: [
                TextSpan(text: _fmt(measurement.values[f.key]), style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                if (measurement.values[f.key] != null) TextSpan(text: ' cm', style: nunito(10, color: Z.muted)),
              ])),
            ]),
          ),
      ],
    ));
  }
}

class MeasurementSheet extends ConsumerStatefulWidget {
  final Client client;
  const MeasurementSheet({super.key, required this.client});
  @override
  ConsumerState<MeasurementSheet> createState() => _MeasurementSheetState();
}

class _MeasurementSheetState extends ConsumerState<MeasurementSheet> {
  final _controllers = MeasureControllers();
  final _notes = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controllers.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = _controllers.validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (!_controllers.hasAny) {
      setState(() => _error = 'Registra al menos una medida.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      // La base descarta en silencio una toma idéntica a la última (trigger);
      // lo avisamos antes para que no parezca que se guardó.
      final existing = await ref.read(repoProvider).measurements(widget.client.id);
      if (existing.isNotEmpty) {
        final last = existing.first;
        final same = measureFields.every((f) => last.values[f.key] == _controllers.valueOf(f.key));
        if (same) {
          setState(() => _error = 'Estas medidas son idénticas a la última toma registrada.');
          return;
        }
      }
      final payload = <String, dynamic>{
        'client_id': widget.client.id,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        ..._controllers.toJson(), //... implementar una coleccion en una coleccion
      };
      await ref.read(repoProvider).createMeasurement(payload);
      ref.invalidate(measurementsProvider(widget.client.id));
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Medidas guardadas correctamente');
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      eyebrow: 'Nueva toma',
      title: 'Medidas de ${widget.client.firstName}',
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: Z.soft, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.straighten_rounded, color: Z.brandDark, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Registra las medidas en centímetros',
                    style: nunito(13, weight: FontWeight.w800, color: Z.ink)),
                Text('Los campos vacíos se guardan sin valor.', style: nunito(11, color: Z.muted)),
              ]),
            ),
          ]),
        ),
        MeasureInputs(controllers: _controllers),
        ZField(
          label: 'Observaciones',
          child: TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Notas sobre ajuste, postura o preferencias…'),
          ),
        ),
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Z.roseSoft, borderRadius: BorderRadius.circular(14)),
            child: Text(_error!, style: nunito(12, weight: FontWeight.w700, color: Z.rose)),
          ),
        Row(children: [
          Expanded(child: ZButton(label: 'Cancelar', secondary: true, onPressed: () => Navigator.pop(context))),
          const SizedBox(width: 10),
          Expanded(
            child: ZButton(label: 'Guardar medidas', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
          ),
        ]),
      ],
    );
  }
}
