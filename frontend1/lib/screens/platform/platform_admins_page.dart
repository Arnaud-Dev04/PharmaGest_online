import 'package:flutter/material.dart';
import 'package:frontend1/screens/admin/tabs/platform_admins_tab.dart';

class PlatformAdminsPage extends StatelessWidget {
  const PlatformAdminsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administrateurs de la Plateforme',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Gestion des comptes ayant un acces global a l\'administration de PharmaGest',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 16),
          Expanded(child: PlatformAdminsTab()),
        ],
      ),
    );
  }
}
