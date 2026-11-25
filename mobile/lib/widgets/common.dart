import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';

void toast(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(message)),
    ]),
    duration: const Duration(milliseconds: 2400),
  ));
}

void toastError(BuildContext context, Object error) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    backgroundColor: Z.rose,
    content: Text(friendlyError(error)),
    duration: const Duration(seconds: 4),
  ));
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String confirmLabel = 'Eliminar'}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: display(19)),
      content: Text(message, style: nunito(14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: Z.rose, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Hoja inferior con las esquinas redondeadas del mockup.
Future<T?> showZSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: builder,
  );
}

class SheetScaffold extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<Widget> children;
  const SheetScaffold({super.key, required this.eyebrow, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Eyebrow(eyebrow),
                    Text(title, style: display(23)),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Z.muted),
                  style: IconButton.styleFrom(backgroundColor: Z.soft),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;
  const Eyebrow(this.text, {super.key, this.color = Z.brandDark});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text.toUpperCase(),
            style: nunito(10, weight: FontWeight.w800, color: color).copyWith(letterSpacing: 1.1)),
      );
}

class PageTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PageTitle({super.key, required this.eyebrow, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow(eyebrow),
              Text(title, style: display(27)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(subtitle!, style: nunito(13, color: Z.muted)),
                ),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class RoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const RoundAction({super.key, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Z.brandDark,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(width: 48, height: 48, child: Icon(icon, color: Colors.white)),
        ),
      );
}

class SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool alert;
  final int? count;
  const SectionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.alert = false,
    this.count,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow(eyebrow, color: alert ? Z.rose : Z.brandDark),
              Text(title, style: display(19)),
            ]),
          ),
          if (count != null)
            Container(
              constraints: const BoxConstraints(minWidth: 26),
              height: 26,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: Z.roseSoft, borderRadius: BorderRadius.circular(99)),
              child: Text('$count', style: nunito(11, weight: FontWeight.w800, color: Z.rose)),
            ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: nunito(11, weight: FontWeight.w800, color: Z.brandDark)),
            ),
        ]),
      );
}

class ZButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool loading;
  final IconData? icon;
  const ZButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: secondary ? Z.brandDark : Colors.white),
          )
        : Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: nunito(15, weight: FontWeight.w800, color: secondary ? Z.brandDark : Colors.white)),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 19, color: secondary ? Z.brandDark : Colors.white),
            ],
          ]);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: secondary
          ? OutlinedButton(
              onPressed: loading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                shape: shape,
                side: const BorderSide(color: Z.border),
                backgroundColor: Colors.white,
              ),
              child: child,
            )
          : FilledButton(
              onPressed: loading ? null : onPressed,
              style: FilledButton.styleFrom(backgroundColor: Z.brandDark, shape: shape),
              child: child,
            ),
    );
  }
}

/// Etiqueta + campo, como `Field` del mockup.
class ZField extends StatelessWidget {
  final String label;
  final Widget child;
  const ZField({super.key, required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Text(label, style: nunito(12, weight: FontWeight.w800, color: Z.ink)),
          ),
          child,
        ]),
      );
}

class ZAvatar extends StatelessWidget {
  final String name;
  final double size;
  const ZAvatar(this.name, {super.key, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Z.brand, Z.brandDark]),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x40368FC5), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Text(initials(name), style: nunito(size * 0.3, weight: FontWeight.w800, color: Colors.white)),
      );
}

class StatusPill extends StatelessWidget {
  final OrderStatus status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case OrderStatus.pending:
        bg = const Color(0xFFFFF4DD);
        fg = const Color(0xFFA96D11);
        break;
      case OrderStatus.inProgress:
        bg = const Color(0xFFE8F4FB);
        fg = const Color(0xFF277CAC);
        break;
      case OrderStatus.delivered:
        bg = const Color(0xFFE9F8F0);
        fg = const Color(0xFF288755);
        break;
      case OrderStatus.cancelled:
        bg = const Color(0xFFF1F1F1);
        fg = const Color(0xFF777777);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(status.label.toUpperCase(),
          style: nunito(8.5, weight: FontWeight.w800, color: fg).copyWith(letterSpacing: .4)),
    );
  }
}

class PaymentPill extends StatelessWidget {
  final bool paid;
  const PaymentPill({super.key, required this.paid});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: paid ? Z.greenSoft : Z.roseSoft,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(paid ? 'PAGADO' : 'SALDO PENDIENTE',
            style: nunito(8.5, weight: FontWeight.w800, color: paid ? Z.green : Z.rose)
                .copyWith(letterSpacing: .4)),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: Z.soft, borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: Z.brandDark, size: 26),
          ),
          const SizedBox(height: 14),
          Text(title, style: display(18)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: nunito(13, color: Z.muted)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar',
        message: friendlyError(error),
        action: SizedBox(width: 180, child: ZButton(label: 'Reintentar', secondary: true, onPressed: onRetry)),
      );
}

/// Atajo para pintar un AsyncValue con carga / error / datos.
class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  const AsyncView({super.key, required this.value, required this.onRetry, required this.builder});

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: Z.brandDark)),
      ),
      error: (e, _) => ErrorView(error: e, onRetry: onRetry),
    );
  }
}

class OrderPreview extends StatelessWidget {
  final GarmentOrder order;
  final String clientName;
  final bool alert;
  final VoidCallback onTap;
  const OrderPreview({
    super.key,
    required this.order,
    required this.clientName,
    required this.onTap,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: alert ? const Color(0xFFFFFAFB) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: alert ? const Color(0xFFF4C6D3) : Z.border),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: alert ? Z.roseSoft : Z.soft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(alert ? Icons.warning_amber_rounded : Icons.calendar_today_rounded,
                    size: 19, color: alert ? Z.rose : Z.brandDark),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('Pedido #${order.id}',
                          style: nunito(10.5, weight: FontWeight.w800, color: Z.brandDark)),
                    ),
                    StatusPill(order.status),
                  ]),
                  const SizedBox(height: 2),
                  Text(clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                  Text(order.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nunito(11, color: Z.muted)),
                  const SizedBox(height: 4),
                  Text(dueLabel(order),
                      style: nunito(11, weight: FontWeight.w800, color: alert ? Z.rose : Z.body)),
                ]),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 10, left: 4),
                child: Icon(Icons.chevron_right_rounded, color: Z.arrow, size: 20),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Fila de lista simple (organizaciones, dependencias, auditoría).
class SimpleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  const SimpleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Z.border),
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Z.soft, borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, size: 20, color: Z.brandDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: nunito(14, weight: FontWeight.w800, color: Z.ink)),
                    Text(subtitle, style: nunito(11, color: Z.muted)),
                  ]),
                ),
                if (trailing != null) trailing!,
              ]),
            ),
          ),
        ),
      );
}
