import 'dart:io' as dart_io;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  RESPONSIVE HELPERS
// ─────────────────────────────────────────────

bool _isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;
double _pagePad(BuildContext context) => _isMobile(context) ? 14 : 24;

// ─────────────────────────────────────────────
//  MODEL CLASSES
// ─────────────────────────────────────────────

class AdminUser {
  final String id;
  String nom, prenom, email, telephone, role;
  bool actif;
  List<String> permissions;
  DateTime dateCreation;

  AdminUser({
    required this.id, required this.nom, required this.prenom,
    required this.email, required this.telephone, required this.role,
    required this.actif, required this.permissions, required this.dateCreation,
  });
}

class Employe {
  final String id;
  String nom, prenom, poste, telephone;
  bool actif;

  Employe({
    required this.id, required this.nom, required this.prenom,
    required this.poste, required this.telephone, required this.actif,
  });
}

class ChefEquipe {
  final String id;
  String nom, prenom, email, telephone, departement;
  int nbEmployes;
  bool actif;
  DateTime dateCreation;
  List<Employe> employes;

  ChefEquipe({
    required this.id, required this.nom, required this.prenom,
    required this.email, required this.telephone, required this.departement,
    required this.nbEmployes, required this.actif, required this.dateCreation,
    List<Employe>? employes,
  }) : employes = employes ?? [];
}

// ─────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────

const _kAccent   = Color(0xFF328EEE);
const _kDark     = Color(0xFF1A2340);
const _kBg       = Color(0xFFF4F7FC);
const _kBorder   = Color(0xFFDDE3EE);
const _kRowHover = Color(0xFFF0F6FF);

// ─────────────────────────────────────────────
//  MAIN SETTINGS PAGE
// ─────────────────────────────────────────────

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});
  @override State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  int _selectedSectionIndex = 0;

  final List<_SettingsSection> _sections = [
    _SettingsSection(icon: Icons.admin_panel_settings, label: 'Administrateurs', labelShort: 'Admins'),
    _SettingsSection(icon: Icons.groups,                label: "Chefs d'équipe",  labelShort: 'Chefs'),
    _SettingsSection(icon: Icons.tune,                  label: 'Général',         labelShort: 'Général'),
    _SettingsSection(icon: Icons.notifications_active,  label: 'Notifications',   labelShort: 'Notifs'),
    _SettingsSection(icon: Icons.security,              label: 'Sécurité',        labelShort: 'Sécurité'),
    _SettingsSection(icon: Icons.storage,               label: 'Base de données', labelShort: 'BDD'),
    _SettingsSection(icon: Icons.info_outline,          label: 'À propos',        labelShort: 'À propos'),
  ];

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    final topPad = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // ── Nav bar ──────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _kAccent.withOpacity(0.18), width: 1.5)),
            boxShadow: [BoxShadow(color: _kAccent.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title row
              Padding(
                padding: EdgeInsets.fromLTRB(mobile ? 14 : 24, topPad + (mobile ? 12 : 14), mobile ? 14 : 24, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _kAccent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.settings_rounded, color: _kAccent, size: 17),
                    ),
                    const SizedBox(width: 10),
                    Text('Paramètres',
                        style: TextStyle(
                            fontSize: mobile ? 16 : 17,
                            fontWeight: FontWeight.w800,
                            color: _kDark)),
                    if (!mobile) ...[
                      Container(margin: const EdgeInsets.symmetric(horizontal: 12), width: 1, height: 16, color: _kBorder),
                      Text('Administration & Configuration',
                          style: TextStyle(fontSize: 12, color: Colors.grey[450])),
                    ],
                    const Spacer(),
                    if (!mobile) const _SuperAdminBadge(),
                  ],
                ),
              ),
              // Tab row
              Padding(
                padding: EdgeInsets.only(left: mobile ? 4 : 8, right: mobile ? 4 : 8, top: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_sections.length, (i) {
                      final s = _sections[i];
                      final sel = _selectedSectionIndex == i;
                      final label = mobile ? s.labelShort : s.label;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSectionIndex = i),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 1),
                            padding: EdgeInsets.symmetric(
                                horizontal: mobile ? 10 : 16,
                                vertical: mobile ? 10 : 11),
                            decoration: BoxDecoration(
                              color: sel ? _kAccent.withOpacity(0.07) : Colors.transparent,
                              border: Border(bottom: BorderSide(
                                color: sel ? _kAccent : Colors.transparent,
                                width: 2.5,
                              )),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: sel ? const EdgeInsets.all(4) : EdgeInsets.zero,
                                decoration: sel
                                    ? BoxDecoration(
                                    color: _kAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6))
                                    : null,
                                child: Icon(s.icon,
                                    size: mobile ? 14 : (sel ? 13 : 15),
                                    color: sel ? _kAccent : Colors.grey[400]),
                              ),
                              SizedBox(width: mobile ? 5 : 7),
                              Text(label,
                                  style: TextStyle(
                                      fontSize: mobile ? 11.5 : 13,
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                      color: sel ? _kAccent : Colors.grey[500])),
                              if (sel) ...[
                                const SizedBox(width: 5),
                                Container(width: 5, height: 5,
                                    decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle)),
                              ],
                            ]),
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

        // ── Content ──────────────────────────────────────────────────────
        Expanded(
          child: Container(
            color: _kBg,
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
  const _SuperAdminBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: _kAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kAccent.withOpacity(0.25)),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.verified_user_rounded, color: _kAccent, size: 13),
      SizedBox(width: 6),
      Text('Super Admin', style: TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _SettingsSection {
  final IconData icon;
  final String label;
  final String labelShort;
  _SettingsSection({required this.icon, required this.label, required this.labelShort});
}

// ─────────────────────────────────────────────
//  SHARED DRAWER (side on desktop, bottom on mobile)
// ─────────────────────────────────────────────

void _openDrawer(BuildContext context, Widget drawer) {
  final mobile = _isMobile(context);
  if (mobile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => drawer,
    );
  } else {
    showGeneralDialog(
      context: context,
      barrierDismissible: true, barrierLabel: 'close', barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => drawer,
      transitionBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

class _SideDrawer extends StatelessWidget {
  final String title, subtitle, saveLabel;
  final IconData icon;
  final Color accentColor;
  final Widget body;
  final VoidCallback onSave;

  const _SideDrawer({
    required this.title, required this.subtitle, required this.icon,
    required this.accentColor, required this.body, required this.onSave,
    this.saveLabel = 'Enregistrer',
  });

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);

    if (mobile) {
      // Bottom sheet style
      return DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Handle
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
            )),
            _drawerHeader(context),
            Expanded(child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              child: body,
            )),
            _drawerFooter(context),
          ]),
        ),
      );
    }

    // Side drawer (desktop)
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 440, height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 32, offset: Offset(-4, 0))],
          ),
          child: Column(children: [
            _drawerHeader(context),
            Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: body)),
            _drawerFooter(context),
          ]),
        ),
      ),
    );
  }

  Widget _drawerHeader(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 20, 14, 18),
    decoration: BoxDecoration(
      color: accentColor.withOpacity(0.06),
      border: Border(bottom: BorderSide(color: accentColor.withOpacity(0.15))),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: accentColor, size: 19),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kDark)),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ])),
      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop()),
    ]),
  );

  Widget _drawerFooter(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _kBorder))),
    child: Row(children: [
      Expanded(child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: _kBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Annuler', style: TextStyle(color: _kDark)),
      )),
      const SizedBox(width: 12),
      Expanded(child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onSave,
        child: Text(saveLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
      )),
    ]),
  );
}

// ─────────────────────────────────────────────
//  SHARED FIELD WIDGETS
// ─────────────────────────────────────────────

class _DrawerField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isPassword, isNumber;
  final TextInputType? keyboardType;

  const _DrawerField({
    required this.label, required this.controller, this.hint = '',
    this.isPassword = false, this.isNumber = false, this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
      const SizedBox(height: 5),
      TextFormField(
        controller: controller, obscureText: isPassword,
        keyboardType: isNumber ? TextInputType.number : (keyboardType ?? TextInputType.text),
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          filled: true, fillColor: const Color(0xFFF8FAFC),
          border:         OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
          enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
          focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
      ),
    ],
  );
}

class _DrawerDropdown extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DrawerDropdown({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
      const SizedBox(height: 5),
      DropdownButtonFormField<String>(
        value: value, isExpanded: true,
        style: const TextStyle(fontSize: 13, color: _kDark),
        decoration: InputDecoration(
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          filled: true, fillColor: const Color(0xFFF8FAFC),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
      ),
    ],
  );
}

