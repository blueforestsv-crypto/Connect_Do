import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_do/helpers/profile_completion.dart';
import 'package:connect_do/screens/auth/register/register_screen.dart';
import 'package:connect_do/utils/academic_options.dart';

void main() {
  group('AcademicOptions.universityFromEmail', () {
    test('deduce la universidad por el dominio', () {
      expect(
        AcademicOptions.universityFromEmail('ana@mail.utec.edu.sv'),
        'UTEC',
      );
      expect(AcademicOptions.universityFromEmail('LUIS@UNAB.EDU.SV'), 'UNAB');
      expect(AcademicOptions.universityFromEmail('x@uma.edu.sv'), 'UMA');
      expect(AcademicOptions.universityFromEmail('x@ues.edu.sv'), 'UES');
      expect(
        AcademicOptions.universityFromEmail('x@catolica.edu.sv'),
        'UNICAES',
      );
      // UPES es la Politécnica, la Pedagógica es UPED.
      expect(AcademicOptions.universityFromEmail('x@upes.edu.sv'), 'UPES');
      expect(
        AcademicOptions.universityFromEmail('x@pedagogica.edu.sv'),
        'UPED',
      );
    });

    test('no adivina con dominios desconocidos o correos incompletos', () {
      expect(AcademicOptions.universityFromEmail('a@gmail.com'), isNull);
      expect(AcademicOptions.universityFromEmail('a@puma.com'), isNull);
      expect(AcademicOptions.universityFromEmail('utec.edu.sv'), isNull);
      expect(AcademicOptions.universityFromEmail('a@'), isNull);
    });
  });

  group('AcademicOptions catálogo', () {
    test('acrónimos únicos y todos con nombre', () {
      final acronyms = AcademicOptions.universities;
      expect(acronyms.toSet().length, acronyms.length);
      expect(acronyms, containsAll(['UES', 'UCA', 'UTEC', 'UFG', 'UDB']));
    });

    test('convierte los valores del registro anterior al acrónimo', () {
      expect(
        AcademicOptions.normalizeUniversity('Universidad Técnologica'),
        'UTEC',
      );
      expect(
        AcademicOptions.normalizeUniversity('Universidad Ándres Bello'),
        'UNAB',
      );
      expect(AcademicOptions.normalizeUniversity('uca'), 'UCA');
      expect(AcademicOptions.normalizeUniversity(''), isNull);
    });

    test('etiqueta con acrónimo y nombre', () {
      expect(
        AcademicOptions.universityLabel('UTEC'),
        'UTEC · Universidad Tecnológica de El Salvador',
      );
    });
  });

  group('ProfileCompletion', () {
    test('perfil recién creado está incompleto', () {
      expect(ProfileCompletion.percent({'email': 'a@b.com'}), 0);
    });

    test('perfil con todo lleno está al 100%', () {
      final user = {
        'university': 'UTEC',
        'career': 'Diseño',
        'level': 'Postgrado',
        'description': 'Hola',
        'skills': ['Figma'],
        'phone': '+50371234567',
        'profile_image_base64': 'abc',
        'cv_file_name': 'cv.pdf',
      };
      expect(ProfileCompletion.percent(user), 100);
      expect(ProfileCompletion.isComplete(user), isTrue);
    });

    test('lista de habilidades vacía no cuenta', () {
      expect(
        ProfileCompletion.percent({'university': 'X', 'skills': <String>[]}),
        13,
      );
    });
  });

  testWidgets('el registro pide solo 4 campos y valida la contraseña', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.text('Regístrate con Google'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ana');
    await tester.enterText(fields.at(1), 'López');
    await tester.enterText(fields.at(2), 'ana@mail.utec.edu.sv');
    await tester.enterText(fields.at(3), 'corta');
    await tester.pump();

    // Universidad deducida del correo.
    expect(
      find.text('UTEC · Universidad Tecnológica de El Salvador'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    // Errores en línea: falta nada salvo la contraseña corta.
    expect(find.text('Usa al menos 8 caracteres.'), findsOneWidget);
    expect(find.text('Escribe tu apellido.'), findsNothing);
  });
}
