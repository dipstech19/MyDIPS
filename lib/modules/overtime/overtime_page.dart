import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/utils/responsive.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart';
import '../employees/models/equipe_model.dart';
import '../shifts/shifts_provider.dart';
import '../shifts/models/shift_models.dart';
import 'models/overtime_model.dart';
import 'overtime_provider.dart';

class OvertimePage extends StatefulWidget {
  const OvertimePage({super.key});

  @override
  State<OvertimePage> createState() => _OvertimePageState();
}

class _OvertimePageState extends State<OvertimePage> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final padding = pagePadding(context);
    final mobile = isMobile(context);
    if (auth.isDirecteur) {
      return _AdminOvertimeView(padding: padding, mobile: mobile);
    }
    return _ChefOvertimeView(padding: padding, mobile: mobile);
  }
}

// ════════════════════════════════════════════════════════════════
// Vue Chef
// ════════════════════════════════════════════════════════════════
class _ChefOvertimeView extends StatefulWidget {
  final double padding;
  final bool mobile;
  const _ChefOvertimeView({required this.padding, required this.mobile});

  @override
  State<_ChefOvertimeView> createState() => _ChefOvertimeViewState();
}

class _ChefOvertimeViewState extends State<_ChefOvertimeView> {
  String? _listeningEquipeId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final equipeId = auth.equipeId;
    // Start/restart stream whenever equipeId changes.
    if (equipeId != null &&
        equipeId.isNotEmpty &&
        equipeId != _listeningEquipeId) {
      _listeningEquipeId = equipeId;
      context.read<OvertimeProvider>().listenTodayForEquipe(equipeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OvertimeProvider>();
    final assignments = provider.todayAssignments;
    final error = provider.todayStreamError;
    final auth = context.read<AuthProvider>();
    final equipeId = auth.equipeId ?? '—';

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text('Erreur de chargement',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade700)),
              const SizedBox(height: 6),
              Text(error,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    context.read<OvertimeProvider>().listenTodayForEquipe(equipeId),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (assignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.more_time, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Aucune affectation d\'heures supplémentaires aujourd\'hui',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Équipe : $equipeId',
                    style: TextStyle(fontSize: 12, color: AppColors.brand)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(widget.padding),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active,
                  color: Colors.deepPurple.shade500, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Notification: ${assignments.length} personne(s) vont travailler avec vous aujourd\'hui.',
                  style: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...assignments.map(
          (a) => _ChefOvertimeCard(assignment: a, mobile: widget.mobile),
        ),
      ],
    );
  }
}

