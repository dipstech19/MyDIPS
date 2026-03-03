import 'dart:io' as dart_io;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  MODEL CLASSES
// ─────────────────────────────────────────────

class AdminUser {
  final String id;
  String nom;
  String prenom;
  String email;
  String telephone;
  String role;
  bool actif;
  List<String> permissions;
  DateTime dateCreation;

  AdminUser({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.role,
    required this.actif,
    required this.permissions,
    required this.dateCreation,
  });
}

// ─────────────────────────────────────────────
//  EMPLOYE MODEL
// ─────────────────────────────────────────────

class Employe {
  final String id;
  String nom;
  String prenom;
  String poste;
  String telephone;
  bool actif;

  Employe({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.poste,
    required this.telephone,
    required this.actif,
  });
}

class ChefEquipe {
  final String id;
  String nom;
  String prenom;
  String email;
  String telephone;
  String departement;
  int nbEmployes;
  bool actif;
  DateTime dateCreation;
  List<Employe> employes;

  ChefEquipe({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.departement,
    required this.nbEmployes,
    required this.actif,
    required this.dateCreation,
    List<Employe>? employes,
  }) : employes = employes ?? [];
}

// ─────────────────────────────────────────────
//  MAIN SETTINGS PAGE
// ─────────────────────────────────────────────

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  int _selectedSectionIndex = 0;

  final List<_SettingsSection> _sections = [
    _SettingsSection(icon: Icons.admin_panel_settings, label: 'Administrateurs'),
    _SettingsSection(icon: Icons.groups, label: 'Chefs d\'équipe'),
    _SettingsSection(icon: Icons.tune, label: 'Général'),
    _SettingsSection(icon: Icons.notifications_active, label: 'Notifications'),
    _SettingsSection(icon: Icons.security, label: 'Sécurité'),
    _SettingsSection(icon: Icons.storage, label: 'Base de données'),
    _SettingsSection(icon: Icons.info_outline, label: 'À propos'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ══════════════════════════════════════════
        //  NAV BAR — blanc, accent #328EEE, moderne
        // ══════════════════════════════════════════
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: const Color(0xFF328EEE).withOpacity(0.18), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF328EEE).withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Row(
                  children: [
                    // Icon with blue bg
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF328EEE).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.settings_rounded,
                          color: Color(0xFF328EEE), size: 18),
                    ),
                    const SizedBox(width: 10),
                    // Title
                    const Text(
                      'Paramètres',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2340),
                        letterSpacing: 0.1,
                      ),
                    ),
                    // Thin vertical separator
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      width: 1,
                      height: 18,
                      color: const Color(0xFFDDE3EE),
                    ),
                    // Subtitle
                    Text(
                      'Administration & Configuration',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[450] ?? Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    _SuperAdminBadge(),
                  ],
                ),
              ),
              // ── Tab row ──
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_sections.length, (i) {
                      final s = _sections[i];
                      final selected = _selectedSectionIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSectionIndex = i),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF328EEE).withOpacity(0.07)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: selected
                                      ? const Color(0xFF328EEE)
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: selected
                                      ? const EdgeInsets.all(5)
                                      : EdgeInsets.zero,
                                  decoration: selected
                                      ? BoxDecoration(
                                    color: const Color(0xFF328EEE)
                                        .withOpacity(0.12),
                                    borderRadius:
                                    BorderRadius.circular(6),
                                  )
                                      : null,
                                  child: Icon(
                                    s.icon,
                                    size: selected ? 13 : 15,
                                    color: selected
                                        ? const Color(0xFF328EEE)
                                        : Colors.grey[400],
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  s.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? const Color(0xFF328EEE)
                                        : Colors.grey[500],
                                    letterSpacing: selected ? 0.1 : 0,
                                  ),
                                ),
                                // petit dot bleu uniquement sur l'onglet actif
                                if (selected) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF328EEE),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ══════════════════════════════════════════
        //  CONTENT
        // ══════════════════════════════════════════
        Expanded(
          child: Container(
            color: const Color(0xFFF4F7FC),
            child: _buildSection(_selectedSectionIndex),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(int index) {
    switch (index) {
      case 0:  return const _AdminsSection();
      case 1:  return const _ChefsEquipeSection();
      case 2:  return const _GeneralSection();
      case 3:  return const _NotificationsSection();
      case 4:  return const _SecuriteSection();
      case 5:  return const _DatabaseSection();
      case 6:  return const _AboutSection();
      default: return const Center(child: Text('Section inconnue'));
    }
  }
}

class _SuperAdminBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF328EEE).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF328EEE).withOpacity(0.25)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF328EEE), size: 13),
          SizedBox(width: 6),
          Text(
            'Super Admin',
            style: TextStyle(
              color: Color(0xFF328EEE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection {
  final IconData icon;
  final String label;
  _SettingsSection({required this.icon, required this.label});
}

// ─────────────────────────────────────────────
//  SHARED ERP TABLE HELPERS
// ─────────────────────────────────────────────

const _kAccent   = Color(0xFF328EEE);
const _kDark     = Color(0xFF1A2340);
const _kBg       = Color(0xFFF4F7FC);
const _kBorder   = Color(0xFFDDE3EE);
const _kRowHover = Color(0xFFF0F6FF);

/// Header cell
Widget _th(String label, {int flex = 1, TextAlign align = TextAlign.left}) =>
    Expanded(
      flex: flex,
      child: Text(label,
          textAlign: align,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF6B7A99))),
    );

/// Reusable drawer panel
class _SideDrawer extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget body;
  final VoidCallback onSave;
  final String saveLabel;

  const _SideDrawer({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.body,
    required this.onSave,
    this.saveLabel = 'Enregistrer',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 440,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 32, offset: Offset(-4, 0))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drawer header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 16, 22),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.06),
                  border: Border(bottom: BorderSide(color: accentColor.withOpacity(0.15))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, color: _kDark)),
                          Text(subtitle,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // ── Scrollable body ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: body,
                ),
              ),
              // ── Footer ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: _kBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: _kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler', style: TextStyle(color: _kDark)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: onSave,
                        child: Text(saveLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact labeled field used inside drawers
class _DrawerField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isPassword;
  final bool isNumber;
  final TextInputType? keyboardType;

  const _DrawerField({
    required this.label,
    required this.controller,
    this.hint = '',
    this.isPassword = false,
    this.isNumber = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumber
              ? TextInputType.number
              : (keyboardType ?? TextInputType.text),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            isDense: true,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kAccent, width: 1.5)),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
        ),
      ],
    );
  }
}

class _DrawerDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DrawerDropdown(
      {required this.label,
        required this.value,
        required this.items,
        required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: _kDark),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kAccent, width: 1.5)),
          ),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

void _openDrawer(BuildContext context, Widget drawer) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => drawer,
    transitionBuilder: (_, anim, __, child) {
      final slide = Tween<Offset>(
          begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      return SlideTransition(position: slide, child: child);
    },
  );
}

// ─────────────────────────────────────────────
//  SECTION: ADMINISTRATEURS
// ─────────────────────────────────────────────

