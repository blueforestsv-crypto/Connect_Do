import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:connect_do/utils/responsive_helper.dart';

class BenefitsScreen extends StatefulWidget {
  const BenefitsScreen({super.key});

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _benefits = [
    {
      "title": "Conecta con Empresas",
      "text":
          "Conecta con empresas que buscan talento y ábrete paso en el mundo laboral.",
      "image": "assets/images/icono 1-01.png",
    },
    {
      "title": "Perfil Profesional",
      "text":
          "Destaca tus habilidades y proyectos ante reclutadores de todo el país.",
      "image": "assets/images/Profesional P.svg",
    },
    {
      "title": "Conoce y Crece",
      "text": "Conoce a universitarios de todo el país y amplía tu networking.",
      "image": "assets/images/Friends.svg",
    },
    {
      "title": "¡Todo Listo!",
      "text":
          "Únete a la comunidad de Connect Do y empieza a transformar tu futuro.",
      "image": "assets/images/Ready.svg",
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _benefits.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushNamed(context, '/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomSafe = ResponsiveHelper.bottomSafe(context);

    final buttonWidth = screenWidth < 360 ? screenWidth * 0.78 : 280.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1F2937),
      body: Stack(
        children: [
          // CAPA 1: ONDAS INFERIORES
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(screenWidth, 240),
              painter: WavePainter(),
            ),
          ),

          // CAPA 2: CONTENIDO
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),

                Image.asset(
                  'assets/images/Connect Do-01.png',
                  width: screenWidth < 360 ? 52 : 60,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemCount: _benefits.length,
                    itemBuilder: (context, index) {
                      return _buildBenefitCard(_benefits[index]);
                    },
                  ),
                ),

                // INDICADORES
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _benefits.length,
                    (index) => _buildIndicator(index == _currentPage),
                  ),
                ),

                SizedBox(height: screenWidth < 360 ? 24 : 34),

                // BOTÓN
                Padding(
                  padding: EdgeInsets.only(
                    bottom: bottomSafe + 24,
                    left: 24,
                    right: 24,
                  ),
                  child: SizedBox(
                    width: buttonWidth,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        _currentPage == _benefits.length - 1
                            ? "Continuar"
                            : "Siguiente",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitCard(Map<String, String> benefit) {
    final String imagePath = benefit['image']!;
    final bool isSvg = imagePath.toLowerCase().endsWith('.svg');

    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 360;

    final horizontalMargin = screenSize.width < 360 ? 24.0 : 40.0;
    final cardPadding = isSmallScreen ? 16.0 : 20.0;
    final imageSize = isSmallScreen ? 120.0 : 150.0;
    final titleSize = isSmallScreen ? 21.0 : 24.0;
    final textSize = isSmallScreen ? 14.0 : 16.0;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: isSmallScreen ? 12 : 20,
      ),
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: isSmallScreen ? 360 : 430),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: imageSize,
                height: imageSize,
                child:
                    isSvg
                        ? SvgPicture.asset(
                          imagePath,
                          fit: BoxFit.contain,
                          placeholderBuilder:
                              (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                        )
                        : Image.asset(
                          imagePath,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (context, error, stackTrace) => Icon(
                                Icons.handshake_outlined,
                                size: isSmallScreen ? 80 : 100,
                                color: const Color(
                                  0xFF22C55E,
                                ).withValues(alpha: 0.5),
                              ),
                        ),
              ),

              SizedBox(height: isSmallScreen ? 22 : 30),

              Text(
                benefit['title']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),

              const SizedBox(height: 15),

              Text(
                benefit['text']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: textSize,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 10,
      width: isActive ? 40 : 15,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2563EB) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isActive ? null : Border.all(color: Colors.grey.shade300),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintGreen = Paint()..color = const Color(0xFF22C55E);
    final paintBlue = Paint()..color = const Color(0xFF2563EB);

    final pathGreen = Path();

    pathGreen.moveTo(0, size.height * 0.4);
    pathGreen.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.1,
      size.width,
      size.height * 0.5,
    );
    pathGreen.lineTo(size.width, size.height);
    pathGreen.lineTo(0, size.height);
    pathGreen.close();

    canvas.drawPath(pathGreen, paintGreen);

    final pathBlue = Path();

    pathBlue.moveTo(0, size.height * 0.6);
    pathBlue.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.3,
      size.width,
      size.height * 0.7,
    );
    pathBlue.lineTo(size.width, size.height);
    pathBlue.lineTo(0, size.height);
    pathBlue.close();

    canvas.drawPath(pathBlue, paintBlue);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
