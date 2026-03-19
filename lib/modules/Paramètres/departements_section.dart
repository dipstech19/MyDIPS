import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/responsive.dart';
import '../employees/departements_provider.dart';
import '../employees/data/departements_repository.dart';

const _kAccent = Color(0xFF328EEE);
const _kDark = Color(0xFF1A2340);
const _kBorder = Color(0xFFE2E8F0);

class DepartementsSection extends StatelessWidget {
  const DepartementsSection();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<DepartementsProvider>();
    if (prov.loading && prov.firebaseAvailable) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = prov.departements;
    return Column(
      children: [
        if (!prov.firebaseAvailable)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off, size: 22, color: Colors.orange.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Données en ligne indisponibles. Connectez Firebase (ex: Android) pour enregistrer et synchroniser.',
                    style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),
        if (prov.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prov.error!,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(pagePadding(context), 14, pagePadding(context), 12),
          child: isMobile(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Départements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                    Text('${list.length} département(s) — Gérés depuis Firestore', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        ),
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Ajouter un département', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        onPressed: () => _showDepartementDialog(context, prov, null),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Départements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kDark)),
                        Text('${list.length} département(s) — Gérés depuis Firestore', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                      ),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Ajouter un département', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      onPressed: () => _showDepartementDialog(context, prov, null),
                    ),
                  ],
                ),
        ),
        const Divider(height: 1, color: _kBorder),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.apartment_outlined, size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Aucun département. Ajoutez depuis le bouton ci‑dessus.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final d = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: _kAccent.withOpacity(0.12),
                        child: Icon(Icons.apartment, color: _kAccent, size: 20),
                      ),
                      title: Text(d.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showDepartementDialog(context, prov, d),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                            onPressed: () => _confirmDeleteDepartement(context, prov, d),
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
}

void _showDepartementDialog(BuildContext context, DepartementsProvider prov, Departement? existing) {
  final nomCtrl = TextEditingController(text: existing?.nom ?? '');
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(existing == null ? 'Nouveau département' : 'Modifier le département'),
      content: TextField(
        controller: nomCtrl,
        decoration: const InputDecoration(labelText: 'Nom du département', hintText: 'Ex: Production, RH, Logistique'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => navigator.pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () async {
            final nom = nomCtrl.text.trim();
            if (nom.isEmpty) {
              messenger.showSnackBar(const SnackBar(content: Text('Entrez un nom de département')));
              return;
            }
            if (!prov.firebaseAvailable) {
              messenger.showSnackBar(const SnackBar(
                content: Text('Données hors ligne. Connectez Firebase (ex: Android) pour enregistrer.'),
                backgroundColor: Colors.orange,
              ));
              if (dialogContext.mounted) navigator.pop();
              return;
            }
            try {
              if (existing == null) {
                await prov.addDepartement(Departement(id: '', nom: nom));
              } else {
                await prov.updateDepartement(Departement(id: existing.id, nom: nom));
              }
              if (dialogContext.mounted) navigator.pop();
              if (context.mounted) {
                messenger.showSnackBar(SnackBar(content: Text(existing == null ? 'Département « $nom » enregistré.' : 'Département mis à jour.')));
              }
            } catch (e) {
              if (context.mounted) {
                messenger.showSnackBar(SnackBar(
                  content: Text('Erreur: ${e.toString().replaceFirst(RegExp(r'^\[[\w-]+/\w+\]\s*'), '')}'),
                  backgroundColor: Colors.red,
                ));
              }
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}

void _confirmDeleteDepartement(BuildContext context, DepartementsProvider prov, Departement d) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Supprimer le département'),
      content: Text('Supprimer « ${d.nom} » ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await prov.deleteDepartement(d.id);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
}

