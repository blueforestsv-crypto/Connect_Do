import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';

/// Estructura común de las pantallas de acceso:
/// fondo sólido, logo o ícono, título, tarjeta y pie.
class AuthLayout extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final Widget child;
  final Widget? footer;

  /// Si es nulo se muestra el logo.
  final IconData? headerIcon;
  final bool showBack;
  final VoidCallback? onBack;

  const AuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.headerIcon,
    this.showBack = true,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: palette.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // En tablets y web el formulario no se estira de más.
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                ResponsiveHelper.bottomSafe(context) + 24,
              ),
              child: _EntranceAnimation(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child:
                            showBack && (canPop || onBack != null)
                                ? AuthBackButton(
                                  onTap:
                                      onBack ??
                                      () => Navigator.maybePop(context),
                                )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child:
                          headerIcon == null
                              ? Image.asset(
                                'assets/images/Connect Do-01.png',
                                height: 52,
                                fit: BoxFit.contain,
                              )
                              : _GradientIconBadge(icon: headerIcon!),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: Brand.displayFont,
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: palette.title,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      DefaultTextStyle(
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: Brand.displayFont,
                          fontSize: 15,
                          height: 1.45,
                          color: palette.body,
                        ),
                        child: subtitle!,
                      ),
                    ],
                    const SizedBox(height: 28),
                    AuthCard(child: child),
                    if (footer != null) ...[
                      const SizedBox(height: 20),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca (o azul noche) con borde y sombra suaves.
class AuthCard extends StatelessWidget {
  final Widget child;

  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Brand.radiusLg),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Patrón del wallpaper de marca, muy tenue y desvanecido hacia abajo.
class AuthBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const AuthBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Semantics(
      button: true,
      label: 'Volver',
      child: Material(
        color: palette.card,
        shape: CircleBorder(side: BorderSide(color: palette.cardBorder)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              PhosphorIconsRegular.arrowLeft,
              size: 20,
              color: palette.title,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientIconBadge extends StatelessWidget {
  final IconData icon;

  const _GradientIconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Brand.blue, Brand.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Brand.blue.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 32),
    );
  }
}

/// Entrada suave: aparece y sube unos píxeles.
class _EntranceAnimation extends StatelessWidget {
  final Widget child;

  const _EntranceAnimation({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder:
          (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - t)),
              child: child,
            ),
          ),
      child: child,
    );
  }
}
