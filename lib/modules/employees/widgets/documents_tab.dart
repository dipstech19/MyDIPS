import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/document_model.dart';
import '../models/employe_model.dart';

class DocumentsTab extends StatefulWidget {
  final Employe employe;
  const DocumentsTab({super.key, required this.employe});

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<DocumentsTab> {
  late List<Document> _docs;
  DocCategorie? _filterCat;

  @override
  void initState() {
    super.initState();
    _docs = List.from(widget.employe.documents);
  }

  List<Document> get _filtered => _filterCat == null
      ? _docs
      : _docs.where((d) => d.categorie == _filterCat).toList();

  Future<void> _downloadDocument(Document doc) async {
    final raw = doc.path.trim();
    if (raw.isEmpty || raw == '/simulated/path') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun lien de téléchargement disponible pour ce document.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lien invalide: ${doc.nom}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
        ),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'ouvrir le document: ${doc.nom}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  void _addDoc(DocCategorie categorie) {
    final now = DateTime.now();
    setState(() {
      _docs.add(Document(
        id: now.millisecondsSinceEpoch.toString(),
        nom: 'Document_${categorie.label}_${now.day}_${now.month}.pdf',
        path: '/simulated/path',
        categorie: categorie,
        dateAjout: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
        extension: 'pdf',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ===== ADD BUTTON EN HAUT + FILTER =====
        Row(
          children: [
            // Add button avec dropdown categories
            PopupMenuButton<DocCategorie>(
              onSelected: _addDoc,
              itemBuilder: (_) => DocCategorie.values.map((c) =>
                  PopupMenuItem(
                    value: c,
                    child: Row(children: [
                      Icon(c.icon, color: c.color, size: 18),
                      const SizedBox(width: 8),
                      Text(c.label),
                    ]),
                  ),
              ).toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Ajouter document',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Filter chips
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(null, 'Tous', Colors.grey),
                    ...DocCategorie.values.map((c) => _filterChip(c, c.label, c.color)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ===== STATS =====
        if (_docs.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DocCategorie.values.map((c) {
                final count = _docs.where((d) => d.categorie == c).length;
                if (count == 0) return const SizedBox();
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon, color: c.color, size: 14),
                      const SizedBox(width: 4),
                      Text('$count ${c.label}',
                          style: TextStyle(color: c.color, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ===== LISTE DOCUMENTS =====
        Expanded(
          child: _filtered.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 52, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('Aucun document',
                    style: TextStyle(color: Colors.grey[400], fontSize: 15)),
                const SizedBox(height: 4),
                Text('Cliquez sur "Ajouter document" pour commencer',
                    style: TextStyle(color: Colors.grey[300], fontSize: 12)),
              ],
            ),
          )
              : ListView.separated(
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final doc = _filtered[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: doc.categorie.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        doc.extension == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                        color: doc.categorie.color, size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc.nom,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: doc.categorie.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(doc.categorie.label,
                                  style: TextStyle(color: doc.categorie.color, fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                            Text('Ajouté le ${doc.dateAjout}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          ]),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, size: 18),
                      color: Colors.blue,
                      tooltip: 'Télécharger',
                      onPressed: () => _downloadDocument(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.red,
                      tooltip: 'Supprimer',
                      onPressed: () => setState(() => _docs.remove(doc)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(DocCategorie? cat, String label, Color color) {
    final isSelected = _filterCat == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _filterCat = cat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          ),
          child: Text(label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      ),
    );
  }
}