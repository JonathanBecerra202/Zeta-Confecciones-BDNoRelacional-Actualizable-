import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Tamaño de página usado en todas las listas.
const kPageSize = 10;

int pageCountFor(int total, [int size = kPageSize]) =>
    total <= 0 ? 1 : (total + size - 1) ~/ size;

/// Recorta la lista a la página [page] (empieza en 0).
List<T> pageSlice<T>(List<T> items, int page, [int size = kPageSize]) {
  final start = page * size;
  if (start >= items.length) return <T>[];
  final end = start + size > items.length ? items.length : start + size;
  return items.sublist(start, end);
}

/// Controles "Anterior · 1 de 5 · Siguiente". [page] empieza en 0.
/// Al tocar "1 de 5" se puede escribir el número de página para ir directo.
/// No se dibuja si solo hay una página.
class PaginationBar extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;
  const PaginationBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });

  Future<void> _jump(BuildContext context) async {
    final target = await showDialog<int>(
      context: context,
      builder: (_) => _GoToPageDialog(current: page + 1, pageCount: pageCount),
    );
    if (target == null) return;
    final index = target - 1;
    if (index != page) onChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    final canPrev = page > 0;
    final canNext = page < pageCount - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(children: [
        Expanded(
          child: _NavButton(
            label: 'Anterior',
            icon: Icons.chevron_left_rounded,
            iconFirst: true,
            onTap: canPrev ? () => onChanged(page - 1) : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _jump(context),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Z.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${page + 1}', style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                    TextSpan(text: ' de $pageCount', style: nunito(12, color: Z.muted)),
                  ])),
                  const SizedBox(width: 6),
                  const Icon(Icons.unfold_more_rounded, size: 16, color: Z.muted),
                ]),
              ),
            ),
          ),
        ),
        Expanded(
          child: _NavButton(
            label: 'Siguiente',
            icon: Icons.chevron_right_rounded,
            iconFirst: false,
            onTap: canNext ? () => onChanged(page + 1) : null,
          ),
        ),
      ]),
    );
  }
}

/// Cuadro para escribir el número de página (1 a [pageCount]).
class _GoToPageDialog extends StatefulWidget {
  final int current;
  final int pageCount;
  const _GoToPageDialog({required this.current, required this.pageCount});

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_ctrl.text.trim());
    if (n == null || n < 1 || n > widget.pageCount) {
      setState(() => _error = 'Escribe un número entre 1 y ${widget.pageCount}.');
      return;
    }
    Navigator.pop(context, n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Ir a la página', style: nunito(16, weight: FontWeight.w800, color: Z.ink)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estás en la ${widget.current} de ${widget.pageCount}.', style: nunito(12, color: Z.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.go,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Ej. ${widget.pageCount}',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: nunito(13, weight: FontWeight.w800, color: Z.muted)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Ir', style: nunito(13, weight: FontWeight.w800, color: Z.brandDark)),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool iconFirst;
  final VoidCallback? onTap;
  const _NavButton({required this.label, required this.icon, required this.iconFirst, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? Z.brandDark : Z.arrow;
    final children = [
      Icon(icon, size: 20, color: color),
      Text(label, style: nunito(12, weight: FontWeight.w800, color: color)),
    ];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Z.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: iconFirst ? children : children.reversed.toList(),
          ),
        ),
      ),
    );
  }
}

/// Barra de búsqueda con el estilo del resto de la app.
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const SearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, color: Z.muted),
        ),
      );
}