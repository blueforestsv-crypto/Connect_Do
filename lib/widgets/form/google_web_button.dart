// El botón oficial de Google solo existe en web. En Android/iOS se usa el
// stub y el botón propio de la app (que abre el selector de cuentas).
export 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart';
