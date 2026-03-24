import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/smart_avatar.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart';
import '../employees/models/equipe_model.dart';
import '../shifts/shifts_provider.dart';
import '../shifts/models/shift_models.dart';
import 'models/overtime_model.dart';
import 'overtime_provider.dart';

/// صفحة بوانتاج الساعات الإضافية.
/// - الشاف يرى العمال المكلَّفين إليه لهذا اليوم ويُسجّل حضورهم/غيابهم.
/// - الأدمن يرى جميع التكاليف ليوم الحالي ويمكنه إضافة/حذف.
class OvertimePage extends StatelessWidget {
  const OvertimePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final overtime = context.watch<OvertimeProvider>();
    final emp = context.watch<EmployeesProvider>();

    if (auth.isChefEquipe && auth.equipeId != null) {
      overtime.watchForEquipe(auth.equipeId!);
    }

    if (auth.isDirecteur) {
      return _AdminOvertimeView(
        assignments: overtime.todayAssignments,
        employes: emp.employes,
        equipes: emp.equipes,
      );
    }

    if (auth.isChefEquipe) {
      final assignments =
          overtime.getAssignmentsForEquipe(auth.equipeId ?? '');
      return _ChefOvertimeView(
        assignments: assignments,
        equipeId: auth.equipeId ?? '',
      );
    }

