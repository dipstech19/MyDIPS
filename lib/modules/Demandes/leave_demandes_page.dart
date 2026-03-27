import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_provider.dart';
import '../employees/conges_provider.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart';
import '../employees/models/equipe_model.dart';
import '../employees/utils/leave_days_utils.dart';
import '../pointage/pointage_provider.dart';
import '../pointage/models/pointage_model.dart';

enum UserRole { demandeur, administrateur }

enum LeaveStatus { pending, approved, rejected }

extension LeaveStatusX on LeaveStatus {
  String get label {
    switch (this) {
      case LeaveStatus.pending:
        return 'En attente';
      case LeaveStatus.approved:
        return 'Approuvé';
      case LeaveStatus.rejected:
        return 'Refusé';
    }
  }

  Color get color {
    switch (this) {
      case LeaveStatus.pending:
        return Colors.orange;
      case LeaveStatus.approved:
        return Colors.green;
      case LeaveStatus.rejected:
        return Colors.red;
    }
  }
}

class _LeaveType {
  final String id;
  final String label;
  const _LeaveType({required this.id, required this.label});
}

class LeaveRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeCin;
  final String employeePoste;
  final String equipeId;
  final String equipeName;
  final String chefName;
  final String leaveTypeId;
  final String leaveTypeLabel;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime startAt;
  final DateTime endAt;
  final String reason;
  final String professionalDetails;
  final String submittedByUserId;
  final String submittedByName;
  final String assignedAdminId;
  final String assignedAdminName;
  final DateTime createdAt;
  final LeaveStatus status;
  final String? adminComment;
  final DateTime? decidedAt;
  final String? decidedByAdminId;
  final String? decidedByAdminName;
  final Uint8List? approvedPdf;

  const LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCin,
    required this.employeePoste,
    required this.equipeId,
    required this.equipeName,
    required this.chefName,
    required this.leaveTypeId,
    required this.leaveTypeLabel,
    required this.startDate,
    required this.endDate,
    required this.startAt,
    required this.endAt,
    required this.reason,
    required this.professionalDetails,
    required this.submittedByUserId,
    required this.submittedByName,
    required this.assignedAdminId,
    required this.assignedAdminName,
    required this.createdAt,
    required this.status,
    this.adminComment,
    this.decidedAt,
    this.decidedByAdminId,
    this.decidedByAdminName,
    this.approvedPdf,
  });

  bool get isPending => status == LeaveStatus.pending;
  bool get isApproved => status == LeaveStatus.approved;

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'employeeCin': employeeCin,
        'employeePoste': employeePoste,
        'equipeId': equipeId,
        'equipeName': equipeName,
        'chefName': chefName,
        'leaveTypeId': leaveTypeId,
        'leaveTypeLabel': leaveTypeLabel,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'reason': reason,
        'professionalDetails': professionalDetails,
        'submittedByUserId': submittedByUserId,
        'submittedByName': submittedByName,
        'assignedAdminId': assignedAdminId,
        'assignedAdminName': assignedAdminName,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': status.name,
        'adminComment': adminComment,
        if (decidedAt != null) 'decidedAt': Timestamp.fromDate(decidedAt!),
        'decidedByAdminId': decidedByAdminId,
        'decidedByAdminName': decidedByAdminName,
        if (approvedPdf != null) 'approvedPdf': approvedPdf,
      };

  static LeaveRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    Uint8List? parsePdf(dynamic value) {
      if (value is Uint8List) return value;
      if (value is List<int>) return Uint8List.fromList(value);
      if (value is List<dynamic>) {
        // Firestore sometimes serializes bytes as a list.
        final list = value.whereType<int>().toList();
        if (list.isNotEmpty) return Uint8List.fromList(list);
      }
      if (value is Blob) return value.bytes;
      return null;
    }

    final statusRaw = (m['status'] as String? ?? 'pending');
    final status = LeaveStatus.values.firstWhere(
      (s) => s.name == statusRaw,
      orElse: () => LeaveStatus.pending,
    );

    return LeaveRequest(
      id: doc.id,
      employeeId: m['employeeId'] as String? ?? '',
      employeeName: m['employeeName'] as String? ?? '',
      employeeCin: m['employeeCin'] as String? ?? '',
      employeePoste: m['employeePoste'] as String? ?? '',
      equipeId: m['equipeId'] as String? ?? '',
      equipeName: m['equipeName'] as String? ?? '',
      chefName: m['chefName'] as String? ?? '',
      leaveTypeId: m['leaveTypeId'] as String? ?? '',
      leaveTypeLabel: m['leaveTypeLabel'] as String? ?? 'Congé',
      startDate: parseDate(m['startDate']),
      endDate: parseDate(m['endDate']),
      startAt: m['startAt'] == null
          ? DateTime(parseDate(m['startDate']).year, parseDate(m['startDate']).month,
              parseDate(m['startDate']).day)
          : parseDate(m['startAt']),
      endAt: m['endAt'] == null
          ? DateTime(parseDate(m['endDate']).year, parseDate(m['endDate']).month,
              parseDate(m['endDate']).day, 23, 59, 59)
          : parseDate(m['endAt']),
      reason: m['reason'] as String? ?? '',
      professionalDetails: m['professionalDetails'] as String? ?? '',
      submittedByUserId: m['submittedByUserId'] as String? ?? '',
      submittedByName: m['submittedByName'] as String? ?? '',
      assignedAdminId: m['assignedAdminId'] as String? ?? '',
      assignedAdminName: m['assignedAdminName'] as String? ?? '',
      createdAt: parseDate(m['createdAt']),
      status: status,
      adminComment: m['adminComment'] as String?,
      decidedAt: m['decidedAt'] == null ? null : parseDate(m['decidedAt']),
      decidedByAdminId: m['decidedByAdminId'] as String?,
      decidedByAdminName: m['decidedByAdminName'] as String?,
      approvedPdf: parsePdf(m['approvedPdf']),
    );
  }
}

class _AdminRecipient {
  final String id;
  final String name;
  final String email;

  const _AdminRecipient({required this.id, required this.name, required this.email});
}

class _LeaveRepository {
  static const _collection = 'leave_requests';
  final _db = FirebaseFirestore.instance;

