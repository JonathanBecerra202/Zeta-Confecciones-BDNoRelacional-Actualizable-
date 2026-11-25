import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/pagination.dart';

const _tableLabels = {
  'client': 'Cliente',
  'organization': 'Organización',
  'department': 'Dependencia',
  'garment_order': 'Pedido',
  'payment': 'Abono',
  'measurement': 'Medidas',
  'role': 'Rol',
  'profile': 'Perfil',
};

const _opLabels = {'INSERT': 'Creó', 'UPDATE': 'Modificó', 'DELETE': 'Eliminó'};

/// Filtros por tipo de acción (null = todas).
const _opFilters = <(String, String?)>[
  ('Todas', null),
  ('Creó', 'INSERT'),
  ('Modificó', 'UPDATE'),
  ('Eliminó', 'DELETE'),
];

/// Solo Admin (el RLS de audit_log también lo exige).
/// Paginación, filtro por acción y búsqueda por usuario se resuelven en Supabase.
class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});
  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  int _page = 0;
  String? _operation;
  String _userQuery = '';
  Timer? _debounce;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _goToPage(int p) {
    setState(() => _page = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _userQuery = v;
        _page = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = AuditQuery(page: _page, operation: _operation, userQuery: _userQuery);
    final result = ref.watch(auditPageProvider(query));
    final names = {
      for (final u in ref.watch(userNamesProvider).valueOrNull ?? const <UserName>[]) u.id: u.fullName
    };
    String userLabel(String? id) => id == null ? 'Sistema / SQL' : (names[id] ?? 'Usuario desconocido');

    final total = result.valueOrNull?.total;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Z.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Z.ink),
        title: Text('Más', style: nunito(14, weight: FontWeight.w800, color: Z.brandDark)),
      ),
      body: RefreshIndicator(
        color: Z.brandDark,
        onRefresh: () async {
          ref.invalidate(userNamesProvider);
          ref.invalidate(auditPageProvider(query));
          await ref.read(auditPageProvider(query).future);
        },
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            PageTitle(
              eyebrow: 'Administración',
              title: 'Auditoría',
              subtitle: total == null ? 'Movimientos del sistema' : '$total movimiento${total == 1 ? '' : 's'}',
            ),
            SearchField(hint: 'Buscar por usuario…', onChanged: _onSearch),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _opFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (label, op) = _opFilters[i];
                  final active = op == _operation;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _operation = op;
                      _page = 0;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? Z.brandDark : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: active ? Z.brandDark : Z.border),
                      ),
                      child: Text(label,
                          style: nunito(12, weight: FontWeight.w800, color: active ? Colors.white : Z.body)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            AsyncView<AuditPageResult>(
              value: result,
              onRetry: () => ref.invalidate(auditPageProvider(query)),
              builder: (res) {
                final pageCount = pageCountFor(res.total);
                // Si los filtros dejan menos páginas que la actual, volver a la última.
                if (_page >= pageCount && _page > 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _page = pageCount - 1);
                  });
                }
                if (res.rows.isEmpty) {
                  return const EmptyState(
                    icon: Icons.verified_user_outlined,
                    title: 'Sin movimientos',
                    message: 'No hay registros que coincidan con los filtros.',
                  );
                }
                return Column(children: [
                  for (final l in res.rows)
                    SimpleRow(
                      icon: switch (l.operation) {
                        'INSERT' => Icons.add_circle_outline_rounded,
                        'DELETE' => Icons.remove_circle_outline_rounded,
                        _ => Icons.edit_outlined,
                      },
                      title:
                          '${_opLabels[l.operation] ?? l.operation} · ${_tableLabels[l.tableName] ?? l.tableName}${l.recordId != null ? ' #${l.recordId}' : ''}',
                      subtitle: '${dateTimeLabel(l.loggedAt)} · ${userLabel(l.userId)}',
                      onTap: () => showZSheet(context, (_) => _AuditDetail(log: l, userName: userLabel(l.userId))),
                    ),
                  PaginationBar(page: _page, pageCount: pageCount, onChanged: _goToPage),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditDetail extends StatelessWidget {
  final AuditLog log;
  final String userName;
  const _AuditDetail({required this.log, required this.userName});

  String _pretty(Map<String, dynamic>? m) =>
      m == null ? '—' : const JsonEncoder.withIndent('  ').convert(m);

  @override
  Widget build(BuildContext context) {
    Widget block(String label, Map<String, dynamic>? data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(label, style: nunito(12, weight: FontWeight.w800, color: Z.ink)),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Z.bg, borderRadius: BorderRadius.circular(14)),
              child: SelectableText(_pretty(data), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ),
          ],
        );

    return SheetScaffold(
      eyebrow: dateTimeLabel(log.loggedAt),
      title: '${_opLabels[log.operation] ?? log.operation} · ${_tableLabels[log.tableName] ?? log.tableName}',
      children: [
        Text('Usuario: $userName', style: nunito(12, color: Z.muted)),
        if (log.before != null) block('Antes', log.before),
        if (log.after != null) block('Después', log.after),
      ],
    );
  }
}