class _DrawerSection extends StatelessWidget {
  final String label;
  const _DrawerSection({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Color(0xFF6B7A99))),
    const SizedBox(width: 10),
    const Expanded(child: Divider(color: _kBorder)),
  ]);
}

// ─────────────────────────────────────────────
//  SECTION: ADMINISTRATEURS
// ─────────────────────────────────────────────

class _AdminsSection extends StatefulWidget {
  const _AdminsSection();
  @override State<_AdminsSection> createState() => _AdminsSectionState();
}

class _AdminsSectionState extends State<_AdminsSection> {
  final List<AdminUser> _admins = [
    AdminUser(id: 'ADM001', nom: 'El Amrani', prenom: 'Karim', email: 'k.elamrani@dips.ma', telephone: '0661 23 45 67', role: 'Admin RH', actif: true, permissions: ['Employés', 'Pointage', 'Rapports'], dateCreation: DateTime(2024, 1, 15)),
    AdminUser(id: 'ADM002', nom: 'Bensouda', prenom: 'Sara', email: 's.bensouda@dips.ma', telephone: '0662 98 76 54', role: 'Admin Magasin', actif: true, permissions: ['Gestion Magasin', 'Rapports'], dateCreation: DateTime(2024, 3, 8)),
    AdminUser(id: 'ADM003', nom: 'Tazi', prenom: 'Omar', email: 'o.tazi@dips.ma', telephone: '0663 11 22 33', role: 'Admin Général', actif: false, permissions: ['Employés', 'Pointage', 'Gestion Magasin', 'Rapports'], dateCreation: DateTime(2023, 11, 20)),
  ];

  String _searchQuery = '';
  List<AdminUser> get _filtered => _admins.where((a) =>
      '${a.nom} ${a.prenom} ${a.email} ${a.role}'.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

  void _openAdminDrawer([AdminUser? existing]) {
    _openDrawer(context, _AdminDrawer(
      existing: existing,
      onSave: (admin) => setState(() {
        if (existing != null) {
          final i = _admins.indexWhere((a) => a.id == existing.id);
          if (i != -1) _admins[i] = admin;
        } else { _admins.add(admin); }
      }),
    ));
  }

  void _confirmDelete(AdminUser admin) {
    showDialog(context: context, builder: (_) => _ConfirmDialog(
      title: "Supprimer l'admin",
      message: 'Confirmer la suppression de ${admin.prenom} ${admin.nom} ?',
      onConfirm: () => setState(() => _admins.removeWhere((a) => a.id == admin.id)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mobile   = _isMobile(context);
    final filtered = _filtered;

    return Column(children: [
      // Top bar
      _SectionTopBar(
        title: 'Administrateurs',
        subtitle: '${_admins.length} compte(s)',
        searchQuery: _searchQuery,
        onSearch: (v) => setState(() => _searchQuery = v),
        onExport: () => _exportAdminsCsv(context),
        onAdd: () => _openAdminDrawer(),
        addLabel: 'Ajouter',
        addColor: _kAccent,
      ),
      const Divider(height: 1, color: _kBorder),

      // Table header — desktop only
      if (!mobile) ...[
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
      ],

      Expanded(
        child: filtered.isEmpty
            ? const _EmptyState()
            : ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final admin = filtered[i];
            return mobile
                ? _AdminMobileCard(
              admin: admin,
              onEdit: () => _openAdminDrawer(admin),
              onDelete: () => _confirmDelete(admin),
              onToggle: () => setState(() => admin.actif = !admin.actif),
              onDetails: () => _showAdminDetails(context, admin),
            )
                : _AdminTableRow(
              admin: admin, isEven: i.isEven,
              onEdit: () => _openAdminDrawer(admin),
              onDelete: () => _confirmDelete(admin),
              onToggle: () => setState(() => admin.actif = !admin.actif),
              onDetails: () => _showAdminDetails(context, admin),
            );
          },
        ),
      ),
    ]);
  }

  void _showAdminDetails(BuildContext context, AdminUser a) {
    _isMobile(context)
        ? showModalBottomSheet(
        context: context, isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AdminDetailSheet(admin: a))
        : showDialog(
        context: context, barrierColor: Colors.black45,
        builder: (_) => _AdminDetailDialog(admin: a));
  }

  void _exportAdminsCsv(BuildContext context) async {
    final csv = StringBuffer();
    csv.writeln('ID,Nom,Prénom,Email,Téléphone,Rôle,Statut,Permissions,Date Création');
    for (final a in _admins) {
      csv.writeln('"${a.id}","${a.nom}","${a.prenom}","${a.email}","${a.telephone}","${a.role}","${a.actif ? 'Actif' : 'Inactif'}","${a.permissions.join(' | ')}","${a.dateCreation.toIso8601String().substring(0, 10)}"');
    }
    await _saveAndOpenFile('administrateurs_export.csv', csv.toString(), context);
  }
}

// ── Admin mobile card ──
class _AdminMobileCard extends StatelessWidget {
  final AdminUser admin;
  final VoidCallback onEdit, onDelete, onToggle, onDetails;
  const _AdminMobileCard({required this.admin, required this.onEdit, required this.onDelete, required this.onToggle, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final a = admin;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${a.prenom} ${a.nom}',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _kDark))),
          _StatusDot(actif: a.actif, onToggle: onToggle),
        ]),
        const SizedBox(height: 4),
        Text(a.email, style: TextStyle(fontSize: 11.5, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
        Text(a.telephone, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Row(children: [
          _RoleBadge(label: a.role, color: _kAccent),
          const Spacer(),
          _TableBtn(icon: Icons.info_outline, tooltip: 'Détails', color: Colors.purple, onTap: onDetails),
          const SizedBox(width: 5),
          _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: onEdit),
          const SizedBox(width: 5),
          _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: onDelete),
        ]),
      ]),
    );
  }
}

// ── Admin desktop table row ──
class _AdminTableRow extends StatefulWidget {
  final AdminUser admin;
  final bool isEven;
  final VoidCallback onEdit, onDelete, onToggle, onDetails;
  const _AdminTableRow({required this.admin, required this.isEven, required this.onEdit, required this.onDelete, required this.onToggle, required this.onDetails});
  @override State<_AdminTableRow> createState() => _AdminTableRowState();
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
              Expanded(flex: 3, child: Text('${a.prenom} ${a.nom}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark),
                  overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2, child: Text(a.telephone, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
              Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _RoleBadge(label: a.role, color: _kAccent))),
              Expanded(flex: 2, child: _StatusDot(actif: a.actif, onToggle: widget.onToggle)),
              SizedBox(width: 110, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _TableBtn(icon: Icons.info_outline, tooltip: 'Détails', color: Colors.purple, onTap: widget.onDetails),
                const SizedBox(width: 5),
                _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: widget.onEdit),
                const SizedBox(width: 5),
                _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: widget.onDelete),
              ])),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
        ]),
      ),
    );
  }
}

