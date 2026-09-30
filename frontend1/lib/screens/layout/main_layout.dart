import 'package:frontend1/providers/license_provider.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/widgets/license/license_warning_modal.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:frontend1/core/constants.dart';
import 'package:frontend1/widgets/layout/app_header.dart';
import 'package:frontend1/widgets/layout/app_sidebar.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final bool noPadding;

  const MainLayout({super.key, required this.child, this.noPadding = false});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    return Consumer<LicenseProvider>(
      builder: (context, licenseProvider, _) {
        // Le super_admin n'est jamais bloqué par la licence
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final isSuperAdmin = auth.user?.role == 'super_admin';

        // Vérifier si on doit afficher la modal (uniquement pour admin et pharmaciens)
        final shouldShowModal =
            !isSuperAdmin &&
            licenseProvider.status != null &&
            (licenseProvider.status!.isExpired ||
                licenseProvider.status!.daysRemaining <= 5);

        // Afficher la modal une seule fois par session
        if (shouldShowModal && !licenseProvider.hasShownWarningThisSession) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              licenseProvider.markWarningAsShown();
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => LicenseWarningModal(
                  isExpired: licenseProvider.status!.isExpired,
                  daysRemaining: licenseProvider.status!.daysRemaining,
                  message: licenseProvider.status!.message,
                  onDismiss: () {
                    if (!licenseProvider.status!.isExpired) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              );
            }
          });
        }

        return Scaffold(
          drawer: context.isMobile ? const AppSidebar() : null,
          appBar: context.isMobile
              ? AppBar(title: const Text('PharmaGest'), elevation: 0)
              : null,
          body: Row(
            children: [
              if (context.isDesktop) const AppSidebar(),
              Expanded(
                child: Column(
                  children: [
                    const AppHeader(),
                    Expanded(
                      child: widget.noPadding
                          ? widget.child
                          : Padding(
                              padding: EdgeInsets.all(context.isMobile ? 16 : 24),
                              child: widget.child,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
