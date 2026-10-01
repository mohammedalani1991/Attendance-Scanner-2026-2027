import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/student.dart';
import '../providers/student_provider.dart';

/// Students screen: the imported student list, importing from Excel, and the template
class ImportStudentsScreen extends ConsumerStatefulWidget {
  const ImportStudentsScreen({super.key});

  @override
  ConsumerState<ImportStudentsScreen> createState() => _ImportStudentsScreenState();
}

class _ImportStudentsScreenState extends ConsumerState<ImportStudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<Student>? _previewStudents;
  List<String>? _errors;
  Map<String, List<int>>? _duplicates;
  String _query = '';

  bool get _isPreviewing => _previewStudents != null;
  bool get _hasErrors =>
      (_errors?.isNotEmpty ?? false) || (_duplicates?.isNotEmpty ?? false);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentCount = ref.watch(studentsProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPreviewing ? 'معاينة الاستيراد' : 'الطلاب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showInstructions,
            tooltip: 'تنسيق الملف',
          ),
          if (!_isPreviewing && studentCount > 0)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete_all') _showDeleteAllDialog();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete_all',
                  child: ListTile(
                    leading: Icon(Icons.delete_sweep_outlined, color: Colors.red),
                    title: Text(
                      'حذف جميع الطلاب',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isPreviewing
              ? _buildPreview()
              : _buildStudentList(),
      bottomNavigationBar: _isPreviewing && !_isLoading ? _buildPreviewActions() : null,
    );
  }

  // ==================== STUDENT LIST ====================

  Widget _buildStudentList() {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final students = ref.watch(studentsProvider).value ?? const <Student>[];

    final query = _query.toLowerCase();
    final filtered = query.isEmpty
        ? students
        : students.where((student) {
            return student.studentName.toLowerCase().contains(query) ||
                (student.studentId ?? '').contains(query) ||
                student.codeValue.toLowerCase().contains(query);
          }).toList();

    // Header widgets followed by one row per student
    final header = <Widget>[
      _buildImportCard(),
      const SizedBox(height: 24),
      if (students.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.groups_outlined, size: 64, color: colors.outline),
              const SizedBox(height: 12),
              Text(
                'لا يوجد طلاب بعد',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'استورد ملف Excel لإضافة قائمة الطلاب.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        )
      else ...[
        Row(
          children: [
            Text(
              'قائمة الطلاب',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            _CountBadge(count: students.length),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'ابحث بالاسم أو الرقم أو الرمز',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
          onChanged: (value) => setState(() => _query = value.trim()),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('لا توجد نتائج مطابقة')),
          ),
      ],
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: header.length + (students.isEmpty ? 0 : filtered.length),
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];
        return _StudentTile(student: filtered[index - header.length]);
      },
    );
  }

  Widget _buildImportCard() {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer.withAlpha(120),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: colors.primary),
                const SizedBox(width: 10),
                Text(
                  'استيراد من Excel',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ملف ‎.xlsx يحتوي على الأعمدة: student_name و code_value (إلزامية)، '
              'و student_id و code_type (اختيارية). ستتمكن من المعاينة قبل الحفظ.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _pickExcelFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('اختيار ملف'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _shareSampleFile,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('نموذج'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== IMPORT PREVIEW ====================

  Widget _buildPreview() {
    final colors = Theme.of(context).colorScheme;
    final students = _previewStudents!;
    final hasErrors = _hasErrors;
    final statusColor = hasErrors ? colors.error : Colors.green;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Overall status
        Card(
          margin: EdgeInsets.zero,
          color: statusColor.withAlpha(25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: statusColor.withAlpha(120)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  hasErrors ? Icons.error_outline : Icons.check_circle_outline,
                  color: statusColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasErrors ? 'توجد أخطاء في الملف' : 'الملف جاهز للاستيراد',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasErrors
                            ? 'صحّح الأخطاء أدناه في الملف ثم أعد اختياره.'
                            : '${students.length} طالب جاهز للحفظ.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Row errors
        if (_errors?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          _IssueList(
            title: 'أخطاء في الصفوف (${_errors!.length})',
            color: colors.error,
            items: _errors!,
          ),
        ],

        // Duplicate codes inside the file
        if (_duplicates?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          _IssueList(
            title: 'رموز مكررة (${_duplicates!.length})',
            color: Colors.orange.shade800,
            items: _duplicates!.entries
                .map((entry) =>
                    '"${entry.key}" مكرر في الصفوف: ${entry.value.join("، ")}')
                .toList(),
          ),
        ],

        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'الطلاب في الملف',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            _CountBadge(count: students.length),
          ],
        ),
        const SizedBox(height: 12),
        for (final student in students) _StudentTile(student: student),
      ],
    );
  }

  Widget _buildPreviewActions() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelImport,
                child: const Text('إلغاء'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _hasErrors || _previewStudents!.isEmpty
                    ? null
                    : _confirmImport,
                icon: const Icon(Icons.save_alt),
                label: Text('استيراد ${_previewStudents!.length} طالب'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      final path = result?.files.single.path;
      if (path == null) return;

      setState(() => _isLoading = true);
      final importResult =
          await ref.read(excelServiceProvider).importStudentsFromExcel(path);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _previewStudents = importResult.students;
        _errors = importResult.errors;
        _duplicates = importResult.duplicates;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر قراءة الملف: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmImport() async {
    final students = _previewStudents;
    if (students == null || students.isEmpty) return;

    setState(() => _isLoading = true);
    final success = await ref.read(studentsProvider.notifier).addStudents(students);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _cancelImport();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم استيراد ${students.length} طالب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'فشل الاستيراد. قد تكون بعض الرموز (code_value) موجودة مسبقاً لطلاب آخرين.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelImport() {
    setState(() {
      _previewStudents = null;
      _errors = null;
      _duplicates = null;
    });
  }

  /// Build the template and open the share sheet (the app folder isn't reachable by users)
  Future<void> _shareSampleFile() async {
    try {
      final filePath = await ref.read(excelServiceProvider).createSampleExcelFile();
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'نموذج استيراد الطلاب',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إنشاء النموذج: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنسيق ملف الطلاب'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الصف الأول يحتوي على أسماء الأعمدة:'),
              SizedBox(height: 12),
              _ColumnHelp(
                name: 'student_name',
                description: 'اسم الطالب',
                isRequired: true,
              ),
              _ColumnHelp(
                name: 'code_value',
                description: 'قيمة رمز QR أو الباركود الموجودة على بطاقة الطالب (فريدة)',
                isRequired: true,
              ),
              _ColumnHelp(
                name: 'student_id',
                description: 'الرقم الجامعي (أرقام فقط)',
                isRequired: false,
              ),
              _ColumnHelp(
                name: 'code_type',
                description: 'qr أو barcode',
                isRequired: false,
              ),
              SizedBox(height: 12),
              Text('• يتم تجاهل الصفوف الفارغة.'),
              Text('• لا يجوز تكرار code_value.'),
              Text('• اضغط "نموذج" للحصول على ملف جاهز للتعبئة.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف جميع الطلاب'),
        content: const Text(
          'هل أنت متأكد من حذف جميع الطلاب؟ لا يمكن التراجع عن هذا الإجراء.\n\n'
          'سجلات الحضور السابقة تبقى محفوظة في الجلسات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);

              final success =
                  await ref.read(studentsProvider.notifier).deleteAllStudents();
              if (!mounted) return;
              setState(() => _isLoading = false);

              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'تم حذف جميع الطلاب' : 'فشل حذف الطلاب',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
  }
}

/// One student row: initial, name, student number and code
class _StudentTile extends StatelessWidget {
  final Student student;

  const _StudentTile({required this.student});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = student.studentName.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          child: Text(
            name.isEmpty ? '?' : name[0],
            style: TextStyle(
              color: colors.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          [
            if (student.studentId != null && student.studentId!.isNotEmpty)
              'رقم: ${student.studentId}',
            'الرمز: ${student.codeValue}',
          ].join(' • '),
        ),
        trailing: Icon(
          student.codeType == 'barcode' ? Icons.view_week_outlined : Icons.qr_code_2,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Collapsible list of import problems
class _IssueList extends StatelessWidget {
  final String title;
  final Color color;
  final List<String> items;

  const _IssueList({
    required this.title,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: items.length <= 10,
        leading: Icon(Icons.warning_amber_rounded, color: color),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item'),
            ),
        ],
      ),
    );
  }
}

/// One column explanation in the format help dialog
class _ColumnHelp extends StatelessWidget {
  final String name;
  final String description;
  final bool isRequired;

  const _ColumnHelp({
    required this.name,
    required this.description,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isRequired ? colors.primaryContainer : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isRequired ? 'إلزامي' : 'اختياري',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(description, style: TextStyle(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
