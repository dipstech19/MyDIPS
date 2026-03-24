import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  const RoleBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class StatBox extends StatelessWidget {
  final int number;
  final String label;
  final Color color;
  const StatBox({super.key, required this.number, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$number', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  const PrimaryButton({super.key, required this.label, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Material(
      color: c,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class AvatarCircle extends StatelessWidget {
  final String letter;
  final Color color;
  final double size;
  const AvatarCircle({super.key, required this.letter, required this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color.withValues(alpha: 0.3),
      child: Text(
        letter.isNotEmpty ? letter.substring(0, 1).toUpperCase() : '?',
        style: TextStyle(color: color, fontSize: size * 0.4, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const InfoBanner({super.key, required this.text, required this.color, this.icon = Icons.info_outline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}

enum AttendanceState { unmarked, present, absent, notInVehicle }

/// Worker card: avatar, name, CIN, and one toggle (unmarked → present → absent → unmarked)
class WorkerTile extends StatelessWidget {
  final String name;
  final String cin;
  final AttendanceState state;
  final ValueChanged<AttendanceState> onStateChanged;

  const WorkerTile({
    super.key,
    required this.name,
    required this.cin,
    required this.state,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AvatarCircle(letter: name.isNotEmpty ? name.substring(0, 1) : '?', color: AppColors.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('CIN: $cin', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            _ToggleButton(state: state, onTap: () {
              switch (state) {
                case AttendanceState.unmarked:
                  onStateChanged(AttendanceState.present);
                  break;
                case AttendanceState.present:
                  onStateChanged(AttendanceState.absent);
                  break;
                case AttendanceState.absent:
                case AttendanceState.notInVehicle:
                  onStateChanged(AttendanceState.unmarked);
                  break;
              }
            }),
          ],
        ),
      ),
    );
  }
}

/// Reusable attendance toggle: unmarked → present → absent → unmarked
class AttendanceToggleButton extends StatelessWidget {
  final AttendanceState state;
  final VoidCallback onTap;

  const AttendanceToggleButton({super.key, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    IconData icon;
    switch (state) {
      case AttendanceState.unmarked:
        bgColor = AppColors.border;
        icon = Icons.circle_outlined;
        break;
      case AttendanceState.present:
        bgColor = AppColors.green;
        icon = Icons.check;
        break;
      case AttendanceState.absent:
        bgColor = AppColors.red;
        icon = Icons.close;
        break;
      case AttendanceState.notInVehicle:
        bgColor = AppColors.yellow;
        icon = Icons.directions_car;
        break;
    }
    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final AttendanceState state;
  final VoidCallback onTap;

  const _ToggleButton({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) => AttendanceToggleButton(state: state, onTap: onTap);
}
class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? Colors.white : color)),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverStatusChips extends StatelessWidget {
  final AttendanceState current;
  final ValueChanged<AttendanceState> onSelect;
  final String presentLabel;
  final String absentLabel;
  final String notInVehicleLabel;
  const DriverStatusChips({super.key, required this.current, required this.onSelect, required this.presentLabel, required this.absentLabel, required this.notInVehicleLabel});

  @override
  Widget build(BuildContext context) {
    if (current == AttendanceState.present) return _StatusChip(label: presentLabel, icon: Icons.check, color: AppColors.green, selected: true, onTap: () => onSelect(AttendanceState.unmarked));
    if (current == AttendanceState.absent) return _StatusChip(label: absentLabel, icon: Icons.close, color: AppColors.red, selected: true, onTap: () => onSelect(AttendanceState.unmarked));
    if (current == AttendanceState.notInVehicle) return _StatusChip(label: notInVehicleLabel, icon: Icons.directions_car, color: AppColors.yellow, selected: true, onTap: () => onSelect(AttendanceState.unmarked));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _StatusChip(label: presentLabel, icon: Icons.check, color: AppColors.green, selected: false, onTap: () => onSelect(AttendanceState.present)),
        _StatusChip(label: absentLabel, icon: Icons.close, color: AppColors.red, selected: false, onTap: () => onSelect(AttendanceState.absent)),
        _StatusChip(label: notInVehicleLabel, icon: Icons.directions_car, color: AppColors.yellow, selected: false, onTap: () => onSelect(AttendanceState.notInVehicle)),
      ],
    );
  }
}

class ChefStatusChips extends StatelessWidget {
  final AttendanceState current;
  final ValueChanged<AttendanceState> onSelect;
  final String presentLabel;
  final String absentLabel;
  const ChefStatusChips({super.key, required this.current, required this.onSelect, required this.presentLabel, required this.absentLabel});

  @override
  Widget build(BuildContext context) {
    if (current == AttendanceState.present) return _StatusChip(label: presentLabel, icon: Icons.check, color: AppColors.green, selected: true, onTap: () => onSelect(AttendanceState.unmarked));
    if (current == AttendanceState.absent) return _StatusChip(label: absentLabel, icon: Icons.close, color: AppColors.red, selected: true, onTap: () => onSelect(AttendanceState.unmarked));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _StatusChip(label: presentLabel, icon: Icons.check, color: AppColors.green, selected: false, onTap: () => onSelect(AttendanceState.present)),
        _StatusChip(label: absentLabel, icon: Icons.close, color: AppColors.red, selected: false, onTap: () => onSelect(AttendanceState.absent)),
      ],
    );
  }
}
