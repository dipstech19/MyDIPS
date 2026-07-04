import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/utils/responsive.dart';
import '../employees/conges_provider.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart';
import '../employees/models/equipe_model.dart';
import '../pointage/pointage_provider.dart';
import '../pointage/models/pointage_model.dart';
import '../distribution/distribution_groups_provider.dart';
import '../groupes/groupes_provider.dart';
import '../groupes/models/groupe_model.dart';

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
  /// Motif par défaut associé à ce type (pré-rempli automatiquement)
  final String defaultReason;
  const _LeaveType({required this.id, required this.label, this.defaultReason = ''});
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
  final String role;

  const _AdminRecipient({required this.id, required this.name, required this.email, required this.role});
}

enum _LeaveRequestBlockReason { pendingExists, approvedSameMonthExists }

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

  /// Business rule for new leave request of same employee:
  /// - Block if any pending request exists (until approved/rejected).
  /// - Block if an approved request exists in the same month range.
  Future<_LeaveRequestBlockReason?> blockReasonForEmployeeNewRequest({
    required String employeeId,
    required DateTime startAt,
    required DateTime endAt,
    String? excludeRequestId,
  }) async {
    final snap = await _db.collection(_collection).where('employeeId', isEqualTo: employeeId).get();
    final startMonth = DateTime(startAt.year, startAt.month, 1);
    final endMonth = DateTime(endAt.year, endAt.month, 1);
    for (final d in snap.docs) {
      if (excludeRequestId != null && d.id == excludeRequestId) continue;
      final req = LeaveRequest.fromDoc(d);
      if (req.status == LeaveStatus.pending) {
        return _LeaveRequestBlockReason.pendingExists;
      }
      if (req.status == LeaveStatus.rejected) continue;
      if (req.status != LeaveStatus.approved) continue;
      final reqStartMonth = DateTime(req.startDate.year, req.startDate.month, 1);
      final reqEndMonth = DateTime(req.endDate.year, req.endDate.month, 1);
      final overlap = !(reqEndMonth.isBefore(startMonth) || reqStartMonth.isAfter(endMonth));
      if (overlap) return _LeaveRequestBlockReason.approvedSameMonthExists;
    }
    return null;
  }
}

class DemandesPage extends StatefulWidget {
  final UserRole role;
  const DemandesPage({super.key, required this.role});

  @override
  State<DemandesPage> createState() => _DemandesPageState();
}