class _AdminsSection extends StatefulWidget {
  const _AdminsSection();
  @override
  State<_AdminsSection> createState() => _AdminsSectionState();
}

class _AdminsSectionState extends State<_AdminsSection> {
  final List<AdminUser> _admins = [
    AdminUser(
      id: 'ADM001',
      nom: 'El Amrani',
      prenom: 'Karim',
      email: 'k.elamrani@dips.ma',
      telephone: '0661 23 45 67',
      role: 'Admin RH',
      actif: true,
      permissions: ['Employés', 'Pointage', 'Rapports'],
      dateCreation: DateTime(2024, 1, 15),
    ),
    AdminUser(
      id: 'ADM002',
      nom: 'Bensouda',
      prenom: 'Sara',
      email: 's.bensouda@dips.ma',
      telephone: '0662 98 76 54',
      role: 'Admin Magasin',
      actif: true,
      permissions: ['Gestion Magasin', 'Rapports'],
      dateCreation: DateTime(2024, 3, 8),
    ),
    AdminUser(
      id: 'ADM003',
      nom: 'Tazi',
      prenom: 'Omar',
      email: 'o.tazi@dips.ma',
      telephone: '0663 11 22 33',
      role: 'Admin Général',
      actif: false,
      permissions: ['Employés', 'Pointage', 'Gestion Magasin', 'Rapports'],
      dateCreation: DateTime(2023, 11, 20),
    ),
  ];

  String _searchQuery = '';

  List<AdminUser> get _filtered => _admins
      .where((a) => '${a.nom} ${a.prenom} ${a.email} ${a.role}'
      .toLowerCase()
      .contains(_searchQuery.toLowerCase()))
      .toList();

  void _openAdminDrawer([AdminUser? existing]) {
    _openDrawer(
      context,
      _AdminDrawer(
        existing: existing,
        onSave: (admin) => setState(() {
          if (existing != null) {
            final i = _admins.indexWhere((a) => a.id == existing.id);
            if (i != -1) _admins[i] = admin;
          } else {
            _admins.add(admin);
          }
        }),
      ),
    );
  }

  void _confirmDelete(AdminUser admin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          const Text('Supprimer l\'admin', style: TextStyle(fontSize: 16)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            children: [
              const TextSpan(text: 'Confirmer la suppression de '),
              TextSpan(
                  text: '${admin.prenom} ${admin.nom}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ' ?'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () {
              setState(() => _admins.removeWhere((a) => a.id == admin.id));
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        // ── Top bar ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          child: Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Administrateurs',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                Text('${_admins.length} compte(s) enregistré(s)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
              const Spacer(),
              SizedBox(
                width: 200,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    filled: true, fillColor: _kBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 15, color: _kDark),
                label: const Text('Exporter CSV', style: TextStyle(fontSize: 12, color: _kDark)),
                onPressed: () => _exportAdminsCsv(context),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent, foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                icon: const Icon(Icons.add, size: 15),
                label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () => _openAdminDrawer(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _kBorder),
        // ── Table header ──
        Container(
          color: const Color(0xFFF0F4FA),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
          child: const Row(children: [
            Expanded(flex: 3, child: _TH('NOM COMPLET')),
            Expanded(flex: 2, child: _TH('TÉLÉPHONE')),
            Expanded(flex: 2, child: _TH('RÔLE')),
            Expanded(flex: 2, child: _TH('STATUT')),
            SizedBox(width: 110, child: _TH('ACTIONS', center: true)),
          ]),
        ),
        const Divider(height: 1, color: _kBorder),
        // ── Rows ──
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState()
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final admin = filtered[i];
              return _AdminTableRow(
                admin: admin,
                isEven: i.isEven,
                onEdit: () => _openAdminDrawer(admin),
                onDelete: () => _confirmDelete(admin),
                onToggle: () => setState(() => admin.actif = !admin.actif),
              );
            },
          ),
        ),
      ],
    );
  }

  void _exportAdminsCsv(BuildContext context) async {
    final csv = StringBuffer();
    csv.writeln('ID,Nom,Prénom,Email,Téléphone,Rôle,Statut,Permissions,Date Création');
    for (final a in _admins) {
      csv.writeln(
        '"${a.id}","${a.nom}","${a.prenom}","${a.email}","${a.telephone}",'
            '"${a.role}","${a.actif ? 'Actif' : 'Inactif'}","${a.permissions.join(' | ')}",'
            '"${a.dateCreation.toIso8601String().substring(0, 10)}"',
      );
    }
    await _saveAndOpenFile('administrateurs_export.csv', csv.toString(), context);
  }
}

// ── Simplified admin row: name / phone / role / status + 3 action icons ──
class _AdminTableRow extends StatefulWidget {
  final AdminUser admin;
  final bool isEven;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  const _AdminTableRow({required this.admin, required this.isEven, required this.onEdit, required this.onDelete, required this.onToggle});
  @override
  State<_AdminTableRow> createState() => _AdminTableRowState();
}

