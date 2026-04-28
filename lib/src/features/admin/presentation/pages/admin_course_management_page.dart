import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/data_service.dart';
import '../../../../core/theme/app_colors.dart';

class AdminCourseManagementPage extends StatefulWidget {
  const AdminCourseManagementPage({super.key});
  @override
  State<AdminCourseManagementPage> createState() => _AdminCourseManagementPageState();
}

class _AdminCourseManagementPageState extends State<AdminCourseManagementPage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<DataService>(builder: (context, ds, _) {
      if (!ds.isLoaded) return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator()));
      final allCourses = ds.courses;
      final pendingRequests = ds.getPendingCourseRequests();

      return Scaffold(
        backgroundColor: AppColors.background,
        body: LayoutBuilder(builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.menu_book, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                const Expanded(child: Text('Course Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18), label: const Text('Add Course'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => _showCourseDialog(context, ds),
                ),
              ]),
              const SizedBox(height: 8),
              Text('${allCourses.length} courses', style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
              if (pendingRequests.isNotEmpty) ...[
                const SizedBox(height: 20),
                _sectionTitle('Pending Course Requests'),
                const SizedBox(height: 8),
                ...pendingRequests.map((req) => _requestCard(context, ds, req)),
              ],
              const SizedBox(height: 20),
              ...allCourses.map((c) {
                final enrolled = ds.getCourseStudents(c['courseId'] as String? ?? '').length;
                final handlers = ds.getFacultyForCourse(c['courseId'] as String? ?? '');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(c['courseCode'] as String? ?? '', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c['courseName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Text('Faculty: ${c['facultyName'] ?? 'N/A'} | ${c['credits']} credits | Dept: ${ds.getDepartmentCode(c['departmentId'] as String? ?? '')} | $enrolled enrolled', style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                      if (handlers.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 6, children: handlers.map((f) => Chip(
                          label: Text(f['name'] as String? ?? '', style: const TextStyle(fontSize: 11)),
                          backgroundColor: AppColors.background,
                          side: const BorderSide(color: AppColors.border),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )).toList()),
                      ],
                    ])),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      tooltip: 'Edit Course',
                      onPressed: () => _showCourseDialog(context, ds, existing: c),
                    ),
                  ]),
                );
              }),
            ]),
          );
        }),
      );
    });
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark));
  }

  Widget _requestCard(BuildContext context, DataService ds, Map<String, dynamic> req) {
    final sourceCourse = ds.courses.firstWhere((c) => c['courseId'] == req['sourceCourseId'], orElse: () => <String, dynamic>{});
    final assignedFaculty = req['preferredFacultyId'] as String? ?? sourceCourse['facultyId'] as String? ?? '';
    final facultyName = assignedFaculty.isNotEmpty ? ds.getFacultyName(assignedFaculty) : 'Not Selected';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(req['courseName'] as String? ?? sourceCourse['courseName'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 4),
        Text('Target: ${ds.getDepartmentCode(req['targetDepartmentId'] as String? ?? '')} | Requested faculty: $facultyName', style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton(onPressed: () => _approveRequest(context, ds, req), child: const Text('Approve')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () { ds.rejectCourseRequest(req['requestId'] as String? ?? ''); setState(() {}); }, child: const Text('Reject')),
        ]),
      ]),
    );
  }

  void _approveRequest(BuildContext context, DataService ds, Map<String, dynamic> req) {
    final sourceCourse = ds.courses.firstWhere((c) => c['courseId'] == req['sourceCourseId'], orElse: () => <String, dynamic>{});
    final candidates = ds.getFacultyForCourse(req['sourceCourseId'] as String? ?? '');
    final allFaculty = ds.faculty;
    final initialFaculty = (req['preferredFacultyId'] as String?) ?? (sourceCourse['facultyId'] as String?) ?? '';
    String selectedFacultyId = initialFaculty;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Approve Course Request', style: TextStyle(color: AppColors.textDark)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Add ${sourceCourse['courseName'] ?? ''} to ${ds.getDepartmentCode(req['targetDepartmentId'] as String? ?? '')}', style: const TextStyle(color: AppColors.textDark)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedFacultyId.isNotEmpty ? selectedFacultyId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assign Faculty', border: OutlineInputBorder()),
                items: allFaculty.map((f) => DropdownMenuItem(value: f['facultyId'] as String, child: Text('${f['name']} (${ds.getDepartmentCode(f['departmentId'] as String? ?? '')})'))).toList(),
                onChanged: (v) => setS(() => selectedFacultyId = v ?? ''),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text('Current handlers: ${candidates.map((f) => f['name']).join(', ')}', style: const TextStyle(color: AppColors.textLight, fontSize: 12))),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              ds.approveCourseRequest(req['requestId'] as String? ?? '', facultyId: selectedFacultyId.isEmpty ? null : selectedFacultyId);
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course request approved'), backgroundColor: AppColors.secondary));
            },
            child: const Text('Approve'),
          ),
        ],
      );
    }));
  }

  void _showCourseDialog(BuildContext context, DataService ds, {Map<String, dynamic>? existing}) {
    final codeC = TextEditingController(text: existing == null ? '' : existing['courseCode'] as String? ?? '');
    final nameC = TextEditingController(text: existing?['courseName'] as String? ?? '');
    final creditsC = TextEditingController(text: '${existing?['credits'] ?? 3}');
    final semC = TextEditingController(text: '${existing?['semester'] ?? 1}');
    final roomC = TextEditingController(text: existing?['room'] as String? ?? '');
    final schedC = TextEditingController(text: existing?['schedule'] as String? ?? '');
    String? selectedDeptId = existing?['departmentId'] as String?;
    String? selectedFacultyId = existing?['facultyId'] as String?;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) {
      final filteredFaculty = selectedDeptId != null ? ds.getDepartmentFaculty(selectedDeptId!) : ds.faculty;
      return AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(existing == null ? 'Add Course' : 'Edit Course', style: const TextStyle(color: AppColors.textDark)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: codeC, readOnly: existing != null, decoration: const InputDecoration(labelText: 'Course Code', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Course Name', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedDeptId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: ds.departments.map((d) => DropdownMenuItem(value: d['departmentId'] as String, child: Text('${d['departmentCode']} - ${d['departmentName']}'))).toList(),
                onChanged: (v) => setS(() { selectedDeptId = v; selectedFacultyId = null; }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedFacultyId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Faculty', border: OutlineInputBorder()),
                items: filteredFaculty.map((f) => DropdownMenuItem(value: f['facultyId'] as String, child: Text('${f['name']} (${ds.getDepartmentCode(f['departmentId'] as String? ?? '')})'))).toList(),
                onChanged: (v) => setS(() => selectedFacultyId = v),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: creditsC, decoration: const InputDecoration(labelText: 'Credits', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: semC, decoration: const InputDecoration(labelText: 'Semester', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              TextField(controller: roomC, decoration: const InputDecoration(labelText: 'Room', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: schedC, decoration: const InputDecoration(labelText: 'Schedule', border: OutlineInputBorder())),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              if (codeC.text.isEmpty || nameC.text.isEmpty || selectedDeptId == null) return;
              final payload = {
                'courseCode': codeC.text.toUpperCase(),
                'courseName': nameC.text,
                'departmentId': selectedDeptId,
                'department': ds.getDepartmentName(selectedDeptId!),
                'facultyId': selectedFacultyId ?? '',
                'credits': int.tryParse(creditsC.text) ?? 3,
                'semester': int.tryParse(semC.text) ?? 1,
                'room': roomC.text,
                'schedule': schedC.text,
                'sections': existing?['sections'] ?? <String>[],
              };
              if (existing == null) {
                ds.addCourse(payload);
              } else {
                ds.updateCourse(existing['courseId'] as String, payload);
              }
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existing == null ? 'Course created' : 'Course updated'), backgroundColor: AppColors.secondary));
            },
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      );
    }));
  }
}