// ── Admin detail bottom sheet (mobile) ──
class _AdminDetailSheet extends StatelessWidget {
  final AdminUser admin;
  const _AdminDetailSheet({required this.admin});
  @override
  Widget build(BuildContext context) {
    final a = admin;
    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: Row(children: [
              Expanded(child: Text('${a.prenom} ${a.nom}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kDark))),
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _DetailRow(icon: Icons.email_outlined, label: 'Email', value: a.email),
              _DetailRow(icon: Icons.phone_outlined, label: 'Téléphone', value: a.telephone),
              _DetailRow(icon: Icons.badge_outlined, label: 'Rôle', value: a.role),
              _DetailRow(icon: Icons.calendar_today, label: 'Créé le',
                  value: '${a.dateCreation.day.toString().padLeft(2,'0')}/${a.dateCreation.month.toString().padLeft(2,'0')}/${a.dateCreation.year}'),
              const SizedBox(height: 18),
              const _DrawerSection(label: "PERMISSIONS D'ACCÈS"),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8,
                  children: a.permissions.map((p) => _PermChip(label: p)).toList()),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ── Admin detail dialog (desktop) ──
class _AdminDetailDialog extends StatelessWidget {
  final AdminUser admin;
  const _AdminDetailDialog({required this.admin});
  @override
  Widget build(BuildContext context) {
    final a = admin;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _DialogHeader(title: '${a.prenom} ${a.nom}', subtitle: a.id, actif: a.actif, accentColor: _kAccent, icon: Icons.manage_accounts),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [
                  _DetailRow(icon: Icons.email_outlined, label: 'Email', value: a.email),
                  _DetailRow(icon: Icons.phone_outlined, label: 'Téléphone', value: a.telephone),
                ])),
                const SizedBox(width: 24),
                Expanded(child: Column(children: [
                  _DetailRow(icon: Icons.badge_outlined, label: 'Rôle', value: a.role),
                  _DetailRow(icon: Icons.calendar_today, label: 'Créé le',
                      value: '${a.dateCreation.day.toString().padLeft(2,'0')}/${a.dateCreation.month.toString().padLeft(2,'0')}/${a.dateCreation.year}'),
                ])),
              ]),
              const SizedBox(height: 22),
              const _DrawerSection(label: "PERMISSIONS D'ACCÈS"),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: a.permissions.map((p) => _PermChip(label: p)).toList()),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ── Admin drawer ──
class _AdminDrawer extends StatefulWidget {
  final AdminUser? existing;
  final Function(AdminUser) onSave;
  const _AdminDrawer({this.existing, required this.onSave});
  @override State<_AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<_AdminDrawer> {
  final _fk = GlobalKey<FormState>();
  late TextEditingController _nomCtrl, _prenomCtrl, _emailCtrl, _telCtrl, _pwdCtrl;
  String _role = 'Admin RH';
  List<String> _perms = [];
  bool _actif = true, _showPwd = false;

  final _roles    = ['Admin RH', 'Admin Magasin', 'Admin Général', 'Admin Pointage'];
  final _allPerms = ['Employés', 'Pointage', 'Gestion Magasin', 'Rapports', 'Paramètres'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nomCtrl    = TextEditingController(text: e?.nom ?? '');
    _prenomCtrl = TextEditingController(text: e?.prenom ?? '');
    _emailCtrl  = TextEditingController(text: e?.email ?? '');
    _telCtrl    = TextEditingController(text: e?.telephone ?? '');
    _pwdCtrl    = TextEditingController();
    _role  = e?.role ?? 'Admin RH';
    _perms = List.from(e?.permissions ?? []);
    _actif = e?.actif ?? true;
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _prenomCtrl.dispose(); _emailCtrl.dispose();
    _telCtrl.dispose(); _pwdCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_fk.currentState!.validate()) return;
    final isNew = widget.existing == null;
    widget.onSave(AdminUser(
      id: isNew ? 'ADM${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}' : widget.existing!.id,
      nom: _nomCtrl.text.trim(), prenom: _prenomCtrl.text.trim(),
      email: _emailCtrl.text.trim(), telephone: _telCtrl.text.trim(),
      role: _role, actif: _actif, permissions: _perms,
      dateCreation: widget.existing?.dateCreation ?? DateTime.now(),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final mobile = _isMobile(context);
    return _SideDrawer(
      title: isEdit ? "Modifier l'administrateur" : 'Nouvel administrateur',
      subtitle: isEdit ? 'Modifier les informations' : 'Créer un nouveau compte admin',
      icon: isEdit ? Icons.manage_accounts : Icons.person_add_alt_1,
      accentColor: _kAccent, saveLabel: isEdit ? 'Modifier' : 'Créer le compte',
      onSave: _save,
      body: Form(
        key: _fk,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _DrawerSection(label: 'IDENTITÉ'),
          const SizedBox(height: 10),
          // Row → Column on mobile
          if (mobile) ...[
            _DrawerField(label: 'Prénom *', controller: _prenomCtrl, hint: 'Ex: Karim'),
            const SizedBox(height: 10),
            _DrawerField(label: 'Nom *', controller: _nomCtrl, hint: 'Ex: El Amrani'),
          ] else
            Row(children: [
              Expanded(child: _DrawerField(label: 'Prénom *', controller: _prenomCtrl, hint: 'Ex: Karim')),
              const SizedBox(width: 12),
              Expanded(child: _DrawerField(label: 'Nom *', controller: _nomCtrl, hint: 'Ex: El Amrani')),
            ]),
          const SizedBox(height: 12),
          _DrawerField(label: 'Email *', controller: _emailCtrl, hint: 'exemple@dips.ma', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _DrawerField(label: 'Téléphone *', controller: _telCtrl, hint: '06xx xx xx xx', keyboardType: TextInputType.phone),
          if (!isEdit) ...[
            const SizedBox(height: 12),
            _PwdField(ctrl: _pwdCtrl, show: _showPwd, onToggle: () => setState(() => _showPwd = !_showPwd)),
          ],
          const SizedBox(height: 20),
          const _DrawerSection(label: 'RÔLE & STATUT'),
          const SizedBox(height: 10),
          _DrawerDropdown(label: 'Rôle *', value: _role, items: _roles, onChanged: (v) => setState(() => _role = v!)),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Statut du compte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
            const Spacer(),
            Switch.adaptive(value: _actif, onChanged: (v) => setState(() => _actif = v), activeColor: _kAccent),
            const SizedBox(width: 6),
            Text(_actif ? 'Actif' : 'Inactif',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _actif ? Colors.green : Colors.red)),
          ]),
          const SizedBox(height: 20),
          const _DrawerSection(label: "PERMISSIONS D'ACCÈS"),
          const SizedBox(height: 10),
          _PermissionsList(allPerms: _allPerms, selected: _perms, onToggle: (p) => setState(() => _perms.contains(p) ? _perms.remove(p) : _perms.add(p))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SECTION: CHEFS D'ÉQUIPE
// ─────────────────────────────────────────────

class _ChefsEquipeSection extends StatefulWidget {
  const _ChefsEquipeSection();
  @override State<_ChefsEquipeSection> createState() => _ChefsEquipeSectionState();
}

class _ChefsEquipeSectionState extends State<_ChefsEquipeSection> {
  final List<ChefEquipe> _chefs = [
    ChefEquipe(id: 'CE001', nom: 'Benhaddou', prenom: 'Farid', email: 'f.benhaddou@dips.ma', telephone: '0661 44 33 22', departement: 'Production', nbEmployes: 3, actif: true, dateCreation: DateTime(2024, 2, 10), employes: [
      Employe(id: 'EMP001', nom: 'Alami',   prenom: 'Youssef', poste: 'Opérateur',   telephone: '0661 11 22 33', actif: true),
      Employe(id: 'EMP002', nom: 'Haddad',  prenom: 'Imane',   poste: 'Technicienne',telephone: '0662 44 55 66', actif: true),
      Employe(id: 'EMP003', nom: 'Berrada', prenom: 'Amine',   poste: 'Contrôleur',  telephone: '0663 77 88 99', actif: false),
    ]),
    ChefEquipe(id: 'CE002', nom: 'Rachidi', prenom: 'Nadia', email: 'n.rachidi@dips.ma', telephone: '0662 55 44 33', departement: 'Logistique', nbEmployes: 2, actif: true, dateCreation: DateTime(2024, 4, 1), employes: [
      Employe(id: 'EMP004', nom: 'Benali', prenom: 'Soufiane', poste: 'Magasinier',   telephone: '0664 12 34 56', actif: true),
      Employe(id: 'EMP005', nom: 'Tahiri', prenom: 'Loubna',   poste: 'Gestionnaire', telephone: '0665 98 76 54', actif: true),
    ]),
    ChefEquipe(id: 'CE003', nom: 'Ouali', prenom: 'Bilal', email: 'b.ouali@dips.ma', telephone: '0663 66 55 44', departement: 'Maintenance', nbEmployes: 2, actif: false, dateCreation: DateTime(2023, 12, 5), employes: [
      Employe(id: 'EMP006', nom: 'Ziani',    prenom: 'Khalid',  poste: 'Électricien',  telephone: '0666 11 22 33', actif: true),
      Employe(id: 'EMP007', nom: 'Moussaoui',prenom: 'Fatima',  poste: 'Mécanicienne', telephone: '0667 44 55 66', actif: false),
    ]),
  ];

  String _searchQuery = '';

  static const _deptColors = {
    'Production':    Color(0xFF3B82F6),
    'Logistique':    Color(0xFFF59E0B),
    'Maintenance':   Color(0xFF10B981),
    'Informatique':  Color(0xFF8B5CF6),
    'Administration':Color(0xFFEF4444),
  };

  List<ChefEquipe> get _filtered => _chefs.where((c) =>
      '${c.nom} ${c.prenom} ${c.email} ${c.departement}'.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

  void _openChefDrawer([ChefEquipe? existing]) {
    _openDrawer(context, _ChefDrawer(
      existing: existing,
      onSave: (chef) => setState(() {
        if (existing != null) {
          final i = _chefs.indexWhere((c) => c.id == existing.id);
          if (i != -1) _chefs[i] = chef;
        } else { _chefs.add(chef); }
      }),
    ));
  }

  void _confirmDelete(ChefEquipe chef) {
    showDialog(context: context, builder: (_) => _ConfirmDialog(
      title: 'Supprimer le chef',
      message: 'Supprimer ${chef.prenom} ${chef.nom} de la liste ?',
      onConfirm: () => setState(() => _chefs.removeWhere((c) => c.id == chef.id)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mobile   = _isMobile(context);
    final filtered = _filtered;

    return Column(children: [
      _SectionTopBar(
        title: "Chefs d'équipe", subtitle: '${_chefs.length} chef(s)',
        searchQuery: _searchQuery, onSearch: (v) => setState(() => _searchQuery = v),
        onExport: () => _exportChefsCsv(context),
        onAdd: () => _openChefDrawer(), addLabel: 'Ajouter', addColor: _kDark,
      ),
      const Divider(height: 1, color: _kBorder),
      if (!mobile) ...[
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
      ],
      Expanded(
        child: filtered.isEmpty
            ? const _EmptyState()
            : ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final chef  = filtered[i];
            final color = _deptColors[chef.departement] ?? Colors.grey;
            return mobile
                ? _ChefMobileCard(
              chef: chef, deptColor: color,
              onEdit: () => _openChefDrawer(chef),
              onDelete: () => _confirmDelete(chef),
              onToggle: () => setState(() => chef.actif = !chef.actif),
              onDetails: () => _showChefDetails(context, chef, color),
            )
                : _ChefTableRow(
              chef: chef, deptColor: color, isEven: i.isEven,
              onEdit: () => _openChefDrawer(chef),
              onDelete: () => _confirmDelete(chef),
              onToggle: () => setState(() => chef.actif = !chef.actif),
              onDetails: () => _showChefDetails(context, chef, color),
            );
          },
        ),
      ),
    ]);
  }

  void _showChefDetails(BuildContext context, ChefEquipe c, Color dc) {
    _isMobile(context)
        ? showModalBottomSheet(
        context: context, isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ChefDetailSheet(chef: c, deptColor: dc))
        : showDialog(
        context: context, barrierColor: Colors.black45,
        builder: (_) => _ChefDetailsDialog(chef: c, deptColor: dc));
  }

  void _exportChefsCsv(BuildContext context) async {
    final csv = StringBuffer();
    csv.writeln('ID,Nom,Prénom,Email,Téléphone,Département,Nb Employés,Statut,Date Création');
    for (final c in _chefs) {
      csv.writeln('"${c.id}","${c.nom}","${c.prenom}","${c.email}","${c.telephone}","${c.departement}","${c.nbEmployes}","${c.actif ? 'Actif' : 'Inactif'}","${c.dateCreation.toIso8601String().substring(0, 10)}"');
    }
    await _saveAndOpenFile('chefs_equipe_export.csv', csv.toString(), context);
  }
}

// ── Chef mobile card ──
class _ChefMobileCard extends StatelessWidget {
  final ChefEquipe chef;
  final Color deptColor;
  final VoidCallback onEdit, onDelete, onToggle, onDetails;
  const _ChefMobileCard({required this.chef, required this.deptColor, required this.onEdit, required this.onDelete, required this.onToggle, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final c = chef;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c.prenom} ${c.nom}',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _kDark))),
          _StatusDot(actif: c.actif, onToggle: onToggle),
        ]),
        const SizedBox(height: 3),
        Text(c.email, style: TextStyle(fontSize: 11.5, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
        Text(c.telephone, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Row(children: [
          _RoleBadge(label: c.departement, color: deptColor),
          const SizedBox(width: 6),
          Text('${c.employes.length} emp.', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const Spacer(),
          _TableBtn(icon: Icons.info_outline, tooltip: 'Détails', color: Colors.purple, onTap: onDetails),
          const SizedBox(width: 5),
          _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: onEdit),
          const SizedBox(width: 5),
          _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: onDelete),
        ]),
      ]),
    );
  }
}

// ── Chef desktop row ──
class _ChefTableRow extends StatefulWidget {
  final ChefEquipe chef;
  final Color deptColor;
  final bool isEven;
  final VoidCallback onEdit, onDelete, onToggle, onDetails;
  const _ChefTableRow({required this.chef, required this.deptColor, required this.isEven, required this.onEdit, required this.onDelete, required this.onToggle, required this.onDetails});
  @override State<_ChefTableRow> createState() => _ChefTableRowState();
}

class _ChefTableRowState extends State<_ChefTableRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.chef; final dc = widget.deptColor;
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
              Expanded(flex: 3, child: Text('${c.prenom} ${c.nom}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kDark), overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2, child: Text(c.telephone, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
              Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _RoleBadge(label: c.departement, color: dc))),
              Expanded(flex: 2, child: _StatusDot(actif: c.actif, onToggle: widget.onToggle)),
              SizedBox(width: 110, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _TableBtn(icon: Icons.info_outline, tooltip: 'Détails', color: Colors.purple, onTap: widget.onDetails),
                const SizedBox(width: 5),
                _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: widget.onEdit),
                const SizedBox(width: 5),
                _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: widget.onDelete),
              ])),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),
        ]),
      ),
    );
  }
}