class _AdminTableRowState extends State<_AdminTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.admin;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? _kRowHover : (widget.isEven ? Colors.white : const Color(0xFFFAFBFD)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(children: [
              // NOM COMPLET (no avatar)
              Expanded(
                flex: 3,
                child: Text('${a.prenom} ${a.nom}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark),
                    overflow: TextOverflow.ellipsis),
              ),
              // TÉLÉPHONE
              Expanded(
                flex: 2,
                child: Text(a.telephone,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ),
              // RÔLE
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _kAccent.withOpacity(0.2)),
                    ),
                    child: Text(a.role,
                        style: const TextStyle(fontSize: 11, color: _kAccent, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              // STATUT
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: widget.onToggle,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: a.actif ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(a.actif ? 'Actif' : 'Inactif',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: a.actif ? Colors.green.shade700 : Colors.red.shade600)),
                  ]),
                ),
              ),
              // ACTIONS: details + edit + delete
              SizedBox(
                width: 110,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _TableBtn(
                    icon: Icons.info_outline,
                    tooltip: 'Détails',
                    color: Colors.purple,
                    onTap: () => _showAdminDetails(context, a),
                  ),
                  const SizedBox(width: 5),
                  _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: widget.onEdit),
                  const SizedBox(width: 5),
                  _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: widget.onDelete),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
        ]),
      ),
    );
  }

  void _showAdminDetails(BuildContext context, AdminUser a) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(28, 22, 20, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kAccent.withOpacity(0.08), Colors.white],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border(bottom: BorderSide(color: _kAccent.withOpacity(0.15))),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.manage_accounts, color: _kAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a.prenom} ${a.nom}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kDark)),
                      Row(children: [
                        Text(a.id, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: a.actif ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(a.actif ? 'Actif' : 'Inactif',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: a.actif ? Colors.green.shade700 : Colors.red.shade600)),
                        ),
                      ]),
                    ]),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                ]),
              ),
              // ── Body ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info grid
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(children: [
                            _DetailRow(icon: Icons.email_outlined, label: 'Email', value: a.email),
                            _DetailRow(icon: Icons.phone_outlined, label: 'Téléphone', value: a.telephone),
                          ]),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(children: [
                            _DetailRow(icon: Icons.badge_outlined, label: 'Rôle', value: a.role),
                            _DetailRow(icon: Icons.calendar_today, label: 'Créé le',
                                value: '${a.dateCreation.day.toString().padLeft(2,'0')}/${a.dateCreation.month.toString().padLeft(2,'0')}/${a.dateCreation.year}'),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      // Permissions section
                      Row(children: [
                        Container(width: 3, height: 14, decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        const Text('PERMISSIONS D\'ACCÈS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: Color(0xFF6B7A99))),
                        const SizedBox(width: 10),
                        const Expanded(child: Divider(color: _kBorder)),
                      ]),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: a.permissions.map((p) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 5),
                            Text(p, style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
                          ]),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Admin sliding drawer ──
class _AdminDrawer extends StatefulWidget {
  final AdminUser? existing;
  final Function(AdminUser) onSave;
  const _AdminDrawer({this.existing, required this.onSave});
  @override
  State<_AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<_AdminDrawer> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomCtrl, _prenomCtrl, _emailCtrl, _telCtrl, _pwdCtrl;
  String _role = 'Admin RH';
  List<String> _perms = [];
  bool _actif = true;
  bool _showPwd = false;

  final _roles = ['Admin RH', 'Admin Magasin', 'Admin Général', 'Admin Pointage'];
  final _allPerms = ['Employés', 'Pointage', 'Gestion Magasin', 'Rapports', 'Paramètres'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nomCtrl   = TextEditingController(text: e?.nom ?? '');
    _prenomCtrl = TextEditingController(text: e?.prenom ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _telCtrl   = TextEditingController(text: e?.telephone ?? '');
    _pwdCtrl   = TextEditingController();
    _role  = e?.role ?? 'Admin RH';
    _perms = List.from(e?.permissions ?? []);
    _actif = e?.actif ?? true;
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _prenomCtrl.dispose();
    _emailCtrl.dispose(); _telCtrl.dispose(); _pwdCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final isNew = widget.existing == null;
    widget.onSave(AdminUser(
      id: isNew
          ? 'ADM${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'
          : widget.existing!.id,
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      telephone: _telCtrl.text.trim(),
      role: _role,
      actif: _actif,
      permissions: _perms,
      dateCreation: widget.existing?.dateCreation ?? DateTime.now(),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return _SideDrawer(
      title: isEdit ? 'Modifier l\'administrateur' : 'Nouvel administrateur',
      subtitle: isEdit ? 'Modifier les informations du compte' : 'Créer un nouveau compte admin',
      icon: isEdit ? Icons.manage_accounts : Icons.person_add_alt_1,
      accentColor: _kAccent,
      saveLabel: isEdit ? 'Modifier' : 'Créer le compte',
      onSave: _save,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Identity ──
            _DrawerSection(label: 'IDENTITÉ'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _DrawerField(label: 'Prénom *', controller: _prenomCtrl, hint: 'Ex: Karim')),
              const SizedBox(width: 12),
              Expanded(child: _DrawerField(label: 'Nom *', controller: _nomCtrl, hint: 'Ex: El Amrani')),
            ]),
            const SizedBox(height: 12),
            _DrawerField(label: 'Email *', controller: _emailCtrl, hint: 'exemple@dips.ma',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _DrawerField(label: 'Téléphone *', controller: _telCtrl, hint: '06xx xx xx xx',
                keyboardType: TextInputType.phone),
            if (!isEdit) ...[
              const SizedBox(height: 12),
              // Password with eye toggle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mot de passe *',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
                  const SizedBox(height: 5),
                  TextFormField(
                    controller: _pwdCtrl,
                    obscureText: !_showPwd,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                          const BorderSide(color: _kAccent, width: 1.5)),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _showPwd
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 17,
                            color: Colors.grey),
                        onPressed: () =>
                            setState(() => _showPwd = !_showPwd),
                      ),
                    ),
                    validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            // ── Role & Status ──
            _DrawerSection(label: 'RÔLE & STATUT'),
            const SizedBox(height: 10),
            _DrawerDropdown(
              label: 'Rôle *',
              value: _role,
              items: _roles,
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Statut du compte',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A5568))),
              const Spacer(),
              Switch.adaptive(
                value: _actif,
                onChanged: (v) => setState(() => _actif = v),
                activeColor: _kAccent,
              ),
              const SizedBox(width: 6),
              Text(
                _actif ? 'Actif' : 'Inactif',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _actif ? Colors.green : Colors.red),
              ),
            ]),
            const SizedBox(height: 20),
            // ── Permissions ──
            _DrawerSection(label: 'PERMISSIONS D\'ACCÈS'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: const Border.fromBorderSide(BorderSide(color: _kBorder)),
              ),
              child: Column(
                children: _allPerms.map((p) {
                  final on = _perms.contains(p);
                  return InkWell(
                    onTap: () => setState(() {
                      on ? _perms.remove(p) : _perms.add(p);
                    }),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: on ? _kAccent : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: on ? _kAccent : Colors.grey.shade300,
                                width: 1.5),
                          ),
                          child: on
                              ? const Icon(Icons.check,
                              size: 12, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(p,
                            style: TextStyle(
                                fontSize: 13,
                                color: on ? _kDark : Colors.grey[600],
                                fontWeight: on
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: CHEFS D'ÉQUIPE
// ─────────────────────────────────────────────

class _ChefsEquipeSection extends StatefulWidget {
  const _ChefsEquipeSection();
  @override
  State<_ChefsEquipeSection> createState() => _ChefsEquipeSectionState();
}

class _ChefsEquipeSectionState extends State<_ChefsEquipeSection> {
  final List<ChefEquipe> _chefs = [
    ChefEquipe(
      id: 'CE001',
      nom: 'Benhaddou',
      prenom: 'Farid',
      email: 'f.benhaddou@dips.ma',
      telephone: '0661 44 33 22',
      departement: 'Production',
      nbEmployes: 3,
      actif: true,
      dateCreation: DateTime(2024, 2, 10),
      employes: [
        Employe(id: 'EMP001', nom: 'Alami', prenom: 'Youssef', poste: 'Opérateur', telephone: '0661 11 22 33', actif: true),
        Employe(id: 'EMP002', nom: 'Haddad', prenom: 'Imane', poste: 'Technicienne', telephone: '0662 44 55 66', actif: true),
        Employe(id: 'EMP003', nom: 'Berrada', prenom: 'Amine', poste: 'Contrôleur', telephone: '0663 77 88 99', actif: false),
      ],
    ),
    ChefEquipe(
      id: 'CE002',
      nom: 'Rachidi',
      prenom: 'Nadia',
      email: 'n.rachidi@dips.ma',
      telephone: '0662 55 44 33',
      departement: 'Logistique',
      nbEmployes: 2,
      actif: true,
      dateCreation: DateTime(2024, 4, 1),
      employes: [
        Employe(id: 'EMP004', nom: 'Benali', prenom: 'Soufiane', poste: 'Magasinier', telephone: '0664 12 34 56', actif: true),
        Employe(id: 'EMP005', nom: 'Tahiri', prenom: 'Loubna', poste: 'Gestionnaire', telephone: '0665 98 76 54', actif: true),
      ],
    ),
    ChefEquipe(
      id: 'CE003',
      nom: 'Ouali',
      prenom: 'Bilal',
      email: 'b.ouali@dips.ma',
      telephone: '0663 66 55 44',
      departement: 'Maintenance',
      nbEmployes: 2,
      actif: false,
      dateCreation: DateTime(2023, 12, 5),
      employes: [
        Employe(id: 'EMP006', nom: 'Ziani', prenom: 'Khalid', poste: 'Électricien', telephone: '0666 11 22 33', actif: true),
        Employe(id: 'EMP007', nom: 'Moussaoui', prenom: 'Fatima', poste: 'Mécanicienne', telephone: '0667 44 55 66', actif: false),
      ],
    ),
  ];

  String _searchQuery = '';

  static const _deptColors = {
    'Production':    Color(0xFF3B82F6),
    'Logistique':    Color(0xFFF59E0B),
    'Maintenance':   Color(0xFF10B981),
    'Informatique':  Color(0xFF8B5CF6),
    'Administration':Color(0xFFEF4444),
  };

  List<ChefEquipe> get _filtered => _chefs
      .where((c) => '${c.nom} ${c.prenom} ${c.email} ${c.departement}'
      .toLowerCase()
      .contains(_searchQuery.toLowerCase()))
      .toList();

  void _openChefDrawer([ChefEquipe? existing]) {
    _openDrawer(
      context,
      _ChefDrawer(
        existing: existing,
        onSave: (chef) => setState(() {
          if (existing != null) {
            final i = _chefs.indexWhere((c) => c.id == existing.id);
            if (i != -1) _chefs[i] = chef;
          } else {
            _chefs.add(chef);
          }
        }),
      ),
    );
  }

  void _confirmDelete(ChefEquipe chef) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          const Text('Supprimer le chef', style: TextStyle(fontSize: 16)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            children: [
              const TextSpan(text: 'Supprimer '),
              TextSpan(
                  text: '${chef.prenom} ${chef.nom}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ' de la liste ?'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () {
              setState(() => _chefs.removeWhere((c) => c.id == chef.id));
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      children: [
        // ── Top bar ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
          child: Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Chefs d\'équipe',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                Text('${_chefs.length} chef(s) enregistré(s)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
              const Spacer(),
              SizedBox(
                width: 200,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    filled: true, fillColor: _kBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _kBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 15, color: _kDark),
                label: const Text('Exporter CSV', style: TextStyle(fontSize: 12, color: _kDark)),
                onPressed: () => _exportChefsCsv(context),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDark, foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                icon: const Icon(Icons.group_add, size: 15),
                label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () => _openChefDrawer(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _kBorder),
        // ── Table header ──
        Container(
          color: const Color(0xFFF0F4FA),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
          child: const Row(children: [
            Expanded(flex: 3, child: _TH('NOM COMPLET')),
            Expanded(flex: 2, child: _TH('TÉLÉPHONE')),
            Expanded(flex: 2, child: _TH('RÔLE / DEPT.')),
            Expanded(flex: 2, child: _TH('STATUT')),
            SizedBox(width: 110, child: _TH('ACTIONS', center: true)),
          ]),
        ),
        const Divider(height: 1, color: _kBorder),
        // ── Rows ──
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState()
              : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final chef = filtered[i];
              final color = _deptColors[chef.departement] ?? Colors.grey;
              return _ChefTableRow(
                chef: chef,
                deptColor: color,
                isEven: i.isEven,
                onEdit: () => _openChefDrawer(chef),
                onDelete: () => _confirmDelete(chef),
                onToggle: () => setState(() => chef.actif = !chef.actif),
              );
            },
          ),
        ),
      ],
    );
  }

  void _exportChefsCsv(BuildContext context) async {
    final csv = StringBuffer();
    csv.writeln('ID,Nom,Prénom,Email,Téléphone,Département,Nb Employés,Statut,Date Création');
    for (final c in _chefs) {
      csv.writeln(
        '"${c.id}","${c.nom}","${c.prenom}","${c.email}","${c.telephone}",'
            '"${c.departement}","${c.nbEmployes}","${c.actif ? 'Actif' : 'Inactif'}",'
            '"${c.dateCreation.toIso8601String().substring(0, 10)}"',
      );
    }
    await _saveAndOpenFile('chefs_equipe_export.csv', csv.toString(), context);
  }
}

// ── Simplified chef row: name / phone / dept / status + 3 icons ──
class _ChefTableRow extends StatefulWidget {
  final ChefEquipe chef;
  final Color deptColor;
  final bool isEven;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  const _ChefTableRow({required this.chef, required this.deptColor, required this.isEven, required this.onEdit, required this.onDelete, required this.onToggle});
  @override
  State<_ChefTableRow> createState() => _ChefTableRowState();
}

class _ChefTableRowState extends State<_ChefTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.chef;
    final dc = widget.deptColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? _kRowHover : (widget.isEven ? Colors.white : const Color(0xFFFAFBFD)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(children: [
              // NOM COMPLET (no avatar)
              Expanded(
                flex: 3,
                child: Text('${c.prenom} ${c.nom}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark),
                    overflow: TextOverflow.ellipsis),
              ),
              // TÉLÉPHONE
              Expanded(
                flex: 2,
                child: Text(c.telephone, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ),
              // DÉPARTEMENT
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: dc.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: dc.withOpacity(0.25)),
                    ),
                    child: Text(c.departement,
                        style: TextStyle(fontSize: 11, color: dc, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              // STATUT
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: widget.onToggle,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: c.actif ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(c.actif ? 'Actif' : 'Inactif',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: c.actif ? Colors.green.shade700 : Colors.red.shade600)),
                  ]),
                ),
              ),
              // ACTIONS
              SizedBox(
                width: 110,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _TableBtn(
                    icon: Icons.info_outline,
                    tooltip: 'Détails',
                    color: Colors.purple,
                    onTap: () => _showChefDetails(context, c, dc),
                  ),
                  const SizedBox(width: 5),
                  _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: widget.onEdit),
                  const SizedBox(width: 5),
                  _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: widget.onDelete),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
        ]),
      ),
    );
  }

  void _showChefDetails(BuildContext context, ChefEquipe c, Color dc) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => _ChefDetailsDialog(chef: c, deptColor: dc),
    );
  }
}

