import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'common.dart';

/// Opción de un selector con búsqueda.
class PickerItem {
  final int id;
  final String title;
  final String? subtitle;

  /// Grupo al que pertenece (p. ej. la organización de una dependencia).
  final int? groupId;
  const PickerItem({required this.id, required this.title, this.subtitle, this.groupId});
}

/// Resultado del selector. `id == null` significa "Todas" (limpiar filtro).
/// Si el usuario cierra la hoja sin elegir, la función devuelve null.
class PickerResult {
  final int? id;
  const PickerResult(this.id);
}

/// Hoja con barra de búsqueda por nombre y, opcionalmente, un filtro por grupo.
Future<PickerResult?> showSearchPicker(
  BuildContext context, {
  required String eyebrow,
  required String title,
  required String hint,
  required List<PickerItem> items,
  int? selectedId,
  String? allLabel,
  List<PickerItem> groups = const [],
  String groupLabel = 'Organización',
  int? initialGroupId,
}) {
  return showZSheet<PickerResult>(
    context,
    (_) => SearchPickerSheet(
      eyebrow: eyebrow,
      title: title,
      hint: hint,
      items: items,
      selectedId: selectedId,
      allLabel: allLabel,
      groups: groups,
      groupLabel: groupLabel,
      initialGroupId: initialGroupId,
    ),
  );
}

class SearchPickerSheet extends StatefulWidget {
  final String eyebrow;
  final String title;
  final String hint;
  final List<PickerItem> items;
  final int? selectedId;
  final String? allLabel;
  final List<PickerItem> groups;
  final String groupLabel;
  final int? initialGroupId;
  const SearchPickerSheet({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.hint,
    required this.items,
    this.selectedId,
    this.allLabel,
    this.groups = const [],
    this.groupLabel = 'Organización',
    this.initialGroupId,
  });

  @override
  State<SearchPickerSheet> createState() => _SearchPickerSheetState();
}

class _SearchPickerSheetState extends State<SearchPickerSheet> {
  String _query = '';
  int? _groupId;

  @override
  void initState() {
    super.initState();
    _groupId = widget.initialGroupId;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final available = media.size.height - keyboard - 140;
    final height = math.max(240.0, math.min(media.size.height * 0.8, available));

    final list = widget.items
        .where((i) => _groupId == null || i.groupId == _groupId)
        .where((i) => matchesSearch(i.title, _query))
        .toList();
    final showAll = widget.allLabel != null && _query.trim().isEmpty;

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
                  Eyebrow(widget.eyebrow),
                  Text(widget.title, style: display(23)),
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
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search_rounded, color: Z.muted),
              ),
            ),
            if (widget.groups.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                value: widget.groups.any((g) => g.id == _groupId) ? _groupId : null,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.filter_list_rounded, color: Z.muted),
                  labelText: 'Filtrar por ${widget.groupLabel.toLowerCase()}',
                ),
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text('Todas las ${widget.groupLabel.toLowerCase()}s')),
                  for (final g in widget.groups)
                    DropdownMenuItem<int?>(value: g.id, child: Text(g.title, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _groupId = v),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: (list.isEmpty && !showAll)
                  ? const SingleChildScrollView(
                      child: EmptyState(
                        icon: Icons.search_rounded,
                        title: 'Sin resultados',
                        message: 'Prueba con otro nombre.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length + (showAll ? 1 : 0),
                      itemBuilder: (_, index) {
                        if (showAll && index == 0) {
                          return _Row(
                            title: widget.allLabel!,
                            subtitle: null,
                            selected: widget.selectedId == null,
                            onTap: () => Navigator.pop(context, const PickerResult(null)),
                          );
                        }
                        final item = list[index - (showAll ? 1 : 0)];
                        return _Row(
                          title: item.title,
                          subtitle: item.subtitle,
                          selected: item.id == widget.selectedId,
                          onTap: () => Navigator.pop(context, PickerResult(item.id)),
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

class _Row extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _Row({required this.title, this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? Z.soft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? Z.brandDark : Z.border),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: nunito(11, color: Z.muted)),
                  ]),
                ),
                if (selected) const Icon(Icons.check_circle_rounded, color: Z.brandDark),
              ]),
            ),
          ),
        ),
      );
}

/// Campo que parece un selector y abre [showSearchPicker] al tocarlo.
class PickerField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  const PickerField({
    super.key,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: hasValue && onClear != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Z.muted),
                  onPressed: onClear,
                )
              : const Icon(Icons.search_rounded, color: Z.muted),
        ),
        child: Text(
          value ?? placeholder,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nunito(14, color: hasValue ? Z.ink : Z.muted),
        ),
      ),
    );
  }
}
