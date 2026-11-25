import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';

/// Pantalla de entrada: marca, propuesta de valor en "bento" y las acciones.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Entrada escalonada: cada bloque aparece y sube un poco después del otro.
  Widget _staggered(int index, Widget child) {
    // Interval exige 0 <= inicio <= fin <= 1.
    final start = (index * 0.1).clamp(0.0, 0.55);
    final end = (start + 0.45).clamp(start, 1.0);
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder:
          (context, child) => Opacity(
            opacity: animation.value,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - animation.value)),
              child: child,
            ),
          ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // En pantallas bajas se oculta el logo para que los botones
                // queden visibles sin desplazarse.
                final compact = constraints.maxHeight < 720;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    ResponsiveHelper.bottomSafe(context) + 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _staggered(0, const Center(child: _AudiencePill())),
                          const Spacer(),
                          SizedBox(height: compact ? 16 : 24),
                          if (!compact) ...[
                            _staggered(
                              1,
                              Center(
                                child: Image.asset(
                                  'assets/images/Connect Do-01.png',
                                  height: 56,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          _staggered(1, _buildHeadline(palette, compact)),
                          SizedBox(height: compact ? 20 : 26),
                          _staggered(2, const _FeaturedCard()),
                          const SizedBox(height: 12),
                          _staggered(
                            3,
                            const IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _TileCard(
                                      icon:
                                          PhosphorIconsRegular
                                              .identificationCard,
                                      accent: Brand.blue,
                                      title: 'Perfil profesional',
                                      text: 'Destaca tus habilidades',
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _TileCard(
                                      icon: PhosphorIconsRegular.usersThree,
                                      accent: Brand.green,
                                      title: 'Networking',
                                      text: 'Conecta con estudiantes',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(height: compact ? 20 : 24),
                          _staggered(
                            4,
                            GradientButton(
                              text: 'Crear cuenta',
                              onPressed:
                                  () =>
                                      Navigator.pushNamed(context, '/register'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _staggered(
                            5,
                            OutlineActionButton(
                              text: 'Ya tengo cuenta',
                              onPressed:
                                  () => Navigator.pushNamed(context, '/login'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadline(AuthPalette palette, bool compact) {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            text: 'Tu carrera empieza\n',
            children: [
              TextSpan(
                text: 'aquí.',
                style: const TextStyle(color: Brand.blue),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: compact ? 28 : 34,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: palette.title,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Conectamos universitarios con empresas que buscan talento.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Brand.displayFont,
            fontSize: 15.5,
            height: 1.45,
            color: palette.body,
          ),
        ),
      ],
    );
  }
}

/// Etiqueta superior: a quién va dirigida la app.
class _AudiencePill extends StatelessWidget {
  const _AudiencePill();

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Brand.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Para universitarios de El Salvador',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Brand.displayFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.label,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta principal del bento, en azul sólido de marca.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Brand.blue,
        borderRadius: BorderRadius.circular(Brand.radiusLg),
      ),
      child: Stack(
        children: [
          // Ícono grande decorativo, recortado por la esquina.
          Positioned(
            right: -18,
            bottom: -26,
            child: Icon(
              PhosphorIconsRegular.briefcase,
              size: 132,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Brand.green,
                        borderRadius: BorderRadius.circular(Brand.radiusSm),
                      ),
                      child: const Icon(
                        PhosphorIconsRegular.briefcase,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Spacer(),
                    Flexible(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Pasantías · Empleo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: Brand.displayFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Oportunidades reales',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Empresas que buscan talento publican aquí sus vacantes.',
                  style: TextStyle(
                    fontFamily: Brand.displayFont,
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta cuadrada del bento.
class _TileCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String text;

  const _TileCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Brand.radiusLg),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: palette.isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(Brand.radiusSm),
            ),
            child: Icon(icon, size: 21, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: palette.title,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: Brand.displayFont,
              fontSize: 13,
              height: 1.4,
              color: palette.body,
            ),
          ),
        ],
      ),
    );
  }
}