// ── Chef detail bottom sheet (mobile) ──
class _ChefDetailSheet extends StatefulWidget {
  final ChefEquipe chef;
  final Color deptColor;
  const _ChefDetailSheet({required this.chef, required this.deptColor});
  @override State<_ChefDetailSheet> createState() => _ChefDetailSheetState();
}

class _ChefDetailSheetState extends State<_ChefDetailSheet> {
  late List<Employe> _employes;
  @override
  void initState() {
    super.initState();
    _employes = List.from(widget.chef.employes);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chef; final dc = widget.deptColor;
    return DraggableScrollableSheet(
      initialChildSize: 0.90, minChildSize: 0.5, maxChildSize: 0.97,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 14, 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c.prenom} ${c.nom}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kDark)),
                _RoleBadge(label: c.departement, color: dc),
              ])),
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _DetailRow(icon: Icons.email_outlined,  label: 'Email',    value: c.email),
              _DetailRow(icon: Icons.phone_outlined,  label: 'Tél.',     value: c.telephone),
              _DetailRow(icon: Icons.people_outline,  label: 'Effectif', value: '${_employes.length} employé(s)'),
              const SizedBox(height: 16),
              Row(children: [
                const _DrawerSection(label: 'EMPLOYÉS'),
                const Spacer(),
                TextButton.icon(
                  icon: Icon(Icons.person_add_outlined, size: 14, color: dc),
                  label: Text('Ajouter', style: TextStyle(color: dc, fontSize: 12)),
                  onPressed: () => _addOrEditEmployee(context),
                ),
              ]),
              const SizedBox(height: 8),
              ..._employes.map((emp) => _EmployeeMobileRow(
                emp: emp, deptColor: dc,
                onEdit: () => _addOrEditEmployee(context, emp),
                onDelete: () => setState(() { _employes.removeWhere((e) => e.id == emp.id); _saveEmployes(); }),
              )).toList(),
            ]),
          )),
        ]),
      ),
    );
  }

  void _saveEmployes() {
    widget.chef.employes..clear()..addAll(_employes);
    widget.chef.nbEmployes = _employes.length;
  }

  void _addOrEditEmployee(BuildContext context, [Employe? existing]) {
    final nomCtrl    = TextEditingController(text: existing?.nom ?? '');
    final prenomCtrl = TextEditingController(text: existing?.prenom ?? '');
    final posteCtrl  = TextEditingController(text: existing?.poste ?? '');
    final telCtrl    = TextEditingController(text: existing?.telephone ?? '');
    bool actif = existing?.actif ?? true;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(existing == null ? 'Ajouter un employé' : "Modifier l'employé",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kDark)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _DrawerField(label: 'Prénom *', controller: prenomCtrl, hint: 'Prénom')),
                const SizedBox(width: 10),
                Expanded(child: _DrawerField(label: 'Nom *', controller: nomCtrl, hint: 'Nom')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _DrawerField(label: 'Poste *', controller: posteCtrl, hint: 'Ex: Technicien')),
                const SizedBox(width: 10),
                Expanded(child: _DrawerField(label: 'Téléphone', controller: telCtrl, hint: '06xx', keyboardType: TextInputType.phone)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
                const Spacer(),
                Switch.adaptive(value: actif, onChanged: (v) => setDlg(() => actif = v), activeColor: widget.deptColor),
                Text(actif ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: actif ? Colors.green : Colors.red)),
              ]),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: widget.deptColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  if (prenomCtrl.text.isEmpty || nomCtrl.text.isEmpty) return;
                  final emp = Employe(
                    id: existing?.id ?? 'EMP${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                    nom: nomCtrl.text.trim(), prenom: prenomCtrl.text.trim(),
                    poste: posteCtrl.text.trim(), telephone: telCtrl.text.trim(), actif: actif,
                  );
                  setState(() {
                    if (existing != null) {
                      final idx = _employes.indexWhere((e) => e.id == existing.id);
                      if (idx != -1) _employes[idx] = emp;
                    } else { _employes.add(emp); }
                    _saveEmployes();
                  });
                  Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Ajouter' : 'Modifier', style: const TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmployeeMobileRow extends StatelessWidget {
  final Employe emp;
  final Color deptColor;
  final VoidCallback onEdit, onDelete;
  const _EmployeeMobileRow({required this.emp, required this.deptColor, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kBorder),
    ),
    child: Row(children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: emp.actif ? Colors.green : Colors.red, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${emp.prenom} ${emp.nom}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kDark)),
        Text(emp.poste, style: TextStyle(fontSize: 11, color: deptColor, fontWeight: FontWeight.w600)),
      ])),
      _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: onEdit),
      const SizedBox(width: 4),
      _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: onDelete),
    ]),
  );
}

