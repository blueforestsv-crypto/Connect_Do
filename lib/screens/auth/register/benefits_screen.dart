import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:connect_do/theme/brand.dart';
import 'package:connect_do/utils/responsive_helper.dart';
import 'package:connect_do/widgets/auth/auth_controls.dart';

/// Presentación de la app. Se muestra una sola vez, en la primera apertura,
/// y ya no forma parte del camino del registro.
class BenefitsScreen extends StatefulWidget {
  static const String seenKey = 'onboarding_visto';

  const BenefitsScreen({super.key});

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<({String title, String text, String image})> _benefits = [
    (
      title: 'Conecta con empresas',
      text:
          'Empresas que buscan talento universitario publican sus oportunidades aquí.',
      image: 'assets/images/icono 1-01.png',
    ),
    (
      title: 'Tu perfil profesional',
      text:
          'Destaca tus habilidades y proyectos ante reclutadores de todo el país.',
      image: 'assets/images/Profesional P.svg',
    ),
    (
      title: 'Conoce y crece',
      text: 'Conoce a universitarios de todo el país y amplía tu networking.',
      image: 'assets/images/Friends.svg',
    ),
    (
      title: '¡Todo listo!',
      text:
          'Únete a la comunidad de Connect Do y empieza a transformar tu futuro.',
      image: 'assets/images/Ready.svg',
    ),
  ];

  bool get _isLast => _currentPage == _benefits.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (!_isLast) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(BenefitsScreen.seenKey, true);

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/welcome');
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/Connect Do-01.png',
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isLast ? 0 : 1,
                        child: TextButton(
                          onPressed: _isLast ? null : _finish,
                          child: Text(
                            'Saltar',
                            style: TextStyle(
                              fontFamily: Brand.displayFont,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: palette.body,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged:
                        (page) => setState(() => _currentPage = page),
                    itemCount: _benefits.length,
                    itemBuilder:
                        (context, index) => _BenefitPage(
                          title: _benefits[index].title,
                          text: _benefits[index].text,
                          image: _benefits[index].image,
                        ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _benefits.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: i == _currentPage ? 28 : 8,
                        decoration: BoxDecoration(
                          gradient: i == _currentPage ? Brand.gradient : null,
                          color: i == _currentPage ? null : palette.fieldBorder,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    28,
                    24,
                    ResponsiveHelper.bottomSafe(context) + 24,
                  ),
                  child: GradientButton(
                    text: _isLast ? 'Empezar' : 'Siguiente',
                    onPressed: _nextPage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitPage extends StatelessWidget {
  final String title;
  final String text;
  final String image;

  const _BenefitPage({
    required this.title,
    required this.text,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final isSvg = image.toLowerCase().endsWith('.svg');
    final compact = MediaQuery.of(context).size.height < 700;
    final artSize = compact ? 200.0 : 260.0;

    return LayoutBuilder(
      builder:
          (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              // Centrado vertical en el espacio disponible.
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: artSize,
                    height: artSize,
                    padding: EdgeInsets.all(artSize * 0.2),
                    decoration: BoxDecoration(
                      color: Brand.blue.withValues(
                        alpha: palette.isDark ? 0.16 : 0.07,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child:
                        isSvg
                            ? SvgPicture.asset(image, fit: BoxFit.contain)
                            : Image.asset(
                              image,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (_, __, ___) => const Icon(
                                    Icons.handshake_outlined,
                                    size: 96,
                                    color: Brand.green,
                                  ),
                            ),
                  ),
                  SizedBox(height: compact ? 28 : 40),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: palette.title,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Brand.displayFont,
                      fontSize: 16,
                      height: 1.5,
                      color: palette.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
