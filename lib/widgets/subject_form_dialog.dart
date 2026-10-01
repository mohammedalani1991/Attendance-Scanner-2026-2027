import 'package:flutter/material.dart';
import '../models/subject.dart';

/// Ask for a subject's name and optional code.
/// Pass [initial] to edit an existing subject. Returns null if cancelled.
Future<({String name, String? code})?> showSubjectFormDialog(
  BuildContext context, {
  Subject? initial,
}) {
  return showDialog<({String name, String? code})>(
    context: context,
    builder: (context) => _SubjectFormDialog(initial: initial),
  );
}

class _SubjectFormDialog extends StatefulWidget {
  final Subject? initial;

  const _SubjectFormDialog({this.initial});

  @override
  State<_SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends State<_SubjectFormDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initial?.name);
  late final TextEditingController _codeController =
      TextEditingController(text: widget.initial?.code);
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _nameError = 'الرجاء إدخال اسم المادة (حرفان على الأقل)');
      return;
    }
    final code = _codeController.text.trim();
    Navigator.pop(context, (name: name, code: code.isEmpty ? null : code));
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return AlertDialog(
      title: Text(isEditing ? 'تعديل المادة' : 'إضافة مادة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'اسم المادة',
              hintText: 'مثال: علوم الحاسب',
              errorText: _nameError,
            ),
            autofocus: true,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'رمز المادة (اختياري)',
              hintText: 'مثال: CS101',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? 'حفظ' : 'إضافة'),
        ),
      ],
    );
  }
}
