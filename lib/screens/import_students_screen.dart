import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/student.dart';
import '../providers/student_provider.dart';

/// Screen for importing students from Excel file
class ImportStudentsScreen extends ConsumerStatefulWidget {
  const ImportStudentsScreen({super.key});

  @override
  ConsumerState<ImportStudentsScreen> createState() => _ImportStudentsScreenState();
}

class _ImportStudentsScreenState extends ConsumerState<ImportStudentsScreen> {
  bool _isLoading = false;
  List<Student>? _previewStudents;
  List<String>? _errors;
  Map<String, List<int>>? _duplicates;
  String? _filePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد الطلاب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showInstructions,
            tooltip: 'إرشادات',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _previewStudents != null
              ? _buildPreview()
              : _buildInitialState(),
    );
  }

  Widget _buildInitialState() {
    final students = ref.watch(studentsProvider);
    final studentCount = students.value?.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current students count
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.people, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    '$studentCount',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Students in Database'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Import button
          ElevatedButton.icon(
            onPressed: _pickExcelFile,
            icon: const Icon(Icons.upload_file),
            label: const Text('Select Excel File'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16.0),
            ),
          ),
          const SizedBox(height: 12),

          // Download sample button
          OutlinedButton.icon(
            onPressed: _downloadSampleFile,
            icon: const Icon(Icons.download),
            label: const Text('Download Sample Template'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16.0),
            ),
          ),
          const SizedBox(height: 24),

          // Instructions
          const Text(
            'Instructions:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('1. Prepare an Excel file (.xlsx) with the following columns:'),
                  SizedBox(height: 4),
                  Text('   • student_id (optional, numeric)'),
                  Text('   • student_name (required, text)'),
                  Text('   • code_value (required, unique text)'),
                  Text('   • code_type (optional: "qr" or "barcode")'),
                  SizedBox(height: 12),
                  Text('2. Make sure there are no duplicate code_value entries'),
                  SizedBox(height: 12),
                  Text('3. The first row should contain column headers'),
                  SizedBox(height: 12),
                  Text('4. Select the file and preview before importing'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Delete all students option (with confirmation)
          if (studentCount > 0)
            OutlinedButton.icon(
              onPressed: _showDeleteAllDialog,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Delete All Students',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16.0),
                side: const BorderSide(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final hasErrors = (_errors?.isNotEmpty ?? false) || (_duplicates?.isNotEmpty ?? false);

    return Column(
      children: [
        // Header with error/success message
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          color: hasErrors ? Colors.red.shade50 : Colors.green.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasErrors ? 'Validation Errors Found' : 'Ready to Import',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: hasErrors ? Colors.red.shade900 : Colors.green.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasErrors
                    ? 'Please fix the errors before importing'
                    : '${_previewStudents!.length} students ready to import',
                style: TextStyle(
                  color: hasErrors ? Colors.red.shade700 : Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),

        // Errors list
        if (_errors != null && _errors!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.red.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Errors:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                ..._errors!.map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text('• $error', style: const TextStyle(color: Colors.red)),
                    )),
              ],
            ),
          ),
        ],

        // Duplicates list
        if (_duplicates != null && _duplicates!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.orange.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Duplicate Code Values:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                ..._duplicates!.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        '• "${entry.key}" appears in rows: ${entry.value.join(", ")}',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    )),
              ],
            ),
          ),
        ],

        // Preview list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _previewStudents!.length,
            itemBuilder: (context, index) {
              final student = _previewStudents![index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(student.studentName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (student.studentId != null)
                        Text('ID: ${student.studentId}'),
                      Text('Code: ${student.codeValue}'),
                      if (student.codeType != null)
                        Text('Type: ${student.codeType}'),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelImport,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: hasErrors ? null : _confirmImport,
                  child: const Text('Import Students'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
          _filePath = result.files.single.path;
        });

        final excelService = ref.read(excelServiceProvider);
        final importResult = await excelService.importStudentsFromExcel(_filePath!);

        setState(() {
          _isLoading = false;
          _previewStudents = importResult.students;
          _errors = importResult.errors;
          _duplicates = importResult.duplicates;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmImport() async {
    if (_previewStudents == null || _previewStudents!.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final success = await ref.read(studentsProvider.notifier).addStudents(_previewStudents!);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${_previewStudents!.length} students'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to import students. Some code values may already exist.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelImport() {
    setState(() {
      _previewStudents = null;
      _errors = null;
      _duplicates = null;
      _filePath = null;
    });
  }

  Future<void> _downloadSampleFile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final excelService = ref.read(excelServiceProvider);
      final filePath = await excelService.createSampleExcelFile();

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sample file saved to:\n$filePath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create sample file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Instructions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Excel File Format:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Required columns:'),
              Text('• student_name: Student\'s full name'),
              Text('• code_value: Unique QR or barcode value'),
              SizedBox(height: 8),
              Text('Optional columns:'),
              Text('• student_id: Numeric student identifier'),
              Text('• code_type: "qr" or "barcode"'),
              SizedBox(height: 12),
              Text(
                'Important Notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• First row must contain column headers'),
              Text('• code_value must be unique (no duplicates)'),
              Text('• Empty rows will be skipped'),
              Text('• Download sample template for reference'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Students'),
        content: const Text(
          'Are you sure you want to delete ALL students from the database? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });

              final success = await ref.read(studentsProvider.notifier).deleteAllStudents();

              setState(() {
                _isLoading = false;
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'All students deleted successfully'
                          : 'Failed to delete students',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}
