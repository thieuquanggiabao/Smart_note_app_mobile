import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NoteApp());
}

class Note {
  String id;
  String title;
  String content;
  List<String> images;
  List<String> signatures;
  DateTime createdAt;
  DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.images = const [],
    this.signatures = const [],
    required this.createdAt,
    required this.updatedAt,
  });
}

class NoteApp extends StatelessWidget {
  const NoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Note',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _allNotes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshNotes();
  }

  Future _refreshNotes() async {
    setState(() => _isLoading = true);
    _allNotes = await DatabaseHelper.instance.readAllNotes();
    _filterNotes(_searchController.text);
    setState(() => _isLoading = false);
  }

  void _filterNotes(String query) {
    setState(() {
      _filteredNotes = _allNotes.where((note) {
        final titleLower = note.title.toLowerCase();
        final searchLower = query.toLowerCase();
        final dateString = DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt);
        return titleLower.contains(searchLower) || dateString.contains(searchLower);
      }).toList();
    });
  }

  void _addOrUpdateNote(Note? note) async {
    final result = await Navigator.of(context).push<Note>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => NoteEditScreen(note: note),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.ease;
          var trailer = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(trailer), child: child);
        },
      ),
    );

    // Xử lý lưu sau khi Auto-save trả về kết quả từ màn hình Edit
    if (result != null) {
      if (note == null) {
        await DatabaseHelper.instance.create(result);
      } else {
        await DatabaseHelper.instance.update(result);
      }
      _refreshNotes();
    }
  }

  void _deleteNote(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa ghi chú này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.delete(id);
      _refreshNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Note - Thiều Quang Gia Bảo - 2351160507'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm tiêu đề hoặc ngày...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withAlpha(128),
              ),
              onChanged: _filterNotes,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredNotes.isEmpty
              ? const Center(child: Text('Bạn chưa có ghi chú nào, hãy tạo mới nhé!'))
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: MasonryGridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      return _buildNoteCard(note);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrUpdateNote(null),
        tooltip: 'Thêm ghi chú',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(note.createdAt);
    return GestureDetector(
      onTap: () => _addOrUpdateNote(note),
      onLongPress: () => _deleteNote(note.id),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.images.isNotEmpty || note.signatures.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(note.images.isNotEmpty ? note.images.first : note.signatures.first),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Text(
                note.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                note.content,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  dateFormatted,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteEditScreen extends StatefulWidget {
  final Note? note;
  const NoteEditScreen({super.key, this.note});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<String> _images = [];
  List<String> _signatures = [];
  final ImagePicker _picker = ImagePicker();
  late SignatureController _signatureController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _images = List.from(widget.note?.images ?? []);
    _signatures = List.from(widget.note?.signatures ?? []);
    _signatureController = SignatureController(penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final List<XFile> pickedImages = await _picker.pickMultiImage();
    if (pickedImages.isNotEmpty) {
      setState(() => _images.addAll(pickedImages.map((e) => e.path)));
    }
  }

  Future<void> _showSignaturePad() async {
    _signatureController.clear();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Viết tay/Ký tên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.grey)), child: Signature(controller: _signatureController, backgroundColor: Colors.white))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => _signatureController.clear()),
                  IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () async {
                    if (_signatureController.isNotEmpty) {
                      final Uint8List? data = await _signatureController.toPngBytes();
                      if (data != null) {
                        final directory = await getApplicationDocumentsDirectory();
                        final path = '${directory.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png';
                        await File(path).writeAsBytes(data);
                        setState(() => _signatures.add(path));
                        if (mounted) Navigator.pop(context);
                      }
                    }
                  }),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  void _autoSaveAndPop() {
    // Nếu tiêu đề và nội dung đều trống thì không cần lưu
    if (_titleController.text.trim().isEmpty && _contentController.text.trim().isEmpty && _images.isEmpty && _signatures.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final now = DateTime.now();
    final note = Note(
      id: widget.note?.id ?? now.toString(),
      title: _titleController.text.trim().isEmpty ? 'Ghi chú không tiêu đề' : _titleController.text.trim(),
      content: _contentController.text.trim(),
      images: _images,
      signatures: _signatures,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Ngăn chặn pop mặc định để xử lý logic Auto-save
      onPopInvoked: (didPop) {
        if (didPop) return;
        _autoSaveAndPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'Thêm ghi chú' : 'Sửa ghi chú'),
          // Sử dụng leading IconButton để bắt sự kiện nhấn nút Back trên AppBar
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _autoSaveAndPop,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (widget.note != null) ...[
                  Align(alignment: Alignment.centerRight, child: Text('Sửa lần cuối: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.note!.updatedAt)}', style: const TextStyle(fontSize: 10, color: Colors.grey))),
                  const SizedBox(height: 8),
                ],
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Tiêu đề', border: OutlineInputBorder()), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (_images.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text('Hình ảnh:', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _images.length, itemBuilder: (context, index) => _buildFileItem(_images[index], () => setState(() => _images.removeAt(index))))),
                  const SizedBox(height: 16),
                ],
                if (_signatures.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text('Bản viết tay:', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _signatures.length, itemBuilder: (context, index) => _buildFileItem(_signatures[index], () => setState(() => _signatures.removeAt(index))))),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.add_a_photo), label: const Text('Ảnh')),
                    OutlinedButton.icon(onPressed: _showSignaturePad, icon: const Icon(Icons.gesture), label: const Text('Viết tay')),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(controller: _contentController, decoration: const InputDecoration(labelText: 'Nội dung', border: OutlineInputBorder(), alignLabelWithHint: true), maxLines: 10, minLines: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(String path, VoidCallback onRemove) {
    return Stack(
      children: [
        Container(margin: const EdgeInsets.only(right: 12), width: 120, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300), image: DecorationImage(image: FileImage(File(path)), fit: BoxFit.cover))),
        Positioned(right: 4, top: 4, child: GestureDetector(onTap: onRemove, child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 16)))),
      ],
    );
  }
}
