import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'folder_colors.dart';

/// Registro das pastas coloridas (usado nas duas plataformas para a lista do app).
class FolderRegistry {
  static const _key = 'folders';

  static Future<Map<String, int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));
  }

  static Future<void> _save(Map<String, int> m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(m));
  }

  static Future<void> set(String path, int argb) async {
    final m = await load();
    m[path] = argb;
    await _save(m);
  }

  static Future<void> remove(String path) async {
    final m = await load();
    m.remove(path);
    await _save(m);
  }
}

abstract class FolderService {
  Future<void> apply(String path, FolderColor color);
  Future<void> restore(String path);

  factory FolderService() =>
      Platform.isWindows ? WindowsFolderService() : AndroidFolderService();
}

/// Android: não existe como mudar o ícone no sistema de arquivos,
/// então a cor fica guardada no app.
class AndroidFolderService implements FolderService {
  @override
  Future<void> apply(String path, FolderColor color) =>
      FolderRegistry.set(path, color.color.value);

  @override
  Future<void> restore(String path) => FolderRegistry.remove(path);
}

/// Windows 11: muda o ícone de verdade via desktop.ini + .ico dentro da pasta.
class WindowsFolderService implements FolderService {
  static const _icoName = '.folder_colorizer.ico';

  Uint8List _buildIco(int argb) {
    final im = img.Image(width: 256, height: 256, numChannels: 4);
    final c = img.ColorRgba8((argb >> 16) & 255, (argb >> 8) & 255, argb & 255, 255);
    img.fillRect(im, x1: 24, y1: 44, x2: 120, y2: 100, color: c, radius: 14); // aba
    img.fillRect(im, x1: 24, y1: 72, x2: 232, y2: 208, color: c, radius: 18); // corpo
    final png = img.encodePng(im);

    final h = ByteData(22);
    h.setUint16(2, 1, Endian.little); // tipo: ícone
    h.setUint16(4, 1, Endian.little); // 1 imagem
    h.setUint16(10, 1, Endian.little); // planes
    h.setUint16(12, 32, Endian.little); // bpp
    h.setUint32(14, png.length, Endian.little);
    h.setUint32(18, 22, Endian.little); // offset
    return (BytesBuilder()
          ..add(h.buffer.asUint8List())
          ..add(png))
        .toBytes();
  }

  Future<void> _attr(List<String> args) => Process.run('attrib', args);

  Future<void> _refresh() async {
    try {
      await Process.run('ie4uinit.exe', ['-show']);
    } catch (_) {}
  }

  @override
  Future<void> apply(String path, FolderColor color) async {
    final ico = File(p.join(path, _icoName));
    final ini = File(p.join(path, 'desktop.ini'));
    for (final f in [ico, ini]) {
      if (await f.exists()) await _attr(['-h', '-s', f.path]);
    }
    await ico.writeAsBytes(_buildIco(color.color.value));
    await ini.writeAsString(
        '[.ShellClassInfo]\r\nIconResource=$_icoName,0\r\n');
    await _attr(['+h', ico.path]);
    await _attr(['+h', '+s', ini.path]);
    await _attr(['+r', path]); // faz o Windows ler o desktop.ini
    await FolderRegistry.set(path, color.color.value);
    await _refresh();
  }

  @override
  Future<void> restore(String path) async {
    for (final name in [_icoName, 'desktop.ini']) {
      final f = File(p.join(path, name));
      if (await f.exists()) {
        await _attr(['-h', '-s', f.path]);
        await f.delete();
      }
    }
    await _attr(['-r', path]);
    await FolderRegistry.remove(path);
    await _refresh();
  }
}
