import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../providers/session_provider.dart';
import '../widgets/session_list_tile.dart';

/// Screen listing every saved session, with search and date filtering
class AllSessionsScreen extends ConsumerStatefulWidget {
  const AllSessionsScreen({super.key});

  @override
  ConsumerState<AllSessionsScreen> createState() => _AllSessionsScreenState();
}

class _AllSessionsScreenState extends ConsumerState<AllSessionsScreen> {
  static const List<String> _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('كل الجلسات'),
        actions: [
          IconButton(
            icon: Icon(
              _dateRange == null ? Icons.date_range_outlined : Icons.date_range,
            ),
            color: _dateRange == null
                ? null
                : Theme.of(context).colorScheme.primary,
            onPressed: () => _pickDateRange(sessions.value ?? []),
            tooltip: 'تصفية حسب التاريخ',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and active filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث باسم المقرر',
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
          ),
          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: InputChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
                  ),
                  onDeleted: () => setState(() => _dateRange = null),
                ),
              ),
            ),

          // Sessions list
          Expanded(
            child: sessions.when(
              data: (sessionList) => _buildList(sessionList),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('خطأ: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Session> sessionList) {
    if (sessionList.isEmpty) {
      return const Center(child: Text('لا توجد جلسات بعد'));
    }

    final filtered = _applyFilters(sessionList);
    if (filtered.isEmpty) {
      return const Center(child: Text('لا توجد جلسات مطابقة'));
    }

    // Flatten into month headers followed by that month's sessions
    // (sessions arrive newest first from the database)
    final items = <Object>[];
    String? currentMonth;
    for (final session in filtered) {
      final month = _formatMonth(session.timestampStart);
      if (month != currentMonth) {
        items.add(month);
        currentMonth = month;
      }
      items.add(session);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(sessionsProvider.notifier).loadSessions(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is String) {
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            );
          }
          final session = item as Session;
          return SessionListTile(
            key: ValueKey('all_session_${session.id}'),
            session: session,
          );
        },
      ),
    );
  }

  List<Session> _applyFilters(List<Session> sessionList) {
    final query = _query.toLowerCase();
    final range = _dateRange;

    return sessionList.where((session) {
      if (query.isNotEmpty &&
          !session.courseName.toLowerCase().contains(query)) {
        return false;
      }
      if (range != null) {
        final start = session.timestampStart;
        // Include the whole last day of the range
        final endExclusive = DateTime(
          range.end.year,
          range.end.month,
          range.end.day + 1,
        );
        if (start.isBefore(range.start) || !start.isBefore(endExclusive)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _pickDateRange(List<Session> sessionList) async {
    final now = DateTime.now();
    final earliest = sessionList.isEmpty
        ? DateTime(now.year - 1)
        : sessionList
            .map((session) => session.timestampStart)
            .reduce((a, b) => a.isBefore(b) ? a : b);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _dateRange,
      helpText: 'اختر الفترة',
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  String _formatMonth(DateTime dateTime) {
    return '${_arabicMonths[dateTime.month - 1]} ${dateTime.year}';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
