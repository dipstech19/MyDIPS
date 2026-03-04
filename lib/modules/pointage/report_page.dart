import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/locale/app_locale.dart';
import '../../core/utils/responsive.dart';
import '../../modules/employees/employees_provider.dart';
import 'pointage_data.dart';

/// صفحة منعزلة: إرسال تقرير أو ملاحظة (من القائمة الجانبية للسائق أو الأدمن)
class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _controller = TextEditingController();
  bool _sendToSuperAdmin = true;
  String? _selectedChefId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'report_write_first'))),
      );
      return;
    }
    final chefs = getChefsForReport(
        context.read<EmployeesProvider>().equipes,
        context.read<EmployeesProvider>().employes);
    final recipient = _sendToSuperAdmin
        ? tr(context, 'report_super_admin')
        : (chefs.where((c) => c.chefId == _selectedChefId).toList().isEmpty
            ? tr(context, 'report_specific_chef')
            : chefs.where((c) => c.chefId == _selectedChefId).first.chefName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tr(context, 'report_sent_to')} $recipient'),
        backgroundColor: Colors.green,
      ),
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final emp = context.watch<EmployeesProvider>();
    final chefs = getChefsForReport(emp.equipes, emp.employes);
    final isRtl = locale.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.all(pagePadding(context)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'report_page_title'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, 'report_content'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _controller,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: tr(context, 'report_content_hint'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(tr(context, 'report_send_to'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      RadioListTile<bool>(
                        title: Text(tr(context, 'report_super_admin')),
                        value: true,
                        groupValue: _sendToSuperAdmin,
                        onChanged: (v) => setState(() {
                          _sendToSuperAdmin = true;
                          _selectedChefId = chefs.isNotEmpty ? chefs.first.chefId : null;
                        }),
                      ),
                      RadioListTile<bool>(
                        title: Text(tr(context, 'report_specific_chef')),
                        value: false,
                        groupValue: _sendToSuperAdmin,
                        onChanged: (v) => setState(() {
                          _sendToSuperAdmin = false;
                          if (chefs.isNotEmpty) _selectedChefId = chefs.first.chefId;
                        }),
                      ),
                      if (!_sendToSuperAdmin && chefs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedChefId ?? chefs.first.chefId,
                          decoration: InputDecoration(
                            labelText: tr(context, 'report_choose_chef'),
                            border: const OutlineInputBorder(),
                          ),
                          items: chefs
                              .map((c) => DropdownMenuItem(value: c.chefId, child: Text(c.chefName)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedChefId = v),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _send,
                          icon: const Icon(Icons.send),
                          label: Text(tr(context, 'report_send')),
                        ),
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
