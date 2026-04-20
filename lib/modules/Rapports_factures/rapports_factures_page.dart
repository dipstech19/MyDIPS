import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/responsive.dart';
import '../logistique/logistique_service.dart';
import '../logistique/vehicule_model.dart';

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
        Container(
          color: const Color(0xFF1565C0),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Rapports'),
              Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Factures'),
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
// Rapports (vide pour l'instant)
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
          Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text('Rapports',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text('Bientôt disponible', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Factures — deux catégories : Logistique & Magasin
// ─────────────────────────────────────────────────────────────────────────────
enum _FactureCategorie { logistique, magasin }

extension _FactureCategorieExt on _FactureCategorie {
  String get label => this == _FactureCategorie.logistique ? 'Logistique' : 'Magasin';
  IconData get icon =>
      this == _FactureCategorie.logistique ? Icons.local_shipping : Icons.inventory_2;
  Color get color => this == _FactureCategorie.logistique ? Colors.indigo : Colors.teal;
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

// ── Category picker ──────────────────────────────────────────────────────────
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
              style: TextStyle(fontSize: mobile ? 16 : 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Sélectionnez une catégorie',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (ctx, constraints) {
            final cards = _FactureCategorie.values
                .map((cat) => _CategoryCard(categorie: cat, onTap: () => onSelect(cat)))
                .toList();
            if (constraints.maxWidth < 480) {
              return Column(
                children: cards
                    .map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c))
                    .toList(),
              );
            }
            return Row(children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(categorie.icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(categorie.label,
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text('Factures ${categorie.label.toLowerCase()}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logistique — liste des véhicules puis détail factures
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

// ── Liste des véhicules ───────────────────────────────────────────────────────
class _VehiculeListView extends StatelessWidget {
  final double padding;
  final VoidCallback onBack;
  final void Function(Vehicule) onSelect;
  const _VehiculeListView(
      {required this.padding, required this.onBack, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Column(
      children: [
        // Sub-header
        Container(
          color: Colors.indigo.withValues(alpha: 0.07),
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.indigo,
                onPressed: onBack,
                tooltip: 'Retour',
              ),
              const SizedBox(width: 6),
              const Icon(Icons.local_shipping, color: Colors.indigo, size: 18),
              const SizedBox(width: 8),
              Text(
                'Factures — Logistique',
                style: TextStyle(
                    fontSize: mobile ? 15 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo),
              ),
            ],
          ),
        ),

        // Liste
        Expanded(
          child: StreamBuilder<List<Vehicule>>(
            stream: LogistiqueService.instance.streamVehicules(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final vehicules = snap.data ?? [];
              if (vehicules.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_shipping, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text('Aucun véhicule',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500])),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.all(padding),
                itemCount: vehicules.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _VehiculeCard(vehicule: vehicules[i], onTap: () => onSelect(vehicules[i])),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping, color: Colors.indigo, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicule.matricule,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${vehicule.marque} ${vehicule.modele}'.trim(),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.indigo, size: 18),
          ],
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
    final mobile = isMobile(context);
    final id = vehicule.id!;
    return Column(
      children: [
        // Sub-header
        Container(
          color: Colors.indigo.withValues(alpha: 0.07),
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: Colors.indigo,
                onPressed: onBack,
                tooltip: 'Retour',
              ),
              const SizedBox(width: 6),
              const Icon(Icons.receipt_long, color: Colors.indigo, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${vehicule.matricule} — ${vehicule.marque} ${vehicule.modele}'.trim(),
                  style: TextStyle(
                      fontSize: mobile ? 14 : 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Sections factures
        Expanded(
          child: StreamBuilder<Vehicule>(
            stream: LogistiqueService.instance.streamVehiculeComplet(id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final v = snap.data ?? vehicule;
              final totalVidanges = v.vidanges.fold(0.0, (s, e) => s + e.montant);
              final totalPleins = v.pleins.fold(0.0, (s, e) => s + e.montant);
              final totalReparations = v.reparations.fold(0.0, (s, e) => s + e.montant);
              final totalGlobal = totalVidanges + totalPleins + totalReparations;

              return ListView(
                padding: EdgeInsets.all(padding),
                children: [
                  // Carte total
                  _TotalCard(total: totalGlobal),
                  const SizedBox(height: 14),

                  // Vidanges
                  _FactureSection(
                    titre: 'Vidanges',
                    icon: Icons.oil_barrel,
                    color: Colors.orange,
                    total: totalVidanges,
                    count: v.vidanges.length,
                    rows: v.vidanges.map((e) => _FactureRow(
                      date: e.date,
                      montant: e.montant,
                      detail: '${e.kilometrage.toStringAsFixed(0)} km',
                      badge: [
                        if (e.filtreHuile) 'Huile',
                        if (e.filtreAir) 'Air',
                        if (e.filtreGasoil) 'Gasoil',
                      ].join(' · '),
                      documentPath: e.documentPath,
                    )).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Pleins gasoil
                  _FactureSection(
                    titre: 'Pleins Gasoil',
                    icon: Icons.local_gas_station,
                    color: Colors.teal,
                    total: totalPleins,
                    count: v.pleins.length,
                    rows: v.pleins.map((e) => _FactureRow(
                      date: e.date,
                      montant: e.montant,
                      detail: '${e.litres.toStringAsFixed(1)} L × ${e.prixParLitre.toStringAsFixed(2)} MAD/L',
                      badge: '${e.kilometrage.toStringAsFixed(0)} km',
                      documentPath: e.documentPath,
                    )).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Réparations
                  _FactureSection(
                    titre: 'Réparations',
                    icon: Icons.build,
                    color: Colors.red.shade400,
                    total: totalReparations,
                    count: v.reparations.length,
                    rows: v.reparations.map((e) => _FactureRow(
                      date: e.date,
                      montant: e.montant,
                      detail: e.description.isNotEmpty ? e.description : '—',
                      badge: e.piecesChangees.isNotEmpty
                          ? e.piecesChangees.join(', ')
                          : null,
                      documentPath: e.documentPath,
                    )).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  const _TotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text('Total dépenses',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          const Spacer(),
          Text(
            '${total.toStringAsFixed(2)} MAD',
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header de section (cliquable)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.titre,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('${widget.count} entrée${widget.count > 1 ? 's' : ''}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  Text(
                    '${widget.total.toStringAsFixed(2)} MAD',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.color),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Rows
          if (_expanded && widget.rows.isNotEmpty) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            ...widget.rows.map((row) => _FactureRowTile(row: row, color: widget.color)),
          ],
          if (_expanded && widget.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('Aucune entrée',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ),
        ],
      ),
    );
  }
}

class _FactureRow {
  final DateTime date;
  final double montant;
  final String detail;
  final String? badge;
  final String? documentPath;
  const _FactureRow(
      {required this.date,
      required this.montant,
      required this.detail,
      this.badge,
      this.documentPath});
}

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

  Future<void> _openPreview(BuildContext context) async {
    if (_isPdf) {
      final uri = Uri.file(row.documentPath!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le fichier PDF')),
        );
      }
      return;
    }
    if (!_isImage) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
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
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 78,
            child: Text(_fmt(row.date),
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ),
          const SizedBox(width: 8),
          // Détail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.detail,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                if (row.badge != null && row.badge!.isNotEmpty)
                  Text(row.badge!,
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Miniature document
          if (row.documentPath != null) ...[
            GestureDetector(
              onTap: () async => _openPreview(context),
              child: _isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(row.documentPath!),
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _docIcon(Icons.broken_image, Colors.grey),
                      ),
                    )
                  : _docIcon(
                      _isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                      _isPdf ? Colors.red.shade400 : Colors.blueGrey,
                    ),
            ),
            const SizedBox(width: 8),
          ],
          // Montant
          Text(
            row.montant.toStringAsFixed(2),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
          Text(' MAD', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _docIcon(IconData icon, Color c) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: c, size: 18),
      );
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
    final mobile = isMobile(context);
    final color = categorie.color;
    return Column(
      children: [
        Container(
          color: color.withValues(alpha: 0.07),
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: color,
                onPressed: onBack,
                tooltip: 'Retour',
              ),
              const SizedBox(width: 6),
              Icon(categorie.icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                'Factures — ${categorie.label}',
                style: TextStyle(
                    fontSize: mobile ? 15 : 16,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(categorie.icon, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text('Factures ${categorie.label}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500])),
                const SizedBox(height: 4),
                Text('Bientôt disponible',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