  Stream<List<LeaveRequest>> watchRequests() {
    return _db.collection(_collection).orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(LeaveRequest.fromDoc).toList(),
        );
  }

  Future<void> create(LeaveRequest req) async {
    await _db.collection(_collection).add(req.toMap());
  }

  Future<void> updateDecision({
    required LeaveRequest req,
    required LeaveStatus newStatus,
    required String adminId,
    required String adminName,
    String? comment,
    Uint8List? approvedPdf,
  }) async {
    await _db.collection(_collection).doc(req.id).update({
      'status': newStatus.name,
      'adminComment': comment,
      'decidedAt': Timestamp.fromDate(DateTime.now()),
      'decidedByAdminId': adminId,
      'decidedByAdminName': adminName,
      if (approvedPdf != null) 'approvedPdf': approvedPdf,
    });
  }

  Future<bool> hasTeamConflict({
    required String equipeId,
    required DateTime startAt,
    required DateTime endAt,
    String? excludeRequestId,
  }) async {
    final snap = await _db.collection(_collection).where('equipeId', isEqualTo: equipeId).get();
    for (final d in snap.docs) {
      if (excludeRequestId != null && d.id == excludeRequestId) continue;
      final req = LeaveRequest.fromDoc(d);
      if (req.status == LeaveStatus.rejected) continue;
      final overlap = !(req.endAt.isBefore(startAt) || req.startAt.isAfter(endAt));
      if (overlap) return true;
    }
    return false;
  }
}

class DemandesPage extends StatefulWidget {
  final UserRole role;
  const DemandesPage({super.key, required this.role});

  @override
  State<DemandesPage> createState() => _DemandesPageState();
}

class _DemandesPageState extends State<DemandesPage> {
  final _repo = _LeaveRepository();
  DateTime _selectedCalendarDate = DateTime.now();
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final empProv = context.watch<EmployeesProvider>();
    final isAdmin = widget.role == UserRole.administrateur;