// ── Chef details dialog (desktop) ──
class _ChefDetailsDialog extends StatefulWidget {
  final ChefEquipe chef;
  final Color deptColor;
  const _ChefDetailsDialog({required this.chef, required this.deptColor});
  @override State<_ChefDetailsDialog> createState() => _ChefDetailsDialogState();
}

class _ChefDetailsDialogState extends State<_ChefDetailsDialog> {
  late List<Employe> _employes;
  @override
  void initState() {
    super.initState();
    _employes = List.from(widget.chef.employes);
  }

  void _saveEmployes() {
    widget.chef.employes..clear()..addAll(_employes);
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                decoration: BoxDecoration(
                  color: widget.deptColor.withOpacity(0.07),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(bottom: BorderSide(color: widget.deptColor.withOpacity(0.2))),
                ),
                child: Row(children: [
                  Icon(existing == null ? Icons.person_add_outlined : Icons.edit_outlined, color: widget.deptColor, size: 20),
                  const SizedBox(width: 10),
                  Text(existing == null ? 'Ajouter un employé' : "Modifier l'employé",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kDark)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
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
                    Expanded(child: _DrawerField(label: 'Téléphone', controller: telCtrl, hint: '06xx', keyboardType: TextInputType.phone)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
                    const Spacer(),
                    Switch.adaptive(value: actif, onChanged: (v) => setDlg(() => actif = v), activeColor: widget.deptColor),
                    Text(actif ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: actif ? Colors.green : Colors.red)),
                  ]),
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: _kBorder), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Annuler', style: TextStyle(color: _kDark)),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: widget.deptColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () {
                      if (prenomCtrl.text.isEmpty || nomCtrl.text.isEmpty) return;
                      final emp = Employe(
                        id: existing?.id ?? 'EMP${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                        nom: nomCtrl.text.trim(), prenom: prenomCtrl.text.trim(),
                        poste: posteCtrl.text.trim(), telephone: telCtrl.text.trim(), actif: actif,
                      );
                      setState(() {
                        if (existing != null) {
                          final idx = _employes.indexWhere((e) => e.id == existing.id);
                          if (idx != -1) _employes[idx] = emp;
                        } else { _employes.add(emp); }
                        _saveEmployes();
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(existing == null ? 'Ajouter' : 'Modifier', style: const TextStyle(fontWeight: FontWeight.w700)),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chef; final dc = widget.deptColor;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 700),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(26, 20, 18, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [dc.withOpacity(0.10), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: dc.withOpacity(0.2))),
            ),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: dc.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.groups, color: dc, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c.prenom} ${c.nom}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kDark)),
                Row(children: [
                  Text(c.id, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(width: 8),
                  _RoleBadge(label: c.departement, color: dc),
                ]),
              ])),
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          // Body
          Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Left info panel
            Container(
              width: 250,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(right: BorderSide(color: _kBorder))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _DetailRow(icon: Icons.email_outlined,  label: 'Email',    value: c.email),
                _DetailRow(icon: Icons.phone_outlined,  label: 'Tél.',     value: c.telephone),
                _DetailRow(icon: Icons.people_outline,  label: 'Effectif', value: '${_employes.length} emp.'),
                _DetailRow(icon: Icons.calendar_today,  label: 'Créé le',
                    value: '${c.dateCreation.day.toString().padLeft(2,'0')}/${c.dateCreation.month.toString().padLeft(2,'0')}/${c.dateCreation.year}'),
                const SizedBox(height: 14),
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
              ]),
            ),
            // Right employees panel
            Expanded(child: Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(18, 12, 14, 10),
                child: Row(children: [
                  Text('EMPLOYÉS (${_employes.length})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: Color(0xFF6B7A99))),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: dc, foregroundColor: Colors.white, elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
                    icon: const Icon(Icons.person_add_outlined, size: 14),
                    label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => _addOrEditEmployee(),
                  ),
                ]),
              ),
              const Divider(height: 1, color: _kBorder),
              Container(color: const Color(0xFFF0F4FA), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: const Row(children: [
                    Expanded(flex: 3, child: _TH('NOM COMPLET')),
                    Expanded(flex: 2, child: _TH('POSTE')),
                    Expanded(flex: 2, child: _TH('TÉLÉPHONE')),
                    SizedBox(width: 70, child: _TH('', center: true)),
                  ])),
              const Divider(height: 1, color: _kBorder),
              Expanded(child: _employes.isEmpty
                  ? Center(child: Text('Aucun employé', style: TextStyle(color: Colors.grey[400], fontSize: 13)))
                  : ListView.builder(
                  itemCount: _employes.length,
                  itemBuilder: (_, i) {
                    final emp = _employes[i];
                    return Container(
                      color: i.isEven ? Colors.white : const Color(0xFFFAFBFD),
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          child: Row(children: [
                            Expanded(flex: 3, child: Text('${emp.prenom} ${emp.nom}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kDark), overflow: TextOverflow.ellipsis)),
                            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _RoleBadge(label: emp.poste, color: dc, small: true))),
                            Expanded(flex: 2, child: Text(emp.telephone, style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                            SizedBox(width: 70, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              _TableBtn(icon: Icons.edit_outlined, tooltip: 'Modifier', color: _kAccent, onTap: () => _addOrEditEmployee(emp)),
                              const SizedBox(width: 5),
                              _TableBtn(icon: Icons.delete_outline, tooltip: 'Supprimer', color: Colors.red, onTap: () {
                                setState(() { _employes.removeWhere((e) => e.id == emp.id); _saveEmployes(); });
                              }),
                            ])),
                          ]),
                        ),
                        const Divider(height: 1, color: _kBorder),
                      ]),
                    );
                  })),
            ])),
          ])),
        ]),
      ),
    );
  }
}

// ── Chef drawer ──
class _ChefDrawer extends StatefulWidget {
  final ChefEquipe? existing;
  final Function(ChefEquipe) onSave;
  const _ChefDrawer({this.existing, required this.onSave});
  @override State<_ChefDrawer> createState() => _ChefDrawerState();
}

