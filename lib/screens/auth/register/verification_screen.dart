import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:connect_do/screens/main_content/home/home_screen.dart';
import 'package:connect_do/utils/responsive_helper.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  // Controladores y focos para los 4 dígitos
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }

    for (var node in _focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  void _onChanged(String value, int index) {
    // Mover al siguiente cuadro al escribir
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }

    // Regresar al anterior al borrar
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  // --- FUNCIÓN DE VERIFICACIÓN (MODO DESARROLLO) ---
  Future<void> _verifyCode() async {
    final codigoCompleto = _controllers.map((c) => c.text).join();

    // 1. Validar que ingresó los 4 números
    if (codigoCompleto.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, ingresa los 4 dígitos"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 2. Mostrar estado de carga
    setState(() => _isLoading = true);

    // 3. Simular que va al servidor a revisar
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // 4. MODO BYPASS: ¡Entra con cualquier código!
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("¡Cuenta verificada con éxito!"),
        backgroundColor: Color(0xFF22C55E),
        duration: Duration(seconds: 2),
      ),
    );

    // 5. Destruir historial y mandarlo al Home
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        ResponsiveHelper.keyboard(context) +
        ResponsiveHelper.bottomSafe(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF22C55E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),

            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: const [
                  Icon(
                    Icons.alternate_email_rounded,
                    size: 70,
                    color: Colors.white,
                  ),

                  SizedBox(height: 20),

                  Text(
                    'Verifica tu identidad',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 12),

                  Text(
                    'Hemos enviado un código a tu correo institucional para confirmar que eres estudiante universitario.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 35),

            // CONTENEDOR DE ACCIÓN
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(45),
                    topRight: Radius.circular(45),
                  ),
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(40, 40, 40, bottomPadding + 30),
                  child: Column(
                    children: [
                      const Text(
                        'Ingresa el código de 4 dígitos',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),

                      const SizedBox(height: 25),

                      // INPUTS OTP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          4,
                          (index) => _buildCodeBox(index),
                        ),
                      ),

                      const SizedBox(height: 30),

                      TextButton(
                        onPressed:
                            _isLoading
                                ? null
                                : () =>
                                    debugPrint("Reenviar código presionado"),
                        child: const Text(
                          '¿No recibiste el correo?\nRevisar en Spam o Reenviar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                      const SizedBox(height: 70),

                      // BOTÓN FINALIZAR
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            disabledBackgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                  : const Text(
                                    'Verificar y Entrar',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBox(int index) {
    return SizedBox(
      width: 60,
      height: 75,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        enabled: !_isLoading,
        onChanged: (value) => _onChanged(value, index),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction:
            index == 3 ? TextInputAction.done : TextInputAction.next,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2563EB),
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF22C55E), width: 2),
          ),
        ),
        onSubmitted: (_) {
          if (index == 3) {
            _verifyCode();
          }
        },
      ),
    );
  }
}