    return StreamBuilder<List<LeaveRequest>>(
      stream: _repo.watchRequests(),
      builder: (context, snap) {
        final requests = snap.data ?? const <LeaveRequest>[];
        final filtered = isAdmin
            ? _adminViewRequests(auth, requests)
            : (auth.equipeId == null || auth.equipeId!.isEmpty)
                ? const <LeaveRequest>[]
                : requests.where((r) => r.equipeId == auth.equipeId).toList();

        return Column(
          children: [
            _header(isAdmin, filtered),
            Expanded(
              child: isAdmin
                  ? _AdminLeaveView(
                      requests: filtered,
                      employees: empProv.employes,
                      equipes: empProv.equipes,
                      selectedDate: _selectedCalendarDate,
                      selectedYear: _selectedYear,
                      selectedMonth: _selectedMonth,
                      onDateChanged: (d) => setState(() => _selectedCalendarDate = d),
                      onYearChanged: (y) => setState(() => _selectedYear = y),
                      onMonthChanged: (m) {
                        setState(() {
                          _selectedMonth = m;
                          if (m == null) return;
                          final currentDay = _selectedCalendarDate.day;
                          final maxDay = DateTime(_selectedYear, m + 1, 0).day;
                          final safeDay = currentDay.clamp(1, maxDay);
                          _selectedCalendarDate = DateTime(_selectedYear, m, safeDay);
                        });
                      },
                      onCreateApprovedByAdmin: (employee, start, end, leaveTypeId, leaveTypeLabel, reason, details) =>
                          _createAndApproveByAdmin(
                        context,
                        employee: employee,
                        start: start,
                        end: end,
                        leaveTypeId: leaveTypeId,
                        leaveTypeLabel: leaveTypeLabel,
                        reason: reason,
                        details: details,
                      ),
                      onApprove: (r, comment) => _approveRequest(context, r, comment),
                      onReject: (r, comment) => _rejectRequest(context, r, comment),
                    )
                  : _ChefLeaveView(
                      requests: filtered,
                      onCreate: (r) => _repo.create(r),
                    ),
            ),
          ],
        );
      },
    );
  }

  List<LeaveRequest> _adminViewRequests(AuthProvider auth, List<LeaveRequest> all) {
    return all;
  }

  Widget _header(bool isAdmin, List<LeaveRequest> requests) {
    final pending = requests.where((r) => r.status == LeaveStatus.pending).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          Icon(isAdmin ? Icons.admin_panel_settings : Icons.assignment, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdmin ? 'Gestion des congés (Admin)' : 'Mes demandes de congé',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  isAdmin ? 'Demandes en attente: $pending' : 'Total demandes: ${requests.length}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _requestedLeaveDays(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    if (e.isBefore(s)) return 0;
    return (e.difference(s).inDays + 1).toDouble();
  }

  String _deriveEquipeIdForEmployee(Employe e, List<Equipe> equipes) {
    final direct = equipes.where((q) => q.chefId == e.id || q.membreIds.contains(e.id)).toList();
    return direct.isNotEmpty ? direct.first.id : '';
  }

  String _deriveEquipeNameForEmployee(Employe e, List<Equipe> equipes) {
    final direct = equipes.where((q) => q.chefId == e.id || q.membreIds.contains(e.id)).toList();
    return direct.isNotEmpty ? direct.first.nom : 'Équipe non définie';
  }

  Future<void> _createAndApproveByAdmin(
    BuildContext context, {
    required Employe employee,
    required DateTime start,
    required DateTime end,
    required String leaveTypeId,
    required String leaveTypeLabel,
    required String reason,
    required String details,
  }) async {
    final auth = context.read<AuthProvider>();
    final empProv = context.read<EmployeesProvider>();
    final conges = context.read<CongesProvider>();
    final pointageProvider = context.read<PointageProvider>();
    final requestedDays = _requestedLeaveDays(start, end);
    final acquired = leaveDaysAcquired(employee.dateDebut);
    final taken = await conges.getDaysTaken(employee.id, refresh: true);
    final remaining = (acquired - taken).clamp(0.0, double.infinity);
    if (requestedDays > remaining) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Solde insuffisant: restant ${remaining.toStringAsFixed(1)}j, demandé ${requestedDays.toStringAsFixed(1)}j.')),
        );
      }
      return;
    }

    final startAt = DateTime(start.year, start.month, start.day, 0, 0);
    final endAt = DateTime(end.year, end.month, end.day, 23, 59);
    final equipeId = _deriveEquipeIdForEmployee(employee, empProv.equipes);
    final equipeName = _deriveEquipeNameForEmployee(employee, empProv.equipes);

    final hasConflict = await _repo.hasTeamConflict(equipeId: equipeId, startAt: startAt, endAt: endAt);
    if (hasConflict) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conflit détecté pour cette équipe sur la période demandée.')),
        );
      }
      return;
    }

    final adminName = auth.currentUser?.nom ?? 'Administrateur';
    final baseReq = LeaveRequest(
      id: '',
      employeeId: employee.id,
      employeeName: employee.nom,
      employeeCin: employee.cin,
      employeePoste: employee.poste,
      equipeId: equipeId,
      equipeName: equipeName,
      chefName: '',
      leaveTypeId: leaveTypeId,
      leaveTypeLabel: leaveTypeLabel,
      startDate: start,
      endDate: end,
      startAt: startAt,
      endAt: endAt,
      reason: reason.trim(),
      professionalDetails: details.trim(),
      submittedByUserId: auth.currentUser?.id ?? '',
      submittedByName: adminName,
      assignedAdminId: auth.currentUser?.id ?? '',
      assignedAdminName: adminName,
      createdAt: DateTime.now(),
      status: LeaveStatus.approved,
      adminComment: 'Approbation directe par administration',
      decidedAt: DateTime.now(),
      decidedByAdminId: auth.currentUser?.id ?? '',
      decidedByAdminName: adminName,
    );
    final pdf = await _buildApprovedLeavePdf(baseReq, adminName);
    final finalReq = LeaveRequest(
      id: baseReq.id,
      employeeId: baseReq.employeeId,
      employeeName: baseReq.employeeName,
      employeeCin: baseReq.employeeCin,
      employeePoste: baseReq.employeePoste,
      equipeId: baseReq.equipeId,
      equipeName: baseReq.equipeName,
      chefName: baseReq.chefName,
      leaveTypeId: baseReq.leaveTypeId,
      leaveTypeLabel: baseReq.leaveTypeLabel,
      startDate: baseReq.startDate,
      endDate: baseReq.endDate,
      startAt: baseReq.startAt,
      endAt: baseReq.endAt,
      reason: baseReq.reason,
      professionalDetails: baseReq.professionalDetails,
      submittedByUserId: baseReq.submittedByUserId,
      submittedByName: baseReq.submittedByName,
      assignedAdminId: baseReq.assignedAdminId,
      assignedAdminName: baseReq.assignedAdminName,
      createdAt: baseReq.createdAt,
      status: baseReq.status,
      adminComment: baseReq.adminComment,
      decidedAt: baseReq.decidedAt,
      decidedByAdminId: baseReq.decidedByAdminId,
      decidedByAdminName: baseReq.decidedByAdminName,
      approvedPdf: pdf,
    );
    await _repo.create(finalReq);

    for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      await pointageProvider.setAdminOverrideForEmployee(
        employeId: employee.id,
        employeNom: employee.nom,
        employeCin: employee.cin,
        equipeId: equipeId,
        equipeName: equipeName,
        chefName: '',
        status: AttendanceStatus.leave,
        viewDate: d,
      );
    }
    await conges.addDaysTaken(employee.id, requestedDays);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Congé créé et approuvé avec succès.')));
    }
  }

  Future<void> _approveRequest(BuildContext context, LeaveRequest req, String comment) async {
    final auth = context.read<AuthProvider>();
    final empProv = context.read<EmployeesProvider>();
    final employee = empProv.employes.where((e) => e.id == req.employeeId).toList();
    if (employee.isNotEmpty) {
      final requestedDays = _requestedLeaveDays(req.startDate, req.endDate);
      final acquired = leaveDaysAcquired(employee.first.dateDebut);
      final conges = context.read<CongesProvider>();
      final taken = await conges.getDaysTaken(req.employeeId, refresh: true);
      final remaining = (acquired - taken).clamp(0.0, double.infinity);
      if (requestedDays > remaining && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Solde insuffisant pour ${employee.first.nom}: restant ${remaining.toStringAsFixed(1)}j, demandé ${requestedDays.toStringAsFixed(1)}j.',
            ),
          ),
        );
        return;
      }
    }

    final hasConflict = await _repo.hasTeamConflict(
      equipeId: req.equipeId,
      startAt: req.startAt,
      endAt: req.endAt,
      excludeRequestId: req.id,
    );
    if (hasConflict && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conflit détecté: une autre demande existe déjà pour cette équipe et période.')),
      );
      return;
    }

    final pdf = await _buildApprovedLeavePdf(req, auth.currentUser?.nom ?? 'Administrateur');
    await _repo.updateDecision(
      req: req,
      newStatus: LeaveStatus.approved,
      adminId: auth.currentUser?.id ?? '',
      adminName: auth.currentUser?.nom ?? '',
      comment: comment.trim().isEmpty ? null : comment.trim(),
      approvedPdf: pdf,
    );

    if (context.mounted) {
      // After approval: automatically mark the leave period as "leave" in pointage
      // so it's counted as present with special (dark blue) styling.
      final pointageProvider = context.read<PointageProvider>();

      if (employee.isNotEmpty) {
        final equipe = empProv.equipes.where((e) => e.id == req.equipeId).toList();
        final chefId = equipe.isNotEmpty ? equipe.first.chefId : '';
        final chef = empProv.employes.where((e) => e.id == chefId).toList();
        final chefName = chef.isNotEmpty ? chef.first.nom : req.submittedByName;

        for (DateTime d = req.startDate;
            !d.isAfter(req.endDate);
            d = d.add(const Duration(days: 1))) {
          await pointageProvider.setAdminOverrideForEmployee(
            employeId: employee.first.id,
            employeNom: employee.first.nom,
            employeCin: employee.first.cin,
            equipeId: req.equipeId,
            equipeName: req.equipeName,
            chefName: chefName,
            status: AttendanceStatus.leave,
            viewDate: d,
          );
        }
      }

      final days = req.endDate.difference(req.startDate).inDays + 1;
      await context.read<CongesProvider>().addDaysTaken(req.employeeId, days.toDouble());
    }
  }

  Future<void> _rejectRequest(BuildContext context, LeaveRequest req, String comment) async {
    final auth = context.read<AuthProvider>();
    await _repo.updateDecision(
      req: req,
      newStatus: LeaveStatus.rejected,
      adminId: auth.currentUser?.id ?? '',
      adminName: auth.currentUser?.nom ?? '',
      comment: comment.trim().isEmpty ? 'Demande refusée' : comment.trim(),
    );
  }

  Future<Uint8List> _buildApprovedLeavePdf(LeaveRequest req, String adminName) async {
    final pdf = pw.Document();
    final fmt = (DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final fmtDateTime = (DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final days = req.endDate.difference(req.startDate).inDays + 1;
    final logoBytes = await _loadLogoBytes();
    final decidedAt = req.decidedAt ?? DateTime.now();
    final requestRef = req.id.isEmpty ? 'REQ-${req.createdAt.millisecondsSinceEpoch}' : req.id;
    final employeeCin = req.employeeCin.trim().isEmpty ? '-' : req.employeeCin.trim();
    final employeePoste = req.employeePoste.trim().isEmpty ? '-' : req.employeePoste.trim();
    final chefName = req.chefName.trim().isEmpty ? '-' : req.chefName.trim();
    final senderName = req.submittedByName.trim().isEmpty ? '-' : req.submittedByName.trim();
    final targetAdmin = req.assignedAdminName.trim().isEmpty ? '-' : req.assignedAdminName.trim();
    final adminComment = (req.adminComment ?? '').trim().isEmpty ? '-' : req.adminComment!.trim();
    final professionalDetails = req.professionalDetails.trim().isEmpty ? '-' : req.professionalDetails.trim();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoBytes != null)
                    pw.Container(
                      width: 72,
                      height: 72,
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                    ),
                  if (logoBytes != null) pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DIPS MANAGEMENT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Formulaire professionnel de demande de congé', style: pw.TextStyle(fontSize: 13, color: PdfColors.blue700)),
                        pw.SizedBox(height: 2),
                        pw.Text('Référence: $requestRef', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Date d\'émission: ${fmtDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 12),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue200),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'Section A - Déclaration du demandeur (Chef / Employé concerné)',
                  style: pw.TextStyle(color: PdfColors.blue800, fontWeight: pw.FontWeight.bold, fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.6),
                  1: pw.FlexColumnWidth(2.9),
                },
                children: [
                  _pdfRow('Nom de l\'employé concerné', req.employeeName),
                  _pdfRow('CIN employé', employeeCin),
                  _pdfRow('Département / Équipe', req.equipeName),
                  _pdfRow('Poste', employeePoste),
                  _pdfRow('Chef d\'équipe responsable', chefName),
                  _pdfRow('Demande saisie par', senderName),
                  _pdfRow('Date de début', fmt(req.startDate)),
                  _pdfRow('Date de fin', fmt(req.endDate)),
                  _pdfRow('Nombre total de jours demandés', '$days'),
                  _pdfRow('Type de congé', req.leaveTypeLabel),
                  _pdfRow('Motif(s) du congé', req.reason),
                  _pdfRow('Détails professionnels', professionalDetails),
                  _pdfRow('Engagement du demandeur', '[X] Demande exacte et soumise pour validation administrative'),
                  _pdfRow('Date de soumission', fmtDateTime(req.createdAt)),
                  _pdfRow('Signature Chef / Demandeur', senderName),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'Section B - Décision administrative (Responsable / Admin)',
                  style: pw.TextStyle(color: PdfColors.green800, fontWeight: pw.FontWeight.bold, fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.6),
                  1: pw.FlexColumnWidth(2.9),
                },
                children: [
                  _pdfRow('Décision', '[X] Congé approuvé    [ ] Congé refusé'),
                  _pdfRow('Responsable validateur', adminName),
                  _pdfRow('Admin destinataire initial', targetAdmin),
                  _pdfRow('Date et heure de validation', fmtDateTime(decidedAt)),
                  _pdfRow('Remarques du responsable', adminComment),
                ],
              ),
              pw.Spacer(),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Visa Chef / Demandeur', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 22),
                          pw.Text(senderName),
                          pw.Text('Date: ${fmt(req.createdAt)}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Signature Responsable (Admin)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 22),
                          pw.Text(adminName),
                          pw.Text('Date: ${fmt(decidedAt)}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Document généré automatiquement par le système DIPS Management.',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ),
    );
    return pdf.save();
  }

  Future<Uint8List?> _loadLogoBytes() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  pw.TableRow _pdfRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }
}

