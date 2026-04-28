// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as excel_lib;
import '../../../../core/data_service.dart';
import '../../../../core/security_service.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});
  @override
  State<AdminUserManagementPage> createState() => _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Upload data
  List<Map<String, String>> _uploadedRows = [];
  List<String> _uploadedHeaders = [];
  Set<int> _selectedForVerification = {};
  bool _isUploading = false;
  String _uploadFileName = '';

  // Preview filters (one per column)
  Map<String, String> _columnFilters = {};

  // Users data (from DataService)
  List<Map<String, dynamic>> _allUsers = [];
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _roleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
  }

  void _loadUsers() {
    final ds = Provider.of<DataService>(context, listen: false);
    _allUsers = List<Map<String, dynamic>>.from(ds.users.map((u) {
      return {
        'userId': u['id'] ?? '',
        'password': u['password'] ?? '',
        'role': u['role'] ?? 'student',
        'name': u['label'] ?? u['id'] ?? '',
        'status': u['status'] ?? 'active',
      };
    }));
    for (var s in ds.students) {
      final idx = _allUsers.indexWhere((u) => u['userId'] == s['studentId']);
      if (idx >= 0) {
        _allUsers[idx]['name'] = s['name'] ?? _allUsers[idx]['name'];
        _allUsers[idx]['department'] = s['department'] ?? '';
        _allUsers[idx]['email'] = s['email'] ?? '';
        _allUsers[idx]['phone'] = s['phone'] ?? '';
        _allUsers[idx]['year'] = '${s['year'] ?? ''}';
        _allUsers[idx]['section'] = s['section'] ?? '';
      }
    }
    for (var f in ds.faculty) {
      final idx = _allUsers.indexWhere((u) => u['userId'] == f['facultyId']);
      if (idx >= 0) {
        _allUsers[idx]['name'] = f['name'] ?? _allUsers[idx]['name'];
        _allUsers[idx]['department'] = f['department'] ?? ds.getDepartmentName(f['departmentId'] as String? ?? '');
        _allUsers[idx]['email'] = f['email'] ?? '';
        _allUsers[idx]['phone'] = f['phone'] ?? '';
        _allUsers[idx]['designation'] = f['designation'] ?? '';
        _allUsers[idx]['qualification'] = f['qualification'] ?? '';
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ===== File Upload =====
  void _pickFile() {
    final input = html.FileUploadInputElement()..accept = '.csv,.xlsx,.xls';
    input.click();
    input.onChange.listen((e) {
      final files = input.files;
      if (files == null || files.isEmpty) return;
      final file = files[0];
      final fileName = file.name.toLowerCase();
      setState(() { _isUploading = true; _uploadFileName = file.name; });
      final reader = html.FileReader();
      if (fileName.endsWith('.xlsx') || fileName.endsWith('.xls')) {
        // Excel file - read as ArrayBuffer
        reader.onLoadEnd.listen((e) {
          final bytes = reader.result as Uint8List?;
          if (bytes != null) {
            _parseExcel(bytes);
          }
          setState(() { _isUploading = false; });
        });
        reader.readAsArrayBuffer(file);
      } else {
        // CSV file - read as text
        reader.onLoadEnd.listen((e) {
          final content = reader.result as String;
          _parseCSV(content);
          setState(() { _isUploading = false; });
        });
        reader.readAsText(file);
      }
    });
  }

  void _parseExcel(Uint8List bytes) {
    try {
      final excelFile = excel_lib.Excel.decodeBytes(bytes);
      if (excelFile.tables.isEmpty) {
        _showError('No sheets found in the Excel file');
        return;
      }
      // Use the first sheet
      final sheetName = excelFile.tables.keys.first;
      final sheet = excelFile.tables[sheetName]!;
      if (sheet.rows.isEmpty) {
        _showError('The sheet "$sheetName" is empty');
        return;
      }
      // First row = headers
      final headers = sheet.rows[0]
          .map((cell) => cell?.value?.toString().trim() ?? '')
          .where((h) => h.isNotEmpty)
          .toList();
      if (headers.isEmpty) {
        _showError('No column headers found in the first row');
        return;
      }
      final rows = <Map<String, String>>[];
      for (var i = 1; i < sheet.rows.length; i++) {
        final excelRow = sheet.rows[i];
        // Skip empty rows
        final hasData = excelRow.any((cell) => cell?.value != null && cell!.value.toString().trim().isNotEmpty);
        if (!hasData) continue;
        final row = <String, String>{};
        for (var j = 0; j < headers.length && j < excelRow.length; j++) {
          final cellValue = excelRow[j]?.value;
          row[headers[j]] = cellValue?.toString().trim() ?? '';
        }
        rows.add(row);
      }
      setState(() {
        _uploadedHeaders = headers;
        _uploadedRows = rows;
        _selectedForVerification = {};
        _columnFilters = {};
        _tabController.animateTo(1);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel parsed: ${rows.length} rows from sheet "$sheetName"'), backgroundColor: const Color(0xFF4CAF50)));
    } catch (e) {
      _showError('Error parsing Excel file: $e');
    }
  }

  void _parseCSV(String content) {
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) return;
    // Detect separator (comma, semicolon, tab)
    final firstLine = lines[0];
    String sep = ',';
    if (firstLine.contains('\t')) sep = '\t';
    else if (firstLine.contains(';') && !firstLine.contains(',')) sep = ';';

    final headers = firstLine.split(sep).map((h) => h.trim().replaceAll('"', '')).where((h) => h.isNotEmpty).toList();
    if (headers.isEmpty) {
      _showError('No column headers found in the CSV');
      return;
    }
    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final values = lines[i].split(sep).map((v) => v.trim().replaceAll('"', '')).toList();
      final row = <String, String>{};
      for (var j = 0; j < headers.length && j < values.length; j++) {
        row[headers[j]] = values[j];
      }
      rows.add(row);
    }
    setState(() {
      _uploadedHeaders = headers;
      _uploadedRows = rows;
      _selectedForVerification = {};
      _columnFilters = {};
      _tabController.animateTo(1);
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // Get unique values per column for filter dropdowns
  List<String> _getColumnValues(String header) {
    final values = <String>{};
    for (final row in _uploadedRows) {
      final v = row[header]?.trim() ?? '';
      if (v.isNotEmpty) values.add(v);
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  // Get filtered preview rows
  List<Map<String, String>> get _filteredPreviewRows {
    if (_columnFilters.isEmpty || _columnFilters.values.every((v) => v == 'All')) {
      return _uploadedRows;
    }
    return _uploadedRows.where((row) {
      for (final entry in _columnFilters.entries) {
        if (entry.value != 'All' && entry.value.isNotEmpty) {
          if ((row[entry.key] ?? '') != entry.value) return false;
        }
      }
      return true;
    }).toList();
  }

  void _toggleSelectAll(bool? val) {
    setState(() {
      if (val == true) {
        _selectedForVerification = Set<int>.from(List.generate(_uploadedRows.length, (i) => i));
      } else {
        _selectedForVerification.clear();
      }
    });
  }

  /// Flexible column lookup — tries multiple aliases for a field.
  String _getField(Map<String, String> row, List<String> aliases, [String fallback = '']) {
    for (final alias in aliases) {
      final v = row[alias];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return fallback;
  }

  void _verifyAndSave() {
    if (_selectedForVerification.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one record to verify'), backgroundColor: Colors.red));
      return;
    }
    final ds = Provider.of<DataService>(context, listen: false);
    int addedCount = 0;
    int skipped = 0;
    for (final idx in _selectedForVerification) {
      final row = _uploadedRows[idx];
      final userId = _getField(row, ['userId', 'studentId', 'facultyId', 'Student ID', 'Faculty ID', 'user_id', 'User ID', 'ID', 'Roll No', 'Roll Number', 'rollNo'], 'NEW$idx');
      final name = _getField(row, ['name', 'Name', 'Full Name', 'Student Name', 'Faculty Name']);
      final role = _getField(row, ['role', 'Role'], 'student').toLowerCase();
      final rawPassword = _getField(row, ['password', 'Password']);
      final department = _getField(row, ['department', 'Department', 'Dept', 'Branch']);
      final departmentId = _getField(row, ['departmentId', 'Department ID', 'department_id']);
      final email = _getField(row, ['email', 'Email', 'E-mail', 'email_id']);
      final phone = _getField(row, ['phone', 'Phone', 'Mobile', 'Contact', 'mobile_no']);

      // Skip if user already exists
      final existing = ds.users.indexWhere((u) => u['id'] == userId);
      if (existing >= 0) { skipped++; continue; }

      // Hash password (use default pattern if none provided)
      final password = rawPassword.isNotEmpty ? rawPassword : 'ksrce@${userId.toLowerCase()}';
      final hashedPassword = SecurityService.hashPassword(password, userId);

      if (role == 'student') {
        // Create student + user via DataService (which auto-hashes)
        // But we have a custom userId, so we do it manually with proper hashing
        ds.students.add({
          'studentId': userId,
          'name': name,
          'department': department,
          'departmentId': departmentId.isNotEmpty ? departmentId : 'DEPT_$department',
          'year': int.tryParse(_getField(row, ['year', 'Year', 'Semester'])) ?? 1,
          'section': _getField(row, ['section', 'Section', 'Sec'], 'A'),
          'email': email,
          'phone': phone,
          'dateOfBirth': _getField(row, ['dateOfBirth', 'DOB', 'Date of Birth', 'dob']),
          'bloodGroup': _getField(row, ['bloodGroup', 'Blood Group', 'blood_group']),
          'address': _getField(row, ['address', 'Address']),
          'parentName': _getField(row, ['parentName', 'Parent Name', 'Father Name', 'Guardian', 'parent_name']),
          'parentPhone': _getField(row, ['parentPhone', 'Parent Phone', 'Parent Mobile', 'parent_phone']),
          'admissionDate': _getField(row, ['admissionDate', 'Admission Date', 'admission_date']),
          'cgpa': double.tryParse(_getField(row, ['cgpa', 'CGPA', 'GPA'])) ?? 0.0,
          'enrolledCourses': <String>[],
          'mentorId': null,
          'classAdviserId': null,
        });
        ds.users.add({
          'id': userId, 'password': hashedPassword,
          'role': 'student', 'label': 'Student - $name', 'status': 'active',
        });
        addedCount++;
      } else if (role == 'faculty') {
        ds.faculty.add({
          'facultyId': userId,
          'name': name,
          'email': email,
          'phone': phone,
          'department': department,
          'departmentId': departmentId.isNotEmpty ? departmentId : 'DEPT_$department',
          'designation': _getField(row, ['designation', 'Designation', 'Position']),
          'qualification': _getField(row, ['qualification', 'Qualification', 'Degree']),
          'specialization': _getField(row, ['specialization', 'Specialization']),
          'experience': _getField(row, ['experience', 'Experience', 'Years']),
          'dateOfJoining': _getField(row, ['dateOfJoining', 'Date of Joining', 'Joining Date', 'date_of_joining']),
          'isHOD': false,
          'isClassAdviser': false,
          'adviserFor': null,
          'menteeIds': <String>[],
          'courseIds': <String>[],
        });
        ds.users.add({
          'id': userId, 'password': hashedPassword,
          'role': 'faculty', 'label': 'Faculty - $name', 'status': 'active',
        });
        addedCount++;
      } else {
        // admin or other role — just create user record
        ds.users.add({
          'id': userId, 'password': hashedPassword,
          'role': role, 'label': name, 'status': 'active',
        });
        addedCount++;
      }
    }
    ds.notifyListeners();
    _loadUsers();
    setState(() {
      _uploadedRows.clear();
      _uploadedHeaders.clear();
      _selectedForVerification.clear();
      _columnFilters.clear();
      _tabController.animateTo(2);
    });
    final msg = '$addedCount users added${skipped > 0 ? ', $skipped duplicates skipped' : ''}!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF4CAF50)));
  }

  // ===== User CRUD =====
  void _addUser() => _showUserDialog(null);
  void _editUser(int index) => _showUserDialog(index);

  void _showUserDialog(int? editIndex) {
    final isEdit = editIndex != null;
    final user = isEdit ? _allUsers[editIndex] : <String, dynamic>{};
    final idCtrl = TextEditingController(text: user['userId'] ?? '');
    final nameCtrl = TextEditingController(text: user['name'] ?? '');
    final passCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: user['department'] ?? '');
    final emailCtrl = TextEditingController(text: user['email'] ?? '');
    final phoneCtrl = TextEditingController(text: user['phone'] ?? '');
    final sectionCtrl = TextEditingController(text: user['section'] ?? '');
    final yearCtrl = TextEditingController(text: user['year'] ?? '');
    final designationCtrl = TextEditingController(text: user['designation'] ?? '');
    final qualificationCtrl = TextEditingController(text: user['qualification'] ?? '');
    String role = user['role'] ?? 'student';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDState) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(isEdit ? Icons.edit : Icons.person_add, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Text(isEdit ? 'Edit User' : 'Add New User', style: const TextStyle(color: AppColors.textDark, fontSize: 17, fontWeight: FontWeight.w600)),
        ]),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440, minWidth: MediaQuery.of(ctx).size.width < 500 ? MediaQuery.of(ctx).size.width * 0.85 : 440),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField('User ID (e.g. STU006)', idCtrl, enabled: !isEdit),
            _dialogField('Full Name', nameCtrl),
            _dialogField(isEdit ? 'New Password (leave blank to keep)' : 'Password', passCtrl, obscure: true),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role, dropdownColor: AppColors.background,
              decoration: _inputDeco('Role'),
              style: const TextStyle(color: Colors.white),
              items: ['student', 'faculty', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
              onChanged: isEdit ? null : (v) => setDState(() => role = v!),
            ),
            const SizedBox(height: 8),
            _dialogField('Department', deptCtrl),
            _dialogField('Email', emailCtrl),
            _dialogField('Phone', phoneCtrl),
            if (role == 'student') ...[_dialogField('Year', yearCtrl), _dialogField('Section', sectionCtrl)],
            if (role == 'faculty') ...[_dialogField('Designation', designationCtrl), _dialogField('Qualification', qualificationCtrl)],
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              if (idCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID and Name are required'), backgroundColor: Colors.red));
                return;
              }
              final ds = Provider.of<DataService>(context, listen: false);
              final uid = idCtrl.text.trim();
              if (isEdit) {
                // Update user record
                final uIdx = ds.users.indexWhere((u) => u['id'] == _allUsers[editIndex]['userId']);
                if (uIdx >= 0) {
                  ds.users[uIdx]['label'] = nameCtrl.text;
                  ds.users[uIdx]['role'] = role;
                  // Only re-hash if password field is non-empty
                  if (passCtrl.text.isNotEmpty) {
                    ds.users[uIdx]['password'] = SecurityService.hashPassword(passCtrl.text, uid);
                  }
                }
                // Sync to student record
                final sIdx = ds.students.indexWhere((s) => s['studentId'] == uid);
                if (sIdx >= 0) {
                  ds.students[sIdx].addAll({
                    'name': nameCtrl.text, 'department': deptCtrl.text, 'email': emailCtrl.text,
                    'phone': phoneCtrl.text, 'year': int.tryParse(yearCtrl.text) ?? ds.students[sIdx]['year'],
                    'section': sectionCtrl.text.isNotEmpty ? sectionCtrl.text : ds.students[sIdx]['section'],
                  });
                }
                // Sync to faculty record
                final fIdx = ds.faculty.indexWhere((f) => f['facultyId'] == uid);
                if (fIdx >= 0) {
                  ds.faculty[fIdx].addAll({
                    'name': nameCtrl.text, 'email': emailCtrl.text, 'phone': phoneCtrl.text,
                    'designation': designationCtrl.text, 'qualification': qualificationCtrl.text,
                  });
                  if (deptCtrl.text.isNotEmpty) ds.faculty[fIdx]['department'] = deptCtrl.text;
                }
              } else {
                // Check for duplicate ID
                if (ds.users.any((u) => u['id'] == uid)) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User ID "$uid" already exists'), backgroundColor: Colors.red));
                  return;
                }
                // Hash password
                final rawPwd = passCtrl.text.isNotEmpty ? passCtrl.text : 'ksrce@${uid.toLowerCase()}';
                final hashedPwd = SecurityService.hashPassword(rawPwd, uid);
                // Create user account
                ds.users.add({'id': uid, 'password': hashedPwd, 'role': role, 'label': nameCtrl.text, 'status': 'active'});
                // Create role-specific record
                if (role == 'student') {
                  ds.students.add({
                    'studentId': uid, 'name': nameCtrl.text, 'department': deptCtrl.text,
                    'departmentId': 'DEPT_${deptCtrl.text}', 'email': emailCtrl.text, 'phone': phoneCtrl.text,
                    'year': int.tryParse(yearCtrl.text) ?? 1, 'section': sectionCtrl.text.isNotEmpty ? sectionCtrl.text : 'A',
                    'enrolledCourses': <String>[], 'mentorId': null, 'classAdviserId': null,
                  });
                } else if (role == 'faculty') {
                  ds.faculty.add({
                    'facultyId': uid, 'name': nameCtrl.text, 'email': emailCtrl.text, 'phone': phoneCtrl.text,
                    'department': deptCtrl.text, 'departmentId': 'DEPT_${deptCtrl.text}',
                    'designation': designationCtrl.text, 'qualification': qualificationCtrl.text,
                    'isHOD': false, 'isClassAdviser': false, 'adviserFor': null,
                    'menteeIds': <String>[], 'courseIds': <String>[],
                  });
                }
              }
              ds.notifyListeners();
              _loadUsers();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'User updated!' : 'User added!'), backgroundColor: const Color(0xFF4CAF50)));
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      );
    }));
  }

  void _deleteUser(int index) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Remove User', style: TextStyle(color: AppColors.textDark)),
      content: Text('Are you sure you want to permanently remove ${_allUsers[index]['name']}?', style: const TextStyle(color: AppColors.textMedium)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textLight))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            final ds = Provider.of<DataService>(context, listen: false);
            final uid = _allUsers[index]['userId'] as String? ?? '';
            ds.users.removeWhere((u) => u['id'] == uid);
            ds.students.removeWhere((s) => s['studentId'] == uid);
            ds.faculty.removeWhere((f) => f['facultyId'] == uid);
            ds.notifyListeners();
            _loadUsers();
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User removed!'), backgroundColor: Colors.red));
          },
          child: const Text('Remove'),
        ),
      ],
    ));
  }

  void _changeStatus(int index, String newStatus) {
    final ds = Provider.of<DataService>(context, listen: false);
    final uIdx = ds.users.indexWhere((u) => u['id'] == _allUsers[index]['userId']);
    if (uIdx >= 0) {
      ds.users[uIdx]['status'] = newStatus;
      ds.notifyListeners();
      _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User status changed to $newStatus'), backgroundColor: AppColors.primary));
    }
  }

  Widget _dialogField(String label, TextEditingController ctrl, {bool obscure = false, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(controller: ctrl, obscureText: obscure, enabled: enabled,
        style: const TextStyle(color: AppColors.textDark),
        decoration: _inputDeco(label)),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: AppColors.textLight),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
    filled: true, fillColor: AppColors.background,
  );

  List<Map<String, dynamic>> get _filteredUsers {
    return _allUsers.where((u) {
      final matchesSearch = _searchQuery.isEmpty || u.values.any((v) => v.toString().toLowerCase().contains(_searchQuery.toLowerCase()));
      final matchesStatus = _statusFilter == 'All' || u['status'] == _statusFilter.toLowerCase();
      final matchesRole = _roleFilter == 'All' || u['role'] == _roleFilter.toLowerCase();
      return matchesSearch && matchesStatus && matchesRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: isMobile
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('User Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 4),
                const Text('Upload, verify, and manage all users', style: TextStyle(fontSize: 14, color: AppColors.textLight)),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                  onPressed: _addUser,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add User'),
                )),
              ])
            : Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('User Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  SizedBox(height: 4),
                  Text('Upload, verify, and manage all users', style: TextStyle(fontSize: 14, color: AppColors.textLight)),
                ])),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                  onPressed: _addUser,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Add User'),
                ),
              ]),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
            labelColor: Colors.white, unselectedLabelColor: AppColors.textLight,
            tabs: isMobile
              ? [
                  Tab(icon: const Icon(Icons.upload_file, size: 20), child: null),
                  Tab(icon: Badge(label: Text('${_uploadedRows.length}', style: const TextStyle(fontSize: 10)), child: const Icon(Icons.preview, size: 20))),
                  Tab(icon: Badge(label: Text('${_allUsers.length}', style: const TextStyle(fontSize: 10)), child: const Icon(Icons.people, size: 20))),
                ]
              : [
                  Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.upload_file, size: 18), const SizedBox(width: 8), const Text('Upload')])),
                  Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.preview, size: 18), const SizedBox(width: 8), Text('Preview (${_uploadedRows.length})')])),
                  Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.people, size: 18), const SizedBox(width: 8), Text('Manage (${_allUsers.length})')])),
                ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: TabBarView(controller: _tabController, children: [
          _buildUploadTab(),
          _buildPreviewTab(),
          _buildManageTab(),
        ])),
      ]);
    });
  }

  // ===== TAB 1: Upload =====
  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        InkWell(
          onTap: _pickFile,
          child: Container(
            width: double.infinity, height: 250,
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 2, strokeAlign: BorderSide.strokeAlignInside),
            ),
            child: _isUploading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text('Click to upload CSV or Excel file', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Supported: .csv, .xlsx, .xls', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
                  if (_uploadFileName.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: Text('Last uploaded: $_uploadFileName', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
                    ),
                  ],
                ]),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('File Format Guide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ]),
            const SizedBox(height: 12),
            Text('Your file should have column headers in the first row. Example:', style: TextStyle(color: AppColors.textMedium, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
              child: const SelectableText(
                'userId,name,role,department,year,section,email,phone\nSTU006,John Doe,student,CSE,2,A,john@email.com,9876543210\nFAC002,Dr. Smith,faculty,ECE,,,,smith@ksrce.edu',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF4CAF50)),
              ),
            ),
            const SizedBox(height: 12),
            Text('The first row becomes column headers and filter options in the preview.', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            const SizedBox(height: 8),
            const Text('Supported columns:', style: TextStyle(color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _formatChip('userId', true), _formatChip('name', true), _formatChip('role', true),
              _formatChip('password', false), _formatChip('department', false), _formatChip('year', false),
              _formatChip('section', false), _formatChip('email', false), _formatChip('phone', false),
              _formatChip('dateOfBirth', false), _formatChip('bloodGroup', false), _formatChip('address', false),
              _formatChip('parentName', false), _formatChip('parentPhone', false),
              _formatChip('designation', false), _formatChip('qualification', false),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _downloadTemplate,
          icon: const Icon(Icons.download, color: AppColors.primary),
          label: const Text('Download CSV Template', style: TextStyle(color: AppColors.primary)),
        )),
      ]),
    );
  }

  Widget _formatChip(String label, bool required) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: required ? AppColors.primary.withOpacity(0.15) : AppColors.border,
        borderRadius: BorderRadius.circular(12),
        border: required ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
      ),
      child: Text('$label${required ? " *" : ""}',
        style: TextStyle(fontSize: 12, color: required ? const Color(0xFF42A5F5) : AppColors.textLight)),
    );
  }

  void _downloadTemplate() {
    const csv = 'userId,name,password,role,department,year,section,email,phone,dateOfBirth,bloodGroup,address,parentName,parentPhone,designation,qualification\n'
        'STU006,John Doe,,student,CSE,2,A,john@email.com,9876543210,2004-05-15,O+,123 Main St,Mr. Doe,9876543211,,\n'
        'FAC002,Dr. Smith,,faculty,ECE,,,,smith@ksrce.edu,,,,,,,Professor,PhD\n';
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)..setAttribute('download', 'user_template.csv')..click();
    html.Url.revokeObjectUrl(url);
  }

  // ===== EXPORT =====
  void _exportUsersCSV() {
    final users = _filteredUsers;
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No users to export'), backgroundColor: Colors.red));
      return;
    }
    final headers = ['userId', 'name', 'role', 'department', 'email', 'phone', 'year', 'status'];
    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    for (final u in users) {
      buffer.writeln(headers.map((h) => '"${(u[h] ?? '').toString().replaceAll('"', '""')}"').join(','));
    }
    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)..setAttribute('download', 'users_export.csv')..click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${users.length} users to CSV'), backgroundColor: const Color(0xFF4CAF50)));
  }

  void _exportUsersExcel() {
    final users = _filteredUsers;
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No users to export'), backgroundColor: Colors.red));
      return;
    }
    final excel = excel_lib.Excel.createExcel();
    final sheet = excel['Users'];
    final headers = ['userId', 'name', 'role', 'department', 'email', 'phone', 'year', 'status'];
    // Header row
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = excel_lib.TextCellValue(headers[i]);
    }
    // Data rows
    for (var r = 0; r < users.length; r++) {
      for (var c = 0; c < headers.length; c++) {
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value =
            excel_lib.TextCellValue((users[r][headers[c]] ?? '').toString());
      }
    }
    // Remove default 'Sheet1' if exists
    if (excel.tables.containsKey('Sheet1')) excel.delete('Sheet1');
    final bytes = excel.encode();
    if (bytes == null) return;
    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)..setAttribute('download', 'users_export.xlsx')..click();
    html.Url.revokeObjectUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${users.length} users to Excel'), backgroundColor: const Color(0xFF4CAF50)));
  }

  // ===== TAB 2: Preview & Verify (with filters) =====
  Widget _buildPreviewTab() {
    if (_uploadedRows.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.table_chart_outlined, size: 64, color: AppColors.textLight.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text('No data to preview', style: TextStyle(fontSize: 18, color: AppColors.textLight)),
        const SizedBox(height: 8),
        Text('Upload a CSV or Excel file first', style: TextStyle(fontSize: 13, color: AppColors.textLight.withOpacity(0.6))),
      ]));
    }

    final filtered = _filteredPreviewRows;
    final hasActiveFilters = _columnFilters.values.any((v) => v != 'All' && v.isNotEmpty);

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return Column(children: [
        // Toolbar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: isMobile
            ? Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.table_chart, size: 18, color: Color(0xFF42A5F5)),
                  const SizedBox(width: 8),
                  Text('${filtered.length}${hasActiveFilters ? " filtered" : ""} of ${_uploadedRows.length}',
                    style: const TextStyle(color: AppColors.textMedium, fontSize: 13)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text('${_selectedForVerification.length} selected', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
                ),
                if (hasActiveFilters)
                  TextButton.icon(
                    onPressed: () => setState(() => _columnFilters.clear()),
                    icon: const Icon(Icons.clear_all, size: 16, color: Color(0xFFFF9800)),
                    label: const Text('Clear Filters', style: TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
                  ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(
                    value: _selectedForVerification.length == _uploadedRows.length && _uploadedRows.isNotEmpty,
                    onChanged: _toggleSelectAll,
                    activeColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.textLight),
                  ),
                  const Text('Select All', style: TextStyle(color: AppColors.textMedium, fontSize: 13)),
                ]),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  onPressed: _verifyAndSave,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Verify & Save'),
                ),
              ])
            : Row(children: [
                const Icon(Icons.table_chart, size: 18, color: Color(0xFF42A5F5)),
                const SizedBox(width: 8),
                Text('${filtered.length}${hasActiveFilters ? " filtered" : ""} of ${_uploadedRows.length} records',
                  style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text('${_selectedForVerification.length} selected', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _columnFilters.clear()),
                    icon: const Icon(Icons.clear_all, size: 16, color: Color(0xFFFF9800)),
                    label: const Text('Clear Filters', style: TextStyle(color: Color(0xFFFF9800), fontSize: 12)),
                  ),
                ],
                const Spacer(),
                Checkbox(
                  value: _selectedForVerification.length == _uploadedRows.length && _uploadedRows.isNotEmpty,
                  onChanged: _toggleSelectAll,
                  activeColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.textLight),
                ),
                const Text('Select All', style: TextStyle(color: AppColors.textMedium, fontSize: 13)),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  onPressed: _verifyAndSave,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Verify & Save'),
                ),
              ]),
        ),
        const SizedBox(height: 8),
        // Filter row
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.filter_list, size: 16, color: AppColors.accent),
            const SizedBox(width: 8),
            const Text('Filters:', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Expanded(child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _uploadedHeaders.map((header) {
                final values = _getColumnValues(header);
                if (values.isEmpty) return const SizedBox.shrink();
                final current = _columnFilters[header] ?? 'All';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: current != 'All' ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: current != 'All' ? AppColors.primary : AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                      value: current,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.textDark, fontSize: 12),
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textLight),
                      items: [
                        DropdownMenuItem(value: 'All', child: Text(header, style: TextStyle(color: current == 'All' ? Colors.white54 : Colors.white, fontSize: 12))),
                        ...values.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (v) => setState(() => _columnFilters[header] = v ?? 'All'),
                    )),
                  ),
                );
              }).toList()),
            )),
          ]),
        ),
        const SizedBox(height: 8),
        // Data table
        Expanded(child: Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              headingRowHeight: 48,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 48,
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: [
                const DataColumn(label: SizedBox(width: 32, child: Text('', style: TextStyle(color: AppColors.textMedium)))),
                const DataColumn(label: Text('#', style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold, fontSize: 13))),
                ..._uploadedHeaders.map((h) => DataColumn(
                  label: Text(h, style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.bold, fontSize: 13)),
                )),
              ],
              rows: List.generate(filtered.length, (fi) {
                final row = filtered[fi];
                final origIdx = _uploadedRows.indexOf(row);
                final selected = _selectedForVerification.contains(origIdx);
                return DataRow(
                  color: WidgetStateProperty.all(selected ? AppColors.primary.withOpacity(0.08) : (fi.isEven ? Colors.transparent : AppColors.background.withOpacity(0.3))),
                  cells: [
                    DataCell(Checkbox(value: selected, activeColor: AppColors.primary, side: const BorderSide(color: AppColors.textLight),
                      onChanged: (v) => setState(() { if (v == true) _selectedForVerification.add(origIdx); else _selectedForVerification.remove(origIdx); }))),
                    DataCell(Text('${origIdx + 1}', style: const TextStyle(color: AppColors.textLight, fontSize: 12))),
                    ..._uploadedHeaders.map((h) => DataCell(
                      Text(row[h] ?? '', style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
                    )),
                  ],
                );
              }),
            ))),
          ),
        )),
      ]);
    });
  }

  // ===== TAB 3: Manage Users =====
  Widget _buildManageTab() {
    final filtered = _filteredUsers;
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return Column(children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? constraints.maxWidth - 80 : 300),
              child: TextField(
                style: const TextStyle(color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Search users...', hintStyle: const TextStyle(color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
                  filled: true, fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            _filterDropdown('Status', _statusFilter, ['All', 'Active', 'Suspended', 'Terminated'], (v) => setState(() => _statusFilter = v!)),
            _filterDropdown('Role', _roleFilter, ['All', 'Student', 'Faculty', 'Admin'], (v) => setState(() => _roleFilter = v!)),
            Text('${filtered.length} users', style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              onSelected: (v) { if (v == 'csv') _exportUsersCSV(); else _exportUsersExcel(); },
              icon: const Icon(Icons.download_rounded, color: AppColors.primary, size: 20),
              tooltip: 'Export Users',
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'csv', child: Row(children: [
                  Icon(Icons.table_chart, size: 16, color: Color(0xFF4CAF50)),
                  SizedBox(width: 8),
                  Text('Export as CSV', style: TextStyle(fontSize: 13)),
                ])),
                const PopupMenuItem(value: 'xlsx', child: Row(children: [
                  Icon(Icons.grid_on, size: 16, color: Color(0xFF2196F3)),
                  SizedBox(width: 8),
                  Text('Export as Excel', style: TextStyle(fontSize: 13)),
                ])),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(child: Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('#', style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('User ID', style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Name', style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Role', style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Department', style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(color: AppColors.textMedium, fontWeight: FontWeight.bold))),
            ],
            rows: List.generate(filtered.length, (i) {
              final u = filtered[i];
              final origIdx = _allUsers.indexOf(u);
              return DataRow(cells: [
                DataCell(Text('${i + 1}', style: const TextStyle(color: AppColors.textLight))),
                DataCell(Text(u['userId'] ?? '', style: const TextStyle(color: Color(0xFF42A5F5), fontWeight: FontWeight.w500))),
                DataCell(Text(u['name'] ?? '', style: const TextStyle(color: AppColors.textDark))),
                DataCell(_roleBadge(u['role'] ?? 'student')),
                DataCell(Text(u['department'] ?? '-', style: const TextStyle(color: AppColors.textMedium))),
                DataCell(_statusBadge(u['status'] ?? 'active')),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  _actionBtn(Icons.edit, 'Edit', AppColors.primary, () => _editUser(origIdx)),
                  _actionBtn(Icons.pause_circle, 'Suspend', const Color(0xFFFF9800), () => _changeStatus(origIdx, 'suspended')),
                  _actionBtn(Icons.block, 'Terminate', const Color(0xFFEF5350), () => _changeStatus(origIdx, 'terminated')),
                  _actionBtn(Icons.play_circle, 'Activate', const Color(0xFF4CAF50), () => _changeStatus(origIdx, 'active')),
                  _actionBtn(Icons.delete_forever, 'Remove', Colors.red, () => _deleteUser(origIdx)),
                ])),
              ]);
            }),
          ))),
        )),
      ]);
    });
  }

  Widget _filterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, dropdownColor: AppColors.background,
        style: const TextStyle(color: AppColors.textDark, fontSize: 13),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text('$label: $i'))).toList(),
        onChanged: onChanged,
      )),
    );
  }

  Widget _roleBadge(String role) {
    final color = role == 'admin' ? AppColors.accent : role == 'faculty' ? const Color(0xFF7E57C2) : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(role.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'active' ? const Color(0xFF4CAF50) : status == 'suspended' ? const Color(0xFFFF9800) : const Color(0xFFEF5350);
    final icon = status == 'active' ? Icons.check_circle : status == 'suspended' ? Icons.pause_circle : Icons.cancel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(message: tooltip, child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 18, color: color)),
    ));
  }
}
