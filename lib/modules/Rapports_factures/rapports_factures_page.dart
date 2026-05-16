import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/responsive.dart';
import '../logistique/logistique_service.dart';
import '../logistique/vehicule_model.dart';

// ── Constantes visuelles ──────────────────────────────────────────────────────
const _kBlue = Color(0xFF000966);
const _kIndigo = Colors.indigo;

class RapportsFacturesPage extends StatefulWidget {
  const RapportsFacturesPage({super.key});

  @override
  State<RapportsFacturesPage> createState() => _RapportsFacturesPageState();
}

class _RapportsFacturesPageState extends State<RapportsFacturesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = pagePadding(context);
    return Column(
      children: [
        // ── Barre d'onglets ────────────────────────────────────────────────
        Container(
          color: _kBlue,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Rapports'),
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Factures'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _RapportsTab(padding: padding),
              _FacturesTab(padding: padding),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rapports (vide)
// ─────────────────────────────────────────────────────────────────────────────
class _RapportsTab extends StatelessWidget {
  final double padding;
  const _RapportsTab({required this.padding});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bar_chart_rounded, size: 40, color: Colors.grey[400]),
          ),
          const SizedBox(height: 14),
          Text('Rapports',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text('Bientôt disponible',
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Factures
// ─────────────────────────────────────────────────────────────────────────────
enum _FactureCategorie { logistique, magasin }

extension _FactureCategorieExt on _FactureCategorie {
  String get label => this == _FactureCategorie.logistique ? 'Logistique' : 'Magasin';
  String get description => this == _FactureCategorie.logistique
      ? 'Vidanges, carburant & réparations'
      : 'Achats & approvisionnements';
  IconData get icon =>
      this == _FactureCategorie.logistique ? Icons.local_shipping_rounded : Icons.inventory_2_rounded;
  Color get color => this == _FactureCategorie.logistique ? _kIndigo : Colors.teal;
}

class _FacturesTab extends StatefulWidget {
  final double padding;
  const _FacturesTab({required this.padding});

  @override
  State<_FacturesTab> createState() => _FacturesTabState();
}

class _FacturesTabState extends State<_FacturesTab> {
  _FactureCategorie? _selected;

  @override
  Widget build(BuildContext context) {
    if (_selected == null) {
      return _CategoryPicker(
        padding: widget.padding,
        onSelect: (cat) => setState(() => _selected = cat),
      );
    }
    if (_selected == _FactureCategorie.logistique) {
      return _LogistiqueFacturesView(
        padding: widget.padding,
        onBack: () => setState(() => _selected = null),
      );
    }
    return _PlaceholderFactureList(
      categorie: _selected!,
      padding: widget.padding,
      onBack: () => setState(() => _selected = null),
    );
  }
}

// ── Sélecteur de catégorie ───────────────────────────────────────────────────
class _CategoryPicker extends StatelessWidget {
  final double padding;
  final void Function(_FactureCategorie) onSelect;
  const _CategoryPicker({required this.padding, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Factures',
              style: TextStyle(
                  fontSize: mobile ? 18 : 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Choisissez une catégorie',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (ctx, constraints) {
            final cards = _FactureCategorie.values
                .map((cat) => _CategoryCard(categorie: cat, onTap: () => onSelect(cat)))
                .toList();
            if (constraints.maxWidth < 500) {
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 12),
                  cards[1],
                ],
              );
            }
            return Row(children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 14),
              Expanded(child: cards[1]),
            ]);
          }),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _FactureCategorie categorie;
  final VoidCallback onTap;
  const _CategoryCard({required this.categorie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = categorie.color;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: color.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(categorie.icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(categorie.label,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    const SizedBox(height: 3),
                    Text(categorie.description,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_rounded, color: color, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logistique — liste des véhicules puis détail
// ─────────────────────────────────────────────────────────────────────────────
class _LogistiqueFacturesView extends StatefulWidget {
  final double padding;
  final VoidCallback onBack;
  const _LogistiqueFacturesView({required this.padding, required this.onBack});

  @override
  State<_LogistiqueFacturesView> createState() => _LogistiqueFacturesViewState();
}

class _LogistiqueFacturesViewState extends State<_LogistiqueFacturesView> {
  Vehicule? _selectedVehicule;

  @override
  Widget build(BuildContext context) {
    if (_selectedVehicule != null) {
      return _VehiculeFacturesDetail(
        vehicule: _selectedVehicule!,
        padding: widget.padding,
        onBack: () => setState(() => _selectedVehicule = null),
      );
    }
    return _VehiculeListView(
      padding: widget.padding,
      onBack: widget.onBack,
      onSelect: (v) => setState(() => _selectedVehicule = v),
    );
  }
}

// ── En-tête de section partagé ───────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onBack;
  const _SectionHeader(
      {required this.title, required this.icon, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            color: _kIndigo,
            onPressed: onBack,
            tooltip: 'Retour',
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kIndigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _kIndigo, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: _kIndigo),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Liste des véhicules ───────────────────────────────────────────────────────
class _VehiculeListView extends StatelessWidget {
  final double padding;
  final VoidCallback onBack;
  final void Function(Vehicule) onSelect;
  const _VehiculeListView(
      {required this.padding, required this.onBack, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          title: 'Factures — Logistique',
          icon: Icons.local_shipping_rounded,
          onBack: onBack,
        ),
        Expanded(
          child: StreamBuilder<List<Vehicule>>(
            stream: LogistiqueService.instance.streamVehicules(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kIndigo));
              }
              final vehicules = snap.data ?? [];
              if (vehicules.isEmpty) {
                return _EmptyState(
                  icon: Icons.local_shipping_rounded,
                  message: 'Aucun véhicule enregistré',
                );
              }
              return ListView.separated(
                padding: EdgeInsets.all(padding),
                itemCount: vehicules.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _VehiculeCard(
                    vehicule: vehicules[i],
                    onTap: () => onSelect(vehicules[i])),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VehiculeCard extends StatelessWidget {
  final Vehicule vehicule;
  final VoidCallback onTap;
  const _VehiculeCard({required this.vehicule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kIndigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: _kIndigo, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicule.matricule,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      '${vehicule.marque} ${vehicule.modele}'.trim(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${vehicule.kilometrage.toStringAsFixed(0)} km',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  const Icon(Icons.chevron_right_rounded,
                      color: _kIndigo, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Détail factures d'un véhicule ────────────────────────────────────────────
class _VehiculeFacturesDetail extends StatelessWidget {
  final Vehicule vehicule;
  final double padding;
  final VoidCallback onBack;
  const _VehiculeFacturesDetail(
      {required this.vehicule, required this.padding, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final id = vehicule.id!;
    return Column(
      children: [
        _SectionHeader(
          title: '${vehicule.matricule} · ${vehicule.marque} ${vehicule.modele}'.trim(),
          icon: Icons.receipt_long_rounded,
          onBack: onBack,
        ),
        Expanded(
          child: StreamBuilder<Vehicule>(
            stream: LogistiqueService.instance.streamVehiculeComplet(id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kIndigo));
              }
              final v = snap.data ?? vehicule;
              final totalV = v.vidanges.fold(0.0, (s, e) => s + e.montant);
              final totalP = v.pleins.fold(0.0, (s, e) => s + e.montant);
              final totalR = v.reparations.fold(0.0, (s, e) => s + e.montant);

              return ListView(
                padding: EdgeInsets.all(padding),
                children: [
                  _TotalCard(
                    totalGlobal: totalV + totalP + totalR,
                    totalVidanges: totalV,
                    totalPleins: totalP,
                    totalReparations: totalR,
                  ),
                  const SizedBox(height: 16),
                  _FactureSection(
                    titre: 'Vidanges',
                    icon: Icons.oil_barrel_rounded,
                    color: Colors.orange.shade700,
                    total: totalV,
                    count: v.vidanges.length,
                    rows: v.vidanges
                        .map((e) => _FactureRow(
                              date: e.date,
                              montant: e.montant,
                              detail: '${e.kilometrage.toStringAsFixed(0)} km',
                              badge: [
                                if (e.filtreHuile) 'Huile',
                                if (e.filtreAir) 'Air',
                                if (e.filtreGasoil) 'Gasoil',
                              ].join(' · '),
                              documentPath: e.documentPath,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _FactureSection(
                    titre: 'Pleins Gasoil',
                    icon: Icons.local_gas_station_rounded,
                    color: Colors.teal.shade600,
                    total: totalP,
                    count: v.pleins.length,
                    rows: v.pleins
                        .map((e) => _FactureRow(
                              date: e.date,
                              montant: e.montant,
                              detail:
                                  '${e.litres.toStringAsFixed(1)} L × ${e.prixParLitre.toStringAsFixed(2)} MAD/L',
                              badge: '${e.kilometrage.toStringAsFixed(0)} km',
                              documentPath: e.documentPath,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _FactureSection(
                    titre: 'Réparations',
                    icon: Icons.build_rounded,
                    color: Colors.red.shade500,
                    total: totalR,
                    count: v.reparations.length,
                    rows: v.reparations
                        .map((e) => _FactureRow(
                              date: e.date,
                              montant: e.montant,
                              detail: e.description.isNotEmpty
                                  ? e.description
                                  : '—',
                              badge: e.piecesChangees.isNotEmpty
                                  ? e.piecesChangees.join(', ')
                                  : null,
                              documentPath: e.documentPath,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Carte total avec mini-stats ───────────────────────────────────────────────
class _TotalCard extends StatelessWidget {
  final double totalGlobal;
  final double totalVidanges;
  final double totalPleins;
  final double totalReparations;
  const _TotalCard({
    required this.totalGlobal,
    required this.totalVidanges,
    required this.totalPleins,
    required this.totalReparations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF000966), Color(0xFF000966)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total principal
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Total dépenses',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Text(
                  '${totalGlobal.toStringAsFixed(2)} MAD',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Mini-stats par type
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                _MiniStat(
                    label: 'Vidanges',
                    amount: totalVidanges,
                    icon: Icons.oil_barrel_rounded,
                    color: Colors.orange.shade300),
                _Divider(),
                _MiniStat(
                    label: 'Gasoil',
                    amount: totalPleins,
                    icon: Icons.local_gas_station_rounded,
                    color: Colors.teal.shade200),
                _Divider(),
                _MiniStat(
                    label: 'Réparations',
                    amount: totalReparations,
                    icon: Icons.build_rounded,
                    color: Colors.red.shade200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  const _MiniStat(
      {required this.label,
      required this.amount,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 3),
          Text('${amount.toStringAsFixed(0)} MAD',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65), fontSize: 10)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 32,
        color: Colors.white.withValues(alpha: 0.2),
      );
}

// ── Section factures (dépliable) ─────────────────────────────────────────────
class _FactureSection extends StatefulWidget {
  final String titre;
  final IconData icon;
  final Color color;
  final double total;
  final int count;
  final List<_FactureRow> rows;
  const _FactureSection({
    required this.titre,
    required this.icon,
    required this.color,
    required this.total,
    required this.count,
    required this.rows,
  });

  @override
  State<_FactureSection> createState() => _FactureSectionState();
}

class _FactureSectionState extends State<_FactureSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // En-tête section
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: c, width: 3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon, color: c, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.titre,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(
                            '${widget.count} entrée${widget.count > 1 ? 's' : ''}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.total.toStringAsFixed(2)} MAD',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: c),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Lignes
            if (_expanded) ...[
              if (widget.rows.isNotEmpty)
                ...widget.rows.map(
                    (row) => _FactureRowTile(row: row, color: widget.color))
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Aucune entrée',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Données d'une ligne ───────────────────────────────────────────────────────
class _FactureRow {
  final DateTime date;
  final double montant;
  final String detail;
  final String? badge;
  final String? documentPath;
  const _FactureRow({
    required this.date,
    required this.montant,
    required this.detail,
    this.badge,
    this.documentPath,
  });
}

// ── Ligne facture ────────────────────────────────────────────────────────────
class _FactureRowTile extends StatelessWidget {
  final _FactureRow row;
  final Color color;
  const _FactureRowTile({required this.row, required this.color});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  bool get _isImage {
    if (row.documentPath == null) return false;
    final ext = row.documentPath!.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
  }

  bool get _isPdf {
    if (row.documentPath == null) return false;
    return row.documentPath!.toLowerCase().endsWith('.pdf');
  }

  String get _fileName {
    if (row.documentPath == null) return '';
    return row.documentPath!.replaceAll('\\', '/').split('/').last;
  }

  Future<void> _download(BuildContext context) async {
    final src = row.documentPath;
    if (src == null) return;
    try {
      final downloadsDir = await getDownloadsDirectory();
      final dir = downloadsDir ?? await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/$_fileName');
      await File(src).copy(dest.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Enregistré : ${dest.path}'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Ouvrir',
            textColor: Colors.white,
            onPressed: () async {
              final uri = Uri.file(dest.path);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _openPreview(BuildContext context) async {
    if (_isPdf) {
      final uri = Uri.file(row.documentPath!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le PDF')),
        );
      }
      return;
    }
    if (!_isImage) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(
                File(row.documentPath!),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                ),
              ),
            ),
            // Fermer
            Positioned(
              top: 10,
              right: 10,
              child: _PreviewBtn(
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            // Télécharger
            Positioned(
              top: 10,
              left: 10,
              child: _PreviewBtn(
                icon: Icons.download_rounded,
                onTap: () => _download(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne principale : date | détail | montant
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_fmt(row.date),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 10),
                // Détail + badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.detail,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      if (row.badge != null && row.badge!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(row.badge!,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500]),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Montant
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${row.montant.toStringAsFixed(2)} MAD',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
              ],
            ),
          ),

          // Barre document (si présent)
          if (row.documentPath != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  // Miniature ou icône
                  GestureDetector(
                    onTap: () => _openPreview(context),
                    child: _isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(row.documentPath!),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _fileIcon(Icons.broken_image, Colors.grey),
                            ),
                          )
                        : _fileIcon(
                            _isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.insert_drive_file_rounded,
                            _isPdf ? Colors.red.shade400 : Colors.blueGrey,
                          ),
                  ),
                  const SizedBox(width: 10),
                  // Nom du fichier
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_fileName,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                        Text(
                          _isImage
                              ? 'Image — appuyer pour agrandir'
                              : _isPdf
                                  ? 'PDF — appuyer pour ouvrir'
                                  : 'Document',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  // Bouton ouvrir
                  _ActionBtn(
                    icon: _isImage
                        ? Icons.zoom_in_rounded
                        : Icons.open_in_new_rounded,
                    color: _kIndigo,
                    tooltip: _isImage ? 'Aperçu' : 'Ouvrir',
                    onTap: () => _openPreview(context),
                  ),
                  const SizedBox(width: 6),
                  // Bouton télécharger
                  _ActionBtn(
                    icon: Icons.download_rounded,
                    color: Colors.green.shade700,
                    tooltip: 'Télécharger',
                    onTap: () => _download(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _fileIcon(IconData icon, Color c) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: c, size: 20),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
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
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

class _PreviewBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PreviewBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets utilitaires
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: Colors.grey[400]),
          ),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Magasin — placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceholderFactureList extends StatelessWidget {
  final _FactureCategorie categorie;
  final double padding;
  final VoidCallback onBack;
  const _PlaceholderFactureList(
      {required this.categorie, required this.padding, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          title: 'Factures — ${categorie.label}',
          icon: categorie.icon,
          onBack: onBack,
        ),
        Expanded(
          child: _EmptyState(
            icon: categorie.icon,
            message: 'Bientôt disponible',
          ),
        ),
      ],
    );
  }
}
