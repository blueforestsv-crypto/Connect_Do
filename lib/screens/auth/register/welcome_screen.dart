import 'package:flutter/material.dart';

import 'package:project_ena/utils/responsive_helper.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // Animación de 20 segundos para un movimiento fluido y sutil
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // MÉTODO PARA CREAR BOTONES CON ESTILO PROPIO
  Widget _buildButton(
    BuildContext context,
    String text,
    Color color,
    String route,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, route),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          shadowColor: color.withOpacity(0.5),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: "Space Grotesk",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    final isSmallHeight = screenSize.height < 700;
    final isSmallWidth = screenSize.width < 360;

    final logoTop =
        isSmallHeight ? screenSize.height * 0.08 : screenSize.height * 0.12;
    final logoWidth =
        isSmallWidth
            ? 210.0
            : isSmallHeight
            ? 220.0
            : 260.0;

    final cardHeight =
        isSmallHeight ? screenSize.height * 0.55 : screenSize.height * 0.48;

    final titleSize = isSmallWidth ? 23.0 : 26.0;
    final subtitleSize = isSmallWidth ? 14.0 : 16.0;

    final bottomSafe = ResponsiveHelper.bottomSafe(context);

    return Scaffold(
      backgroundColor: const Color(0xFF2563EB),
      body: Stack(
        children: [
          // 1. CAPA DE FONDO: WALLPAPER ANIMADO
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.55,
                  child: Image.asset(
                    'assets/images/WallpaperCD.png',
                    alignment: Alignment(0, _controller.value * 2 - 1),
                    repeat: ImageRepeat.repeat,
                    fit: BoxFit.none,
                  ),
                );
              },
            ),
          ),

          // 2. CAPA DE GRADIENTE
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF2563EB).withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 3. CAPA MEDIA: EL LOGO
          Positioned(
            top: logoTop,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/Connect Do-01.png',
                width: logoWidth,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // 4. CAPA SUPERIOR: TARJETA BLANCA CON SOMBRA
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: cardHeight,
              padding: EdgeInsets.fromLTRB(
                40,
                isSmallHeight ? 26 : 35,
                40,
                bottomSafe + 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(60),
                  topRight: Radius.circular(60),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 25,
                    spreadRadius: 2,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: cardHeight - bottomSafe - 60,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Text(
                          '¡Bienvenido a Connect Do!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: "Space Grotesk",
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'La plataforma que conecta a universitarios con empresas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: "Space Grotesk",
                            fontSize: subtitleSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),

                        const Spacer(),

                        // BOTÓN REGÍSTRATE
                        _buildButton(
                          context,
                          "Regístrate",
                          const Color(0xFF22C55E),
                          '/benefits',
                        ),

                        const SizedBox(height: 18),

                        // BOTÓN INICIA SESIÓN
                        _buildButton(
                          context,
                          "Inicia sesión",
                          const Color(0xFF2563EB),
                          '/login',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