class _DemandesPageState extends State<DemandesPage>
    with AutomaticKeepAliveClientMixin {
  static const Duration _decisionEditWindow = Duration(hours: 24);
  final _repo = _LeaveRepository();
  DateTime _selectedCalendarDate = DateTime.now();
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth;

  // Le stream est stocké en tant que variable d'état pour éviter
  // de recréer un nouvel abonnement à chaque rebuild du widget.
  late final Stream<List<LeaveRequest>> _requestsStream;

  // Cache local des dernières données reçues — permet d'afficher
  // instantanément les données sans attendre le prochain événement Firestore.
  List<LeaveRequest> _cachedRequests = const [];

  @override
  bool get wantKeepAlive => true;

  bool _canEditDecision(LeaveRequest req) {
    final auth = context.read<AuthProvider>();
    if (auth.isDirecteur) return true;
    if (req.status == LeaveStatus.pending) return true;
    final decidedAt = req.decidedAt;
    if (decidedAt == null) return false;
    return DateTime.now().difference(decidedAt) <= _decisionEditWindow;
  }

  _LeaveRequestBlockReason? _blockReasonFromCachedRequests(LeaveRequest req) {
    final startMonth = DateTime(req.startDate.year, req.startDate.month, 1);
    final endMonth = DateTime(req.endDate.year, req.endDate.month, 1);
    for (final r in _cachedRequests) {
      if (r.employeeId != req.employeeId) continue;
      if (r.status == LeaveStatus.pending) {
        return _LeaveRequestBlockReason.pendingExists;
      }
      if (r.status != LeaveStatus.approved) continue;
      final rs = DateTime(r.startDate.year, r.startDate.month, 1);
      final re = DateTime(r.endDate.year, r.endDate.month, 1);
      final overlap = !(re.isBefore(startMonth) || rs.isAfter(endMonth));
      if (overlap) return _LeaveRequestBlockReason.approvedSameMonthExists;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _requestsStream = _repo.watchRequests();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // requis par AutomaticKeepAliveClientMixin
    final auth = context.watch<AuthProvider>();
    final empProv = context.watch<EmployeesProvider>();
    final isAdmin = widget.role == UserRole.administrateur;

    return StreamBuilder<List<LeaveRequest>>(
      stream: _requestsStream,
      initialData: _cachedRequests,
      builder: (context, snap) {
        if (snap.hasData) _cachedRequests = snap.data!;
        final requests = snap.data ?? const <LeaveRequest>[];
        final filtered = isAdmin
            ? _adminViewRequests(auth, requests)
            : requests.where((r) {
                final own = auth.userId != null && auth.userId!.isNotEmpty && r.submittedByUserId == auth.userId;
                final sameEquipe = auth.equipeId != null && auth.equipeId!.isNotEmpty && r.equipeId == auth.equipeId;
                return own || sameEquipe;
              }).toList();

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
                      onCreatePendingSelf: (r) => _createPendingByChef(context, r),
                      onApprove: (r, comment) => _approveRequest(context, r, comment),
                      onReject: (r, comment) => _rejectRequest(context, r, comment),
                    )
                  : _ChefLeaveView(
                      requests: filtered,
                      onCreate: (r) => _createPendingByChef(context, r),
                    ),
            ),
          ],
        );
      },
    );
  }

  List<LeaveRequest> _adminViewRequests(AuthProvider auth, List<LeaveRequest> all) {
    // Super/top admin keeps full visibility.
    if (auth.isSuperAdmin || auth.adminRole.contains('général') || auth.adminRole.contains('general')) {
      return all;
    }
    // Chef d'atelier must keep approval page for workers + chefs d'équipe requests.
    if (auth.isChefAtelierAdmin) {
      return all.where((r) {
        final p = r.employeePoste.trim().toLowerCase();
        final isZoneOrRh =
            p.contains('chef de zone') || p.contains('chef zone') || p == 'rh' || p.contains('ressource');
        final isDistribution = p.contains('distribution') || p.contains('distri') || p.contains('livreur');
        return !isZoneOrRh && !isDistribution;
      }).toList();
    }
    if (auth.isChefZoneAdmin) {
      final uid = auth.userId;
      if (uid == null || uid.isEmpty) return const <LeaveRequest>[];
      // Chef de zone should only see requests explicitly assigned to him.
      return all.where((r) => r.assignedAdminId == uid).toList();
    }
    final uid = auth.userId;
    if (uid == null || uid.isEmpty) return all;
    // Role-based approvers (atelier/zone/rh) see requests assigned to them.
    return all.where((r) => r.assignedAdminId == uid).toList();
  }

  Widget _header(bool isAdmin, List<LeaveRequest> requests) {
    final pending = requests.where((r) => r.status == LeaveStatus.pending).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          Icon(isAdmin ? Icons.admin_panel_settings : Icons.assignment, color: AppColors.brand),
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

  /// Identifiant « équipe » pour congés / pointage : id d’[Equipe] ou `groupe:<id>` pour un [Groupe] (ex. équipe normale).
  String _deriveLeaveEquipeIdForEmployee(Employe e, List<Equipe> equipes, List<Groupe> groupes) {
    final direct = equipes.where((q) => q.chefId == e.id || q.membreIds.contains(e.id)).toList();
    if (direct.isNotEmpty) return direct.first.id;
    final g = groupes.where((gr) => gr.membreIds.contains(e.id)).toList();
    if (g.isNotEmpty) return 'groupe:${g.first.id}';
    return '';
  }

  String _deriveLeaveEquipeNameForEmployee(Employe e, List<Equipe> equipes, List<Groupe> groupes) {
    final direct = equipes.where((q) => q.chefId == e.id || q.membreIds.contains(e.id)).toList();
    if (direct.isNotEmpty) return direct.first.nom;
    final g = groupes.where((gr) => gr.membreIds.contains(e.id)).toList();
    if (g.isNotEmpty) return g.first.nom;
    return 'Équipe non définie';
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

    final startAt = DateTime(start.year, start.month, start.day, 0, 0);
    final endAt = DateTime(end.year, end.month, end.day, 23, 59);
    final groupes = context.read<GroupesProvider>().groupes;
    final equipeId = _deriveLeaveEquipeIdForEmployee(employee, empProv.equipes, groupes);
    final equipeName = _deriveLeaveEquipeNameForEmployee(employee, empProv.equipes, groupes);

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
    final pdf = await _buildApprovedLeavePdf(
      baseReq,
      adminName,
      resolvedChefName: _resolveChefNameForPdf(baseReq, empProv.equipes, empProv.employes),
    );
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

  Future<void> _createPendingByChef(BuildContext context, LeaveRequest req) async {
    // Fast path: local cache check (no network).
    _LeaveRequestBlockReason? blockReason = _blockReasonFromCachedRequests(req);
    // Fallback: if no local data available, query backend.
    if (blockReason == null && _cachedRequests.isEmpty) {
      blockReason = await _repo.blockReasonForEmployeeNewRequest(
        employeeId: req.employeeId,
        startAt: req.startDate,
        endAt: req.endDate,
      );
    }
    if (blockReason != null) {
      if (context.mounted) {
        final msg = blockReason == _LeaveRequestBlockReason.pendingExists
            ? 'Impossible: une demande de ce collaborateur est déjà en attente.'
            : 'Impossible: ce collaborateur a déjà une demande approuvée dans ce mois.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    // Optimistic UI insert for instant feedback on weak networks.
    if (mounted) {
      setState(() {
        _cachedRequests = [req, ..._cachedRequests];
      });
    }
    // Pending request should be saved immediately; PDF is only needed on decision.
    await _repo.create(req);
  }

  Future<void> _approveRequest(BuildContext context, LeaveRequest req, String comment) async {
    if (!_canEditDecision(req)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de modifier après 24h.')),
        );
      }
      return;
    }
    final auth = context.read<AuthProvider>();
    final empProv = context.read<EmployeesProvider>();
    if (req.status == LeaveStatus.approved) return;
    final employee = empProv.employes.where((e) => e.id == req.employeeId).toList();
    if (employee.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employé introuvable. Vérifiez la demande avant approbation.')),
        );
      }
      return;
    }
    final pdf = await _buildApprovedLeavePdf(
      req,
      auth.currentUser?.nom ?? 'Administrateur',
      decisionStatus: LeaveStatus.approved,
      resolvedChefName: _resolveChefNameForPdf(req, empProv.equipes, empProv.employes),
    );
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

      final days = req.endDate.difference(req.startDate).inDays + 1;
      await context.read<CongesProvider>().addDaysTaken(req.employeeId, days.toDouble());
    }
  }

  Future<void> _rejectRequest(BuildContext context, LeaveRequest req, String comment) async {
    if (!_canEditDecision(req)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de modifier après 24h.')),
        );
      }
      return;
    }
    final auth = context.read<AuthProvider>();
    final empProv = context.read<EmployeesProvider>();
    if (req.status == LeaveStatus.rejected) return;
    final pdf = await _buildApprovedLeavePdf(
      req,
      auth.currentUser?.nom ?? 'Administrateur',
      decisionStatus: LeaveStatus.rejected,
      resolvedChefName: _resolveChefNameForPdf(req, empProv.equipes, empProv.employes),
    );
    await _repo.updateDecision(
      req: req,
      newStatus: LeaveStatus.rejected,
      adminId: auth.currentUser?.id ?? '',
      adminName: auth.currentUser?.nom ?? '',
      comment: comment.trim().isEmpty ? 'Demande refusée' : comment.trim(),
      approvedPdf: pdf,
    );

    // If this request was previously approved, rollback leave effects.
    if (req.status == LeaveStatus.approved) {
      final pointageProvider = context.read<PointageProvider>();
      final conges = context.read<CongesProvider>();
      final employee = empProv.employes.where((e) => e.id == req.employeeId).toList();
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
            status: AttendanceStatus.unmarked,
            viewDate: d,
          );
        }
      }
      final days = req.endDate.difference(req.startDate).inDays + 1;
      await conges.addDaysTaken(req.employeeId, -days.toDouble());
    }
  }

  Future<Uint8List> _buildApprovedLeavePdf(
    LeaveRequest req,
    String adminName, {
    LeaveStatus decisionStatus = LeaveStatus.approved,
    String? resolvedChefName,
  }) async {
    final pdf = pw.Document();
    final fmt = (DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final days = req.endDate.difference(req.startDate).inDays + 1;
    final logoBytes = await _loadLogoBytes();
    final decidedAt = req.decidedAt ?? DateTime.now();
    final isApproved = decisionStatus == LeaveStatus.approved;
    final isRejected = decisionStatus == LeaveStatus.rejected;
    final isPendingDecision = decisionStatus == LeaveStatus.pending;
    final employeePoste = req.employeePoste.trim().isEmpty ? '-' : req.employeePoste.trim();
    final isChefAtelierRequester =
        employeePoste.toLowerCase().contains('chef atelier') ||
        employeePoste.toLowerCase().contains('chef d\'atelier') ||
        employeePoste.toLowerCase().contains('chef datelier');

    final employeeName  = req.employeeName.trim().isEmpty  ? '-' : req.employeeName.trim();
    final employeeCin   = req.employeeCin.trim().isEmpty   ? '-' : req.employeeCin.trim();
    final chefNameRaw   = (resolvedChefName ?? req.chefName).trim();
    final chefName      = chefNameRaw.isEmpty ? '-' : chefNameRaw;
    final equipeName    = req.equipeName.trim().isEmpty    ? '-' : req.equipeName.trim();
    final adminComment  = (req.adminComment ?? '').trim().isEmpty ? '' : req.adminComment!.trim();
    final reason        = req.reason.trim().isEmpty        ? '-' : req.reason.trim();
    final leaveType     = req.leaveTypeLabel.trim().isEmpty ? 'Congé' : req.leaveTypeLabel.trim();

    final daysLabel = '$days jour${days > 1 ? 's' : ''}';
    final startLabel = fmt(req.startDate);
    final endLabel = fmt(req.endDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 44, vertical: 36),
        build: (ctx) {
          // ── helpers ────────────────────────────────────────────────
          pw.Widget _signBox(
            String title, {
            required String name,
            required String date,
            required bool signed,
            required PdfColor accent,
          }) =>
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(10, 10, 10, 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        title,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: signed ? accent.shade(0.12) : PdfColors.grey200,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                          border: pw.Border.all(
                            color: signed ? accent : PdfColors.grey500,
                            width: 0.6,
                          ),
                        ),
                        child: pw.Text(
                          signed ? '[X] Signé' : '[ ] En attente',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: signed ? accent : PdfColors.grey700,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Divider(color: PdfColors.grey500, thickness: 0.5),
                      pw.SizedBox(height: 4),
                      pw.Text(name, style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center),
                      pw.Text(date,
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                          textAlign: pw.TextAlign.center),
                    ],
                  ),
                ),
              );

          // ── page ───────────────────────────────────────────────────
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // ── en-tête ──────────────────────────────────────────
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoBytes != null) ...[
                    pw.Container(
                      width: 60, height: 60,
                      child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DIGITALIZATION, INNOVATION & PROCESS SIMULATION',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900)),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Adresse : Résidence REDA, 1ier Étage, N°6, Av. ANNAKHIL, El Jadida',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          'Tél.: 0523352515 – 0666282392   |   www.dips.ma',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('El Jadida le ${fmt(req.createdAt)}',
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColors.blue800, thickness: 1),
              pw.SizedBox(height: 12),

              // ── fiche employé ──────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoLine('Nom complet', employeeName),
                          pw.SizedBox(height: 3),
                          _infoLine('CIN', employeeCin),
                          pw.SizedBox(height: 3),
                          _infoLine('Poste', employeePoste),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoLine('Équipe', equipeName),
                          pw.SizedBox(height: 3),
                          _infoLine('Chef d\'équipe', isChefAtelierRequester ? '-' : chefName),
                          pw.SizedBox(height: 3),
                          _infoLine('Type de congé', leaveType),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // ── objet ──────────────────────────────────────────
              pw.Text('Objet : Demande de congé',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              // ── formule d'appel ────────────────────────────────
              pw.Text('Monsieur le Directeur,',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),

              // ── corps ──────────────────────────────────────────
              pw.RichText(
                textAlign: pw.TextAlign.justify,
                text: pw.TextSpan(
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                  children: [
                    const pw.TextSpan(
                      text: 'Je sollicite, par la présente, votre autorisation de bien vouloir m\'accorder ',
                    ),
                    pw.TextSpan(
                      text: daysLabel,
                      style: pw.TextStyle(color: PdfColors.blue800, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(text: ' de congé ($leaveType) pour la période du '),
                    pw.TextSpan(
                      text: startLabel,
                      style: pw.TextStyle(color: PdfColors.blue800, fontWeight: pw.FontWeight.bold),
                    ),
                    const pw.TextSpan(text: ' au '),
                    pw.TextSpan(
                      text: endLabel,
                      style: pw.TextStyle(color: PdfColors.blue800, fontWeight: pw.FontWeight.bold),
                    ),
                    const pw.TextSpan(text: ' inclus.\n\n'),
                    pw.TextSpan(text: 'Motif : $reason\n\n'),
                    const pw.TextSpan(
                      text: 'En vous remerciant à l\'avance pour votre compréhension, je vous prie de croire, '
                          'Monsieur le Directeur, en l\'expression de mes salutations distinguées.',
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // ── décision (si approuvée) ────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: isApproved
                      ? PdfColors.green50
                      : isRejected
                          ? PdfColors.red50
                          : PdfColors.grey100,
                  border: pw.Border.all(
                    color: isApproved
                        ? PdfColors.green400
                        : isRejected
                            ? PdfColors.red400
                            : PdfColors.grey500,
                    width: 0.8,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Décision : ',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          isApproved
                              ? '[X] Congé APPROUVÉ'
                              : isRejected
                                  ? '[X] Refusé'
                                  : '[ ] En attente de validation',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: isApproved
                                ? PdfColors.green800
                                : isRejected
                                    ? PdfColors.red800
                                    : PdfColors.grey800,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text('Période accordée : ',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          '${fmt(req.startDate)} - ${fmt(req.endDate)}  ($days jour${days > 1 ? 's' : ''})',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: isApproved
                                ? PdfColors.green800
                                : isRejected
                                    ? PdfColors.red800
                                    : PdfColors.grey800,
                          ),
                        ),
                      ],
                    ),
                    if (adminComment.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Remarque : ',
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Expanded(
                            child: pw.Text(adminComment,
                                style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text('Date de validation : ',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                          fmt(decidedAt),
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: isApproved
                                ? PdfColors.green800
                                : isRejected
                                    ? PdfColors.red800
                                    : PdfColors.grey800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ── 3 blocs de signature ───────────────────────────
              if (isChefAtelierRequester)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _signBox(
                      'Signature Chef d\'atelier',
                      name: employeeName,
                      date: 'Le ${fmt(req.createdAt)}',
                      signed: true,
                      accent: PdfColors.blue700,
                    ),
                    pw.SizedBox(width: 10),
                    _signBox(
                      'Validation (Chef zone / RH / Admin)',
                      name: isPendingDecision ? '' : adminName,
                      date: isPendingDecision ? '' : 'Le ${fmt(decidedAt)}',
                      signed: !isPendingDecision,
                      accent: isApproved ? PdfColors.green700 : PdfColors.red700,
                    ),
                  ],
                )
              else
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _signBox(
                      'Signature du demandeur',
                      name: employeeName,
                      date: 'Le ${fmt(req.createdAt)}',
                      signed: true,
                      accent: PdfColors.blue700,
                    ),
                    pw.SizedBox(width: 10),
                    _signBox(
                      'Visa Chef d\'équipe',
                      name: chefName,
                      date: 'Le ${fmt(req.createdAt)}',
                      signed: true,
                      accent: PdfColors.blue700,
                    ),
                    pw.SizedBox(width: 10),
                    _signBox(
                      'Validation Chef d\'atelier',
                      name: isPendingDecision ? '' : adminName,
                      date: isPendingDecision ? '' : 'Le ${fmt(decidedAt)}',
                      signed: !isPendingDecision,
                      accent: isApproved ? PdfColors.green700 : PdfColors.red700,
                    ),
                  ],
                ),

              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Text(
                'Document généré par le système DIPS Management  •  www.dips.ma',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  String _resolveChefNameForPdf(LeaveRequest req, List<Equipe> equipes, List<Employe> employes) {
    final rawChef = req.chefName.trim();
    final rawEquipe = req.equipeName.trim();
    final looksLikeEquipeName = rawChef.isNotEmpty && rawChef.toLowerCase() == rawEquipe.toLowerCase();
    if (rawChef.isNotEmpty && !looksLikeEquipeName) return rawChef;

    final eq = equipes.where((e) => e.id == req.equipeId).toList();
    if (eq.isNotEmpty && eq.first.chefId.isNotEmpty) {
      final chef = employes.where((e) => e.id == eq.first.chefId).toList();
      if (chef.isNotEmpty) return chef.first.nom;
    }

    final submittedBy = req.submittedByName.trim();
    if (submittedBy.isNotEmpty && submittedBy.toLowerCase() != rawEquipe.toLowerCase()) {
      return submittedBy;
    }
    return rawChef;
  }

  /// Ligne label: valeur pour la fiche employé en haut du PDF
  static pw.Widget _infoLine(String label, String value) => pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label : ',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(
              text: value,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      );

  Future<Uint8List?> _loadLogoBytes() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

}

class _ChefLeaveView extends StatefulWidget {
  final List<LeaveRequest> requests;
  final Future<void> Function(LeaveRequest req) onCreate;

  const _ChefLeaveView({required this.requests, required this.onCreate});

  @override
  State<_ChefLeaveView> createState() => _ChefLeaveViewState();
}

class _ChefLeaveViewState extends State<_ChefLeaveView> {
  late int _calYear;
  late int _calMonth;
  late DateTime _selectedCalDate;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _calYear = n.year;
    _calMonth = n.month;
    _selectedCalDate = DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.requests]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final monthStart = DateTime(_calYear, _calMonth, 1);
    final monthEnd = DateTime(_calYear, _calMonth + 1, 0);
    final monthRequestsExact = widget.requests
        .where((r) => !(r.endDate.isBefore(monthStart) || r.startDate.isAfter(monthEnd)))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChefLeaveForm(onCreate: widget.onCreate),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.calendar_month, size: 22, color: AppColors.brand),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Vue calendrier (équipe)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              DropdownButton<int>(
                value: _calYear,
                items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (y) {
                  if (y == null) return;
                  setState(() {
                    _calYear = y;
                    final maxD = DateTime(_calYear, _calMonth + 1, 0).day;
                    final d = _selectedCalDate.day.clamp(1, maxD);
                    _selectedCalDate = DateTime(_calYear, _calMonth, d);
                  });
                },
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _calMonth,
                items: List.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                    .toList(),
                onChanged: (m) {
                  if (m == null) return;
                  setState(() {
                    _calMonth = m;
                    final maxD = DateTime(_calYear, _calMonth + 1, 0).day;
                    final d = _selectedCalDate.day.clamp(1, maxD);
                    _selectedCalDate = DateTime(_calYear, _calMonth, d);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _LargeLeaveCalendar(
                year: _calYear,
                month: _calMonth,
                selectedDate: _selectedCalDate,
                requests: monthRequestsExact,
                onDateChanged: (d) => setState(() => _selectedCalDate = DateTime(d.year, d.month, d.day)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur un jour pour voir le détail des congés (popup).',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600], height: 1.25),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.history, size: 22, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sorted.isEmpty ? 'Vos demandes' : 'Vos demandes (${sorted.length})',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Demandes envoyées pour votre équipe — les plus récentes en premier.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600], height: 1.25),
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            Card(
              elevation: 0,
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Center(
                  child: Text(
                    'Aucune demande pour le moment.\nUtilisez le formulaire ci-dessus pour en créer une.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], height: 1.35),
                  ),
                ),
              ),
            )
          else
            ...sorted.map((r) => _LeaveRequestCard(req: r, isAdmin: false)),
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
  final Future<void> Function(LeaveRequest req)? onCreatePendingSelf;
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
    this.onCreatePendingSelf,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canCreateAndApprove = true;
    final canCreatePersonalPending = auth.isChefAtelierAdmin;
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

    final mobile = isMobile(context);
    if (mobile) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Vue calendrier',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                DropdownButton<int>(
                  value: selectedYear,
                  items: List.generate(5, (i) => selectedYear - 2 + i)
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onYearChanged(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                IconButton(
                  tooltip: 'Types de congé (Admin)',
                  icon: const Icon(Icons.category_outlined),
                  onPressed: () => _showLeaveTypeManagerDialog(context),
                ),
                if (canCreateAndApprove)
                  IconButton(
                    tooltip: 'Saisir un congé manuellement',
                    icon: const Icon(Icons.add_task_outlined),
                    onPressed: () => _showAdminCreateApproveDialog(context),
                  ),
                if (canCreatePersonalPending)
                  IconButton(
                    tooltip: 'Demande personnelle (en attente)',
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    onPressed: () => _showCreatePersonalPendingDialog(context),
                  ),
                IconButton(
                  tooltip: 'Supprimer toutes les demandes',
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                  onPressed: () => _deleteAllLeaveRequests(context),
                ),
                IconButton(
                  tooltip: 'Réinitialiser soldes congé (Test)',
                  icon: const Icon(Icons.restart_alt, color: Colors.orange),
                  onPressed: () => _showResetLeaveDaysDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 10),
            Text(
              'Demandes (toutes) • En attente: ${pending.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (sortedAll.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Aucune demande')),
              )
            else
              ...sortedAll.map(
                (r) => _LeaveRequestCard(
                  req: r,
                  isAdmin: true,
                  onApprove: onApprove,
                  onReject: onReject,
                ),
              ),
          ],
        ),
      );
    }

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
                    if (canCreateAndApprove)
                      IconButton(
                        tooltip: 'Créer et approuver (Admin)',
                        icon: const Icon(Icons.add_task_outlined),
                        onPressed: () => _showAdminCreateApproveDialog(context),
                      ),
                    if (canCreatePersonalPending)
                      IconButton(
                        tooltip: 'Demande personnelle (en attente)',
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        onPressed: () => _showCreatePersonalPendingDialog(context),
                      ),
                    IconButton(
                      tooltip: 'Supprimer toutes les demandes',
                      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                      onPressed: () => _deleteAllLeaveRequests(context),
                    ),
                    IconButton(
                      tooltip: 'Réinitialiser soldes congé (Test)',
                      icon: const Icon(Icons.restart_alt, color: Colors.orange),
                      onPressed: () => _showResetLeaveDaysDialog(context),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(
                    'Appuyez sur un jour : détail des congés (popup).',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  Future<void> _deleteAllLeaveRequests(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Supprimer toutes les demandes'),
          ],
        ),
        content: const Text(
          'Cette action va supprimer TOUTES les demandes de congé enregistrées.\n\n'
          'Les soldes et le pointage ne seront pas modifiés.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final db = FirebaseFirestore.instance;
      const batchSize = 400;
      final snap = await db.collection('leave_requests').get();
      for (int i = 0; i < snap.docs.length; i += batchSize) {
        final chunk = snap.docs.skip(i).take(batchSize).toList();
        final wb = db.batch();
        for (final doc in chunk) {
          wb.delete(doc.reference);
        }
        await wb.commit();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${snap.docs.length} demande(s) supprimée(s).'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showLeaveTypeManagerDialog(BuildContext context) async {
    final labelCtrl = TextEditingController();
    final defaultReasonCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateD) {
          return AlertDialog(
            title: const Text('Types de congé'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Libellé du type *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: defaultReasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Motif par défaut (pré-rempli automatiquement)',
                        hintText: 'Ex: Congé annuel, Congé maladie...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
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
                            'defaultReason': defaultReasonCtrl.text.trim(),
                            'actif': true,
                            'createdAt': Timestamp.now(),
                          });
                          labelCtrl.clear();
                          defaultReasonCtrl.clear();
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
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (ctx, i) {
                            final d = docs[i];
                            final m = d.data();
                            final label = (m['label'] as String?)?.trim() ?? '';
                            final defReason = (m['defaultReason'] as String?)?.trim() ?? '';
                            return ListTile(
                              dense: true,
                              title: Text(label.isEmpty ? d.id : label, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: defReason.isNotEmpty
                                  ? Text('Motif: $defReason', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                                  : const Text('Aucun motif par défaut', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier le motif par défaut',
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () async {
                                      final editCtrl = TextEditingController(text: defReason);
                                      final newReason = await showDialog<String>(
                                        context: ctx,
                                        builder: (c) => AlertDialog(
                                          title: Text('Motif de: ${label.isEmpty ? d.id : label}'),
                                          content: TextField(
                                            controller: editCtrl,
                                            decoration: const InputDecoration(labelText: 'Motif par défaut', border: OutlineInputBorder()),
                                            maxLines: 3,
                                            autofocus: true,
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
                                            FilledButton(onPressed: () => Navigator.pop(c, editCtrl.text.trim()), child: const Text('Enregistrer')),
                                          ],
                                        ),
                                      );
                                      if (newReason != null) {
                                        await FirebaseFirestore.instance.collection('leave_types').doc(d.id).update({
                                          'defaultReason': newReason,
                                        });
                                      }
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Désactiver',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance.collection('leave_types').doc(d.id).update({
                                        'actif': false,
                                      });
                                      setStateD(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Réinitialisation complète (test uniquement) :
  ///   1. Supprime toutes les demandes de congé (leave_requests)
  ///   2. Remet adminFinalStatus = null sur tous les pointages marqués "leave"
  ///   3. Remet leaveDaysTaken = 0 pour tous les employés
  Future<void> _showResetLeaveDaysDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Réinitialiser toutes les données congé'),
          ],
        ),
        content: const Text(
          'Cette action va :\n'
          '• Supprimer TOUTES les demandes de congé\n'
          '• Effacer les marquages congé dans le pointage\n'
          '• Remettre à zéro les jours pris pour tous les collaborateurs\n\n'
          'À utiliser uniquement en phase de test.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tout réinitialiser'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Réinitialisation en cours...'),
            ],
          ),
          duration: Duration(seconds: 60),
          backgroundColor: Colors.orange,
        ),
      );
    }

    try {
      final db = FirebaseFirestore.instance;
      const batchSize = 400;

      // ── 1. Supprimer toutes les demandes de congé ──────────────────
      final leaveSnap = await db.collection('leave_requests').get();
      for (int i = 0; i < leaveSnap.docs.length; i += batchSize) {
        final chunk = leaveSnap.docs.skip(i).take(batchSize).toList();
        final wb = db.batch();
        for (final doc in chunk) {
          wb.delete(doc.reference);
        }
        await wb.commit();
      }

      // ── 2. Effacer adminFinalStatus = "leave" dans pointage ────────
      final pointageSnap = await db
          .collection('pointage')
          .where('adminFinalStatus', isEqualTo: 'leave')
          .get();
      for (int i = 0; i < pointageSnap.docs.length; i += batchSize) {
        final chunk = pointageSnap.docs.skip(i).take(batchSize).toList();
        final wb = db.batch();
        for (final doc in chunk) {
          wb.update(doc.reference, {'adminFinalStatus': FieldValue.delete()});
        }
        await wb.commit();
      }

      // ── 3. Remettre leaveDaysTaken = 0 pour tous les employés ─────
      final empSnap = await db.collection('employes').get();
      for (int i = 0; i < empSnap.docs.length; i += batchSize) {
        final chunk = empSnap.docs.skip(i).take(batchSize).toList();
        final wb = db.batch();
        for (final doc in chunk) {
          wb.update(doc.reference, {
            'leaveDaysTaken': 0.0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await wb.commit();
      }

      // ── 4. Vider les caches locaux ─────────────────────────────────
      if (context.mounted) {
        Provider.of<CongesProvider>(context, listen: false).resetAllCachedDaysTaken();
        Provider.of<EmployeesProvider>(context, listen: false).forceRefresh();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Réinitialisation complète : '
              '${leaveSnap.docs.length} demande(s) supprimée(s), '
              '${pointageSnap.docs.length} pointage(s) effacé(s), '
              '${empSnap.docs.length} collaborateur(s) remis à zéro.',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAdminCreateApproveDialog(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();
    String? employeeId;
    String? selectedTeamId;
    String? leaveTypeId;
    List<_LeaveType> leaveTypes = const [];

    final auth = context.read<AuthProvider>();
    final groupes = context.read<GroupesProvider>().groupes;
    final adminSiteIds = auth.currentUser?.allowedSiteIds ?? const <String>['all'];
    final hasAllSites = adminSiteIds.isEmpty || adminSiteIds.contains('all');
    bool isZoneOrRh(String poste) {
      final p = poste.trim().toLowerCase();
      return p.contains('chef de zone') ||
          p.contains('chef zone') ||
          p == 'rh' ||
          p.contains('ressource');
    }
    bool isAtelier(String poste) {
      final p = poste.trim().toLowerCase();
      return p.contains('chef atelier') || p.contains('chef d\'atelier') || p.contains('chef datelier');
    }
    bool isDistribution(String poste) {
      final p = poste.trim().toLowerCase();
      return p.contains('distribution') || p.contains('distri') || p.contains('livreur');
    }

    QuerySnapshot<Map<String, dynamic>>? leaveTypesSnap;
    try {
      leaveTypesSnap = await FirebaseFirestore.instance
          .collection('leave_types')
          .where('actif', isEqualTo: true)
          .get();
    } catch (_) {}

    String? teamIdForEmployee(String employeId) {
      final team = equipes.where((q) => q.chefId == employeId || q.membreIds.contains(employeId)).toList();
      if (team.isNotEmpty) return team.first.id;
      final gr = groupes.where((g) => g.membreIds.contains(employeId)).toList();
      if (gr.isNotEmpty) return 'groupe:${gr.first.id}';
      return null;
    }
    String teamNameForEmployee(String employeId) {
      final team = equipes.where((q) => q.chefId == employeId || q.membreIds.contains(employeId)).toList();
      if (team.isNotEmpty) return team.first.nom;
      final gr = groupes.where((g) => g.membreIds.contains(employeId)).toList();
      if (gr.isNotEmpty) return gr.first.nom;
      return 'Sans équipe';
    }
    // Tous les collaborateurs sont affichés, peu importe leur solde
    final activeEmployees = employees.where((e) {
      if (!hasAllSites && !adminSiteIds.contains(e.siteId)) return false;
      if (auth.isChefAtelierAdmin) {
        if (isZoneOrRh(e.poste) || isAtelier(e.poste) || isDistribution(e.poste)) return false;
      }
      return true;
    }).toList();
    if (activeEmployees.isNotEmpty) {
      employeeId = activeEmployees.first.id;
      final tk = teamIdForEmployee(employeeId);
      selectedTeamId = auth.isChefAtelierAdmin ? tk : (tk ?? '__no_team__');
    }

    leaveTypes = (leaveTypesSnap?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
        .map((d) {
          final data = d.data();
          return _LeaveType(
            id: d.id,
            label: ((data['label'] as String?) ?? '').trim().isEmpty ? 'Congé' : (data['label'] as String).trim(),
            defaultReason: ((data['defaultReason'] as String?) ?? '').trim(),
          );
        })
        .toList();
    if (leaveTypes.isEmpty) leaveTypes = const [_LeaveType(id: 'default', label: 'Congé')];
    leaveTypeId = leaveTypes.first.id;
    // Pré-remplir le motif avec le motif par défaut du premier type
    if (leaveTypes.first.defaultReason.isNotEmpty) {
      reasonCtrl.text = leaveTypes.first.defaultReason;
    }

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
          final selectedTeamName = selected == null ? '-' : teamNameForEmployee(selected.id);
          final dialogWidth = MediaQuery.of(ctx).size.width * 0.94;
          final compact = MediaQuery.of(ctx).size.width < 520;
          // date de retour au service = end + 1 jour
          final returnDate = end.add(const Duration(days: 1));
          return AlertDialog(
            title: const Text('Saisie manuelle d\'un congé'),
            content: SizedBox(
              width: dialogWidth > 560 ? 560 : dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── 1. Choix de l'équipe ──
                    DropdownButtonFormField<String?>(
                      value: selectedTeamId,
                      decoration: const InputDecoration(labelText: 'Équipe', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Toutes les équipes')),
                        ...equipes.map((q) => DropdownMenuItem<String?>(value: q.id, child: Text(q.nom))),
                        ...groupes.map((g) => DropdownMenuItem<String?>(value: 'groupe:${g.id}', child: Text(g.nom))),
                        if (!auth.isChefAtelierAdmin)
                          const DropdownMenuItem<String?>(value: '__no_team__', child: Text('Sans équipe')),
                      ],
                      onChanged: (v) => setS(() => selectedTeamId = v),
                    ),
                    const SizedBox(height: 8),
                    // ── 2. Choix du collaborateur ──
                    DropdownButtonFormField<String?>(
                      value: employeeId,
                      decoration: InputDecoration(
                        labelText: 'Collaborateur${selectedTeamName != '-' ? ' — $selectedTeamName' : ''}',
                        border: const OutlineInputBorder(),
                      ),
                      items: filteredEmployees
                          .map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.nom)))
                          .toList(),
                      onChanged: (v) => setS(() => employeeId = v),
                    ),
                    const SizedBox(height: 12),
                    // ── 3 & 4. Dates ──
                    if (compact) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_outlined, size: 16),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: start,
                              firstDate: DateTime(2020, 1, 1),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (d != null) setS(() {
                              start = DateTime(d.year, d.month, d.day);
                              if (end.isBefore(start)) end = start;
                            });
                          },
                          label: Text('Début de congé : ${start.day.toString().padLeft(2,'0')}/${start.month.toString().padLeft(2,'0')}/${start.year}'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event_available_outlined, size: 16),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: returnDate.isBefore(start.add(const Duration(days: 1))) ? start.add(const Duration(days: 1)) : returnDate,
                              firstDate: start.add(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 731)),
                            );
                            if (d != null) setS(() => end = d.subtract(const Duration(days: 1)));
                          },
                          label: Text('Date de retour au service : ${returnDate.day.toString().padLeft(2,'0')}/${returnDate.month.toString().padLeft(2,'0')}/${returnDate.year}'),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today_outlined, size: 16),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: start,
                                  firstDate: DateTime(2020, 1, 1),
                                  lastDate: DateTime.now().add(const Duration(days: 730)),
                                );
                                if (d != null) setS(() {
                                  start = DateTime(d.year, d.month, d.day);
                                  if (end.isBefore(start)) end = start;
                                });
                              },
                              label: Text('Début : ${start.day.toString().padLeft(2,'0')}/${start.month.toString().padLeft(2,'0')}/${start.year}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.event_available_outlined, size: 16),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: returnDate.isBefore(start.add(const Duration(days: 1))) ? start.add(const Duration(days: 1)) : returnDate,
                                  firstDate: start.add(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 731)),
                                );
                                if (d != null) setS(() => end = d.subtract(const Duration(days: 1)));
                              },
                              label: Text('Retour : ${returnDate.day.toString().padLeft(2,'0')}/${returnDate.month.toString().padLeft(2,'0')}/${returnDate.year}'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    // ── Durée calculée ──
                    Builder(builder: (_) {
                      final days = end.difference(start).inDays + 1;
                      final valid = !end.isBefore(start) && days > 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: valid ? AppColors.brandLight : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: valid ? AppColors.brandBorder : Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.date_range, size: 16, color: valid ? AppColors.brand : Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              valid ? '$days jour${days > 1 ? 's' : ''} de congé' : 'Dates invalides',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: valid ? AppColors.brandDark : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: leaveTypeId,
                      decoration: const InputDecoration(labelText: 'Type de congé', border: OutlineInputBorder()),
                      items: leaveTypes.map((t) => DropdownMenuItem<String?>(value: t.id, child: Text(t.label))).toList(),
                      onChanged: (v) {
                        setS(() {
                          leaveTypeId = v;
                          if (v != null) {
                            final sel = leaveTypes.where((t) => t.id == v).toList();
                            if (sel.isNotEmpty && sel.first.defaultReason.isNotEmpty) {
                              reasonCtrl.text = sel.first.defaultReason;
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Motif (optionnel)',
                        hintText: 'Ex: Congé annuel',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  if (employeeId == null || leaveTypeId == null || end.isBefore(start)) return;
                  final emp = filteredEmployees.firstWhere((e) => e.id == employeeId);
                  final lt = leaveTypes.firstWhere((t) => t.id == leaveTypeId);
                  Navigator.pop(ctx);
                  await onCreateApprovedByAdmin(
                    emp,
                    start,
                    end,
                    lt.id,
                    lt.label,
                    reasonCtrl.text.trim().isEmpty ? lt.label : reasonCtrl.text.trim(),
                    '',
                  );
                },
                child: const Text('Enregistrer le congé'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreatePersonalPendingDialog(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final reasonCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();
    List<_LeaveType> leaveTypes = const [];
    String? leaveTypeId;

    final leaveSnap = await FirebaseFirestore.instance
        .collection('leave_types')
        .where('actif', isEqualTo: true)
        .get();
    leaveTypes = leaveSnap.docs
        .map((d) {
          final data = d.data();
          return _LeaveType(
            id: d.id,
            label: ((data['label'] as String?) ?? '').trim().isEmpty ? 'Congé' : (data['label'] as String).trim(),
            defaultReason: ((data['defaultReason'] as String?) ?? '').trim(),
          );
        })
        .toList();
    if (leaveTypes.isEmpty) leaveTypes = const [_LeaveType(id: 'default', label: 'Congé')];
    leaveTypeId = leaveTypes.first.id;
    if (leaveTypes.first.defaultReason.isNotEmpty) reasonCtrl.text = leaveTypes.first.defaultReason;

    final approversSnap = await FirebaseFirestore.instance
        .collection('admins')
        .where('actif', isEqualTo: true)
        .get();
    final approvers = approversSnap.docs
        .map((d) {
          final m = d.data();
          return _AdminRecipient(
            id: d.id,
            name: '${m['prenom'] ?? ''} ${m['nom'] ?? ''}'.trim(),
            email: m['email'] as String? ?? '',
            role: (m['role'] as String? ?? '').trim(),
          );
        })
        .where((a) {
          final r = a.role.toLowerCase();
          final isUpward = r.contains('zone') || r.contains('rh') || r.contains('general') || r.contains('général');
          final isAtelier = r.contains('atelier');
          final isSelf = auth.userId != null && a.id == auth.userId;
          return isUpward && !isAtelier && !isSelf;
        })
        .toList();
    String? adminId = approvers.isNotEmpty ? approvers.first.id : null;
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
    final earliestAllowedDate = auth.isChefZoneAdmin
        ? DateTime(2020, 1, 1)
        : tomorrow;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final dialogWidth = MediaQuery.of(ctx).size.width * 0.94;
          final compact = MediaQuery.of(ctx).size.width < 520;
          return AlertDialog(
            title: const Text('Créer demande personnelle (en attente)'),
            content: SizedBox(
              width: dialogWidth > 560 ? 560 : dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String?>(
                      value: adminId,
                      decoration: const InputDecoration(labelText: 'Destinataire (Chef zone / RH)', border: OutlineInputBorder()),
                      items: approvers
                          .map((a) => DropdownMenuItem<String?>(
                                value: a.id,
                                child: Text('${a.name.isEmpty ? a.email : a.name} (${a.role})'),
                              ))
                          .toList(),
                      onChanged: (v) => setS(() => adminId = v),
                    ),
                    const SizedBox(height: 8),
                    if (compact) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: start,
                              firstDate: earliestAllowedDate,
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (d != null) setS(() {
                              start = DateTime(d.year, d.month, d.day);
                              if (end.isBefore(start)) end = start;
                            });
                          },
                          child: Text('Du: ${start.day}/${start.month}/${start.year}'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: end.isBefore(start) ? start : end,
                              firstDate: start,
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (d != null) setS(() => end = DateTime(d.year, d.month, d.day));
                          },
                          child: Text('Au: ${end.day}/${end.month}/${end.year}'),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: ctx,
                                  initialDate: start,
                                  firstDate: earliestAllowedDate,
                                  lastDate: DateTime.now().add(const Duration(days: 730)),
                                );
                                if (d != null) setS(() {
                                  start = DateTime(d.year, d.month, d.day);
                                  if (end.isBefore(start)) end = start;
                                });
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
                                  initialDate: end.isBefore(start) ? start : end,
                                  firstDate: start,
                                  lastDate: DateTime.now().add(const Duration(days: 730)),
                                );
                                if (d != null) setS(() => end = DateTime(d.year, d.month, d.day));
                              },
                              child: Text('Au: ${end.day}/${end.month}/${end.year}'),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    // ── Compteur de jours ──
                    Builder(builder: (_) {
                      final days = end.difference(start).inDays + 1;
                      final valid = !end.isBefore(start);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: valid ? AppColors.brandLight : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: valid ? AppColors.brandBorder : Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              size: 16,
                              color: valid ? AppColors.brand : Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              valid
                                  ? '$days jour${days > 1 ? 's' : ''} de congé'
                                  : 'Date de fin invalide',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: valid ? AppColors.brandDark : Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: leaveTypeId,
                      decoration: const InputDecoration(labelText: 'Type de congé', border: OutlineInputBorder()),
                      items: leaveTypes.map((t) => DropdownMenuItem<String?>(value: t.id, child: Text(t.label))).toList(),
                      onChanged: (v) {
                        setS(() {
                          leaveTypeId = v;
                          if (v != null) {
                            final sel = leaveTypes.where((t) => t.id == v).toList();
                            if (sel.isNotEmpty && sel.first.defaultReason.isNotEmpty) {
                              reasonCtrl.text = sel.first.defaultReason;
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(labelText: 'Motif', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: detailsCtrl,
                      decoration: const InputDecoration(labelText: 'Détails professionnels', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  if (adminId == null || leaveTypeId == null || end.isBefore(start) || reasonCtrl.text.trim().isEmpty) return;
                  if (!auth.isChefZoneAdmin && start.isBefore(tomorrow)) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('La demande de congé doit commencer à partir de demain.')),
                      );
                    }
                    return;
                  }
                  final approver = approvers.firstWhere((a) => a.id == adminId);
                  final lt = leaveTypes.firstWhere((t) => t.id == leaveTypeId);
                  final req = LeaveRequest(
                    id: '',
                    employeeId: auth.userId ?? 'self',
                    employeeName: auth.currentUser?.nom ?? 'Chef d\'atelier',
                    employeeCin: '',
                    employeePoste: 'Chef d\'atelier',
                    equipeId: auth.equipeId ?? '',
                    equipeName: auth.equipeId ?? '',
                    chefName: auth.currentUser?.nom ?? '',
                    leaveTypeId: lt.id,
                    leaveTypeLabel: lt.label,
                    startDate: start,
                    endDate: end,
                    startAt: DateTime(start.year, start.month, start.day, 0, 0),
                    endAt: DateTime(end.year, end.month, end.day, 23, 59),
                    reason: reasonCtrl.text.trim(),
                    professionalDetails: detailsCtrl.text.trim(),
                    submittedByUserId: auth.userId ?? '',
                    submittedByName: auth.currentUser?.nom ?? '',
                    assignedAdminId: approver.id,
                    assignedAdminName: approver.name.isEmpty ? approver.email : approver.name,
                    createdAt: DateTime.now(),
                    status: LeaveStatus.pending,
                  );
                  Navigator.pop(ctx);
                  await onCreatePendingSelf?.call(req);
                },
                child: const Text('Créer la demande'),
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

void _showLeaveDayDetailsDialog(BuildContext context, DateTime day, List<LeaveRequest> dayRequests) {
  final fmt = (DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  final title = 'Congés — ${fmt(day)}';
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.event_note, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: dayRequests.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aucun congé enregistré pour ce jour.',
                  style: TextStyle(color: Colors.grey[700], height: 1.35),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dayRequests.length} demande(s)',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 12),
                    ...dayRequests.map((r) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.employeeName,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  r.leaveTypeLabel,
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade900, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text('Équipe: ${r.equipeName}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                                Text(
                                  'Période: ${fmt(r.startDate)} → ${fmt(r.endDate)}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: r.status.color.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        r.status.label,
                                        style: TextStyle(color: r.status.color, fontWeight: FontWeight.w800, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
      ],
    ),
  );
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
          onTap: () {
            onDateChanged(dayDate);
            _showLeaveDayDetailsDialog(context, dayDate, dayReq);
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: selected ? AppColors.brandLight : bg,
              border: Border.all(color: selected ? AppColors.brand : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 56;
                final veryCompact = constraints.maxHeight < 32;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$d', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
                    if (!veryCompact) const SizedBox(height: 1),
                    if (!compact && !veryCompact && dayReq.isNotEmpty)
                      Flexible(
                        child: Text(
                          '${dayReq.first.employeeName} (${dayReq.first.startDate.day}/${dayReq.first.startDate.month}-${dayReq.first.endDate.day}/${dayReq.first.endDate.month})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 8.5, height: 1.05),
                        ),
                      ),
                    if (!veryCompact && dayReq.length > 1)
                      Text(
                        '+${dayReq.length - 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
                      ),
                  ],
                );
              },
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
  List<_LeaveType> _leaveTypes = const [];
  String? _leaveTypeId;
  bool _loadingLeaveTypes = true;
  bool _saving = false;

  bool _isAtelierPoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('atelier');
  }

  bool _isZonePoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('zone');
  }

  bool _isRhPoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p == 'rh' || p.contains('ressource') || p.contains('rh');
  }

  bool _isDistributionPoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('distribution') || p.contains('distri') || p.contains('livreur');
  }

  bool _isTopAdminRole(String role) {
    final r = role.trim().toLowerCase();
    return r.contains('général') || r.contains('general') || r.contains('directeur');
  }

  bool _canBackdateLeave(AuthProvider auth) => auth.isChefZoneAdmin;

  List<_AdminRecipient> _eligibleAdminsForPoste(
    AuthProvider auth,
    String poste,
    List<_AdminRecipient> admins,
  ) {
    if (admins.isEmpty) return const [];
    // Regular demandeur (ex: Chef d'équipe) sends to Chef d'atelier.
    if (!auth.isDirecteur) {
      if (_isDistributionPoste(poste)) {
        final zoneTargets = admins.where((a) => a.role.toLowerCase().contains('zone')).toList();
        return zoneTargets;
      }
      final atelierTargets = admins.where((a) => a.role.toLowerCase().contains('atelier')).toList();
      if (atelierTargets.isNotEmpty) return atelierTargets;
      return admins;
    }
    // If connected user is Chef d'atelier admin, he can only send upward:
    // RH / Chef de zone / higher admin (never to another Chef d'atelier).
    if (auth.isChefAtelierAdmin) {
      return admins.where((a) {
        final r = a.role.toLowerCase();
        final isUpward = r.contains('zone') || r.contains('rh') || _isTopAdminRole(a.role);
        final isAtelier = r.contains('atelier');
        final isSelf = auth.userId != null && a.id == auth.userId;
        return isUpward && !isAtelier && !isSelf;
      }).toList();
    }
    // Chef de zone sends upward to top admin only.
    if (auth.isChefZoneAdmin) {
      return admins.where((a) => _isTopAdminRole(a.role)).toList();
    }
    if (_isAtelierPoste(poste)) {
      return admins.where((a) {
        final r = a.role.toLowerCase();
        return r.contains('zone') || r.contains('rh') || _isTopAdminRole(a.role);
      }).toList();
    }
    if (_isZonePoste(poste) || _isRhPoste(poste)) {
      return admins.where((a) => _isTopAdminRole(a.role)).toList();
    }
    return admins;
  }

  @override
  void initState() {
    super.initState();
    _loadAdmins();
    _loadLeaveTypes();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
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
        role: (m['role'] as String? ?? '').trim(),
      );
    }).toList();
    if (mounted) {
      setState(() {
        _admins = list;
        _adminId = list.isNotEmpty ? list.first.id : null;
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
        defaultReason: ((m['defaultReason'] as String?) ?? '').trim(),
      );
    }).toList();
    if (!mounted) return;
    final types = list.isNotEmpty ? list : const [_LeaveType(id: 'default', label: 'Congé')];
    setState(() {
      _leaveTypes = types;
      _leaveTypeId = types.isNotEmpty ? types.first.id : null;
      _loadingLeaveTypes = false;
      // Pré-remplir le motif avec le motif par défaut du premier type
      if (types.isNotEmpty && types.first.defaultReason.isNotEmpty && _reasonCtrl.text.trim().isEmpty) {
        _reasonCtrl.text = types.first.defaultReason;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final empProv = context.watch<EmployeesProvider>();
    final distGroupsProv = context.watch<DistributionGroupsProvider>();
    final equipe = _resolveEquipe(auth, empProv);
    final employeesRaw = _resolveTeamEmployees(equipe, empProv, auth, distGroupsProv);
    final employees = <String, Employe>{for (final e in employeesRaw) e.id: e}.values.toList();

    if (employees.isEmpty) {
      _employeeId = null;
    } else if (_employeeId == null || !employees.any((e) => e.id == _employeeId)) {
      _employeeId = employees.first.id;
    }

    // Auto-sélection silencieuse de l'admin destinataire
    final adminsUnique = <String, _AdminRecipient>{for (final a in _admins) a.id: a}.values.toList();
    Employe? selectedEmployee = _employeeId == null
        ? null
        : employees.where((e) => e.id == _employeeId).firstOrNull;
    final adminsEligible = _eligibleAdminsForPoste(auth, selectedEmployee?.poste ?? '', adminsUnique);
    if (adminsEligible.isNotEmpty && (_adminId == null || !adminsEligible.any((a) => a.id == _adminId))) {
      _adminId = adminsEligible.first.id;
    }

    final returnDate = _end.add(const Duration(days: 1));
    final nbJours = _end.difference(_start).inDays + 1;
    final datesValides = !_end.isBefore(_start) && nbJours > 0;

    final fmtDate = (DateTime d) =>
        '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── En-tête avec dégradé de marque ──
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brand, AppColors.brandDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.beach_access_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Demande de congé',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'La demande sera soumise en attente de validation.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Corps du formulaire ──
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Section 1 : Collaborateur ──
                _chefFormSectionLabel('Collaborateur', Icons.person_outline),
                const SizedBox(height: 8),
                if (employees.isEmpty)
                  _chefFormEmptyTeam()
                else
                  DropdownButtonFormField<String?>(
                    value: _employeeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Choisir un collaborateur',
                      prefixIcon: Icon(Icons.person_pin_outlined),
                    ),
                    items: employees
                        .map((e) => DropdownMenuItem<String?>(
                              value: e.id,
                              child: Text(e.nom, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _employeeId = v;
                      _adminId = null;
                    }),
                  ),
                const SizedBox(height: 22),

                // ── Section 2 : Période ──
                _chefFormSectionLabel('Période de congé', Icons.date_range_outlined),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _chefDateTile(
                        label: 'Début de congé',
                        date: _start,
                        icon: Icons.flight_takeoff_rounded,
                        accentColor: const Color(0xFF1565C0),
                        formatted: fmtDate(_start),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _start,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                          );
                          if (d != null) {
                            setState(() {
                              _start = DateTime(d.year, d.month, d.day);
                              if (_end.isBefore(_start)) _end = _start;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _chefDateTile(
                        label: 'Retour au service',
                        date: returnDate,
                        icon: Icons.flight_land_rounded,
                        accentColor: const Color(0xFF2E7D32),
                        formatted: fmtDate(returnDate),
                        onTap: () async {
                          final minReturn = _start.add(const Duration(days: 1));
                          final initReturn =
                              returnDate.isBefore(minReturn) ? minReturn : returnDate;
                          final d = await showDatePicker(
                            context: context,
                            initialDate: initReturn,
                            firstDate: minReturn,
                            lastDate: DateTime.now().add(const Duration(days: 731)),
                          );
                          if (d != null) {
                            setState(() => _end = d.subtract(const Duration(days: 1)));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Badge durée ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: datesValides
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: datesValides
                          ? const Color(0xFFA5D6A7)
                          : const Color(0xFFEF9A9A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        datesValides
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        size: 16,
                        color: datesValides
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          datesValides
                              ? '$nbJours jour${nbJours > 1 ? 's' : ''} de congé  ·  du ${fmtDate(_start)} au ${fmtDate(_end)}'
                              : 'Dates invalides — vérifiez les dates saisies',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: datesValides
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ── Section 3 : Type de congé ──
                _chefFormSectionLabel('Type de congé', Icons.category_outlined),
                const SizedBox(height: 8),
                if (_loadingLeaveTypes)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<String?>(
                    value: _leaveTypeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Choisir un type de congé',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    items: _leaveTypes
                        .map((t) => DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(t.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _leaveTypeId = v;
                        if (v != null) {
                          final sel = _leaveTypes.where((t) => t.id == v).toList();
                          if (sel.isNotEmpty && sel.first.defaultReason.isNotEmpty) {
                            _reasonCtrl.text = sel.first.defaultReason;
                          }
                        }
                      });
                    },
                  ),
                const SizedBox(height: 18),

                // ── Section 4 : Motif ──
                _chefFormSectionLabel('Motif', Icons.notes_outlined),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Motif du congé (optionnel)',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // ── Bouton soumettre ──
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: (_saving || employees.isEmpty || !datesValides)
                        ? null
                        : () => _submit(context, equipe, employees),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.brandBorder,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _saving ? 'Envoi en cours...' : 'Soumettre la demande',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chefFormSectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _chefFormEmptyTeam() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aucun collaborateur disponible dans votre équipe.',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chefDateTile({
    required String label,
    required DateTime date,
    required IconData icon,
    required Color accentColor,
    required String formatted,
    required VoidCallback onTap,
  }) {
    return Material(
      color: accentColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: accentColor),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.edit_calendar_outlined,
                      size: 13, color: accentColor.withValues(alpha: 0.55)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                formatted,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
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

  List<Employe> _resolveTeamEmployees(
    Equipe? equipe,
    EmployeesProvider emps,
    AuthProvider auth,
    DistributionGroupsProvider distGroupsProv,
  ) {
    if (equipe == null && auth.isDistributionResponsable) {
      final adminSiteIds = auth.currentUser?.allowedSiteIds ?? const <String>['all'];
      final hasAllSites = adminSiteIds.isEmpty || adminSiteIds.contains('all');
      final allowedDist = auth.distributionGroupIds;
      final memberIds = <String>{};
      for (final g in distGroupsProv.groups) {
        if (allowedDist.isNotEmpty && !allowedDist.contains(g.id)) continue;
        memberIds.addAll(g.membreIds);
      }
      final members = emps.employes
          .where((e) =>
              e.statut == EmployeStatut.enService &&
              memberIds.contains(e.id) &&
              (hasAllSites || adminSiteIds.contains(e.siteId)))
          .toList();
      // Allow account holder to submit leave for himself even without linked employee record.
      final selfId = auth.userId ?? 'self_distribution';
      final hasSelfAsEmployee = members.any((e) => e.id == selfId);
      if (!hasSelfAsEmployee) {
        members.add(
          Employe(
            id: selfId,
            nom: auth.currentUser?.nom ?? 'Responsable Distribution',
            cin: '',
            telephone: '',
            dateNaissance: '',
            adresse: '',
            email: auth.currentUser?.username ?? '',
            poste: 'Responsable Distribution',
            magasin: '',
            departement: '',
            salaireBase: 0,
            typeContrat: '',
            dateDebut: '2020-01-01',
            cnss: '',
            dateCnss: '',
            statut: EmployeStatut.enService,
            leaveDaysExtra: 30,
            leaveDaysTaken: 0,
          ),
        );
      }
      return members;
    }

    // Admin role-based demandeur mode (Chef d'atelier / Chef de zone):
    // when no equipe link exists, resolve target employees by poste hierarchy.
    if (equipe == null && auth.isChefAtelierAdmin) {
      final adminSiteIds = auth.currentUser?.allowedSiteIds ?? const <String>['all'];
      final hasAllSites = adminSiteIds.isEmpty || adminSiteIds.contains('all');
      final list = emps.employes.where((e) {
        final p = e.poste.trim().toLowerCase();
        final isZoneOrRh = _isZonePoste(p) || _isRhPoste(p);
        return e.statut == EmployeStatut.enService &&
            (hasAllSites || adminSiteIds.contains(e.siteId)) &&
            !isZoneOrRh &&
            !_isDistributionPoste(p) &&
            !(p.contains('chef atelier') || p.contains('chef d\'atelier') || p.contains('chef datelier'));
      }).toList();
      if (list.isNotEmpty) return list;
    }
    if (equipe == null && auth.isChefZoneAdmin) {
      final adminSiteIds = auth.currentUser?.allowedSiteIds ?? const <String>['all'];
      final hasAllSites = adminSiteIds.isEmpty || adminSiteIds.contains('all');
      final allowedDist = auth.distributionGroupIds;
      final memberIds = <String>{};
      for (final g in distGroupsProv.groups) {
        if (allowedDist.isNotEmpty && !allowedDist.contains(g.id)) continue;
        memberIds.addAll(g.membreIds);
      }
      return emps.employes
          .where((e) =>
              e.statut == EmployeStatut.enService &&
              memberIds.contains(e.id) &&
              (hasAllSites || adminSiteIds.contains(e.siteId)))
          .toList();
    }

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
    final base = emps.employes.where((e) => ids.contains(e.id)).toList();
    if (auth.isChefAtelierAdmin) {
      return base.where((e) => !_isDistributionPoste(e.poste)).toList();
    }
    return base;
  }

  Future<void> _submit(BuildContext context, Equipe? equipe, List<Employe> employees) async {
    if (!_formKey.currentState!.validate()) return;
    if (_employeeId == null || _adminId == null) return;
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La date de fin doit être >= date début')));
      return;
    }
    final auth = context.read<AuthProvider>();
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
    if (!_canBackdateLeave(auth) && _start.isBefore(tomorrow)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La demande de congé doit commencer à partir de demain.')),
      );
      return;
    }
    final distGroupsProv = context.read<DistributionGroupsProvider>();
    final employee = employees.firstWhere((e) => e.id == _employeeId);
    final admin = _admins.firstWhere((a) => a.id == _adminId);
    String equipeId = equipe?.id ?? (auth.equipeId ?? '');
    String equipeName = equipe?.nom ?? 'Équipe non définie';
    if (auth.isDistributionResponsable) {
      final allowedDist = auth.distributionGroupIds;
      final linkedGroup = distGroupsProv.groups.where((g) {
        final allowed = allowedDist.isEmpty || allowedDist.contains(g.id);
        return allowed && g.membreIds.contains(employee.id);
      }).toList();
      if (linkedGroup.isNotEmpty) {
        equipeId = 'distribution:${linkedGroup.first.id}';
        equipeName = linkedGroup.first.nom;
      } else if (allowedDist.isNotEmpty) {
        final g = distGroupsProv.groups.where((x) => x.id == allowedDist.first).toList();
        if (g.isNotEmpty) {
          equipeId = 'distribution:${g.first.id}';
          equipeName = g.first.nom;
        } else {
          equipeId = 'distribution:self';
          equipeName = 'Distribution';
        }
      } else {
        equipeId = 'distribution:self';
        equipeName = 'Distribution';
      }
    }
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

    final startAt = DateTime(_start.year, _start.month, _start.day, 0, 0);
    final endAt = DateTime(_end.year, _end.month, _end.day, 23, 59);

    setState(() => _saving = true);
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

/// Affiche le nom du compte connecté si la demande est la sienne, sinon le nom stocké.
String _leaveSubmittedByDisplay(LeaveRequest req, AuthProvider auth) {
  final uid = auth.userId;
  if (uid != null && uid.isNotEmpty && req.submittedByUserId == uid) {
    final n = (auth.currentUser?.nom ?? '').trim();
    if (n.isNotEmpty) return n;
  }
  final s = req.submittedByName.trim();
  return s.isEmpty ? '—' : s;
}

class _LeaveCardInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LeaveCardInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveRequestCard extends StatefulWidget {
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
  State<_LeaveRequestCard> createState() => _LeaveRequestCardState();
}

class _LeaveRequestCardState extends State<_LeaveRequestCard> {
  static const Duration _decisionEditWindow = Duration(hours: 24);
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    final fmt = (DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final isPending = req.status == LeaveStatus.pending;
    final canEditDecision = isPending ||
        (req.decidedAt != null &&
            DateTime.now().difference(req.decidedAt!) <= _decisionEditWindow);
    final auth = context.watch<AuthProvider>();
    final canEditDecisionWithRole = auth.isDirecteur ? true : canEditDecision;
    final isOwnRequest = auth.userId != null && req.submittedByUserId == auth.userId;
    final canActAsAdmin = !(auth.isChefAtelierAdmin && isOwnRequest);
    final employeesProvider = context.watch<EmployeesProvider>();
    final resolvedChefName = _resolveChefName(
      req,
      employeesProvider.equipes,
      employeesProvider.employes,
    );
    final submittedByDisplay = _leaveSubmittedByDisplay(req, auth);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: widget.isAdmin ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          req.employeeName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade700, size: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${req.employeeCin.isNotEmpty ? '${req.employeeCin} · ' : ''}${req.equipeName}',
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: req.status.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          req.status.label,
                          style: TextStyle(color: req.status.color, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 10),
                  _LeaveCardInfoRow(icon: Icons.category_outlined, label: 'Type', value: req.leaveTypeLabel),
                  _LeaveCardInfoRow(icon: Icons.groups_outlined, label: 'Chef d\'équipe', value: resolvedChefName),
                  _LeaveCardInfoRow(
                    icon: Icons.date_range,
                    label: 'Période',
                    value: '${fmt(req.startDate)} → ${fmt(req.endDate)}',
                  ),
                  _LeaveCardInfoRow(icon: Icons.send_outlined, label: 'Soumis par', value: submittedByDisplay),
                  _LeaveCardInfoRow(icon: Icons.admin_panel_settings_outlined, label: 'Admin destinataire', value: req.assignedAdminName),
                  const SizedBox(height: 8),
                  Text('Motif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey.shade800)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(req.reason, style: TextStyle(height: 1.35, color: Colors.grey.shade900)),
                  ),
                  if (req.professionalDetails.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Détails professionnels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey.shade800)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: Text(req.professionalDetails, style: TextStyle(height: 1.35, color: Colors.grey.shade900)),
                    ),
                  ],
                  if (req.adminComment != null && req.adminComment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Commentaire admin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey.shade800)),
                    const SizedBox(height: 4),
                    Text(req.adminComment!, style: TextStyle(color: Colors.grey.shade800)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (req.approvedPdf != null)
                        OutlinedButton.icon(
                          onPressed: () async => _downloadPdf(context),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Télécharger PDF'),
                        ),
                      if (widget.isAdmin && canEditDecisionWithRole && canActAsAdmin) ...[
                        if (req.status != LeaveStatus.approved)
                          FilledButton.icon(
                            onPressed: () async {
                              final c = await _askComment(
                                context,
                                title: isPending ? 'Approuver la demande' : 'Changer vers Approuvé',
                              );
                              if (c == null) return;
                              await widget.onApprove?.call(req, c);
                            },
                            icon: const Icon(Icons.check),
                            label: Text(isPending ? 'Approuver' : 'Mettre Approuvé'),
                          ),
                        if (req.status != LeaveStatus.approved) const SizedBox(width: 8),
                        if (req.status != LeaveStatus.rejected)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final c = await _askComment(
                                context,
                                title: isPending ? 'Refuser la demande' : 'Changer vers Refusé',
                                requiredComment: true,
                              );
                              if (c == null) return;
                              await widget.onReject?.call(req, c);
                            },
                            icon: const Icon(Icons.close),
                            label: Text(isPending ? 'Refuser' : 'Mettre Refusé'),
                          ),
                      ],
                    ],
                  ),
                ],
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
    final r = widget.req;
    final bytes = r.approvedPdf;
    if (bytes == null || bytes.isEmpty) return;

    final safeEmployee = r.employeeName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'conge_${safeEmployee}_${r.startDate.year}${r.startDate.month.toString().padLeft(2, '0')}${r.startDate.day.toString().padLeft(2, '0')}.pdf';

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

  String _resolveChefName(LeaveRequest request, List<Equipe> equipes, List<Employe> employes) {
    final rawChef = request.chefName.trim();
    final rawEquipe = request.equipeName.trim();
    final normalizedChef = rawChef.toLowerCase();
    final normalizedEquipe = rawEquipe.toLowerCase();
    final looksLikeEquipeName = normalizedChef.isNotEmpty && normalizedChef == normalizedEquipe;

    if (rawChef.isNotEmpty && !looksLikeEquipeName) {
      return rawChef;
    }

    final equipeMatches = equipes.where((e) => e.id == request.equipeId).toList();
    if (equipeMatches.isNotEmpty) {
      final equipe = equipeMatches.first;
      final chefMatches = employes.where((e) => e.id == equipe.chefId).toList();
      if (chefMatches.isNotEmpty) return chefMatches.first.nom;
    }

    final submittedBy = request.submittedByName.trim();
    if (submittedBy.isNotEmpty && submittedBy.toLowerCase() != normalizedEquipe) {
      return submittedBy;
    }
    return rawChef.isNotEmpty ? rawChef : '-';
  }
}
