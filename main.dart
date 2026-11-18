import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'folder_colors.dart';
import 'folder_service.dart';

void main() => runApp(const FolderColorizerApp());

class FolderColorizerApp extends StatelessWidget {
  const FolderColorizerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Folder Colorizer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF4F6FA),
          colorSchemeSeed: const Color(0xFF3B82F6),
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _service = FolderService();
  final _pathCtrl = TextEditingController();
  Map<String, int> _saved = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final m = await FolderRegistry.load();
    if (mounted) setState(() => _saved = m);
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _browse() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) setState(() => _pathCtrl.text = dir);
  }

  Future<void> _apply(FolderColor c) async {
    final path = _pathCtrl.text.trim();
    if (path.isEmpty) return _msg('Escolha uma pasta primeiro.');
    try {
      await _service.apply(path, c);
      await _reload();
      _msg('Pasta pintada de ${c.name}.');
    } catch (e) {
      _msg('Erro: $e');
    }
  }

  Future<void> _restore() async {
    final path = _pathCtrl.text.trim();
    if (path.isEmpty) return _msg('Escolha uma pasta primeiro.');
    try {
      await _service.restore(path);
      await _reload();
      _msg('Ícone padrão restaurado.');
    } catch (e) {
      _msg('Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            decoration: const BoxDecoration(
              color: Color(0xFF151F35),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Folder Colorizer',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('Give important folders a color you can spot instantly.',
                  style: TextStyle(color: Color(0xFFCBD5E1))),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const _Label('FOLDER'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _pathCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _browse, child: const Text('Browse...')),
              ]),
              const SizedBox(height: 24),
              const _Label('CHOOSE A COLOR'),
              GridView.extent(
                maxCrossAxisExtent: 110,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: [
                  for (final c in folderColors) _ColorTile(c, onTap: () => _apply(c)),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                    onPressed: _restore, child: const Text('Restore default icon')),
              ),
              if (_saved.isNotEmpty) ...[
                const SizedBox(height: 28),
                const _Label('COLORED FOLDERS'),
                for (final e in _saved.entries)
                  ListTile(
                    leading: Icon(Icons.folder, size: 36, color: Color(e.value)),
                    title: Text(e.key.split(RegExp(r'[\\/]')).last),
                    subtitle: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => setState(() => _pathCtrl.text = e.key),
                  ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class _ColorTile extends StatelessWidget {
  final FolderColor c;
  final VoidCallback onTap;
  const _ColorTile(this.c, {required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.color.withOpacity(.5), width: 2),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.folder, size: 34, color: c.color),
            const SizedBox(height: 6),
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      );
}