class _ChefDrawerState extends State<_ChefDrawer> {
  final _fk = GlobalKey<FormState>();
  late TextEditingController _nomCtrl, _prenomCtrl, _emailCtrl, _telCtrl, _nbEmpCtrl;
  String _dept = 'Production';
  bool _actif = true;
  final _depts = ['Production', 'Logistique', 'Maintenance', 'Informatique', 'Administration'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nomCtrl    = TextEditingController(text: e?.nom ?? '');
    _prenomCtrl = TextEditingController(text: e?.prenom ?? '');
    _emailCtrl  = TextEditingController(text: e?.email ?? '');
    _telCtrl    = TextEditingController(text: e?.telephone ?? '');
    _nbEmpCtrl  = TextEditingController(text: '${e?.nbEmployes ?? 0}');
    _dept  = e?.departement ?? 'Production';
    _actif = e?.actif ?? true;
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _prenomCtrl.dispose(); _emailCtrl.dispose();
    _telCtrl.dispose(); _nbEmpCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_fk.currentState!.validate()) return;
    final isNew = widget.existing == null;
    widget.onSave(ChefEquipe(
      id: isNew ? 'CE${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}' : widget.existing!.id,
      nom: _nomCtrl.text.trim(), prenom: _prenomCtrl.text.trim(),
      email: _emailCtrl.text.trim(), telephone: _telCtrl.text.trim(),
      departement: _dept, nbEmployes: int.tryParse(_nbEmpCtrl.text) ?? 0,
      actif: _actif, dateCreation: widget.existing?.dateCreation ?? DateTime.now(),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final mobile = _isMobile(context);
    return _SideDrawer(
      title: isEdit ? "Modifier le chef d'équipe" : "Nouveau chef d'équipe",
      subtitle: isEdit ? 'Mettre à jour les informations' : 'Enregistrer un nouveau chef',
      icon: isEdit ? Icons.manage_accounts : Icons.group_add,
      accentColor: _kDark, saveLabel: isEdit ? 'Modifier' : 'Enregistrer',
      onSave: _save,
      body: Form(
        key: _fk,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _DrawerSection(label: 'IDENTITÉ'),
          const SizedBox(height: 10),
          if (mobile) ...[
            _DrawerField(label: 'Prénom *', controller: _prenomCtrl, hint: 'Ex: Farid'),
            const SizedBox(height: 10),
            _DrawerField(label: 'Nom *', controller: _nomCtrl, hint: 'Ex: Benhaddou'),
          ] else
            Row(children: [
              Expanded(child: _DrawerField(label: 'Prénom *', controller: _prenomCtrl, hint: 'Ex: Farid')),
              const SizedBox(width: 12),
              Expanded(child: _DrawerField(label: 'Nom *', controller: _nomCtrl, hint: 'Ex: Benhaddou')),
            ]),
          const SizedBox(height: 12),
          _DrawerField(label: 'Email *', controller: _emailCtrl, hint: 'exemple@dips.ma', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _DrawerField(label: 'Téléphone', controller: _telCtrl, hint: '06xx xx xx xx', keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          const _DrawerSection(label: 'AFFECTATION'),
          const SizedBox(height: 10),
          _DrawerDropdown(label: 'Département *', value: _dept, items: _depts, onChanged: (v) => setState(() => _dept = v!)),
          const SizedBox(height: 12),
          _DrawerField(label: "Nombre d'employés", controller: _nbEmpCtrl, hint: '0', isNumber: true),
          const SizedBox(height: 20),
          const _DrawerSection(label: 'STATUT'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: const Border.fromBorderSide(BorderSide(color: _kBorder))),
            child: Row(children: [
              Text('Compte actif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              const Spacer(),
              Switch.adaptive(value: _actif, onChanged: (v) => setState(() => _actif = v), activeColor: _kDark),
              Text(_actif ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _actif ? Colors.green : Colors.red)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  GENERAL / NOTIFICATIONS / SECURITE / DATABASE / ABOUT
//  (all scrollable sections — responsive 2-col → 1-col)
// ─────────────────────────────────────────────

class _GeneralSection extends StatefulWidget {
  const _GeneralSection();
  @override State<_GeneralSection> createState() => _GeneralSectionState();
}

class _GeneralSectionState extends State<_GeneralSection> {
  final _nomEntCtrl  = TextEditingController(text: 'DIPS Entreprise');
  final _adresseCtrl = TextEditingController(text: 'Casablanca, Maroc');
  final _emailCtrl   = TextEditingController(text: 'contact@dips.ma');
  final _telCtrl     = TextEditingController(text: '+212 52 00 00 00');
  String _langue = 'Français';
  String _devise = 'MAD (Dirham Marocain)';
  bool _modeMainenance = false, _notifDesktop = true;

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    final pad    = _pagePad(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(title: 'Paramètres Généraux', subtitle: "Configuration de base de l'application"),
        const SizedBox(height: 18),
        _SettingsCard(title: "Informations de l'entreprise", icon: Icons.business, children: [
          if (mobile) ...[
            _FormField(label: "Nom de l'entreprise", controller: _nomEntCtrl, hint: ''),
            const SizedBox(height: 12),
            _FormField(label: 'Adresse', controller: _adresseCtrl, hint: ''),
            const SizedBox(height: 12),
            _FormField(label: 'Email', controller: _emailCtrl, hint: ''),
            const SizedBox(height: 12),
            _FormField(label: 'Téléphone', controller: _telCtrl, hint: ''),
          ] else ...[
            Row(children: [
              Expanded(child: _FormField(label: "Nom de l'entreprise", controller: _nomEntCtrl, hint: '')),
              const SizedBox(width: 16),
              Expanded(child: _FormField(label: 'Adresse', controller: _adresseCtrl, hint: '')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _FormField(label: 'Email', controller: _emailCtrl, hint: '')),
              const SizedBox(width: 16),
              Expanded(child: _FormField(label: 'Téléphone', controller: _telCtrl, hint: '')),
            ]),
          ],
        ]),
        const SizedBox(height: 14),
        _SettingsCard(title: 'Localisation', icon: Icons.language, children: [
          if (mobile) ...[
            _DropdownSetting(label: 'Langue', value: _langue, items: ['Français', 'العربية', 'English'], onChanged: (v) => setState(() => _langue = v!)),
            const SizedBox(height: 12),
            _DropdownSetting(label: 'Devise', value: _devise, items: ['MAD (Dirham Marocain)', 'EUR (Euro)', 'USD (Dollar)'], onChanged: (v) => setState(() => _devise = v!)),
          ] else
            Row(children: [
              Expanded(child: _DropdownSetting(label: 'Langue', value: _langue, items: ['Français', 'العربية', 'English'], onChanged: (v) => setState(() => _langue = v!))),
              const SizedBox(width: 16),
              Expanded(child: _DropdownSetting(label: 'Devise', value: _devise, items: ['MAD (Dirham Marocain)', 'EUR (Euro)', 'USD (Dollar)'], onChanged: (v) => setState(() => _devise = v!))),
            ]),
        ]),
        const SizedBox(height: 14),
        _SettingsCard(title: 'Système', icon: Icons.tune, children: [
          _SwitchSetting(label: 'Mode Maintenance', subtitle: "Désactiver l'accès utilisateur", value: _modeMainenance, onChanged: (v) => setState(() => _modeMainenance = v), iconColor: Colors.orange),
          const Divider(height: 20),
          _SwitchSetting(label: 'Notifications desktop', subtitle: 'Afficher les notifications système', value: _notifDesktop, onChanged: (v) => setState(() => _notifDesktop = v), iconColor: _kAccent),
        ]),
        const SizedBox(height: 18),
        Align(alignment: Alignment.centerRight, child: _SaveBtn(onTap: () => _showSaveSuccess(context))),
      ]),
    );
  }
}

class _NotificationsSection extends StatefulWidget {
  const _NotificationsSection();
  @override State<_NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<_NotificationsSection> {
  bool _absences = true, _stockBas = true, _rapports = false, _connexions = true, _email = true, _son = false;

  @override
  Widget build(BuildContext context) {
    final pad = _pagePad(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(title: 'Notifications', subtitle: 'Gérer les alertes et notifications'),
        const SizedBox(height: 18),
        _SettingsCard(title: 'Alertes Métier', icon: Icons.notifications_active, children: [
          _SwitchSetting(label: 'Absences non justifiées', subtitle: "Alerte lors d'une absence non signalée", value: _absences, onChanged: (v) => setState(() => _absences = v), iconColor: Colors.red),
          const Divider(height: 20),
          _SwitchSetting(label: 'Stock bas', subtitle: "Alerte quand un produit est en stock critique", value: _stockBas, onChanged: (v) => setState(() => _stockBas = v), iconColor: Colors.orange),
          const Divider(height: 20),
          _SwitchSetting(label: 'Génération de rapports', subtitle: 'Notifier quand un rapport est prêt', value: _rapports, onChanged: (v) => setState(() => _rapports = v), iconColor: Colors.purple),
          const Divider(height: 20),
          _SwitchSetting(label: 'Nouvelles connexions admin', subtitle: "Alerte lors de connexion d'un admin", value: _connexions, onChanged: (v) => setState(() => _connexions = v), iconColor: _kAccent),
        ]),
        const SizedBox(height: 14),
        _SettingsCard(title: 'Canaux', icon: Icons.send, children: [
          _SwitchSetting(label: 'Email', subtitle: 'Envoyer des notifications par email', value: _email, onChanged: (v) => setState(() => _email = v), iconColor: Colors.green),
          const Divider(height: 20),
          _SwitchSetting(label: 'Son', subtitle: 'Jouer un son lors des notifications', value: _son, onChanged: (v) => setState(() => _son = v), iconColor: Colors.blue),
        ]),
        const SizedBox(height: 18),
        Align(alignment: Alignment.centerRight, child: _SaveBtn(onTap: () => _showSaveSuccess(context))),
      ]),
    );
  }
}

class _SecuriteSection extends StatefulWidget {
  const _SecuriteSection();
  @override State<_SecuriteSection> createState() => _SecuriteSectionState();
}

class _SecuriteSectionState extends State<_SecuriteSection> {
  bool _auth2 = false, _verrou = true;
  String _session = '30 minutes', _tentatives = '3 tentatives';
  final _oldPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _confPwd = TextEditingController();
  bool _showOld = false, _showNew = false, _showConf = false;

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    final pad    = _pagePad(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(title: 'Sécurité', subtitle: "Paramètres de sécurité et d'authentification"),
        const SizedBox(height: 18),
        _SettingsCard(title: 'Politique de sécurité', icon: Icons.security, children: [
          _SwitchSetting(label: 'Double authentification (2FA)', subtitle: 'Vérification en deux étapes', value: _auth2, onChanged: (v) => setState(() => _auth2 = v), iconColor: Colors.green),
          const Divider(height: 20),
          _SwitchSetting(label: 'Verrouillage automatique', subtitle: "Verrouiller après inactivité", value: _verrou, onChanged: (v) => setState(() => _verrou = v), iconColor: Colors.orange),
          const Divider(height: 20),
          if (mobile) ...[
            _DropdownSetting(label: 'Durée de session', value: _session, items: ['15 minutes', '30 minutes', '1 heure', '2 heures'], onChanged: (v) => setState(() => _session = v!)),
            const SizedBox(height: 12),
            _DropdownSetting(label: 'Tentatives de connexion', value: _tentatives, items: ['3 tentatives', '5 tentatives', '10 tentatives'], onChanged: (v) => setState(() => _tentatives = v!)),
          ] else
            Row(children: [
              Expanded(child: _DropdownSetting(label: 'Durée de session', value: _session, items: ['15 minutes', '30 minutes', '1 heure', '2 heures'], onChanged: (v) => setState(() => _session = v!))),
              const SizedBox(width: 16),
              Expanded(child: _DropdownSetting(label: 'Tentatives de connexion', value: _tentatives, items: ['3 tentatives', '5 tentatives', '10 tentatives'], onChanged: (v) => setState(() => _tentatives = v!))),
            ]),
        ]),
        const SizedBox(height: 14),
        _SettingsCard(title: 'Changer le mot de passe Super Admin', icon: Icons.lock_outline, children: [
          _PasswordField(label: 'Mot de passe actuel',    controller: _oldPwd,  show: _showOld,  onToggle: () => setState(() => _showOld  = !_showOld)),
          const SizedBox(height: 12),
          _PasswordField(label: 'Nouveau mot de passe',   controller: _newPwd,  show: _showNew,  onToggle: () => setState(() => _showNew  = !_showNew)),
          const SizedBox(height: 12),
          _PasswordField(label: 'Confirmer le mot de passe', controller: _confPwd, show: _showConf, onToggle: () => setState(() => _showConf = !_showConf)),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerRight, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            onPressed: () => _showSaveSuccess(context),
            child: const Text('Modifier le mot de passe'),
          )),
        ]),
        const SizedBox(height: 18),
        Align(alignment: Alignment.centerRight, child: _SaveBtn(onTap: () => _showSaveSuccess(context))),
      ]),
    );
  }
}

class _DatabaseSection extends StatefulWidget {
  const _DatabaseSection();
  @override State<_DatabaseSection> createState() => _DatabaseSectionState();
}

class _DatabaseSectionState extends State<_DatabaseSection> {
  bool _exportLoading = false, _importLoading = false;
  String? _lastExportPath, _importStatus;