class _ChefOvertimeCard extends StatelessWidget {
  final OvertimeAssignment assignment;
  final bool mobile;
  const _ChefOvertimeCard({required this.assignment, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OvertimeProvider>();
    final auth = context.read<AuthProvider>();
    final shiftsProvider = context.watch<ShiftsProvider>();
    final ot = assignment;
    final dateStr =
        '${ot.date.day.toString().padLeft(2, '0')}/${ot.date.month.toString().padLeft(2, '0')}/${ot.date.year}';

    final arrived  = ot.attendanceStatus == OvertimeAttendanceStatus.present;
    final absent   = ot.attendanceStatus == OvertimeAttendanceStatus.absent;
    final departed = ot.departureConfirmedAt != null;
    DateTime shiftEnd(ShiftType shift, DateTime day) {
      switch (shift) {
        case ShiftType.morning:
          return DateTime(day.year, day.month, day.day, 14);
        case ShiftType.evening:
          return DateTime(day.year, day.month, day.day, 22);
        case ShiftType.night:
          return DateTime(day.year, day.month, day.day + 1, 6);
        case ShiftType.rest:
          return DateTime(day.year, day.month, day.day);
      }
    }

    DateTime shiftStart(ShiftType shift, DateTime day) {
      switch (shift) {
        case ShiftType.morning:
          return DateTime(day.year, day.month, day.day, 6);
        case ShiftType.evening:
          return DateTime(day.year, day.month, day.day, 14);
        case ShiftType.night:
          return DateTime(day.year, day.month, day.day, 22);
        case ShiftType.rest:
          return DateTime(day.year, day.month, day.day);
      }
    }

    final shiftDay = DateTime(ot.date.year, ot.date.month, ot.date.day);
    final targetShift =
        shiftsProvider.getShiftForEquipe(ot.targetEquipeId, shiftDay);
    final shiftStartedAt = shiftStart(targetShift, shiftDay);
    final shiftEndedAt = shiftEnd(targetShift, shiftDay);
    final now = DateTime.now();
    final canStartShift = now.isAfter(shiftStartedAt) || now.isAtSameMomentAs(shiftStartedAt);
    final canFinishShift = now.isAfter(shiftEndedAt) || now.isAtSameMomentAs(shiftEndedAt);

    return Card(
      margin: EdgeInsets.only(bottom: mobile ? 10 : 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ot.locked
              ? Colors.green.shade200
              : arrived
                  ? Colors.green.shade100
                  : absent
                      ? Colors.red.shade100
                      : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(mobile ? 14 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ot.employeNom,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.swap_horiz, size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text('${ot.originEquipeName}  →  ${ot.targetEquipeName}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                      Text('Date : $dateStr',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                if (ot.locked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text('Verrouillé',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                if (!ot.locked && departed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade100),
                    ),
                    child: Text('8h ✓',
                        style: TextStyle(fontSize: 12, color: Colors.indigo.shade700,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),

            if (!ot.locked) ...[
              const SizedBox(height: 12),
              if (!arrived && !absent) ...[
                if (!canStartShift)
                  Text(
                    'Le bouton début du shift sera disponible à ${shiftStartedAt.hour.toString().padLeft(2, '0')}:${shiftStartedAt.minute.toString().padLeft(2, '0')}.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                if (canStartShift)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await provider.confirmOvertimeArrival(ot.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Début du shift confirmé.'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.fixed,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('Début du shift'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => provider.markOvertimeAbsent(ot.id),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Absent'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],

              // Show end-shift only after planned shift end time.
              if (arrived && !departed) ...[
                if (!canFinishShift)
                  Text(
                    'Fin du shift disponible à ${shiftEndedAt.hour.toString().padLeft(2, '0')}:${shiftEndedAt.minute.toString().padLeft(2, '0')}.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                if (canFinishShift)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final chefId = auth.currentUser?.id ?? '';
                        await provider.confirmOvertimeDeparture(ot.id);
                        await provider.submitAndLock(ot.id, chefId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fin du shift confirmée — 8h enregistrées et envoyées.'),
                              backgroundColor: Colors.indigo,
                              behavior: SnackBarBehavior.fixed,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Fin du shift (8h auto)'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.indigo.shade600,
                      ),
                    ),
                  ),
              ],

              // If absent chosen, allow explicit final send/lock.
              if (absent) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final chefId = auth.currentUser?.id ?? '';
                      await provider.submitAndLock(ot.id, chefId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Absence envoyée et verrouillée.'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Envoyer absence'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ],

            // ── Admin: déverrouiller ────────────────────────
            if (ot.locked && auth.isDirecteur) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await provider.adminUnlock(ot.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Déverrouillé avec succès.'),
                          behavior: SnackBarBehavior.fixed,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text('Déverrouiller (Admin)'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OvertimeStatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final bool disabled;
  final VoidCallback? onTap;

  const _OvertimeStatusChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.disabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled && !selected ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? color : Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? color : Colors.grey.shade600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Vue Admin
// ════════════════════════════════════════════════════════════════
class _AdminOvertimeView extends StatefulWidget {
  final double padding;
  final bool mobile;
  const _AdminOvertimeView({required this.padding, required this.mobile});

  @override
  State<_AdminOvertimeView> createState() => _AdminOvertimeViewState();
}

class _AdminOvertimeViewState extends State<_AdminOvertimeView> {
  DateTime _filterDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OvertimeProvider>().listenForDate(_filterDate);
    });
  }

  void _changeDate(DateTime date) {
    setState(() => _filterDate = date);
    context.read<OvertimeProvider>().listenForDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final equipes = context.watch<EmployeesProvider>().equipes;
    final employes = context.watch<EmployeesProvider>().employes;
    final auth = context.watch<AuthProvider>();
    final assignments = context.watch<OvertimeProvider>().dateAssignments;
    final dateStr =
        '${_filterDate.day}/${_filterDate.month}/${_filterDate.year}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => _AssignOvertimeDialog(
                equipes: equipes, employes: employes),
          );
          // Stream auto-updates — no manual reload needed.
        },
        icon: const Icon(Icons.add),
        label: const Text('Affecter heures supp.'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(widget.padding),
            child: InkWell(
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _filterDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (p != null && mounted) _changeDate(p);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .primaryColor
                      .withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Theme.of(context)
                          .primaryColor
                          .withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 18,
                        color: Theme.of(context).primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Affectations du : $dateStr',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.edit, size: 16, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: assignments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.more_time,
                            size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Aucune affectation pour cette date.',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(
                        horizontal: widget.padding),
                    itemCount: assignments.length,
                    itemBuilder: (context, i) => _AdminAssignmentCard(
                      assignment: assignments[i],
                      mobile: widget.mobile,
                      onDelete: () => context
                          .read<OvertimeProvider>()
                          .deleteAssignment(assignments[i].id),
                      onUnlock: auth.isDirecteur
                          ? () => context
                              .read<OvertimeProvider>()
                              .adminUnlock(assignments[i].id)
                          : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminAssignmentCard extends StatelessWidget {
  final OvertimeAssignment assignment;
  final bool mobile;
  final VoidCallback onDelete;
  final VoidCallback? onUnlock;

  const _AdminAssignmentCard({
    required this.assignment,
    required this.mobile,
    required this.onDelete,
    this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final ot = assignment;
    Color statusColor;
    String statusLabel;
    switch (ot.attendanceStatus) {
      case OvertimeAttendanceStatus.present:
        statusColor = Colors.green;
        statusLabel = 'Présent';
        break;
      case OvertimeAttendanceStatus.absent:
        statusColor = Colors.red;
        statusLabel = 'Absent';
        break;
      case OvertimeAttendanceStatus.unset:
        statusColor = Colors.grey;
        statusLabel = 'Non enregistré';
    }

    return Card(
      margin: EdgeInsets.only(bottom: mobile ? 10 : 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
            horizontal: mobile ? 14 : 12, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(Icons.person, color: statusColor, size: 22),
        ),
        title: Text(ot.employeNom,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${ot.originEquipeName}  →  ${ot.targetEquipeName}',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('Statut : $statusLabel',
                style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.w500)),
            if (ot.locked)
              Text('Verrouillé ✓',
                  style: TextStyle(
                      fontSize: 11, color: Colors.green.shade700)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ot.locked && onUnlock != null)
              IconButton(
                icon: Icon(Icons.lock_open,
                    color: Colors.orange.shade600),
                tooltip: 'Déverrouiller',
                onPressed: onUnlock,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Supprimer',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Dialogue d'affectation des heures supplémentaires
// ════════════════════════════════════════════════════════════════
class _AssignOvertimeDialog extends StatefulWidget {
  final List<Equipe> equipes;
  final List<Employe> employes;

  const _AssignOvertimeDialog(
      {required this.equipes, required this.employes});

  @override
  State<_AssignOvertimeDialog> createState() =>
      _AssignOvertimeDialogState();
}

class _AssignOvertimeDialogState extends State<_AssignOvertimeDialog> {
  int _step = 0;
  Equipe? _originEquipe;
  Employe? _selectedEmployee;
  Equipe? _targetEquipe;
  DateTime _targetDate =
      DateTime.now().add(const Duration(days: 1));

  List<Equipe> get _equipes =>
      List<Equipe>.from(widget.equipes)
        ..sort((a, b) => a.nom.compareTo(b.nom));

  List<Employe> get _membersOfOrigin {
    if (_originEquipe == null) return [];
    return widget.employes
        .where((e) => _originEquipe!.membreIds.contains(e.id))
        .toList();
  }

  DateTime _shiftEnd(ShiftType shift, DateTime day) {
    switch (shift) {
      case ShiftType.morning:
        return DateTime(day.year, day.month, day.day, 14);
      case ShiftType.evening:
        return DateTime(day.year, day.month, day.day, 22);
      case ShiftType.night:
        return DateTime(day.year, day.month, day.day + 1, 6);
      case ShiftType.rest:
        return DateTime(day.year, day.month, day.day);
    }
  }

  DateTime _shiftStart(ShiftType shift, DateTime day) {
    switch (shift) {
      case ShiftType.morning:
        return DateTime(day.year, day.month, day.day, 6);
      case ShiftType.evening:
        return DateTime(day.year, day.month, day.day, 14);
      case ShiftType.night:
        return DateTime(day.year, day.month, day.day, 22);
      case ShiftType.rest:
        return DateTime(day.year, day.month, day.day);
    }
  }

  bool get canConfirm =>
      _originEquipe != null &&
      _selectedEmployee != null &&
      _targetEquipe != null;

  @override
  Widget build(BuildContext context) {
    final shiftsProvider = context.watch<ShiftsProvider>();
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    ShiftType? origShift;
    DateTime? origShiftEnd;
    if (_originEquipe != null && shiftsProvider.hasConfig) {
      origShift =
          shiftsProvider.getShiftForEquipe(_originEquipe!.id, today);
      origShiftEnd = _shiftEnd(origShift, today);
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.more_time, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('Affecter des heures supplémentaires'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepLabel(number: 1, label: 'Choisir l\'équipe d\'origine', active: true),
              DropdownButtonFormField<Equipe>(
                value: _originEquipe,
                hint: const Text('Choisir l\'équipe'),
                items: _equipes
                    .map((eq) => DropdownMenuItem(
                        value: eq, child: Text(eq.nom)))
                    .toList(),
                onChanged: (eq) => setState(() {
                  _originEquipe = eq;
                  _selectedEmployee = null;
                  _targetEquipe = null;
                  if (eq != null) _step = 1;
                }),
                decoration:
                    const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),

              if (_step >= 1) ...[
                _StepLabel(
                    number: 2, label: 'Choisir le collaborateur', active: true),
                if (_membersOfOrigin.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Aucun collaborateur dans cette équipe.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade700)),
                  )
                else
                  DropdownButtonFormField<Employe>(
                    value: _selectedEmployee,
                    hint: const Text('Choisir le collaborateur'),
                    items: _membersOfOrigin
                        .map((e) => DropdownMenuItem(
                            value: e, child: Text(e.nom)))
                        .toList(),
                    onChanged: (e) => setState(() {
                      _selectedEmployee = e;
                      _targetEquipe = null;
                      if (e != null) _step = 2;
                    }),
                    decoration: const InputDecoration(
                        border: OutlineInputBorder()),
                  ),
                const SizedBox(height: 14),
              ],

              if (_step >= 2) ...[
                _StepLabel(
                    number: 3,
                    label: 'Choisir la date et l\'équipe',
                    active: true),
                Row(
                  children: [
                    _DateChip(
                      label: 'Aujourd\'hui',
                      selected: _targetDate.year == todayDay.year &&
                          _targetDate.month == todayDay.month &&
                          _targetDate.day == todayDay.day,
                      onTap: () => setState(() {
                        _targetDate = todayDay;
                        _targetEquipe = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _DateChip(
                      label: 'Demain',
                      selected: DateTime(_targetDate.year,
                                  _targetDate.month, _targetDate.day)
                              .difference(todayDay)
                              .inDays ==
                          1,
                      onTap: () => setState(() {
                        _targetDate =
                            todayDay.add(const Duration(days: 1));
                        _targetEquipe = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _targetDate,
                          firstDate: todayDay,
                          lastDate: todayDay
                              .add(const Duration(days: 30)),
                        );
                        if (p != null) {
                          setState(() {
                            _targetDate = p;
                            _targetEquipe = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text(
                          '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (origShift != null && origShift != ShiftType.rest)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.brandLight),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppColors.brand),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Shift actuel du collaborateur : ${origShift.shortLabel} (${origShift.timeRange})\n'
                            'Même jour : uniquement les shifts démarrant après la fin de son shift.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.brandDark),
                          ),
                        ),
                      ],
                    ),
                  ),

                ..._equipes
                    .where((eq) => eq.id != _originEquipe?.id)
                    .map((eq) {
                  if (!shiftsProvider.hasConfig) {
                    return _TargetEquipeTile(
                      equipe: eq,
                      shiftLabel: null,
                      disabled: false,
                      disabledReason: null,
                      selected: _targetEquipe?.id == eq.id,
                      onTap: () => setState(() => _targetEquipe = eq),
                    );
                  }
                  final targetShift =
                      shiftsProvider.getShiftForEquipe(eq.id, _targetDate);
                  String? disabledReason;
                  if (targetShift == ShiftType.rest) {
                    disabledReason = 'En repos ce jour-là';
                  } else if (origShift != null && origShiftEnd != null) {
                    final isSameDay = DateTime(_targetDate.year,
                            _targetDate.month, _targetDate.day) ==
                        todayDay;
                    if (isSameDay) {
                      final targetStart =
                          _shiftStart(targetShift, _targetDate);
                      if (targetStart.isBefore(origShiftEnd)) {
                        disabledReason =
                            'Le shift commence avant la fin du shift du collaborateur';
                      }
                    }
                  }
                  return _TargetEquipeTile(
                    equipe: eq,
                    shiftLabel:
                        '${targetShift.shortLabel} (${targetShift.timeRange})',
                    disabled: disabledReason != null,
                    disabledReason: disabledReason,
                    selected: _targetEquipe?.id == eq.id,
                    onTap: disabledReason == null
                        ? () => setState(() => _targetEquipe = eq)
                        : null,
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () async {
                  final auth = context.read<AuthProvider>();
                  await context.read<OvertimeProvider>().assignOvertime(
                        employeId: _selectedEmployee!.id,
                        employeNom: _selectedEmployee!.nom,
                        originEquipeId: _originEquipe!.id,
                        originEquipeName: _originEquipe!.nom,
                        targetEquipeId: _targetEquipe!.id,
                        targetEquipeName: _targetEquipe!.nom,
                        date: _targetDate,
                        adminId: auth.currentUser?.id ?? '',
                      );
                  if (context.mounted) Navigator.pop(context);
                }
              : null,
          child: const Text('Confirmer l\'affectation'),
        ),
      ],
    );
  }
}

// ── Widgets utilitaires ──────────────────────────────────────────────

class _TargetEquipeTile extends StatelessWidget {
  final Equipe equipe;
  final String? shiftLabel;
  final bool disabled;
  final String? disabledReason;
  final bool selected;
  final VoidCallback? onTap;

  const _TargetEquipeTile({
    required this.equipe,
    required this.shiftLabel,
    required this.disabled,
    required this.disabledReason,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.groups,
                    size: 20,
                    color: selected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(equipe.nom,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: disabled ? Colors.grey.shade600 : null,
                          )),
                      if (shiftLabel != null)
                        Text(shiftLabel!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600)),
                      if (disabledReason != null)
                        Text(disabledReason!,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700)),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle,
                      color: Theme.of(context).primaryColor, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final int number;
  final String label;
  final bool active;

  const _StepLabel(
      {required this.number,
      required this.label,
      required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: active
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$number',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? null : Colors.grey.shade500,
              )),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? Colors.white : null,
            )),
      ),
    );
  }
}
