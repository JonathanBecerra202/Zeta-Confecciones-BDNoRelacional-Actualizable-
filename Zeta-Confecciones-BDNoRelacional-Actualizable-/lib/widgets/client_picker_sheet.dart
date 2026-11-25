import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../bloc/providers.dart';
import 'common.dart';

/// Hoja con barra de búsqueda para elegir un cliente.
/// Devuelve el `client_id` elegido (Navigator.pop) o null si se cierra.
class ClientPickerSheet extends ConsumerStatefulWidget {
  final int? selectedId;
  const ClientPickerSheet({super.key, this.selectedId});
  @override
  ConsumerState<ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends ConsumerState<ClientPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final deps = {
      for (final d in ref.watch(departmentsProvider).valueOrNull ?? const <Department>[]) d.id: d
    };
    final orgs = {
      for (final o in ref.watch(organizationsProvider).valueOrNull ?? const <Organization>[]) o.id: o
    };

    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final available = media.size.height - keyboard - 140;
    final height = math.max(220.0, math.min(media.size.height * 0.75, available));

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Eyebrow('Nuevo pedido'),
                  Text('Elegir cliente', style: display(23)),
                ]),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Z.muted),
                style: IconButton.styleFrom(backgroundColor: Z.soft),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Buscar cliente por nombre…',
                prefixIcon: Icon(Icons.search_rounded, color: Z.muted),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: clientsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Z.brandDark)),
                error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(clientsProvider)),
                data: (all) {
                  final list = all
                      .where((c) => c.active || c.id == widget.selectedId)
                      .where((c) => matchesSearch(c.fullName, _query))
                      .toList();
                  if (list.isEmpty) {
                    return const SingleChildScrollView(
                      child: EmptyState(
                        icon: Icons.search_rounded,
                        title: 'Sin resultados',
                        message: 'No hay clientes con ese nombre.',
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final dep = c.departmentId == null ? null : deps[c.departmentId];
                      final org = dep == null ? null : orgs[dep.organizationId];
                      final selected = c.id == widget.selectedId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: selected ? Z.soft : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pop(context, c.id),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: selected ? Z.brandDark : Z.border),
                              ),
                              child: Row(children: [
                                ZAvatar(c.fullName, size: 38),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(c.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                                    if (dep != null || org != null)
                                      Text([org?.name, dep?.name].whereType<String>().join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: nunito(11, color: Z.muted)),
                                  ]),
                                ),
                                if (selected) const Icon(Icons.check_circle_rounded, color: Z.brandDark),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
