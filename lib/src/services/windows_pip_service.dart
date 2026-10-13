import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Service Picture-in-Picture (PiP) natif pour Windows.
///
/// Permet de détacher la fenêtre Terebi dans un format compact Always-on-Top
/// épinglé au-dessus des autres fenêtres de l'OS.
class WindowsPipService {
  static bool get isSupported => Platform.isWindows;

  static DynamicLibrary? _user32;
  static DynamicLibrary? _kernel32;

  static DynamicLibrary get user32 =>
      _user32 ??= DynamicLibrary.open('user32.dll');
  static DynamicLibrary get kernel32 =>
      _kernel32 ??= DynamicLibrary.open('kernel32.dll');

  static int? _savedX;
  static int? _savedY;
  static int? _savedWidth;
  static int? _savedHeight;
  static bool _isPip = false;

  static bool get isPip => _isPip;

  static int _findWindowHwnd() {
    if (!Platform.isWindows) return 0;
    try {
      final getForeground = user32.lookupFunction<
          IntPtr Function(),
          int Function()>('GetForegroundWindow');
      final getProcessId = kernel32.lookupFunction<
          Uint32 Function(),
          int Function()>('GetCurrentProcessId');
      final getWindowThreadProcessId = user32.lookupFunction<
          Uint32 Function(IntPtr, Pointer<Uint32>),
          int Function(int, Pointer<Uint32>)>('GetWindowThreadProcessId');

      final currentPid = getProcessId();
      final fg = getForeground();

      final pidPtr = calloc<Uint32>();
      getWindowThreadProcessId(fg, pidPtr);
      final fgPid = pidPtr.value;
      calloc.free(pidPtr);

      if (fg != 0 && fgPid == currentPid) {
        return fg;
      }

      // Repli par FindWindowW (classe de fenêtre Flutter ou titre)
      final findWindow = user32.lookupFunction<
          IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
          int Function(Pointer<Utf16>, Pointer<Utf16>)>('FindWindowW');

      final cls = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
      final hwndCls = findWindow(cls, nullptr);
      calloc.free(cls);
      if (hwndCls != 0) return hwndCls;

      for (final name in ['terebi', 'Terebi']) {
        final title = name.toNativeUtf16();
        final hwnd = findWindow(nullptr, title);
        calloc.free(title);
        if (hwnd != 0) return hwnd;
      }
    } catch (_) {}
    return 0;
  }

  /// Active le mode PiP (fenêtre Always-on-Top en bas à droite).
  static bool enterPip({int width = 460, int height = 260}) {
    if (!Platform.isWindows) return false;
    final hwnd = _findWindowHwnd();
    if (hwnd == 0) return false;

    try {
      final getWindowRect = user32.lookupFunction<
          Int32 Function(IntPtr, Pointer<Int32>),
          int Function(int, Pointer<Int32>)>('GetWindowRect');
      final getSystemMetrics = user32.lookupFunction<
          Int32 Function(Int32),
          int Function(int)>('GetSystemMetrics');
      final setWindowPos = user32.lookupFunction<
          Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
          int Function(int, int, int, int, int, int, int)>('SetWindowPos');

      // Mémorise la géométrie précédente
      final rect = calloc<Int32>(4);
      if (getWindowRect(hwnd, rect) != 0) {
        _savedX = rect[0];
        _savedY = rect[1];
        _savedWidth = rect[2] - rect[0];
        _savedHeight = rect[3] - rect[1];
      }
      calloc.free(rect);

      // Détermine la résolution de l'écran principal
      final screenW = getSystemMetrics(0); // SM_CXSCREEN
      final screenH = getSystemMetrics(1); // SM_CYSCREEN

      final x = (screenW - width - 24).clamp(0, screenW);
      final y = (screenH - height - 60).clamp(0, screenH);

      // HWND_TOPMOST = -1, SWP_SHOWWINDOW = 0x0040
      const hwndTopmost = -1;
      const swpShowWindow = 0x0040;

      setWindowPos(hwnd, hwndTopmost, x, y, width, height, swpShowWindow);
      _isPip = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quitte le mode PiP et restaure la taille normale de la fenêtre.
  static bool exitPip() {
    if (!Platform.isWindows) return false;
    final hwnd = _findWindowHwnd();
    if (hwnd == 0) return false;

    try {
      final setWindowPos = user32.lookupFunction<
          Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
          int Function(int, int, int, int, int, int, int)>('SetWindowPos');

      const hwndNoTopmost = -2;
      const swpShowWindow = 0x0040;

      final x = _savedX ?? 100;
      final y = _savedY ?? 100;
      final w = _savedWidth ?? 1280;
      final h = _savedHeight ?? 720;

      setWindowPos(hwnd, hwndNoTopmost, x, y, w, h, swpShowWindow);
      _isPip = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bascule entre le mode PiP et la fenêtre normale.
  static bool togglePip() {
    if (_isPip) {
      return exitPip();
    } else {
      return enterPip();
    }
  }
}