  @override
  Widget build(BuildContext context) {
    final pad = _pagePad(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(title: 'Base de données', subtitle: 'Sauvegarde, restauration et maintenance'),
        const SizedBox(height: 18),
        _SettingsCard(title: 'Export des données', icon: Icons.file_download_outlined, children: [
          Text("Exportez toutes les données dans un fichier CSV ou JSON.", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _ExportFormatBtn(label: 'Exporter en CSV', icon: Icons.table_chart_outlined, color: Colors.green, loading: _exportLoading, onTap: () => _doExport(context, 'csv')),
            _ExportFormatBtn(label: 'Exporter en JSON', icon: Icons.data_object, color: Colors.blue, loading: _exportLoading, onTap: () => _doExport(context, 'json')),
          ]),
          if (_lastExportPath != null) ...[
            const SizedBox(height: 12),
            _StatusBanner(message: 'Fichier enregistré : $_lastExportPath', success: true),
          ],
        ]),
        const SizedBox(height: 14),
        _SettingsCard(title: 'Import des données', icon: Icons.file_upload_outlined, children: [
          Text("Importez des données depuis un fichier CSV.", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _kDark, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: _importLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('Choisir un fichier CSV', style: TextStyle(fontSize: 13)),
            onPressed: _importLoading ? null : () => _doImport(context),
          ),
          if (_importStatus != null) ...[
            const SizedBox(height: 12),
            _StatusBanner(message: _importStatus!, success: _importStatus!.startsWith('✓')),
          ],
        ]),
        const SizedBox(height: 14),
        _SettingsCard(title: 'Historique des sauvegardes', icon: Icons.history, children: [
          ...['01/03/2026 - 08:00', '28/02/2026 - 08:00', '27/02/2026 - 08:00'].map((d) => Padding(
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
          )),
        ]),
        const SizedBox(height: 14),
        _SettingsCard(title: 'Zone de danger', icon: Icons.warning_amber_rounded, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Réinitialiser la base de données', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
              Text("Cette action est irréversible.", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            const SizedBox(width: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => _showResetConfirm(context),
              child: const Text('Réinitialiser', style: TextStyle(fontSize: 13)),
            ),
          ]),
        ]),
      ]),
    );
  }

  Future<void> _doExport(BuildContext context, String format) async {
    setState(() { _exportLoading = true; _lastExportPath = null; });
    try {
      final dir   = await _getDesktopOrDocumentsPath();
      final now   = DateTime.now();
      final ts    = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}';
      final path  = '$dir/dips_export_$ts.$format';
      final content = format == 'csv'
          ? 'Type,ID,Nom,Prénom,Email\n"Admin","ADM001","El Amrani","Karim","k.elamrani@dips.ma"\n'
          : '{"export_date":"${now.toIso8601String()}","application":"DIPS"}';
      await _saveAndOpenFile(path, content, context);
      setState(() => _lastExportPath = path);
    } finally { setState(() => _exportLoading = false); }
  }

  Future<void> _doImport(BuildContext context) async {
    setState(() { _importLoading = true; _importStatus = null; });
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() => _importStatus = '✓ Import simulé avec succès.');
    } finally { setState(() => _importLoading = false); }
  }

  void _showRestoreConfirm(BuildContext context, String date) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(children: [Icon(Icons.restore, color: Colors.blue), SizedBox(width: 8), Text('Restaurer la sauvegarde')]),
      content: Text('Restaurer les données du $date ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, elevation: 0),
            onPressed: () { Navigator.pop(context); _showSaveSuccess(context); }, child: const Text('Restaurer')),
      ],
    ));
  }

  void _showResetConfirm(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Text('Réinitialisation')]),
      content: const Text('Cette action est IRRÉVERSIBLE. Toutes les données seront effacées.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context), child: const Text('Réinitialiser')),
      ],
    ));
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(_pagePad(context)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader(title: 'À propos', subtitle: 'Informations sur le système DIPS'),
      const SizedBox(height: 22),
      Center(child: Container(
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _kBorder)),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: _kAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.business, color: _kAccent, size: 50)),
          const SizedBox(height: 14),
          const Text('DIPS', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _kDark)),
          const Text('Système de Gestion', style: TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 14),
          ...[['Version', '1.0.0'], ['Build', '2026.03.01'], ['Plateforme', 'Flutter'], ['Base de données', 'SQLite'], ['Licence', 'Propriétaire']].map(
                (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 130, child: Text(item[0], style: TextStyle(color: Colors.grey[600], fontSize: 13))),
                Text(item[1], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ),
        ]),
      )),
    ]),
  );
}

// ─────────────────────────────────────────────
//  REUSABLE SMALL WIDGETS
// ─────────────────────────────────────────────

class _SectionTopBar extends StatelessWidget {
  final String title, subtitle, searchQuery, addLabel;
  final ValueChanged<String> onSearch;
  final VoidCallback onExport, onAdd;
  final Color addColor;

