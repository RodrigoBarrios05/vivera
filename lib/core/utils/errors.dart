import 'package:supabase_flutter/supabase_flutter.dart';

String readableError(Object error) {
  if (error is PostgrestException) {
    return error.message;
  }

  if (error is AuthException) {
    return _translateAuthMessage(error.message);
  }

  final raw = error.toString();

  if (raw.contains('SocketException') ||
      raw.contains('ClientException') ||
      raw.contains('Failed host lookup') ||
      raw.contains('Connection refused') ||
      raw.contains('Network is unreachable')) {
    return 'No se pudo conectar. Revisá tu conexión a internet.';
  }

  if (raw.contains('JWT expired')) {
    return 'Tu sesión expiró. Volvé a iniciar sesión.';
  }

  return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
}

String _translateAuthMessage(String message) {
  final normalized = message.toLowerCase();

  if (normalized.contains('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (normalized.contains('email not confirmed')) {
    return 'Confirmá tu correo antes de iniciar sesión.';
  }
  if (normalized.contains('user already registered')) {
    return 'Ya existe una cuenta con ese correo.';
  }
  if (normalized.contains('password should be at least')) {
    return 'La contraseña debe tener al menos 6 caracteres.';
  }
  if (normalized.contains('for security purposes')) {
    return 'Esperá unos segundos antes de volver a intentar.';
  }
  if (normalized.contains('invalid email')) {
    return 'El correo no es válido.';
  }
  if (normalized.contains('signup is disabled')) {
    return 'El registro está deshabilitado.';
  }
  if (normalized.contains('rate limit')) {
    return 'Demasiados intentos. Esperá un momento.';
  }

  return message;
}
