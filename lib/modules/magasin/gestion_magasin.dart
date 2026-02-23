import 'package:flutter/material.dart';

// ─── Modèle Produit ───────────────────────────────────────────────────────────

class Produit {
  final String id;
  String nom;
  String reference;
  String categorie;
  double prixAchat;
  int quantiteStock;

  Produit({
    required this.id,
    required this.nom,
    required this.reference,
    required this.categorie,
    required this.prixAchat,
    required this.quantiteStock,
  });
}

// ─── Page Principale ──────────────────────────────────────────────────────────

class GestionMagasin extends StatefulWidget {
  const GestionMagasin({super.key});

  @override
  State<GestionMagasin> createState() => _GestionMagasinState();
}

class _GestionMagasinState extends State<GestionMagasin> {
  static const Color kBlue = Color(0xFF328EEE);
  static const Color kBlueDark = Color(0xFF1A6FCA);
  static const Color kBlueLight = Color(0xFFE8F3FD);
  static const Color kBlueMid = Color(0xFFB3D6F9);

  // ── Données fictives ──
  final List<Produit> _allProduits = [
    Produit(id: '1', nom: 'Laptop Dell XPS 15', reference: 'REF-001', categorie: 'Informatique', prixAchat: 1200.00, quantiteStock: 8),
    Produit(id: '2', nom: 'Souris Logitech MX', reference: 'REF-002', categorie: 'Périphériques', prixAchat: 45.00, quantiteStock: 35),
    Produit(id: '3', nom: 'Clavier Mécanique', reference: 'REF-003', categorie: 'Périphériques', prixAchat: 90.00, quantiteStock: 20),
    Produit(id: '4', nom: 'Écran Samsung 27"', reference: 'REF-004', categorie: 'Écrans', prixAchat: 320.00, quantiteStock: 5),
    Produit(id: '5', nom: 'Chaise de Bureau', reference: 'REF-005', categorie: 'Mobilier', prixAchat: 250.00, quantiteStock: 12),
    Produit(id: '6', nom: 'Câble HDMI 2m', reference: 'REF-006', categorie: 'Accessoires', prixAchat: 8.50, quantiteStock: 60),
    Produit(id: '7', nom: 'SSD 1TB Samsung', reference: 'REF-007', categorie: 'Stockage', prixAchat: 95.00, quantiteStock: 0),
  ];

  List<Produit> _filtered = [];
  String _searchQuery = '';
  String _selectedCategorie = 'Toutes';
  String _sortBy = 'nom';
  bool _sortAsc = true;

  final _searchCtrl = TextEditingController();

  List<String> get _categories {
    final cats = _allProduits.map((p) => p.categorie).toSet().toList();
    cats.sort();
    return ['Toutes', ...cats];
  }

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filtered = _allProduits.where((p) {
        final matchSearch = _searchQuery.isEmpty ||
            p.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.reference.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchCat = _selectedCategorie == 'Toutes' || p.categorie == _selectedCategorie;
        return matchSearch && matchCat;
      }).toList();