class _ChefLeaveView extends StatelessWidget {
  final List<LeaveRequest> requests;
  final Future<void> Function(LeaveRequest req) onCreate;

  const _ChefLeaveView({required this.requests, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _ChefLeaveForm(onCreate: onCreate),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, i) => _LeaveRequestCard(req: requests[i], isAdmin: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminLeaveView extends StatelessWidget {
  final List<LeaveRequest> requests;
  final List<Employe> employees;
  final List<Equipe> equipes;
  final DateTime selectedDate;
  final int selectedYear;
  final int? selectedMonth;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int?> onMonthChanged;
  final Future<void> Function(
    Employe employee,
    DateTime start,
    DateTime end,
    String leaveTypeId,
    String leaveTypeLabel,
    String reason,
    String details,
  ) onCreateApprovedByAdmin;
  final Future<void> Function(LeaveRequest req, String comment) onApprove;
  final Future<void> Function(LeaveRequest req, String comment) onReject;

  const _AdminLeaveView({
    required this.requests,
    required this.employees,
    required this.equipes,
    required this.selectedDate,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onDateChanged,
    required this.onYearChanged,
    required this.onMonthChanged,
    required this.onCreateApprovedByAdmin,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = (DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final yearRequests = requests.where((r) => r.startDate.year == selectedYear || r.endDate.year == selectedYear).toList();
    final filteredRequests = selectedMonth == null
        ? yearRequests
        : yearRequests.where((r) => r.startDate.month <= selectedMonth! && r.endDate.month >= selectedMonth!).toList();
    final pending = filteredRequests.where((r) => r.status == LeaveStatus.pending).toList();
    final onSelectedDayFiltered = filteredRequests
        .where((r) => !selectedDate.isBefore(r.startDate) && !selectedDate.isAfter(r.endDate))
        .toList();
    final monthForView = selectedMonth ?? selectedDate.month;
    final monthStart = DateTime(selectedYear, monthForView, 1);
    final monthEnd = DateTime(selectedYear, monthForView + 1, 0);
    final monthRequestsExact = filteredRequests
        .where((r) => !(r.endDate.isBefore(monthStart) || r.startDate.isAfter(monthEnd)))
        .toList();
    final sortedAll = [...filteredRequests]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demandes (toutes) • En attente: ${pending.length}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: sortedAll.isEmpty
                      ? const Center(child: Text('Aucune demande'))
                      : ListView.builder(
                          itemCount: sortedAll.length,
                          itemBuilder: (context, i) => _LeaveRequestCard(
                            req: sortedAll[i],
                            isAdmin: true,
                            onApprove: onApprove,
                            onReject: onReject,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: ListView(
              children: [
                Row(
                  children: [
                    const Text('Vue calendrier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    DropdownButton<int>(
                      value: selectedYear,
                      items: List.generate(5, (i) => selectedYear - 2 + i)
                          .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) onYearChanged(v);
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Types de congé (Admin)',
                      icon: const Icon(Icons.category_outlined),
                      onPressed: () => _showLeaveTypeManagerDialog(context),
                    ),
                    IconButton(
                      tooltip: 'Créer et approuver (Admin)',
                      icon: const Icon(Icons.add_task_outlined),
                      onPressed: () => _showAdminCreateApproveDialog(context),
                    ),
                  ],
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _LargeLeaveCalendar(
                      year: selectedYear,
                      month: monthForView,
                      selectedDate: selectedDate,
                      requests: monthRequestsExact,
                      onDateChanged: onDateChanged,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('Tous: ${yearRequests.length}'),
                          selected: selectedMonth == null,
                          onSelected: (_) => onMonthChanged(null),
                        ),
                      ),
                      ...List.generate(12, (i) => i + 1).map((m) {
                        final mStart = DateTime(selectedYear, m, 1);
                        final mEnd = DateTime(selectedYear, m + 1, 0);
                        final monthReq = yearRequests.where((r) => !(r.endDate.isBefore(mStart) || r.startDate.isAfter(mEnd))).length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$m: $monthReq'),
                            selected: selectedMonth == m,
                            onSelected: (_) => onMonthChanged(m),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedMonth == null
                      ? 'Filtre actif: Tous les mois (${filteredRequests.length})'
                      : 'Filtre actif: Mois $selectedMonth (${filteredRequests.length})',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 240,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: onSelectedDayFiltered.isNotEmpty
                          ? ListView(
                              children: onSelectedDayFiltered
                                  .map((r) => ListTile(
                                        dense: true,
                                        title: Text(r.employeeName),
                                        subtitle: Text('${r.leaveTypeLabel} • ${r.equipeName} • ${r.chefName} • Du ${fmt(r.startDate)} au ${fmt(r.endDate)}'),
                                        trailing: Text(r.status.label, style: TextStyle(color: r.status.color)),
                                      ))
                                  .toList(),
                            )
                          : filteredRequests.isNotEmpty
                              ? ListView(
                                  children: [
                                    const ListTile(
                                      dense: true,
                                      title: Text(
                                        'Aucun congé sur la date sélectionnée',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      subtitle: Text('Aperçu des congés du filtre actif'),
                                    ),
                                    ...filteredRequests.take(8).map(
                                          (r) => ListTile(
                                            dense: true,
                                            leading: Icon(Icons.event_note, color: r.status.color, size: 18),
                                            title: Text('${r.employeeName} • ${r.equipeName}'),
                                            subtitle: Text('Du ${fmt(r.startDate)} au ${fmt(r.endDate)}'),
                                            trailing: Text(
                                              r.status.label,
                                              style: TextStyle(color: r.status.color, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ),
                                  ],
                                )
                              : const Center(
                                  child: Text('Aucun congé disponible pour ce filtre'),
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLeaveTypeManagerDialog(BuildContext context) async {
    final labelCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateD) {
          return AlertDialog(
            title: const Text('Types de congé'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Libellé du type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                      onPressed: () async {
                        final text = labelCtrl.text.trim();
                        if (text.isEmpty) return;
                        await FirebaseFirestore.instance.collection('leave_types').add({
                          'label': text,
                          'actif': true,
                          'createdAt': Timestamp.now(),
                        });
                        labelCtrl.clear();
                        setStateD(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Types actifs', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('leave_types')
                        .where('actif', isEqualTo: true)
                        .snapshots(),
                    builder: (ctx, snap) {
                      final docs = snap.data?.docs ?? const [];
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Aucun type'),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: docs.length,
                        itemBuilder: (ctx, i) {
                          final d = docs[i];
                          final m = d.data();
                          final label = (m['label'] as String?)?.trim() ?? '';
                          return ListTile(
                            dense: true,
                            title: Text(label.isEmpty ? d.id : label),
                            trailing: IconButton(
                              tooltip: 'Désactiver',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('leave_types').doc(d.id).update({
                                  'actif': false,
                                });
                                setStateD(() {});
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAdminCreateApproveDialog(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();
    String? employeeId;
    String? selectedTeamId;
    String? leaveTypeId;
    List<_LeaveType> leaveTypes = const [];

    final activeEmployees = employees.where((e) {
      final acquired = leaveDaysAcquired(e.dateDebut);
      final remaining = (acquired - e.leaveDaysTaken).clamp(0.0, double.infinity);
      return remaining > 0;
    }).toList();
    String? teamIdForEmployee(String employeId) {
      final team = equipes.where((q) => q.chefId == employeId || q.membreIds.contains(employeId)).toList();
      return team.isNotEmpty ? team.first.id : null;
    }
    String teamNameForEmployee(String employeId) {
      final team = equipes.where((q) => q.chefId == employeId || q.membreIds.contains(employeId)).toList();
      return team.isNotEmpty ? team.first.nom : 'Sans équipe';
    }
    if (activeEmployees.isNotEmpty) {
      employeeId = activeEmployees.first.id;
      selectedTeamId = teamIdForEmployee(employeeId) ?? '__no_team__';
    }

    final snap = await FirebaseFirestore.instance.collection('leave_types').where('actif', isEqualTo: true).get();
    leaveTypes = snap.docs
        .map((d) => _LeaveType(
              id: d.id,
              label: ((d.data()['label'] as String?) ?? '').trim().isEmpty ? 'Congé' : (d.data()['label'] as String).trim(),
            ))
        .toList();
    if (leaveTypes.isEmpty) leaveTypes = const [_LeaveType(id: 'default', label: 'Congé')];
    leaveTypeId = leaveTypes.first.id;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final filteredEmployees = activeEmployees.where((e) {
            final eTeamId = teamIdForEmployee(e.id) ?? '__no_team__';
            if (selectedTeamId == null) return true;
            return eTeamId == selectedTeamId;
          }).toList();
          if (filteredEmployees.isEmpty) {
            employeeId = null;
          } else if (employeeId == null || !filteredEmployees.any((e) => e.id == employeeId)) {
            employeeId = filteredEmployees.first.id;
          }

          Employe? selected;
          if (employeeId != null) {
            final list = filteredEmployees.where((e) => e.id == employeeId).toList();
            if (list.isNotEmpty) selected = list.first;
          }
          final remaining = selected == null
              ? 0.0
              : (leaveDaysAcquired(selected.dateDebut) - selected.leaveDaysTaken).clamp(0.0, double.infinity);
          final selectedTeamName = selected == null ? '-' : teamNameForEmployee(selected.id);
          return AlertDialog(
            title: const Text('Créer et approuver un congé'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String?>(
                      value: selectedTeamId,
                      decoration: const InputDecoration(labelText: 'Filtre équipe', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Toutes les équipes')),
                        ...equipes.map((q) => DropdownMenuItem<String?>(value: q.id, child: Text(q.nom))),
                        const DropdownMenuItem<String?>(value: '__no_team__', child: Text('Sans équipe')),
                      ],
                      onChanged: (v) => setS(() => selectedTeamId = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: employeeId,
                      decoration: const InputDecoration(labelText: 'Employé', border: OutlineInputBorder()),
                      items: filteredEmployees
                          .map((e) {
                            final rem = (leaveDaysAcquired(e.dateDebut) - e.leaveDaysTaken).clamp(0.0, double.infinity);
                            return DropdownMenuItem<String?>(value: e.id, child: Text('${e.nom} (${rem.toStringAsFixed(1)}j restant)'));
                          })
                          .toList(),
                      onChanged: (v) => setS(() => employeeId = v),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Équipe: $selectedTeamName  •  Solde restant: ${remaining.toStringAsFixed(1)}j',
                        style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: start,
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (d != null) setS(() => start = DateTime(d.year, d.month, d.day));
                            },
                            child: Text('Du: ${start.day}/${start.month}/${start.year}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: end,
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (d != null) setS(() => end = DateTime(d.year, d.month, d.day));
                            },
                            child: Text('Au: ${end.day}/${end.month}/${end.year}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: leaveTypeId,
                      decoration: const InputDecoration(labelText: 'Type de congé', border: OutlineInputBorder()),
                      items: leaveTypes.map((t) => DropdownMenuItem<String?>(value: t.id, child: Text(t.label))).toList(),
                      onChanged: (v) => setS(() => leaveTypeId = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(labelText: 'Motif', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  if (employeeId == null || leaveTypeId == null || end.isBefore(start) || reasonCtrl.text.trim().isEmpty) return;
                  final emp = filteredEmployees.firstWhere((e) => e.id == employeeId);
                  final lt = leaveTypes.firstWhere((t) => t.id == leaveTypeId);
                  Navigator.pop(ctx);
                  await onCreateApprovedByAdmin(
                    emp,
                    start,
                    end,
                    lt.id,
                    lt.label,
                    reasonCtrl.text.trim(),
                    '',
                  );
                },
                child: const Text('Créer + Approuver'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChefLeaveForm extends StatefulWidget {
  final Future<void> Function(LeaveRequest req) onCreate;
  const _ChefLeaveForm({required this.onCreate});

  @override
  State<_ChefLeaveForm> createState() => _ChefLeaveFormState();
}

class _LargeLeaveCalendar extends StatelessWidget {
  final int year;
  final int month;
  final DateTime selectedDate;
  final List<LeaveRequest> requests;
  final ValueChanged<DateTime> onDateChanged;

  const _LargeLeaveCalendar({
    required this.year,
    required this.month,
    required this.selectedDate,
    required this.requests,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    const weekLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final offset = firstDay.weekday - 1; // Monday start
    final cells = <Widget>[];

    for (var i = 0; i < offset; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final dayDate = DateTime(year, month, d);
      final dayReq = requests.where((r) => !dayDate.isBefore(r.startDate) && !dayDate.isAfter(r.endDate)).toList();
      Color bg = Colors.white;
      if (dayReq.any((r) => r.status == LeaveStatus.approved)) {
        bg = const Color(0xFFE3F2FD);
      } else if (dayReq.any((r) => r.status == LeaveStatus.pending)) {
        bg = const Color(0xFFFFF3E0);
      } else if (dayReq.any((r) => r.status == LeaveStatus.rejected)) {
        bg = const Color(0xFFFFEBEE);
      }
      final selected = selectedDate.year == year && selectedDate.month == month && selectedDate.day == d;
      cells.add(
        InkWell(
          onTap: () => onDateChanged(dayDate),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: selected ? Colors.blue.shade100 : bg,
              border: Border.all(color: selected ? Colors.blue : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$d', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                const SizedBox(height: 1),
                if (dayReq.isNotEmpty)
                  Expanded(
                    child: Text(
                      '${dayReq.first.employeeName} (${dayReq.first.startDate.day}/${dayReq.first.startDate.month}-${dayReq.first.endDate.day}/${dayReq.first.endDate.month})',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8.5, height: 1.05),
                    ),
                  ),
                if (dayReq.length > 1)
                  Text(
                    '+${dayReq.length - 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: weekLabels
              .map((w) => Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(w, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ))
              .toList(),
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          children: cells,
        ),
      ],
    );
  }
}

class _ChefLeaveFormState extends State<_ChefLeaveForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  String? _employeeId;
  String? _adminId;
  List<_AdminRecipient> _admins = const [];
  bool _loadingAdmins = true;
  List<_LeaveType> _leaveTypes = const [];
  String? _leaveTypeId;
  bool _loadingLeaveTypes = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
    _loadLeaveTypes();
  }

  Future<void> _loadAdmins() async {
    final snap = await FirebaseFirestore.instance
        .collection('admins')
        .where('actif', isEqualTo: true)
        .get();
    final list = snap.docs.map((d) {
      final m = d.data();
      return _AdminRecipient(
        id: d.id,
        name: '${m['prenom'] ?? ''} ${m['nom'] ?? ''}'.trim(),
        email: m['email'] as String? ?? '',
      );
    }).toList();
    if (mounted) {
      setState(() {
        _admins = list;
        _adminId = list.isNotEmpty ? list.first.id : null;
        _loadingAdmins = false;
      });
    }
  }

  Future<void> _loadLeaveTypes() async {
    final snap = await FirebaseFirestore.instance
        .collection('leave_types')
        .where('actif', isEqualTo: true)
        .get();
    final list = snap.docs.map((d) {
      final m = d.data();
      return _LeaveType(
        id: d.id,
        label: (m['label'] as String?)?.trim().isNotEmpty == true ? (m['label'] as String).trim() : 'Congé',
      );
    }).toList();
    if (!mounted) return;
    setState(() {
      _leaveTypes = list.isNotEmpty ? list : const [_LeaveType(id: 'default', label: 'Congé')];
      _leaveTypeId = (_leaveTypes.isNotEmpty) ? _leaveTypes.first.id : null;
      _loadingLeaveTypes = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final empProv = context.watch<EmployeesProvider>();
    final equipe = _resolveEquipe(auth, empProv);
    final employeesRaw = _resolveTeamEmployees(equipe, empProv, auth);
    final employeesUnique = <String, Employe>{for (final e in employeesRaw) e.id: e}.values.toList();
    final employeesEligible = employeesUnique.where((e) {
      final acquired = leaveDaysAcquired(e.dateDebut);
      final remaining = (acquired - e.leaveDaysTaken).clamp(0.0, double.infinity);
      return remaining > 0;
    }).toList();
    if (employeesEligible.isEmpty) {
      _employeeId = null;
    } else if (_employeeId == null || !employeesEligible.any((e) => e.id == _employeeId)) {
      _employeeId = employeesEligible.first.id;
    }

    final adminsUnique = <String, _AdminRecipient>{for (final a in _admins) a.id: a}.values.toList();
    if (adminsUnique.isEmpty) {
      _adminId = null;
    } else if (_adminId == null || !adminsUnique.any((a) => a.id == _adminId)) {
      _adminId = adminsUnique.first.id;
    }
    Employe? selectedEmployee;
    if (_employeeId != null) {
      final selected = employeesEligible.where((e) => e.id == _employeeId).toList();
      if (selected.isNotEmpty) selectedEmployee = selected.first;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nouvelle demande de congé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _employeeId,
                        decoration: const InputDecoration(labelText: 'Employé concerné', border: OutlineInputBorder()),
                        items: employeesEligible
                            .map((e) {
                              final rem = (leaveDaysAcquired(e.dateDebut) - e.leaveDaysTaken).clamp(0.0, double.infinity);
                              return DropdownMenuItem<String?>(value: e.id, child: Text('${e.nom} (${rem.toStringAsFixed(1)}j)'));
                            })
                            .toList(),
                        onChanged: (v) => setState(() => _employeeId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _loadingAdmins
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<String?>(
                              value: _adminId,
                              decoration: const InputDecoration(labelText: 'Admin destinataire', border: OutlineInputBorder()),
                              items: adminsUnique
                                  .map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name.isEmpty ? a.email : a.name)))
                                  .toList(),
                              onChanged: (v) => setState(() => _adminId = v),
                            ),
                    ),
                  ],
                ),
                if (employeesEligible.isEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Aucun employé avec solde de congé disponible.',
                      style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (selectedEmployee != null) ...[
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final emp = selectedEmployee!;
                      return Consumer<CongesProvider>(
                        builder: (context, conges, _) {
                          final cachedTaken = conges.getCachedDaysTaken(emp.id);
                          if (cachedTaken == null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              conges.loadDaysTaken(emp.id);
                            });
                            return const LinearProgressIndicator();
                          }
                          final acquired = leaveDaysAcquired(emp.dateDebut);
                          final remaining = (acquired - cachedTaken).clamp(0.0, double.infinity);
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Text(
                              'Solde congé (${emp.nom}) - Autorisé: ${acquired.toStringAsFixed(1)}j • Pris: ${cachedTaken.toStringAsFixed(1)}j • Restant: ${remaining.toStringAsFixed(1)}j',
                              style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _dateField(context, 'Du', _start, (d) => setState(() => _start = d))),
                    const SizedBox(width: 8),
                    Expanded(child: _dateField(context, 'Au', _end, (d) => setState(() => _end = d))),
                  ],
                ),
                const SizedBox(height: 10),
                _loadingLeaveTypes
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<String?>(
                        value: _leaveTypeId,
                        decoration: const InputDecoration(
                          labelText: 'Type de congé',
                          border: OutlineInputBorder(),
                        ),
                        items: _leaveTypes
                            .map((t) => DropdownMenuItem<String?>(
                                  value: t.id,
                                  child: Text(t.label),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _leaveTypeId = v),
                      ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Motif', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _detailsCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Détails professionnels (remplacement, contexte, tâches)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_saving || employeesEligible.isEmpty) ? null : () => _submit(context, equipe, employeesEligible),
                    icon: _saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(_saving ? 'Envoi...' : 'Envoyer la demande'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Equipe? _resolveEquipe(AuthProvider auth, EmployeesProvider emps) {
    final id = auth.equipeId;
    if (id != null && id.isNotEmpty) {
      final list = emps.equipes.where((e) => e.id == id).toList();
      if (list.isNotEmpty) return list.first;
    }
    return null;
  }

  List<Employe> _resolveTeamEmployees(Equipe? equipe, EmployeesProvider emps, AuthProvider auth) {
    if (equipe == null) {
      return [
        Employe(
          id: auth.currentUser?.id ?? 'self',
          nom: auth.currentUser?.nom ?? 'Chef',
          cin: '',
          telephone: '',
          dateNaissance: '',
          adresse: '',
          email: auth.currentUser?.username ?? '',
          poste: 'Chef',
          magasin: '',
          departement: '',
          salaireBase: 0,
          typeContrat: '',
          dateDebut: '',
          cnss: '',
          dateCnss: '',
          statut: EmployeStatut.enService,
        ),
      ];
    }
    final ids = <String>{equipe.chefId, ...equipe.membreIds};
    return emps.employes.where((e) => ids.contains(e.id)).toList();
  }

  Widget _dateField(BuildContext context, String label, DateTime value, ValueChanged<DateTime> onPick) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 730)),
        );
        if (picked != null) onPick(DateTime(picked.year, picked.month, picked.day));
      },
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text('$label: ${value.day}/${value.month}/${value.year}'),
    );
  }

  Future<void> _submit(BuildContext context, Equipe? equipe, List<Employe> employees) async {
    if (!_formKey.currentState!.validate()) return;
    if (_employeeId == null || _adminId == null) return;
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La date de fin doit être >= date début')));
      return;
    }
    final auth = context.read<AuthProvider>();
    final employee = employees.firstWhere((e) => e.id == _employeeId);
    final admin = _admins.firstWhere((a) => a.id == _adminId);
    final equipeId = equipe?.id ?? (auth.equipeId ?? '');
    final equipeName = equipe?.nom ?? 'Équipe non définie';
    final chefName = auth.currentUser?.nom ?? '';
    if (_leaveTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez choisir un type de congé.')));
      return;
    }
    final leaveType = _leaveTypes.where((t) => t.id == _leaveTypeId).toList();
    final selectedType = leaveType.isNotEmpty ? leaveType.first : (_leaveTypes.isNotEmpty ? _leaveTypes.first : null);
    if (selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun type de congé disponible.')));
      return;
    }
    final leaveTypeId = selectedType.id;
    final leaveTypeLabel = selectedType.label;

    // Full-day leave by default (no manual time selection).
    final startAt = DateTime(_start.year, _start.month, _start.day, 0, 0);
    final endAt = DateTime(_end.year, _end.month, _end.day, 23, 59);
    final requestedDays = (DateTime(_end.year, _end.month, _end.day)
                .difference(DateTime(_start.year, _start.month, _start.day))
                .inDays +
            1)
        .toDouble();
    final conges = context.read<CongesProvider>();
    final taken = await conges.getDaysTaken(employee.id, refresh: true);
    final acquired = leaveDaysAcquired(employee.dateDebut);
    final remaining = (acquired - taken).clamp(0.0, double.infinity);
    if (requestedDays > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solde insuffisant: restant ${remaining.toStringAsFixed(1)}j, demandé ${requestedDays.toStringAsFixed(1)}j.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = _LeaveRepository();
    final hasConflict = await repo.hasTeamConflict(
      equipeId: equipeId,
      startAt: startAt,
      endAt: endAt,
    );
    if (hasConflict && mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conflit: un congé existe déjà sur cette période pour la même équipe.')),
      );
      return;
    }

    final req = LeaveRequest(
      id: '',
      employeeId: employee.id,
      employeeName: employee.nom,
      employeeCin: employee.cin,
      employeePoste: employee.poste,
      equipeId: equipeId,
      equipeName: equipeName,
      chefName: chefName,
      leaveTypeId: leaveTypeId,
      leaveTypeLabel: leaveTypeLabel,
      startDate: _start,
      endDate: _end,
      startAt: startAt,
      endAt: endAt,
      reason: _reasonCtrl.text.trim(),
      professionalDetails: _detailsCtrl.text.trim(),
      submittedByUserId: auth.currentUser?.id ?? '',
      submittedByName: auth.currentUser?.nom ?? '',
      assignedAdminId: admin.id,
      assignedAdminName: admin.name.isEmpty ? admin.email : admin.name,
      createdAt: DateTime.now(),
      status: LeaveStatus.pending,
    );
    await widget.onCreate(req);

    if (mounted) {
      setState(() => _saving = false);
      _reasonCtrl.clear();
      _detailsCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée avec succès')));
    }
  }
}

class _LeaveRequestCard extends StatelessWidget {
  final LeaveRequest req;
  final bool isAdmin;
  final Future<void> Function(LeaveRequest req, String comment)? onApprove;
  final Future<void> Function(LeaveRequest req, String comment)? onReject;

  const _LeaveRequestCard({
    required this.req,
    required this.isAdmin,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = (DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final isPending = req.status == LeaveStatus.pending;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${req.employeeName} • ${req.employeeCin} • ${req.equipeName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: req.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text(req.status.label, style: TextStyle(color: req.status.color, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Type: ${req.leaveTypeLabel}'),
            Text('Chef: ${req.chefName}'),
            Text('Période: ${fmt(req.startDate)} -> ${fmt(req.endDate)}'),
            Text('Motif (texte): ${req.reason}'),
            if (req.professionalDetails.isNotEmpty) Text('Détails: ${req.professionalDetails}'),
            Text('Soumis par: ${req.submittedByName}'),
            Text('Admin destinataire: ${req.assignedAdminName}'),
            if (req.adminComment != null && req.adminComment!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Commentaire admin: ${req.adminComment}'),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (req.isApproved && req.approvedPdf != null)
                  OutlinedButton.icon(
                    onPressed: () async => _downloadPdf(context),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(isAdmin ? 'Télécharger PDF (Admin)' : 'Télécharger PDF'),
                  ),
                if (isAdmin && isPending) ...[
                  FilledButton.icon(
                    onPressed: () async {
                      final c = await _askComment(context, title: 'Approuver la demande');
                      if (c == null) return;
                      await onApprove?.call(req, c);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Approuver'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final c = await _askComment(context, title: 'Refuser la demande', requiredComment: true);
                      if (c == null) return;
                      await onReject?.call(req, c);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Refuser'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askComment(
    BuildContext context, {
    required String title,
    bool requiredComment = false,
  }) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: requiredComment ? 'Commentaire obligatoire' : 'Commentaire (optionnel)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (requiredComment && text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    final bytes = req.approvedPdf;
    if (bytes == null || bytes.isEmpty) return;

    final safeEmployee = req.employeeName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'conge_${safeEmployee}_${req.startDate.year}${req.startDate.month.toString().padLeft(2, '0')}${req.startDate.day.toString().padLeft(2, '0')}.pdf';

    try {
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
        return;
      }

      var savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le PDF du congé',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (savePath == null || savePath.trim().isEmpty) return;
      if (!savePath.toLowerCase().endsWith('.pdf')) {
        savePath = '$savePath.pdf';
      }

      final outFile = File(savePath);
      await outFile.writeAsBytes(bytes, flush: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF enregistré: $savePath')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec du téléchargement PDF: $e')),
        );
      }
    }
  }
}
