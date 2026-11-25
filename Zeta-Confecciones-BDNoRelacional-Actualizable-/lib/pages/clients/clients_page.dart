import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../bloc/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/pagination.dart';
import '../../widgets/search_picker_sheet.dart';
import 'client_detail_page.dart';
import 'client_form_page.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});
  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  String _query = '';
  int? _orgId;
  int? _depId;
  bool _showInactive = false;
  bool _showFilters = false;
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

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final orgs = ref.watch(organizationsProvider).valueOrNull ?? const <Organization>[];
    final deps = ref.watch(departmentsProvider).valueOrNull ?? const <Department>[];
    final depById = {for (final d in deps) d.id: d};
    final orgById = {for (final o in orgs) o.id: o};
    final availableDeps = _orgId == null ? deps : deps.where((d) => d.organizationId == _orgId).toList();
    final hasFilters = _orgId != null || _depId != null || _showInactive;

    Future<void> refresh() async {
      ref.invalidate(clientsProvider);
      ref.invalidate(organizationsProvider);
      ref.invalidate(departmentsProvider);
      await ref.read(clientsProvider.future);
    }

    return RefreshIndicator(
      color: Z.brandDark,
      onRefresh: refresh,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          AsyncView<List<Client>>(
            value: clientsAsync,
            onRetry: () => ref.invalidate(clientsProvider),
            builder: (clients) {
              final filtered = clients.where((c) {
                if (!_showInactive && !c.active) return false;
                final dep = c.departmentId == null ? null : depById[c.departmentId];
                if (_orgId != null && dep?.organizationId != _orgId) return false;
                if (_depId != null && c.departmentId != _depId) return false;
                return matchesSearch(c.fullName, _query);
              }).toList();
              final activeCount = clients.where((c) => c.active).length;
              final pageCount = pageCountFor(filtered.length);
              final page = _page >= pageCount ? pageCount - 1 : _page;
              final visible = pageSlice(filtered, page);

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PageTitle(
                  eyebrow: 'Directorio', //texto pequeño que aparece sobre el título.
                  title: 'Clientes',
                  subtitle: '$activeCount clientes activos',
                  trailing: RoundAction( //contenido que se coloca al lado opuesto del título.
                    icon: Icons.add_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientFormPage())),
                  ),
                ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() {
                        _query = v;
                        _page = 0;
                      }),
                      decoration: const InputDecoration(
                        hintText: 'Buscar por nombre…',
                        prefixIcon: Icon(Icons.search_rounded, color: Z.muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material( //sirve como base visual para el botón de filtros que viene dentro.
                    color: _showFilters ? Z.soft : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _showFilters = !_showFilters),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _showFilters ? Z.brandDark : Z.border),
                        ),
                        child: Stack(alignment: Alignment.center, children: [
                          const Icon(Icons.tune_rounded, color: Z.brandDark),
                          if (hasFilters)
                            const Positioned(
                              top: 11,
                              right: 11,
                              child: CircleAvatar(radius: 4, backgroundColor: Z.rose),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ]),
                if (_showFilters)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Z.border),
                    ),
                    child: Column(children: [
                      ZField(
                        label: 'Organización',
                        child: PickerField(
                          value: orgById[_orgId]?.name,
                          placeholder: 'Todas las organizaciones',
                          onClear: () => setState(() {
                            _orgId = null;
                            _depId = null;
                            _page = 0;
                          }),
                          onTap: () async {
                            final r = await showSearchPicker(
                              context,
                              eyebrow: 'Filtro',
                              title: 'Filtrar por organización',
                              hint: 'Buscar organización por nombre…',
                              items: [for (final o in orgs) PickerItem(id: o.id, title: o.name)],
                              selectedId: _orgId,
                              allLabel: 'Todas las organizaciones',
                            );
                            if (r == null) return;
                            setState(() {
                              if (r.id != _orgId) _depId = null; // la dependencia debe ser de la organización
                              _orgId = r.id;
                              _page = 0;
                            });
                          },
                        ),
                      ),
                      ZField(
                        label: 'Dependencia',
                        child: PickerField(
                          value: availableDeps.where((d) => d.id == _depId).isEmpty
                              ? null
                              : availableDeps.firstWhere((d) => d.id == _depId).name,
                          placeholder: _orgId == null
                              ? 'Todas las dependencias'
                              : 'Todas las de ${orgById[_orgId]?.name ?? 'la organización'}',
                          onClear: () => setState(() {
                            _depId = null;
                            _page = 0;
                          }),
                          onTap: () async {
                            final r = await showSearchPicker(
                              context,
                              eyebrow: 'Filtro',
                              title: 'Filtrar por dependencia',
                              hint: 'Buscar dependencia por nombre…',
                              // Con organización elegida solo se ofrecen sus dependencias.
                              items: [
                                for (final d in availableDeps)
                                  PickerItem(
                                    id: d.id,
                                    title: d.name,
                                    subtitle: orgById[d.organizationId]?.name,
                                    groupId: d.organizationId,
                                  ),
                              ],
                              // Sin organización elegida se puede acotar por organización dentro del selector.
                              groups: _orgId == null ? [for (final o in orgs) PickerItem(id: o.id, title: o.name)] : const [],
                              selectedId: _depId,
                              allLabel: 'Todas las dependencias',
                            );
                            if (r == null) return;
                            setState(() {
                              _depId = r.id;
                              _page = 0;
                            });
                          },
                        ),
                      ),
                      SwitchListTile(
                        value: _showInactive,
                        onChanged: (v) => setState(() {
                          _showInactive = v;
                          _page = 0;
                        }),
                        contentPadding: EdgeInsets.zero,
                        activeColor: Z.brandDark,
                        title: Text('Mostrar inactivos', style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                        subtitle: Text('Incluye clientes dados de baja', style: nunito(11, color: Z.muted)),
                      ),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
                  child: Row(children: [
                    Text('${filtered.length} resultado${filtered.length == 1 ? '' : 's'}',
                        style: nunito(11, weight: FontWeight.w700, color: Z.muted)),
                    const Spacer(),
                    if (_orgId != null || _depId != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _orgId = null;
                          _depId = null;
                          _page = 0;
                        }),
                        child: Text('Limpiar filtros', style: nunito(11, weight: FontWeight.w800, color: Z.brandDark)),
                      ),
                  ]),
                ),
                if (filtered.isEmpty)
                  EmptyState(
                    icon: Icons.search_rounded,
                    title: 'Sin resultados',
                    message: 'Prueba con otro nombre o ajusta los filtros.',
                    action: SizedBox(
                      width: 200,
                      child: ZButton(
                        label: 'Limpiar búsqueda',
                        secondary: true,
                        onPressed: () => setState(() {
                          _query = '';
                          _orgId = null;
                          _depId = null;
                          _showInactive = false;
                          _page = 0;
                        }),
                      ),
                    ),
                  )
                else ...[
                  for (final c in visible)
                    _ClientRow(
                      client: c,
                      department: c.departmentId == null ? null : depById[c.departmentId],
                      organization: c.departmentId == null
                          ? null
                          : orgById[depById[c.departmentId]?.organizationId],
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

class _ClientRow extends StatelessWidget {
  final Client client;
  final Department? department;
  final Organization? organization;
  const _ClientRow({required this.client, this.department, this.organization});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ClientDetailPage(clientId: client.id)),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Z.border),
            ),
            child: Row(children: [
              ZAvatar(client.fullName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(client.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                  if (department != null) Text(department!.name, style: nunito(11, color: Z.muted)),
                  if (organization != null)
                    Text(organization!.name, style: nunito(11, weight: FontWeight.w800, color: Z.brandDark)),
                  if (client.phone != null && client.phone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(children: [
                        const Icon(Icons.phone_outlined, size: 12, color: Z.muted),
                        const SizedBox(width: 4),
                        Text(client.phone!, style: nunito(11, color: Z.muted)),
                      ]),
                    ),
                ]),
              ),
              _StatePill(active: client.active),
              const Icon(Icons.chevron_right_rounded, color: Z.arrow),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  final bool active;
  const _StatePill({required this.active});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Z.greenSoft : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(active ? 'Activo' : 'Inactivo',
            style: nunito(10, weight: FontWeight.w800, color: active ? Z.green : const Color(0xFF777777))),
      );
}