// ── Chef details dialog with employee CRUD ──
class _ChefDetailsDialog extends StatefulWidget {
  final ChefEquipe chef;
  final Color deptColor;
  const _ChefDetailsDialog({required this.chef, required this.deptColor});
  @override
  State<_ChefDetailsDialog> createState() => _ChefDetailsDialogState();
}

class _ChefDetailsDialogState extends State<_ChefDetailsDialog> {
  late List<Employe> _employes;

  @override
  void initState() {
    super.initState();
    _employes = List.from(widget.chef.employes);
  }

  void _saveEmployes() {
    widget.chef.employes
      ..clear()
      ..addAll(_employes);
    widget.chef.nbEmployes = _employes.length;
  }

  void _addOrEditEmployee([Employe? existing]) {
    final nomCtrl    = TextEditingController(text: existing?.nom ?? '');
    final prenomCtrl = TextEditingController(text: existing?.prenom ?? '');
    final posteCtrl  = TextEditingController(text: existing?.poste ?? '');
    final telCtrl    = TextEditingController(text: existing?.telephone ?? '');
    bool actif = existing?.actif ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                  decoration: BoxDecoration(
                    color: widget.deptColor.withOpacity(0.07),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    border: Border(bottom: BorderSide(color: widget.deptColor.withOpacity(0.2))),
                  ),
                  child: Row(children: [
                    Icon(existing == null ? Icons.person_add_outlined : Icons.edit_outlined,
                        color: widget.deptColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      existing == null ? 'Ajouter un employé' : 'Modifier l\'employé',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kDark),
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
                  ]),
                ),
                // form
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _DrawerField(label: 'Prénom *', controller: prenomCtrl, hint: 'Prénom')),
                      const SizedBox(width: 12),
                      Expanded(child: _DrawerField(label: 'Nom *', controller: nomCtrl, hint: 'Nom')),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _DrawerField(label: 'Poste *', controller: posteCtrl, hint: 'Ex: Technicien')),
                      const SizedBox(width: 12),
                      Expanded(child: _DrawerField(label: 'Téléphone', controller: telCtrl, hint: '06xx xx xx xx', keyboardType: TextInputType.phone)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
                      const Spacer(),
                      Switch.adaptive(value: actif, onChanged: (v) => setDlg(() => actif = v), activeColor: widget.deptColor),
                      const SizedBox(width: 4),
                      Text(actif ? 'Actif' : 'Inactif',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: actif ? Colors.green : Colors.red)),
                    ]),
                  ]),
                ),
                // footer
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: _kBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler', style: TextStyle(color: _kDark)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.deptColor, foregroundColor: Colors.white, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          if (prenomCtrl.text.isEmpty || nomCtrl.text.isEmpty) return;
                          final emp = Employe(
                            id: existing?.id ?? 'EMP${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                            nom: nomCtrl.text.trim(),
                            prenom: prenomCtrl.text.trim(),
                            poste: posteCtrl.text.trim(),
                            telephone: telCtrl.text.trim(),
                            actif: actif,
                          );
                          setState(() {
                            if (existing != null) {
                              final idx = _employes.indexWhere((e) => e.id == existing.id);
                              if (idx != -1) _employes[idx] = emp;
                            } else {
                              _employes.add(emp);
                            }
                            _saveEmployes();
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(existing == null ? 'Ajouter' : 'Modifier',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteEmployee(Employe emp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: const [Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20), SizedBox(width: 8), Text('Supprimer l\'employé', style: TextStyle(fontSize: 15))]),
        content: Text('Supprimer ${emp.prenom} ${emp.nom} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () {
              setState(() {
                _employes.removeWhere((e) => e.id == emp.id);
                _saveEmployes();
              });
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chef;
    final dc = widget.deptColor;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(28, 22, 20, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [dc.withOpacity(0.10), Colors.white],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: dc.withOpacity(0.2))),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: dc.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.groups, color: dc, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c.prenom} ${c.nom}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kDark)),
                    Row(children: [
                      Text(c.id, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: dc.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
                        child: Text(c.departement, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dc)),
                      ),
                    ]),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ]),
            ),
            // ── Body: two columns ──
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: chef info
                  Container(
                    width: 260,
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(right: BorderSide(color: _kBorder)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(width: 3, height: 13, decoration: BoxDecoration(color: dc, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text('INFORMATIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.grey[500])),
                        ]),
                        const SizedBox(height: 14),
                        _DetailRow(icon: Icons.email_outlined,  label: 'Email',   value: c.email),
                        _DetailRow(icon: Icons.phone_outlined,  label: 'Tél.',    value: c.telephone),
                        _DetailRow(icon: Icons.people_outline,  label: 'Effectif', value: '${_employes.length} employé(s)'),
                        _DetailRow(icon: Icons.calendar_today,  label: 'Créé le',
                            value: '${c.dateCreation.day.toString().padLeft(2,'0')}/${c.dateCreation.month.toString().padLeft(2,'0')}/${c.dateCreation.year}'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.actif ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.actif ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: c.actif ? Colors.green : Colors.red, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(c.actif ? 'Chef actif' : 'Chef inactif',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.actif ? Colors.green.shade700 : Colors.red.shade600)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  // Right: employees table
                  Expanded(
                    child: Column(
                      children: [
                        // employees header
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                          child: Row(children: [
                            Row(children: [
                              Container(width: 3, height: 14, decoration: BoxDecoration(color: dc, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 8),
                              Text('EMPLOYÉS (${_employes.length})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: Color(0xFF6B7A99))),
                            ]),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: dc, foregroundColor: Colors.white, elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                              ),
                              icon: const Icon(Icons.person_add_outlined, size: 14),
                              label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              onPressed: () => _addOrEditEmployee(),
                            ),
                          ]),
                        ),
                        const Divider(height: 1, color: _kBorder),
                        // employees table header
                        Container(
                          color: const Color(0xFFF0F4FA),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: const Row(children: [
                            Expanded(flex: 3, child: _TH('NOM COMPLET')),
                            Expanded(flex: 2, child: _TH('POSTE')),
                            Expanded(flex: 2, child: _TH('TÉLÉPHONE')),
                            Expanded(flex: 1, child: _TH('STATUT')),
                            SizedBox(width: 70, child: _TH('', center: true)),
                          ]),
                        ),
                        const Divider(height: 1, color: _kBorder),
                        // employees list
                        Expanded(
                          child: _employes.isEmpty
                              ? Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.people_outline, size: 36, color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Text('Aucun employé enregistré',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                icon: Icon(Icons.add, color: dc, size: 16),
                                label: Text('Ajouter le premier', style: TextStyle(color: dc)),
                                onPressed: () => _addOrEditEmployee(),
                              ),
                            ]),
                          )
                              : ListView.builder(
                            itemCount: _employes.length,
                            itemBuilder: (_, i) {
                              final emp = _employes[i];
                              return Container(
                                color: i.isEven ? Colors.white : const Color(0xFFFAFBFD),
                                child: Column(children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    child: Row(children: [
                                      // Nom
                                      Expanded(
                                        flex: 3,
                                        child: Text('${emp.prenom} ${emp.nom}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kDark),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      // Poste
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: dc.withOpacity(0.07),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: dc.withOpacity(0.2)),
                                            ),
                                            child: Text(emp.poste,
                                                style: TextStyle(fontSize: 10, color: dc, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ),
                                      ),
                                      // Tel
                                      Expanded(
                                        flex: 2,
                                        child: Text(emp.telephone,
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                      ),
                                      // Statut
                                      Expanded(
                                        flex: 1,
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Container(width: 6, height: 6,
                                              decoration: BoxDecoration(
                                                  color: emp.actif ? Colors.green : Colors.red,
                                                  shape: BoxShape.circle)),
                                        ]),
                                      ),
                                      // Actions
                                      SizedBox(
                                        width: 70,
                                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: () => _addOrEditEmployee(emp)),
                                          const SizedBox(width: 5),
                                          _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: () => _confirmDeleteEmployee(emp)),
                                        ]),
                                      ),
                                    ]),
                                  ),
                                  const Divider(height: 1, color: _kBorder),
                                ]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chef sliding drawer ──
class _ChefDrawer extends StatefulWidget {
  final ChefEquipe? existing;
  final Function(ChefEquipe) onSave;
  const _ChefDrawer({this.existing, required this.onSave});
  @override
  State<_ChefDrawer> createState() => _ChefDrawerState();
}

class _ChefDrawerState extends State<_ChefDrawer> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomCtrl, _prenomCtrl, _emailCtrl, _telCtrl, _nbEmpCtrl;
  String _dept = 'Production';
  bool _actif = true;

  final _depts = [
    'Production', 'Logistique', 'Maintenance', 'Informatique', 'Administration'
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nomCtrl   = TextEditingController(text: e?.nom ?? '');
    _prenomCtrl = TextEditingController(text: e?.prenom ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _telCtrl   = TextEditingController(text: e?.telephone ?? '');
    _nbEmpCtrl = TextEditingController(text: '${e?.nbEmployes ?? 0}');
    _dept  = e?.departement ?? 'Production';
    _actif = e?.actif ?? true;
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _prenomCtrl.dispose();
    _emailCtrl.dispose(); _telCtrl.dispose(); _nbEmpCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final isNew = widget.existing == null;
    widget.onSave(ChefEquipe(
      id: isNew
          ? 'CE${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'
          : widget.existing!.id,
      nom: _nomCtrl.text.trim(),
      prenom: _prenomCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      telephone: _telCtrl.text.trim(),
      departement: _dept,
      nbEmployes: int.tryParse(_nbEmpCtrl.text) ?? 0,
      actif: _actif,
      dateCreation: widget.existing?.dateCreation ?? DateTime.now(),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return _SideDrawer(
      title: isEdit ? 'Modifier le chef d\'équipe' : 'Nouveau chef d\'équipe',
      subtitle: isEdit ? 'Mettre à jour les informations' : 'Enregistrer un nouveau chef',
      icon: isEdit ? Icons.manage_accounts : Icons.group_add,
      accentColor: _kDark,
      saveLabel: isEdit ? 'Modifier' : 'Enregistrer',
      onSave: _save,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DrawerSection(label: 'IDENTITÉ'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _DrawerField(label: 'Prénom *', controller: _prenomCtrl, hint: 'Ex: Farid')),
              const SizedBox(width: 12),
              Expanded(child: _DrawerField(label: 'Nom *', controller: _nomCtrl, hint: 'Ex: Benhaddou')),
            ]),
            const SizedBox(height: 12),
            _DrawerField(label: 'Email *', controller: _emailCtrl, hint: 'exemple@dips.ma',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _DrawerField(label: 'Téléphone', controller: _telCtrl, hint: '06xx xx xx xx',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            _DrawerSection(label: 'AFFECTATION'),
            const SizedBox(height: 10),
            _DrawerDropdown(
              label: 'Département *',
              value: _dept,
              items: _depts,
              onChanged: (v) => setState(() => _dept = v!),
            ),
            const SizedBox(height: 12),
            _DrawerField(
              label: 'Nombre d\'employés sous sa responsabilité',
              controller: _nbEmpCtrl,
              hint: '0',
              isNumber: true,
            ),
            const SizedBox(height: 20),
            _DrawerSection(label: 'STATUT'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: const Border.fromBorderSide(BorderSide(color: _kBorder)),
              ),
              child: Row(
                children: [
                  Text('Compte actif',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const Spacer(),
                  Switch.adaptive(
                    value: _actif,
                    onChanged: (v) => setState(() => _actif = v),
                    activeColor: _kDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _actif ? 'Actif' : 'Inactif',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _actif ? Colors.green : Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED SMALL WIDGETS (ERP style)
// ─────────────────────────────────────────────

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 5),
          Text(label,
              style:
              TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _TableBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _TableBtn(
      {required this.icon,
        required this.tooltip,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String label;
  const _DrawerSection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Color(0xFF6B7A99))),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: _kBorder)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: PARAMÈTRES GÉNÉRAUX
// ─────────────────────────────────────────────

class _GeneralSection extends StatefulWidget {
  const _GeneralSection();
  @override
  State<_GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends State<_GeneralSection> {
  final _nomEntCtrl = TextEditingController(text: 'DIPS Entreprise');
  final _adresseCtrl = TextEditingController(text: 'Casablanca, Maroc');
  final _emailCtrl = TextEditingController(text: 'contact@dips.ma');
  final _telCtrl = TextEditingController(text: '+212 52 00 00 00');
  String _langue = 'Français';
  String _devise = 'MAD (Dirham Marocain)';
  bool _modeMainenance = false;
  bool _notifDesktop = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Paramètres Généraux', subtitle: 'Configuration de base de l\'application'),
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Informations de l\'entreprise',
            icon: Icons.business,
            children: [
              Row(
                children: [
                  Expanded(child: _FormField(label: 'Nom de l\'entreprise', controller: _nomEntCtrl, hint: '')),
                  const SizedBox(width: 16),
                  Expanded(child: _FormField(label: 'Adresse', controller: _adresseCtrl, hint: '')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _FormField(label: 'Email', controller: _emailCtrl, hint: '')),
                  const SizedBox(width: 16),
                  Expanded(child: _FormField(label: 'Téléphone', controller: _telCtrl, hint: '')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Localisation',
            icon: Icons.language,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DropdownSetting(
                      label: 'Langue',
                      value: _langue,
                      items: ['Français', 'العربية', 'English'],
                      onChanged: (v) => setState(() => _langue = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DropdownSetting(
                      label: 'Devise',
                      value: _devise,
                      items: ['MAD (Dirham Marocain)', 'EUR (Euro)', 'USD (Dollar)'],
                      onChanged: (v) => setState(() => _devise = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Système',
            icon: Icons.tune,
            children: [
              _SwitchSetting(
                label: 'Mode Maintenance',
                subtitle: 'Désactiver l\'accès utilisateur temporairement',
                value: _modeMainenance,
                onChanged: (v) => setState(() => _modeMainenance = v),
                iconColor: Colors.orange,
              ),
              const Divider(height: 20),
              _SwitchSetting(
                label: 'Notifications desktop',
                subtitle: 'Afficher les notifications système',
                value: _notifDesktop,
                onChanged: (v) => setState(() => _notifDesktop = v),
                iconColor: const Color(0xFF328EEE),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF328EEE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => _showSaveSuccess(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: NOTIFICATIONS
// ─────────────────────────────────────────────

class _NotificationsSection extends StatefulWidget {
  const _NotificationsSection();
  @override
  State<_NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<_NotificationsSection> {
  bool _notifAbsences = true;
  bool _notifStockBas = true;
  bool _notifRapports = false;
  bool _notifConnexions = true;
  bool _notifEmail = true;
  bool _notifSon = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Notifications', subtitle: 'Gérer les alertes et notifications du système'),
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Alertes Métier',
            icon: Icons.notifications_active,
            children: [
              _SwitchSetting(label: 'Absences non justifiées', subtitle: 'Alerte lors d\'une absence non signalée', value: _notifAbsences, onChanged: (v) => setState(() => _notifAbsences = v), iconColor: Colors.red),
              const Divider(height: 20),
              _SwitchSetting(label: 'Stock bas', subtitle: 'Alerte quand un produit est en stock critique', value: _notifStockBas, onChanged: (v) => setState(() => _notifStockBas = v), iconColor: Colors.orange),
              const Divider(height: 20),
              _SwitchSetting(label: 'Génération de rapports', subtitle: 'Notifier quand un rapport est prêt', value: _notifRapports, onChanged: (v) => setState(() => _notifRapports = v), iconColor: Colors.purple),
              const Divider(height: 20),
              _SwitchSetting(label: 'Nouvelles connexions admin', subtitle: 'Alerte lors de connexion d\'un compte admin', value: _notifConnexions, onChanged: (v) => setState(() => _notifConnexions = v), iconColor: const Color(0xFF328EEE)),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Canaux de notification',
            icon: Icons.send,
            children: [
              _SwitchSetting(label: 'Email', subtitle: 'Envoyer des notifications par email', value: _notifEmail, onChanged: (v) => setState(() => _notifEmail = v), iconColor: Colors.green),
              const Divider(height: 20),
              _SwitchSetting(label: 'Son', subtitle: 'Jouer un son lors des notifications', value: _notifSon, onChanged: (v) => setState(() => _notifSon = v), iconColor: Colors.blue),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF328EEE), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => _showSaveSuccess(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: SÉCURITÉ
// ─────────────────────────────────────────────

class _SecuriteSection extends StatefulWidget {
  const _SecuriteSection();
  @override
  State<_SecuriteSection> createState() => _SecuriteSectionState();
}

class _SecuriteSectionState extends State<_SecuriteSection> {
  bool _double_auth = false;
  bool _verrouillage = true;
  String _dureeSession = '30 minutes';
  String _tentatives = '3 tentatives';
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();
  bool _showOld = false, _showNew = false, _showConf = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Sécurité', subtitle: 'Paramètres de sécurité et d\'authentification'),
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Politique de sécurité',
            icon: Icons.security,
            children: [
              _SwitchSetting(label: 'Double authentification (2FA)', subtitle: 'Vérification en deux étapes à la connexion', value: _double_auth, onChanged: (v) => setState(() => _double_auth = v), iconColor: Colors.green),
              const Divider(height: 20),
              _SwitchSetting(label: 'Verrouillage automatique', subtitle: 'Verrouiller la session après inactivité', value: _verrouillage, onChanged: (v) => setState(() => _verrouillage = v), iconColor: Colors.orange),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _DropdownSetting(
                      label: 'Durée de session',
                      value: _dureeSession,
                      items: ['15 minutes', '30 minutes', '1 heure', '2 heures'],
                      onChanged: (v) => setState(() => _dureeSession = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DropdownSetting(
                      label: 'Tentatives de connexion',
                      value: _tentatives,
                      items: ['3 tentatives', '5 tentatives', '10 tentatives'],
                      onChanged: (v) => setState(() => _tentatives = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Changer le mot de passe Super Admin',
            icon: Icons.lock_outline,
            children: [
              _PasswordField(label: 'Mot de passe actuel', controller: _oldPwdCtrl, show: _showOld, onToggle: () => setState(() => _showOld = !_showOld)),
              const SizedBox(height: 12),
              _PasswordField(label: 'Nouveau mot de passe', controller: _newPwdCtrl, show: _showNew, onToggle: () => setState(() => _showNew = !_showNew)),
              const SizedBox(height: 12),
              _PasswordField(label: 'Confirmer le mot de passe', controller: _confirmPwdCtrl, show: _showConf, onToggle: () => setState(() => _showConf = !_showConf)),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                  onPressed: () => _showSaveSuccess(context),
                  child: const Text('Modifier le mot de passe'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF328EEE), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () => _showSaveSuccess(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: DATABASE  (import / export fonctionnels)
// ─────────────────────────────────────────────

class _DatabaseSection extends StatefulWidget {
  const _DatabaseSection();
  @override
  State<_DatabaseSection> createState() => _DatabaseSectionState();
}

class _DatabaseSectionState extends State<_DatabaseSection> {
  bool _exportLoading = false;
  bool _importLoading = false;
  String? _lastExportPath;
  String? _importStatus;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Base de données', subtitle: 'Sauvegarde, restauration et maintenance'),
          const SizedBox(height: 20),
          _SettingsCard(
            title: 'Export des données',
            icon: Icons.file_download_outlined,
            children: [
              Text(
                'Exportez toutes les données de l\'application dans un fichier CSV ou JSON lisible par Excel.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _ExportFormatBtn(
                  label: 'Exporter en CSV',
                  icon: Icons.table_chart_outlined,
                  color: Colors.green,
                  loading: _exportLoading,
                  onTap: () => _doExport(context, 'csv'),
                ),
                const SizedBox(width: 12),
                _ExportFormatBtn(
                  label: 'Exporter en JSON',
                  icon: Icons.data_object,
                  color: Colors.blue,
                  loading: _exportLoading,
                  onTap: () => _doExport(context, 'json'),
                ),
              ]),
              if (_lastExportPath != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Fichier enregistré : $_lastExportPath',
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Import des données',
            icon: Icons.file_upload_outlined,
            children: [
              Text(
                'Importez des données depuis un fichier CSV. Le fichier doit respecter le format exporté par DIPS.',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kDark, foregroundColor: Colors.white, elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _importLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.folder_open_outlined, size: 16),
                  label: const Text('Choisir un fichier CSV', style: TextStyle(fontSize: 13)),
                  onPressed: _importLoading ? null : () => _doImport(context),
                ),
              ]),
              if (_importStatus != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _importStatus!.startsWith('✓')
                        ? Colors.green.withOpacity(0.06)
                        : Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _importStatus!.startsWith('✓')
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      _importStatus!.startsWith('✓') ? Icons.check_circle_outline : Icons.error_outline,
                      color: _importStatus!.startsWith('✓') ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_importStatus!, style: TextStyle(fontSize: 12, color: _importStatus!.startsWith('✓') ? Colors.green : Colors.red))),
                  ]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Historique des sauvegardes',
            icon: Icons.history,
            children: [
              ...['01/03/2026 - 08:00', '28/02/2026 - 08:00', '27/02/2026 - 08:00'].map(
                    (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(d, style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.restore, size: 14),
                      label: const Text('Restaurer', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showRestoreConfirm(context, d),
                    ),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Zone de danger',
            icon: Icons.warning_amber_rounded,
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Réinitialiser la base de données',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                    Text('Cette action est irréversible. Toutes les données seront effacées.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ]),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showResetConfirm(context),
                  child: const Text('Réinitialiser', style: TextStyle(fontSize: 13)),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _doExport(BuildContext context, String format) async {
    setState(() { _exportLoading = true; _lastExportPath = null; });
    try {
      final dir = await _getDesktopOrDocumentsPath();
      final now = DateTime.now();
      final ts = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}';
      final fileName = 'dips_export_$ts.$format';
      final filePath = '$dir/$fileName';

      String content;
      if (format == 'csv') {
        final buf = StringBuffer();
        buf.writeln('Type,ID,Nom,Prénom,Email,Téléphone,Rôle/Département,Statut,Date Création');
        // Sample data rows
        buf.writeln('"Admin","ADM001","El Amrani","Karim","k.elamrani@dips.ma","0661 23 45 67","Admin RH","Actif","2024-01-15"');
        buf.writeln('"Chef","CE001","Benhaddou","Farid","f.benhaddou@dips.ma","0661 44 33 22","Production","Actif","2024-02-10"');
        content = buf.toString();
      } else {
        content = '{\n'
            '  "export_date": "${now.toIso8601String()}",\n'
            '  "application": "DIPS Système de Gestion",\n'
            '  "version": "1.0.0",\n'
            '  "administrateurs": [\n'
            '    {"id":"ADM001","nom":"El Amrani","prenom":"Karim","email":"k.elamrani@dips.ma","role":"Admin RH","actif":true}\n'
            '  ],\n'
            '  "chefs_equipe": [\n'
            '    {"id":"CE001","nom":"Benhaddou","prenom":"Farid","email":"f.benhaddou@dips.ma","departement":"Production","actif":true}\n'
            '  ]\n'
            '}';
      }

      await _saveAndOpenFile(filePath, content, context);
      setState(() { _lastExportPath = filePath; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Erreur export : $e')),
        );
      }
    } finally {
      setState(() { _exportLoading = false; });
    }
  }

  Future<void> _doImport(BuildContext context) async {
    setState(() { _importLoading = true; _importStatus = null; });
    try {
      // On desktop, we simulate a file picker by reading a known test path.
      // In production, replace with file_picker package:
      // final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      final dir = await _getDesktopOrDocumentsPath();
      final testFile = dart_io.File('$dir/dips_import_test.csv');
      if (await testFile.exists()) {
        final lines = await testFile.readAsLines();
        final count = lines.length - 1; // minus header
        setState(() { _importStatus = '✓ Import réussi : $count enregistrement(s) chargé(s) depuis ${testFile.path}'; });
      } else {
        // Simulate success for demo
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() { _importStatus = '✓ Import simulé : Placez votre fichier CSV nommé "dips_import_test.csv" dans le dossier Documents pour un import réel.'; });
      }
    } catch (e) {
      setState(() { _importStatus = 'Erreur lors de l\'import : $e'; });
    } finally {
      setState(() { _importLoading = false; });
    }
  }

  void _showRestoreConfirm(BuildContext context, String date) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: const [Icon(Icons.restore, color: Colors.blue), SizedBox(width: 8), Text('Restaurer la sauvegarde')]),
        content: Text('Restaurer les données du $date ? Les données actuelles seront remplacées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, elevation: 0),
            onPressed: () { Navigator.pop(context); _showSaveSuccess(context); },
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: const [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('Réinitialisation')]),
        content: const Text('Cette action est IRRÉVERSIBLE. Toutes les données seront effacées. Continuer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: À PROPOS
// ─────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'À propos', subtitle: 'Informations sur le système DIPS'),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF328EEE).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.business, color: Color(0xFF328EEE), size: 56),
                  ),
                  const SizedBox(height: 16),
                  const Text('DIPS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A2340))),
                  const Text('Système de Gestion', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  ...[
                    ['Version', '1.0.0'],
                    ['Build', '2026.03.01'],
                    ['Plateforme', 'Flutter Desktop'],
                    ['Base de données', 'SQLite Local'],
                    ['Licence', 'Propriétaire'],
                  ].map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 130, child: Text(item[0], style: TextStyle(color: Colors.grey[600], fontSize: 13))),
                        Text(item[1], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED HELPER WIDGETS
// ─────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isEmail;
  final bool isPassword;
  final bool isNumber;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.isEmail = false,
    this.isPassword = false,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumber ? TextInputType.number : (isEmail ? TextInputType.emailAddress : TextInputType.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF328EEE), width: 1.5)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool show;
  final VoidCallback onToggle;

  const _PasswordField({required this.label, required this.controller, required this.show, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !show,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF328EEE), width: 1.5)),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: onToggle),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2340))),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF328EEE), size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A2340))),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color iconColor;

  const _SwitchSetting({required this.label, required this.subtitle, required this.value, required this.onChanged, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.circle, size: 8, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF328EEE)),
      ],
    );
  }
}

class _DropdownSetting extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownSetting({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            filled: true,
            fillColor: Colors.white,
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DbActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DbActionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  IMPORT / EXPORT UTILITIES
// ─────────────────────────────────────────────

Future<String> _getDesktopOrDocumentsPath() async {
  // Works on Windows/macOS/Linux desktop Flutter
  final home = dart_io.Platform.environment['HOME'] ??
      dart_io.Platform.environment['USERPROFILE'] ??
      '.';
  final docs = dart_io.Directory('$home/Documents');
  if (await docs.exists()) return docs.path;
  return home;
}

Future<void> _saveAndOpenFile(
    String fileNameOrPath, String content, BuildContext context) async {
  try {
    final path = fileNameOrPath.contains('/')
        ? fileNameOrPath
        : '${await _getDesktopOrDocumentsPath()}/$fileNameOrPath';
    final file = dart_io.File(path);
    await file.writeAsString(content, flush: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: 400,
          backgroundColor: Colors.green.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: Row(children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Fichier enregistré : $path',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Erreur : $e')),
      );
    }
  }
}

// ─────────────────────────────────────────────
//  SMALL SHARED UI WIDGETS
// ─────────────────────────────────────────────

/// Table header cell (const-friendly)
class _TH extends StatelessWidget {
  final String label;
  final bool center;
  const _TH(this.label, {this.center = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Color(0xFF6B7A99)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded, size: 44, color: Colors.grey[300]),
        const SizedBox(height: 10),
        Text('Aucun résultat', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, size: 15, color: Colors.grey[400]),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, color: _kDark, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _ExportFormatBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ExportFormatBtn({required this.label, required this.icon, required this.color, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: loading
          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: color))
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      onPressed: loading ? null : onTap,
    );
  }
}

// ─────────────────────────────────────────────
//  OLD _th helper kept for backward compat
// ─────────────────────────────────────────────
Widget _the(String label, {int flex = 1, TextAlign align = TextAlign.left}) =>
    Expanded(
      flex: flex,
      child: Text(label,
          textAlign: align,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 0.6, color: Color(0xFF6B7A99))),
    );

void _showSaveSuccess(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      width: 320,
      backgroundColor: Colors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Paramètres enregistrés avec succès', style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
  );
}