      _filtered.sort((a, b) {
        int cmp;
        switch (_sortBy) {
          case 'reference':
            cmp = a.reference.compareTo(b.reference);
            break;
          case 'prixAchat':
            cmp = a.prixAchat.compareTo(b.prixAchat);
            break;
          case 'quantiteStock':
            cmp = a.quantiteStock.compareTo(b.quantiteStock);
            break;
          default:
            cmp = a.nom.compareTo(b.nom);
        }
        return _sortAsc ? cmp : -cmp;
      });
    });
  }

  // ── Dialog Ajouter / Modifier ──
  void _openDialog({Produit? produit}) {
    final isEdit = produit != null;
    final nomCtrl = TextEditingController(text: produit?.nom ?? '');
    final refCtrl = TextEditingController(text: produit?.reference ?? '');
    final catCtrl = TextEditingController(text: produit?.categorie ?? '');
    final prixCtrl = TextEditingController(text: produit != null ? produit.prixAchat.toString() : '');
    final qteCtrl = TextEditingController(text: produit != null ? produit.quantiteStock.toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          decoration: const BoxDecoration(
            color: kBlue,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Row(
            children: [
              Icon(isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Modifier le produit' : 'Ajouter un produit',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            _dialogField(controller: nomCtrl, label: 'Nom du produit', icon: Icons.inventory_2_outlined),
            _dialogField(controller: refCtrl, label: 'Référence', icon: Icons.qr_code_rounded),
            _dialogField(controller: catCtrl, label: 'Catégorie', icon: Icons.category_outlined),
            _dialogField(
              controller: prixCtrl,
              label: "Prix d'achat (MAD)",
              icon: Icons.attach_money_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            _dialogField(
              controller: qteCtrl,
              label: 'Quantité en stock',
              icon: Icons.warehouse_outlined,
              keyboardType: TextInputType.number,
            ),
          ]),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            icon: Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
            label: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
            onPressed: () {
              final nom = nomCtrl.text.trim();
              final ref = refCtrl.text.trim();
              final cat = catCtrl.text.trim();
              final prix = double.tryParse(prixCtrl.text.trim()) ?? 0;
              final qte = int.tryParse(qteCtrl.text.trim()) ?? 0;

              if (nom.isEmpty || ref.isEmpty || cat.isEmpty) return;

              setState(() {
                if (isEdit) {
                  produit!.nom = nom;
                  produit.reference = ref;
                  produit.categorie = cat;
                  produit.prixAchat = prix;
                  produit.quantiteStock = qte;
                } else {
                  _allProduits.add(Produit(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    nom: nom,
                    reference: ref,
                    categorie: cat,
                    prixAchat: prix,
                    quantiteStock: qte,
                  ));
                }
              });
              _applyFilters();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: kBlue, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kBlue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  void _confirmDelete(Produit p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer "${p.nom}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _allProduits.removeWhere((x) => x.id == p.id));
              _applyFilters();
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Header stats ──
  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: kBlue.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: kBlueMid.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kBlueLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: kBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A2B4A))),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalProduits = _allProduits.length;
    final ruptures = _allProduits.where((p) => p.quantiteStock == 0).length;
    final valeurTotale = _allProduits.fold<double>(0, (s, p) => s + p.prixAchat * p.quantiteStock);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FE),
      body: Column(
        children: [
          // ── Top Bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.store_rounded, color: kBlue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Gestion du Magasin',
                  style: TextStyle(color: kBlue, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Ajouter produit', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () => _openDialog(),
                ),
              ],
            ),
          ),

          // ── Stats ──
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
            child: Row(
              children: [
                _statCard('Total produits', '$totalProduits', Icons.inventory_2_rounded),
                const SizedBox(width: 16),
                _statCard('Ruptures de stock', '$ruptures', Icons.warning_amber_rounded),
                const SizedBox(width: 16),
                _statCard('Valeur totale', '${valeurTotale.toStringAsFixed(2)} MAD', Icons.account_balance_wallet_rounded),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Filtres ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                // Recherche
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom ou référence…',
                        prefixIcon: const Icon(Icons.search_rounded, color: kBlue, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _searchQuery = '';
                            _applyFilters();
                          },
                        )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: kBlueMid)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: kBlue, width: 2)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: kBlueMid.withOpacity(0.6))),
                      ),
                      onChanged: (v) {
                        _searchQuery = v;
                        _applyFilters();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Filtre catégorie
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBlueMid.withOpacity(0.6)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategorie,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kBlue),
                        isExpanded: true,
                        hint: const Text('Catégorie'),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                            .toList(),
                        onChanged: (v) {
                          _selectedCategorie = v!;
                          _applyFilters();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Tri
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBlueMid.withOpacity(0.6)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        icon: const Icon(Icons.sort_rounded, color: kBlue),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'nom', child: Text('Trier : Nom', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'reference', child: Text('Trier : Référence', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'prixAchat', child: Text("Trier : Prix d'achat", style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'quantiteStock', child: Text('Trier : Stock', style: TextStyle(fontSize: 14))),
                        ],
                        onChanged: (v) {
                          _sortBy = v!;
                          _applyFilters();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Ordre asc/desc
                Tooltip(
                  message: _sortAsc ? 'Croissant' : 'Décroissant',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() {
                      _sortAsc = !_sortAsc;
                      _applyFilters();
                    }),
                    child: Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: kBlueLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBlueMid.withOpacity(0.6)),
                      ),
                      child: Icon(
                        _sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: kBlue,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Tableau ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: kBlue.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      // En-tête tableau
                      Container(
                        color: kBlueLight,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            _headerCell('Nom du produit', flex: 3, sortKey: 'nom'),
                            _headerCell('Référence', flex: 2, sortKey: 'reference'),
                            _headerCell('Catégorie', flex: 2),
                            _headerCell("Prix d'achat", flex: 2, sortKey: 'prixAchat'),
                            _headerCell('Stock', flex: 1, sortKey: 'quantiteStock'),
                            const Expanded(flex: 1, child: SizedBox()),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFDEECFB)),
                      // Lignes
                      Expanded(
                        child: _filtered.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 54, color: kBlueMid),
                              const SizedBox(height: 12),
                              Text('Aucun produit trouvé', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                            ],
                          ),
                        )
                            : ListView.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F4F8)),
                          itemBuilder: (ctx, i) {
                            final p = _filtered[i];
                            final isRupture = p.quantiteStock == 0;
                            final isLow = p.quantiteStock > 0 && p.quantiteStock <= 5;
                            return _ProductRow(
                              produit: p,
                              isRupture: isRupture,
                              isLow: isLow,
                              onEdit: () => _openDialog(produit: p),
                              onDelete: () => _confirmDelete(p),
                            );
                          },
                        ),
                      ),
                      // Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: kBlueLight.withOpacity(0.6),
                          border: const Border(top: BorderSide(color: Color(0xFFDEECFB))),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${_filtered.length} produit${_filtered.length > 1 ? 's' : ''} affiché${_filtered.length > 1 ? 's' : ''} sur $totalProduits',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {int flex = 1, String? sortKey}) {
    final isActive = sortKey != null && _sortBy == sortKey;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: sortKey != null
            ? () {
          if (_sortBy == sortKey) {
            _sortAsc = !_sortAsc;
          } else {
            _sortBy = sortKey;
            _sortAsc = true;
          }
          _applyFilters();
        }
            : null,
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isActive ? const Color(0xFF328EEE) : const Color(0xFF4A6080),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 14, color: const Color(0xFF328EEE)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Widget Ligne Produit ─────────────────────────────────────────────────────

class _ProductRow extends StatefulWidget {
  final Produit produit;
  final bool isRupture;
  final bool isLow;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductRow({
    required this.produit,
    required this.isRupture,
    required this.isLow,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered ? const Color(0xFFF0F7FF) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            // Nom
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF328EEE)),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(p.nom,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF1A2B4A)),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            // Référence
            Expanded(
              flex: 2,
              child: Text(p.reference,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7A8D), fontFamily: 'monospace')),
            ),
            // Catégorie (badge)
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F3FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    p.categorie,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF328EEE), fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            // Prix
            Expanded(
              flex: 2,
              child: Text(
                '${p.prixAchat.toStringAsFixed(2)} MAD',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A2B4A)),
              ),
            ),
            // Stock (badge coloré)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isRupture
                      ? const Color(0xFFFFEEEE)
                      : widget.isLow
                      ? const Color(0xFFFFF8E1)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${p.quantiteStock}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isRupture
                        ? Colors.red
                        : widget.isLow
                        ? Colors.orange[700]
                        : Colors.green[700],
                  ),
                ),
              ),
            ),
            // Actions
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: 'Modifier',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: widget.onEdit,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F3FD),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF328EEE)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Supprimer',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                      ),
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