    return const Center(
      child: Text('Accès non autorisé', style: TextStyle(color: Colors.grey)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vue Administrateur
// ─────────────────────────────────────────────────────────────────────────────

class _AdminOvertimeView extends StatelessWidget {
  final List<OvertimeAssignment> assignments;
  final List<Employe> employes;
  final List<Equipe> equipes;

  const _AdminOvertimeView({
    required this.assignments,
    required this.employes,
    required this.equipes,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final today = DateTime.now();

    return Padding(
      padding: EdgeInsets.all(mobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.more_time,
                    color: Colors.purple.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Heures supplémentaires',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                        '${today.day}/${today.month}/${today.year} — ${assignments.length} affectation(s)',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Affecter'),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.purple.shade600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (assignments.isEmpty)
            _EmptyState(
              icon: Icons.more_time,
              message: 'Aucune affectation de HS pour aujourd\'hui.',
              color: Colors.purple,
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: assignments.length,
                itemBuilder: (_, i) => _AdminAssignmentCard(
                  assignment: assignments[i],
                  employes: employes,
                  equipes: equipes,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AssignOvertimeDialog(
        employes: employes,
        equipes: equipes,
        date: DateTime.now(),
      ),
    );
  }
}

class _AdminAssignmentCard extends StatelessWidget {
  final OvertimeAssignment assignment;
  final List<Employe> employes;
  final List<Equipe> equipes;

  const _AdminAssignmentCard({
    required this.assignment,
    required this.employes,
    required this.equipes,
  });

  @override
  Widget build(BuildContext context) {
    final overtime = context.read<OvertimeProvider>();
    final e = employes.where((x) => x.id == assignment.employeId).toList();
    final emp = e.isEmpty ? null : e.first;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (assignment.attendanceStatus) {
      case OvertimeAttendanceStatus.present:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = 'Présent';
        break;
      case OvertimeAttendanceStatus.absent:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusLabel = 'Absent';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusLabel = 'En attente';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SmartAvatar(
              imageUrl: emp?.photoUrl,
              fallbackText: assignment.employeNom,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(assignment.employeNom,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.arrow_forward,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(assignment.targetEquipeName,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(assignment.overtimeMinutes / 60).toStringAsFixed(0)}h',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  Text(assignment.originalEquipeName,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(statusLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade400, size: 20),
              tooltip: 'Supprimer',
              onPressed: () async {
                final ok = await overtime.deleteAssignment(assignment.id);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Erreur lors de la suppression.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vue Shaf
// ─────────────────────────────────────────────────────────────────────────────

class _ChefOvertimeView extends StatelessWidget {
  final List<OvertimeAssignment> assignments;
  final String equipeId;

  const _ChefOvertimeView({
    required this.assignments,
    required this.equipeId,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final today = DateTime.now();

    return Padding(
      padding: EdgeInsets.all(mobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.more_time,
                    color: Colors.purple.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Heures supplémentaires — Mon équipe',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                        '${today.day}/${today.month}/${today.year} — ${assignments.length} travailleur(s) HS',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (assignments.isEmpty)
            _EmptyState(
              icon: Icons.more_time,
              message:
                  'Aucun travailleur en heures supplémentaires pour votre équipe aujourd\'hui.',
              color: Colors.purple,
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: assignments.length,
                itemBuilder: (_, i) => _ChefOvertimeCard(
                  assignment: assignments[i],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChefOvertimeCard extends StatelessWidget {
  final OvertimeAssignment assignment;

  const _ChefOvertimeCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final overtime = context.read<OvertimeProvider>();
    final isDirecteur = auth.isDirecteur;

    final isPresent = assignment.attendanceStatus == OvertimeAttendanceStatus.present;
    final isAbsent = assignment.attendanceStatus == OvertimeAttendanceStatus.absent;
    final isFinished = assignment.finished;
    final isLocked = assignment.locked;
    final statusSet = isPresent || isAbsent;

    // مقفل: لا يمكن التعديل إلا للأدمن
    final canEdit = !isLocked || isDirecteur;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isLocked ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLocked
            ? BorderSide(color: Colors.grey.shade300)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ─────────────────────────────────────────────────
            Row(
              children: [
                SmartAvatar(
                  fallbackText: assignment.employeNom,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(assignment.employeNom,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: Colors.purple.shade200, width: 0.5),
                        ),
                        child: Text(
                          'HS depuis: ${assignment.originalEquipeName}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocked)
                  Tooltip(
                    message: 'Rapport envoyé — modif. admin uniquement',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock,
                              size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('Envoyé',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(assignment.overtimeMinutes / 60).toStringAsFixed(0)}h prévues',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Corps ────────────────────────────────────────────────────
            if (isLocked && !isDirecteur)
              // Vue lecture seule pour le chef après envoi
              _LockedStatusDisplay(assignment: assignment)
            else if (isFinished && !isDirecteur)
              _FinishedDisplay(assignment: assignment)
            else ...[
              // Boutons présent / absent
              Row(
                children: [
                  Expanded(
                    child: _OvertimeStatusChip(
                      label: 'Présent',
                      icon: Icons.check,
                      selected: isPresent,
                      color: Colors.green,
                      disabled: !canEdit,
                      onTap: canEdit
                          ? () async {
                              await overtime.markAttendance(
                                assignment: assignment,
                                status: OvertimeAttendanceStatus.present,
                                chefId: auth.currentUser?.id,
                              );
                            }
                          : () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _OvertimeStatusChip(
                      label: 'Absent',
                      icon: Icons.close,
                      selected: isAbsent,
                      color: Colors.red,
                      disabled: !canEdit,
                      onTap: canEdit
                          ? () async {
                              await overtime.markAttendance(
                                assignment: assignment,
                                status: OvertimeAttendanceStatus.absent,
                                chefId: auth.currentUser?.id,
                              );
                            }
                          : () {},
                    ),
                  ),
                  if (isPresent && canEdit) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OvertimeStatusChip(
                        label: 'Fin HS',
                        icon: Icons.flag,
                        selected: isFinished,
                        color: Colors.blue,
                        onTap: () =>
                            _showFinishDialog(context, overtime, auth),
                      ),
                    ),
                  ],
                ],
              ),

              // Bouton Envoyer rapport (visible quand statut est défini et non verrouillé)
              if (statusSet && !isLocked) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Envoyer & Verrouiller le rapport'),
                    onPressed: () async {
                      final chefId = auth.currentUser?.id ?? '';
                      final ok = await overtime.submitAndLock(
                        assignment: assignment,
                        chefId: chefId,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Définissez la présence avant d\'envoyer.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],

              // Bouton débloquer (admin seulement)
              if (isLocked && isDirecteur) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text('Débloquer (Admin)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                  ),
                  onPressed: () async {
                    await overtime.adminUnlock(assignment.id);
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showFinishDialog(
      BuildContext context, OvertimeProvider overtime, AuthProvider auth) {
    int minutes = assignment.overtimeMinutes;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Confirmer la fin des HS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(assignment.employeNom,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Heures effectuées :',
                  style: TextStyle(
                      color: Colors.grey.shade700, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: minutes >= 60
                        ? () => setState(() => minutes -= 60)
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(minutes / 60).toStringAsFixed(1)}h ($minutes min)',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => minutes += 60),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple.shade600),
              onPressed: () async {
                await overtime.markFinished(
                  assignment: assignment,
                  overtimeMinutes: minutes,
                  chefId: auth.currentUser?.id,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }
}

// عرض حالة مقفلة (للشاف بعد الإرسال)
class _LockedStatusDisplay extends StatelessWidget {
  final OvertimeAssignment assignment;
  const _LockedStatusDisplay({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final isPresent =
        assignment.attendanceStatus == OvertimeAttendanceStatus.present;
    final isAbsent =
        assignment.attendanceStatus == OvertimeAttendanceStatus.absent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPresent
            ? Colors.green.shade50
            : isAbsent
                ? Colors.red.shade50
                : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPresent
              ? Colors.green.shade200
              : isAbsent
                  ? Colors.red.shade200
                  : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPresent
                ? Icons.check_circle
                : isAbsent
                    ? Icons.cancel
                    : Icons.schedule,
            color: isPresent
                ? Colors.green.shade600
                : isAbsent
                    ? Colors.red.shade600
                    : Colors.grey.shade500,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPresent
                      ? 'Présent — ${(assignment.overtimeMinutes / 60).toStringAsFixed(1)}h'
                      : isAbsent
                          ? 'Absent'
                          : 'En attente',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isPresent
                        ? Colors.green.shade700
                        : isAbsent
                            ? Colors.red.shade700
                            : Colors.grey.shade600,
                  ),
                ),
                Text('Rapport envoyé — verrouillé',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// عرض حالة منتهي (shift terminé)
class _FinishedDisplay extends StatelessWidget {
  final OvertimeAssignment assignment;
  const _FinishedDisplay({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
          const SizedBox(width: 8),
          Text(
            'Shift terminé — ${(assignment.overtimeMinutes / 60).toStringAsFixed(1)}h confirmées',
            style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _OvertimeStatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool disabled;

  const _OvertimeStatusChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled ? Colors.grey.shade400 : color;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.shade100
              : selected
                  ? effectiveColor.withValues(alpha: 0.12)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled
                ? Colors.grey.shade300
                : selected
                    ? effectiveColor
                    : Colors.grey.shade300,
            width: selected && !disabled ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: disabled
                    ? Colors.grey.shade400
                    : selected
                        ? effectiveColor
                        : Colors.grey.shade500),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected && !disabled
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: disabled
                    ? Colors.grey.shade400
                    : selected
                        ? effectiveColor
                        : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog: تكليف موظف بساعات إضافية (الأدمن) — اختيار فريق → موظف → فريق مستقبِل
// ─────────────────────────────────────────────────────────────────────────────

class _AssignOvertimeDialog extends StatefulWidget {
  final List<Employe> employes;
  final List<Equipe> equipes;
  final DateTime date;

  const _AssignOvertimeDialog({
    required this.employes,
    required this.equipes,
    required this.date,
  });

  @override
  State<_AssignOvertimeDialog> createState() => _AssignOvertimeDialogState();
}

class _AssignOvertimeDialogState extends State<_AssignOvertimeDialog> {
  // الخطوة 1: اختيار الفريق الأصلي
  String? _selectedOrigEquipeId;
  // الخطوة 2: اختيار الموظف من الفريق
  String? _selectedEmployeId;
  // الخطوة 3: تاريخ ووقت الفريق المستقبِل
  late DateTime _targetDate;
  String? _selectedTargetEquipeId;
  int _overtimeMinutes = 480;

  @override
  void initState() {
    super.initState();
    // نبدأ بتاريخ اليوم التالي كافتراض منطقي
    _targetDate = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    ).add(const Duration(days: 1));
  }

  List<Equipe> get _sortedEquipes => List<Equipe>.from(widget.equipes)
    ..sort((a, b) => a.nom.compareTo(b.nom));

  /// وقت بداية شيفت معين في يوم معين
  DateTime _shiftStartOnDay(ShiftType shift, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    switch (shift) {
      case ShiftType.morning:
        return DateTime(d.year, d.month, d.day, 6, 0);
      case ShiftType.evening:
        return DateTime(d.year, d.month, d.day, 14, 0);
      case ShiftType.night:
        return DateTime(d.year, d.month, d.day, 22, 0);
      case ShiftType.rest:
        return d;
    }
  }

  /// أعضاء الفريق المختار النشطون
  List<Employe> get _membersOfSelectedEquipe {
    if (_selectedOrigEquipeId == null) return [];
    final eq = widget.equipes
        .where((e) => e.id == _selectedOrigEquipeId)
        .toList();
    if (eq.isEmpty) return [];
    final memberIds = eq.first.membreIds.toSet();
    return widget.employes
        .where((e) =>
            memberIds.contains(e.id) && e.statut == EmployeStatut.enService)
        .toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
  }

  @override
  Widget build(BuildContext context) {
    final overtime = context.read<OvertimeProvider>();
    final auth = context.read<AuthProvider>();
    final shiftsProvider = context.read<ShiftsProvider>();
    final now = widget.date;

    final origEq = _selectedOrigEquipeId != null
        ? widget.equipes
            .where((e) => e.id == _selectedOrigEquipeId)
            .toList()
            .firstOrNull
        : null;

    // شيفت الموظف في يوم التكليف (now)
    final origShift = origEq != null
        ? shiftsProvider.getShiftForEquipe(origEq.id, now)
        : null;
    // وقت انتهاء شيفت الموظف الأصلي
    final origShiftEnd = origShift != null && origShift != ShiftType.rest
        ? origShift.getShiftEnd(now)
        : null;

    final selectedEmp = _selectedEmployeId != null
        ? widget.employes
            .where((e) => e.id == _selectedEmployeId)
            .toList()
            .firstOrNull
        : null;

    // كل الفرق عدا الفريق الأصلي — مرتبة
    final allTargetEquipes = _sortedEquipes
        .where((eq) => eq.id != (_selectedOrigEquipeId ?? ''))
        .toList();

    // لكل فريق: احسب شيفته في _targetDate وتحقق منطقياً
    // فريق مقبول = يعمل (ليس RH) في _targetDate + شيفته يبدأ بعد انتهاء شيفت الموظف (إذا نفس اليوم)
    bool isTargetValid(Equipe eq) {
      final shift = shiftsProvider.getShiftForEquipe(eq.id, _targetDate);
      if (shift == ShiftType.rest) return false;
      // إذا كان يوم _targetDate = يوم now، تحقق من ترتيب الشيفت
      final isSameDay = _targetDate.year == now.year &&
          _targetDate.month == now.month &&
          _targetDate.day == now.day;
      if (isSameDay && origShiftEnd != null) {
        // وقت بدء شيفت الفريق المستقبِل
        final targetStart = _shiftStartOnDay(shift, _targetDate);
        // يجب أن يبدأ الشيفت المستقبِل بعد (أو عند) انتهاء شيفت الموظف
        if (targetStart.isBefore(origShiftEnd)) return false;
      }
      return true;
    }

    // الفريق المستقبِل المختار وشيفته
    final targetEq = _selectedTargetEquipeId != null
        ? widget.equipes
            .where((eq) => eq.id == _selectedTargetEquipeId)
            .toList()
            .firstOrNull
        : null;
    final targetShift = targetEq != null
        ? shiftsProvider.getShiftForEquipe(targetEq.id, _targetDate)
        : null;
    final targetIsRest = targetShift == ShiftType.rest;
    final targetIsInvalid = targetEq != null && !isTargetValid(targetEq);

    final canConfirm = selectedEmp != null &&
        _selectedTargetEquipeId != null &&
        !targetIsRest &&
        !targetIsInvalid;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.more_time, color: Colors.purple.shade600, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Affecter en Heures Supplémentaires',
                style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête date
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 13, color: Colors.purple.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${now.day}/${now.month}/${now.year}',
                      style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── ÉTAPE 1 : Équipe source ──────────────────────────────────
              _StepLabel(number: '1', label: 'Sélectionner l\'équipe source'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedOrigEquipeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  hintText: 'Équipe du travailleur',
                ),
                items: _sortedEquipes.map((eq) {
                  final shift = shiftsProvider.getShiftForEquipe(eq.id, now);
                  return DropdownMenuItem(
                    value: eq.id,
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(eq.nom,
                                overflow: TextOverflow.ellipsis)),
                        _ShiftBadge(shift: shift),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  _selectedOrigEquipeId = v;
                  _selectedEmployeId = null;
                  _selectedTargetEquipeId = null;
                }),
              ),

              // ── ÉTAPE 2 : Employé de l'équipe ────────────────────────────
              if (_selectedOrigEquipeId != null) ...[
                const SizedBox(height: 16),
                _StepLabel(number: '2', label: 'Sélectionner le travailleur'),
                const SizedBox(height: 8),
                if (_membersOfSelectedEquipe.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text('Aucun membre actif dans cette équipe.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800)),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedEmployeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      hintText: 'Choisir le travailleur',
                    ),
                    items: _membersOfSelectedEquipe
                        .map((e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.nom,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedEmployeId = v;
                      _selectedTargetEquipeId = null;
                    }),
                  ),
              ],

              // ── ÉTAPE 3 : Équipe cible ───────────────────────────────────
              if (_selectedEmployeId != null) ...[
                const SizedBox(height: 16),
                _StepLabel(
                    number: '3',
                    label: 'Équipe cible (qui reçoit le travailleur)'),
                const SizedBox(height: 8),

                // ── منتقي تاريخ الشيفت المستقبِل ─────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.calendar_month,
                        color: Colors.blue.shade600, size: 20),
                    title: Text(
                      'Date du shift cible',
                      style: TextStyle(
                          fontSize: 12, color: Colors.blue.shade700),
                    ),
                    subtitle: Text(
                      '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue.shade900),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // زر اليوم نفسه
                        _DateChip(
                          label: 'Auj.',
                          selected: _targetDate.day == now.day &&
                              _targetDate.month == now.month &&
                              _targetDate.year == now.year,
                          onTap: () => setState(() {
                            _targetDate = DateTime(
                                now.year, now.month, now.day);
                            _selectedTargetEquipeId = null;
                          }),
                        ),
                        const SizedBox(width: 6),
                        // زر اليوم التالي
                        _DateChip(
                          label: 'Dem.',
                          selected: _targetDate.day != now.day ||
                              _targetDate.month != now.month ||
                              _targetDate.year != now.year,
                          onTap: () => setState(() {
                            _targetDate = DateTime(
                                now.year, now.month, now.day)
                                .add(const Duration(days: 1));
                            _selectedTargetEquipeId = null;
                          }),
                        ),
                        const SizedBox(width: 6),
                        // منتقي تاريخ مخصص
                        IconButton(
                          tooltip: 'Choisir une date',
                          icon: Icon(Icons.edit_calendar,
                              size: 18, color: Colors.blue.shade600),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _targetDate,
                              firstDate: DateTime(now.year, now.month,
                                  now.day),
                              lastDate: now
                                  .add(const Duration(days: 30)),
                            );
                            if (picked != null) {
                              setState(() {
                                _targetDate = picked;
                                _selectedTargetEquipeId = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // معلومة شيفت الموظف الأصلي
                if (origShift != null && origShift != ShiftType.rest)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Shift actuel de l\'employé : ${origShift.shortLabel} (${origShift.timeRange}) — '
                            'Seuls les shifts commençant après sa fin sont disponibles.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Liste des équipes cibles avec badge shift et indicateur actif/repos
                ...allTargetEquipes.map((eq) {
                  final shift =
                      shiftsProvider.getShiftForEquipe(eq.id, _targetDate);
                  final isRest = shift == ShiftType.rest;
                  final isInvalid = !isTargetValid(eq);
                  final isDisabled = isRest || isInvalid;
                  final isSelected = eq.id == _selectedTargetEquipeId;

                  String? disabledReason;
                  if (isRest) {
                    disabledReason = 'En repos ce jour-là';
                  } else if (isInvalid) {
                    disabledReason =
                        'Shift avant la fin du shift de l\'employé';
                  }

                  return GestureDetector(
                    onTap: isDisabled
                        ? null
                        : () => setState(() => _selectedTargetEquipeId =
                            isSelected ? null : eq.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? Colors.grey.shade100
                            : isSelected
                                ? Colors.purple.shade50
                                : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDisabled
                              ? Colors.grey.shade300
                              : isSelected
                                  ? Colors.purple.shade400
                                  : Colors.grey.shade300,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: isDisabled
                                ? Colors.grey.shade400
                                : isSelected
                                    ? Colors.purple.shade600
                                    : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eq.nom,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isDisabled
                                        ? Colors.grey.shade400
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  disabledReason ??
                                      shift.timeRange,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isInvalid
                                          ? Colors.red.shade400
                                          : Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ShiftBadge(shift: shift, large: true),
                        ],
                      ),
                    ),
                  );
                }),

                // تحذير إذا لا توجد فرق متاحة
                if (allTargetEquipes
                    .every((eq) => !isTargetValid(eq)))
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber,
                            size: 16,
                            color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Aucune équipe disponible pour ce créneau. '
                            'Essayez "Demain" ou choisissez une autre date.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Durée prévue ─────────────────────────────────────────
                _StepLabel(number: '4', label: 'Durée des HS prévue'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: Colors.purple.shade400),
                        onPressed: _overtimeMinutes >= 60
                            ? () =>
                                setState(() => _overtimeMinutes -= 60)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Text(
                            '${(_overtimeMinutes / 60).toStringAsFixed(0)}h',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700),
                          ),
                          Text('$_overtimeMinutes min',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline,
                            color: Colors.purple.shade400),
                        onPressed: () =>
                            setState(() => _overtimeMinutes += 60),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: canConfirm
                  ? Colors.purple.shade600
                  : Colors.grey.shade300),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Confirmer'),
          onPressed: canConfirm
              ? () async {
                  if (targetEq == null || selectedEmp == null) return;

                  // Resolve chef name from chefId
                  final chefEmp = widget.employes
                      .where((x) => x.id == targetEq.chefId)
                      .toList();
                  final chefName = chefEmp.isEmpty
                      ? targetEq.chefId
                      : chefEmp.first.nom;

                  final ok = await overtime.assignOvertime(
                    employeId: selectedEmp.id,
                    employeNom: selectedEmp.nom,
                    employeCin: selectedEmp.cin,
                    originalEquipeId: origEq?.id ?? '',
                    originalEquipeName: origEq?.nom ?? '',
                    targetEquipeId: targetEq.id,
                    targetEquipeName: targetEq.nom,
                    targetChefName: chefName,
                    date: _targetDate,
                    adminId: auth.currentUser?.id,
                    overtimeMinutes: _overtimeMinutes,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok
                            ? '${selectedEmp.nom} affecté en HS dans ${targetEq.nom}'
                            : 'Erreur lors de l\'affectation.'),
                        backgroundColor:
                            ok ? Colors.green : Colors.red,
                      ),
                    );
                  }
                }
              : null,
        ),
      ],
    );
  }
}

// زر تاريخ سريع (اليوم / الغد)
class _DateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DateChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade600 : Colors.blue.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.blue.shade800,
          ),
        ),
      ),
    );
  }
}

// Badge compact pour le type de shift
class _ShiftBadge extends StatelessWidget {
  final ShiftType shift;
  final bool large;

  const _ShiftBadge({required this.shift, this.large = false});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (shift) {
      case ShiftType.morning:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade800;
        break;
      case ShiftType.evening:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        break;
      case ShiftType.night:
        bg = Colors.indigo.shade100;
        fg = Colors.indigo.shade800;
        break;
      case ShiftType.rest:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade600;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 8 : 5, vertical: large ? 4 : 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        large ? '${shift.shortLabel} · ${shift.timeRange}' : shift.shortLabel,
        style: TextStyle(
            fontSize: large ? 11 : 10,
            fontWeight: FontWeight.bold,
            color: fg),
      ),
    );
  }
}

// رقم خطوة + تسمية
class _StepLabel extends StatelessWidget {
  final String number;
  final String label;

  const _StepLabel({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.purple.shade600,
            shape: BoxShape.circle,
          ),
          child: Text(number,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets communs
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