  const _SectionTopBar({
    required this.title, required this.subtitle, required this.searchQuery,
    required this.onSearch, required this.onExport, required this.onAdd,
    required this.addLabel, required this.addColor,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = _isMobile(context);
    if (mobile) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kDark)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ])),
            _TableBtn(icon: Icons.file_download_outlined, tooltip: 'Exporter CSV', color: _kDark, onTap: onExport),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: addColor, foregroundColor: Colors.white, elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
              icon: const Icon(Icons.add, size: 15),
              label: Text(addLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: onAdd,
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            onChanged: onSearch,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher...', hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search, size: 16), isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              filled: true, fillColor: _kBg,
              border:        OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
            ),
          ),
        ]),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
        const Spacer(),
        SizedBox(
          width: 200,
          child: TextField(
            onChanged: onSearch,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher...', hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search, size: 16), isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              filled: true, fillColor: _kBg,
              border:        OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: _kBorder)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(side: const BorderSide(color: _kBorder), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
          icon: const Icon(Icons.file_download_outlined, size: 15, color: _kDark),
          label: const Text('Exporter CSV', style: TextStyle(fontSize: 12, color: _kDark)),
          onPressed: onExport,
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: addColor, foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
          icon: const Icon(Icons.add, size: 15),
          label: Text(addLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          onPressed: onAdd,
        ),
      ]),
    );
  }
}

class _TH extends StatelessWidget {
  final String label;
  final bool center;
  const _TH(this.label, {this.center = false});
  @override
  Widget build(BuildContext context) => Text(label,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Color(0xFF6B7A99)));
}

class _StatusDot extends StatelessWidget {
  final bool actif;
  final VoidCallback onToggle;
  const _StatusDot({required this.actif, required this.onToggle});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: actif ? Colors.green : Colors.red, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(actif ? 'Actif' : 'Inactif',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: actif ? Colors.green.shade700 : Colors.red.shade600)),
    ]),
  );
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;
  const _RoleBadge({required this.label, required this.color, this.small = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.2))),
    child: Text(label, style: TextStyle(fontSize: small ? 10 : 11, color: color, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
  );
}

class _TableBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _TableBtn({required this.icon, required this.tooltip, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.15))),
        child: Icon(icon, size: 15, color: color),
      ),
    ),
  );
}

class _PermChip extends StatelessWidget {
  final String label;
  const _PermChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF4F46E5)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
    ]),
  );
}

class _PermissionsList extends StatelessWidget {
  final List<String> allPerms, selected;
  final ValueChanged<String> onToggle;
  const _PermissionsList({required this.allPerms, required this.selected, required this.onToggle});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: const Border.fromBorderSide(BorderSide(color: _kBorder))),
    child: Column(children: allPerms.map((p) {
      final on = selected.contains(p);
      return InkWell(
        onTap: () => onToggle(p),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: on ? _kAccent : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: on ? _kAccent : Colors.grey.shade300, width: 1.5),
              ),
              child: on ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Text(p, style: TextStyle(fontSize: 13, color: on ? _kDark : Colors.grey[600], fontWeight: on ? FontWeight.w600 : FontWeight.normal)),
          ]),
        ),
      );
    }).toList()),
  );
}

class _PwdField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool show;
  final VoidCallback onToggle;
  const _PwdField({required this.ctrl, required this.show, required this.onToggle});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Mot de passe *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl, obscureText: !show,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: '••••••••', hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          filled: true, fillColor: const Color(0xFFF8FAFC),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
          suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 17, color: Colors.grey), onPressed: onToggle),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
      ),
    ],
  );
}

class _DialogHeader extends StatelessWidget {
  final String title, subtitle;
  final bool actif;
  final Color accentColor;
  final IconData icon;
  const _DialogHeader({required this.title, required this.subtitle, required this.actif, required this.accentColor, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(26, 20, 18, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [accentColor.withOpacity(0.08), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      border: Border(bottom: BorderSide(color: accentColor.withOpacity(0.15))),
    ),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: accentColor, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kDark)),
        Row(children: [
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: actif ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(actif ? 'Actif' : 'Inactif',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: actif ? Colors.green.shade700 : Colors.red.shade600)),
          ),
        ]),
      ])),
      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
    ]),
  );
}

class _ConfirmDialog extends StatelessWidget {
  final String title, message;
  final VoidCallback onConfirm;
  const _ConfirmDialog({required this.title, required this.message, required this.onConfirm});
  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    title: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16))]),
    content: Text(message, style: const TextStyle(fontSize: 13)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
        onPressed: () { onConfirm(); Navigator.pop(context); },
        child: const Text('Supprimer'),
      ),
    ],
  );
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool success;
  const _StatusBanner({required this.message, required this.success});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: (success ? Colors.green : Colors.red).withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: (success ? Colors.green : Colors.red).withOpacity(0.2)),
    ),
    child: Row(children: [
      Icon(success ? Icons.check_circle_outline : Icons.error_outline, color: success ? Colors.green : Colors.red, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: success ? Colors.green : Colors.red), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _SaveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
    icon: const Icon(Icons.save_outlined, size: 17),
    label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w600)),
    onPressed: onTap,
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.search_off_rounded, size: 44, color: Colors.grey[300]),
    const SizedBox(height: 10),
    Text('Aucun résultat', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
  ]));
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey[400]),
      const SizedBox(width: 8),
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: _kDark, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─────────────────────────────────────────────
//  SETTINGS CARD WIDGETS
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeader({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: _kDark)),
    const SizedBox(height: 3),
    Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
  ]);
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SettingsCard({required this.title, required this.icon, required this.children});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(_isMobile(context) ? 14 : 18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: _kAccent, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kDark))),
      ]),
      const SizedBox(height: 14),
      const Divider(height: 1),
      const SizedBox(height: 12),
      ...children,
    ]),
  );
}

class _SwitchSetting extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color iconColor;
  const _SwitchSetting({required this.label, required this.subtitle, required this.value, required this.onChanged, required this.iconColor});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
        child: Icon(Icons.circle, size: 7, color: iconColor)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
    ])),
    Switch(value: value, onChanged: onChanged, activeColor: _kAccent),
  ]);
}

class _DropdownSetting extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownSetting({required this.label, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        filled: true, fillColor: Colors.white,
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
    ),
  ]);
}

class _FormField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final bool isEmail, isPassword, isNumber;
  const _FormField({required this.label, required this.controller, required this.hint, this.isEmail = false, this.isPassword = false, this.isNumber = false});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    TextFormField(
      controller: controller, obscureText: isPassword,
      keyboardType: isNumber ? TextInputType.number : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
        filled: true, fillColor: Colors.white,
      ),
    ),
  ]);
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool show;
  final VoidCallback onToggle;
  const _PasswordField({required this.label, required this.controller, required this.show, required this.onToggle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    TextFormField(
      controller: controller, obscureText: !show,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
        filled: true, fillColor: Colors.white,
        suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off : Icons.visibility, size: 17), onPressed: onToggle),
      ),
    ),
  ]);
}

class _ExportFormatBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ExportFormatBtn({required this.label, required this.icon, required this.color, required this.loading, required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: color.withOpacity(0.4)), foregroundColor: color,
      backgroundColor: color.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    icon: loading
        ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: color))
        : Icon(icon, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    onPressed: loading ? null : onTap,
  );
}

// ─────────────────────────────────────────────
//  I/O UTILITIES
// ─────────────────────────────────────────────

Future<String> _getDesktopOrDocumentsPath() async {
  final home = dart_io.Platform.environment['HOME'] ?? dart_io.Platform.environment['USERPROFILE'] ?? '.';
  final docs = dart_io.Directory('$home/Documents');
  if (await docs.exists()) return docs.path;
  return home;
}

Future<void> _saveAndOpenFile(String fileNameOrPath, String content, BuildContext context) async {
  try {
    final path = fileNameOrPath.contains('/') ? fileNameOrPath : '${await _getDesktopOrDocumentsPath()}/$fileNameOrPath';
    final file = dart_io.File(path);
    await file.writeAsString(content, flush: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating, width: 400,
        backgroundColor: Colors.green.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('Fichier enregistré : $path', style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ]),
      ));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text('Erreur : $e')));
    }
  }
}

void _showSaveSuccess(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating, width: 320, backgroundColor: Colors.green,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: const Row(children: [
      Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8),
      Text('Paramètres enregistrés avec succès', style: TextStyle(color: Colors.white)),
    ]),
  ));
}