import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../distribution/distribution_pointage_page.dart';
import 'pointage_department_provider.dart';
import 'pointage_page.dart';

/// Page Pointage (directeur/admin) avec un sélecteur Dessalement/Distribution
/// en en-tête, sur le même modèle que le SegmentedButton de la page Shifts.
/// Un IndexedStack garde les deux pages en vie pour préserver leur état.
class PointageSectionSwitcher extends StatelessWidget {
  const PointageSectionSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final deptProv = context.watch<PointageDepartmentProvider>();
    final dept = deptProv.selected;
    final index = dept == PointageDepartmentProvider.distribution ? 1 : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: PointageDepartmentProvider.dessalement,
                label: Text('Dessalement'),
                icon: Icon(Icons.water_drop_outlined, size: 18),
              ),
              ButtonSegment(
                value: PointageDepartmentProvider.distribution,
                label: Text('Distribution'),
                icon: Icon(Icons.local_shipping_outlined, size: 18),
              ),
            ],
            selected: {dept},
            onSelectionChanged: (next) => deptProv.setSelected(next.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: index,
            children: const [
              PointagePage(),
              DistributionPointagePage(),
            ],
          ),
        ),
      ],
    );
  }
}
