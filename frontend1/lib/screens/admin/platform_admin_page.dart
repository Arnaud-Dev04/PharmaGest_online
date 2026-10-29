import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend1/core/theme.dart';
import 'package:frontend1/models/pharmacy.dart';
import 'package:frontend1/providers/auth_provider.dart';
import 'package:frontend1/providers/language_provider.dart';
import 'package:frontend1/services/platform_admin_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend1/screens/admin/tabs/platform_admins_tab.dart';
import 'package:frontend1/screens/admin/tabs/platform_licenses_tab.dart';

class PlatformAdminPage extends StatefulWidget {
  const PlatformAdminPage({super.key});

  @override
  State<PlatformAdminPage> createState() => _PlatformAdminPageState();
}

class _PlatformAdminPageState extends State<PlatformAdminPage> {
  final PlatformAdminService _service = PlatformAdminService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _loadGeneration = 0;
  List<Pharmacy> _pharmacies = [];
  int _currentPage = 1;
  int _totalPharmacies = 0;
  int _totalPages = 0;
  static const int _pageSize = 25;
  PlatformMetrics? _metrics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final generation = ++_loadGeneration;
    final requestedPage = page ?? _currentPage;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final loadMetrics = _metrics == null;
      final futures = <Future<Object>>[
        _service.getPharmacies(
          page: requestedPage,
          pageSize: _pageSize,
          search: _searchController.text,
        ),
        if (loadMetrics) _service.getMetrics(),
      ];
      final results = await Future.wait<Object>(futures);
      if (!mounted) return;
      if (generation != _loadGeneration) return;
      final pharmacyPage = results[0] as PharmacyPage;
      setState(() {
        _pharmacies = pharmacyPage.items;
        _currentPage = pharmacyPage.page;
        _totalPharmacies = pharmacyPage.total;
        _totalPages = pharmacyPage.totalPages;
        if (loadMetrics) _metrics = results[1] as PlatformMetrics;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showPharmacyForm({Pharmacy? pharmacy}) async {
    final language = context.read<LanguageProvider>();
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: pharmacy?.name ?? '');
    final code = TextEditingController(text: pharmacy?.code ?? '');
    final address = TextEditingController(text: pharmacy?.address ?? '');
    final city = TextEditingController(text: pharmacy?.city ?? '');
    final country = TextEditingController(text: pharmacy?.country ?? '');
    final phone = TextEditingController(text: pharmacy?.phone ?? '');
    final email = TextEditingController(text: pharmacy?.email ?? '');
    final username = TextEditingController();
    final password = TextEditingController();
    var plan = pharmacy?.plan ?? 'basic';
    var maxUsers = pharmacy?.maxUsers ?? 3;
    if (plan == 'basic' && maxUsers > 3) maxUsers = 3;
    if (plan == 'pro' && maxUsers > 10) maxUsers = 10;
    if (plan == 'enterprise' && maxUsers > 1000) maxUsers = 1000;
    var isSaving = false;

    List<int> optionsForPlan(String selectedPlan, int selectedMaxUsers) {
      final options = switch (selectedPlan) {
        'basic' => [1, 2, 3],
        'pro' => List<int>.generate(10, (index) => index + 1),
        _ => [3, 5, 10, 25, 50, 1000],
      };
      if (!options.contains(selectedMaxUsers)) options.add(selectedMaxUsers);
      options.sort();
      return options;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            language.translate(
              pharmacy == null ? 'platformNewPharmacy' : 'platformEditPharmacy',
            ),
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _formField(
                      name,
                      language.translate('name'),
                      required: true,
                    ),
                    if (pharmacy == null)
                      _formField(
                        code,
                        language.translate('platformCode'),
                        required: true,
                        helper: 'A-Z, 0-9, _',
                      ),
                    _formField(address, language.translate('address')),
                    _formField(city, language.translate('platformCity')),
                    _formField(country, language.translate('platformCountry')),
                    _formField(phone, language.translate('phone')),
                    _formField(email, language.translate('email')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: plan,
                      decoration: InputDecoration(
                        labelText: language.translate('platformPlan'),
                        border: const OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'basic', child: Text('Basic')),
                        DropdownMenuItem(value: 'pro', child: Text('Pro')),
                        DropdownMenuItem(
                          value: 'enterprise',
                          child: Text('Enterprise'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            plan = value;
                            final maxAllowed = switch (plan) {
                              'basic' => 3,
                              'pro' => 10,
                              _ => 1000,
                            };
                            if (maxUsers > maxAllowed) maxUsers = maxAllowed;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: maxUsers,
                      decoration: InputDecoration(
                        labelText: language.translate('platformMaxUsers'),
                        border: const OutlineInputBorder(),
                      ),
                      items: optionsForPlan(plan, maxUsers)
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value == 1000
                                    ? language.translate('unlimited')
                                    : '$value',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => maxUsers = value);
                        }
                      },
                    ),
                    if (pharmacy == null) ...[
                      const Divider(height: 28),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          language.translate('platformFirstAdmin'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _formField(
                        username,
                        language.translate('username'),
                        required: true,
                      ),
                      _formField(
                        password,
                        language.translate('password'),
                        required: true,
                        obscure: true,
                        helper: language.translate(
                          'platformInitialPasswordHint',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: Text(language.translate('cancel')),
            ),
            FilledButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        if (pharmacy == null) {
                          await _service.onboardPharmacy({
                            'name': name.text.trim(),
                            'code': code.text.trim(),
                            'address': _nullable(address.text),
                            'city': _nullable(city.text),
                            'country': _nullable(country.text),
                            'phone': _nullable(phone.text),
                            'email': _nullable(email.text),
                            'plan': plan,
                            'max_users': maxUsers,
                            'admin_username': username.text.trim(),
                            'admin_password': password.text,
                          });
                        } else {
                          await _service.updatePharmacy(pharmacy.id, {
                            'name': name.text.trim(),
                            'address': _nullable(address.text),
                            'city': _nullable(city.text),
                            'country': _nullable(country.text),
                            'phone': _nullable(phone.text),
                            'email': _nullable(email.text),
                            'plan': plan,
                            'max_users': maxUsers,
                          });
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(language.translate('platformSaved')),
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${language.translate('errorPrefix')}: $error',
                            ),
                          ),
                        );
                      }
                    },
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(language.translate(isSaving ? 'saving' : 'save')),
            ),
          ],
        ),
      ),
    );

    for (final controller in [
      name,
      code,
      address,
      city,
      country,
      phone,
      email,
      username,
      password,
    ]) {
      controller.dispose();
    }
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _showAccountManagement() async {
    final language = context.read<LanguageProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUsername = authProvider.user?.username;
    final messenger = ScaffoldMessenger.of(context);
    final accounts = await _service.getAccounts();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(language.translate('platformAccounts')),
            content: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final created = await _showCreatePlatformAccount();
                        if (!created || !dialogContext.mounted) return;
                        final refreshed = await _service.getAccounts();
                        setDialogState(() {
                          accounts
                            ..clear()
                            ..addAll(refreshed);
                        });
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(language.translate('platformCreateAccount')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: accounts.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final isPlatform = account.role == 'platform_admin';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(account.username),
                          subtitle: Text(
                            '${language.translate(isPlatform ? 'platformAdminRole' : 'pharmacyAdminRole')}'
                            '${account.pharmacyName == null ? '' : ' · ${account.pharmacyName}'}'
                            '${account.mustChangePassword ? ' · ${language.translate('passwordChangeRequired')}' : ''}',
                          ),
                          trailing: IconButton(
                            tooltip: language.translate(
                              'platformResetPassword',
                            ),
                            icon: const Icon(Icons.key_outlined),
                            onPressed: () async {
                              final reset = await _showResetAdminPassword(
                                account,
                              );
                              if (!reset || !dialogContext.mounted) return;
                              final refreshed = await _service.getAccounts();
                              setDialogState(() {
                                accounts
                                  ..clear()
                                  ..addAll(refreshed);
                              });
                              if (account.username == currentUsername) {
                                await authProvider.logout();
                                if (!mounted) return;
                                Navigator.of(
                                  this.context,
                                ).pushNamedAndRemoveUntil(
                                  '/login',
                                  (_) => false,
                                );
                                return;
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    language.translate('platformPasswordReset'),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(language.translate('close')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _showCreatePlatformAccount() async {
    final language = context.read<LanguageProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final username = TextEditingController();
    final password = TextEditingController();
    var saving = false;
    var created = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(language.translate('platformCreateAccount')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: username,
                  decoration: InputDecoration(
                    labelText: language.translate('username'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().length < 3
                      ? language.translate('platformUsernameHint')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: language.translate('password'),
                    helperText: language.translate(
                      'platformInitialPasswordHint',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.length < 8
                      ? language.translate('platformInitialPasswordHint')
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(language.translate('cancel')),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        await _service.createPlatformAccount(
                          username: username.text.trim(),
                          password: password.text,
                        );
                        created = true;
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => saving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '${language.translate('errorPrefix')}: $error',
                            ),
                          ),
                        );
                      }
                    },
              child: Text(language.translate(saving ? 'saving' : 'save')),
            ),
          ],
        ),
      ),
    );
    username.dispose();
    password.dispose();
    return created;
  }

  Future<bool> _showResetAdminPassword(PlatformAccount account) async {
    final language = context.read<LanguageProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final formKey = GlobalKey<FormState>();
    final password = TextEditingController();
    final currentPassword = TextEditingController();
    final currentUsername = context.read<AuthProvider>().user?.username;
    final isSelf = account.username == currentUsername;
    var saving = false;
    var updated = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            '${language.translate('platformResetPassword')}: ${account.username}',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelf) ...[
                  TextFormField(
                    controller: currentPassword,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: language.translate('currentPassword'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? language.translate('currentPasswordRequired')
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: language.translate('platformTemporaryPassword'),
                    helperText: language.translate(
                      'platformTemporaryPasswordHint',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.length < 8
                      ? language.translate('platformTemporaryPasswordHint')
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(language.translate('cancel')),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        await _service.resetAdminPassword(
                          userId: account.id,
                          temporaryPassword: password.text,
                          currentPassword: isSelf ? currentPassword.text : null,
                        );
                        updated = true;
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => saving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '${language.translate('errorPrefix')}: $error',
                            ),
                          ),
                        );
                      }
                    },
              child: Text(language.translate(saving ? 'saving' : 'save')),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    currentPassword.dispose();
    return updated;
  }

  Widget _formField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool obscure = false,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null
            : null,
      ),
    );
  }

  Future<void> _toggleStatus(Pharmacy pharmacy, bool value) async {
    try {
      await _service.setPharmacyStatus(pharmacy.id, value);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().translate('platformActionFailed'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final isPlatformAdmin = context.select<AuthProvider, bool>(
      (auth) => auth.user?.role == 'platform_admin',
    );
    if (!isPlatformAdmin) {
      return Center(child: Text(language.translate('platformAccessDenied')));
    }
    return DefaultTabController(
      length: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryColor,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.storefront_outlined),
                      text: 'Pharmacies',
                    ),
                    Tab(
                      icon: Icon(Icons.manage_accounts_outlined),
                      text: 'Admins Plateforme',
                    ),
                    Tab(
                      icon: Icon(Icons.vpn_key_outlined),
                      text: 'Gestion Licences',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPharmaciesTab(context, language, isCompact),
                    const PlatformAdminsTab(),
                    const PlatformLicensesTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPharmaciesTab(
    BuildContext context,
    LanguageProvider language,
    bool isCompact,
  ) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          language.translate('platformTitle'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(language.translate('platformSubtitle')),
      ],
    );
    final refreshButton = IconButton(
      tooltip: language.translate('refresh'),
      onPressed: _isLoading ? null : _load,
      icon: const Icon(Icons.refresh),
    );
    final createButton = FilledButton.icon(
      onPressed: () => _showPharmacyForm(),
      icon: const Icon(Icons.add_business_outlined),
      label: Text(language.translate('platformNewPharmacy')),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCompact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: title),
                  refreshButton,
                ],
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [createButton],
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: title),
              refreshButton,
              const SizedBox(width: 8),
              createButton,
            ],
          ),
        const SizedBox(height: 20),
        if (_metrics != null) _buildMetrics(language, isCompact),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (_) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(
              const Duration(milliseconds: 300),
              () => _load(page: 1),
            );
          },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: language.translate('platformSearch'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildPharmacyList(language, isCompact)),
      ],
    );
  }

  Widget _buildMetrics(LanguageProvider language, bool compact) {
    final metrics = _metrics!;
    final values = [
      (
        label: language.translate('platformPharmacies'),
        value: '${metrics.pharmacyCount}',
        icon: Icons.storefront_outlined,
        color: AppTheme.primaryColor,
      ),
      (
        label: language.translate('platformActive'),
        value: '${metrics.activePharmacyCount}',
        icon: Icons.check_circle_outline,
        color: AppTheme.successColor,
      ),
      (
        label: language.translate('platformUsers'),
        value: '${metrics.userCount}',
        icon: Icons.people_outline,
        color: AppTheme.warningColor,
      ),
      (
        label: language.translate('platformSales'),
        value: '${metrics.saleCount}',
        icon: Icons.point_of_sale_outlined,
        color: AppTheme.dangerColor,
      ),
      (
        label: language.translate('platformRevenue'),
        value: NumberFormat.decimalPattern().format(metrics.totalRevenue),
        icon: Icons.payments_outlined,
        color: AppTheme.successColor,
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: values.map((entry) {
        final width = compact ? 155.0 : 205.0;
        return SizedBox(
          width: width,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(entry.icon, color: entry.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPharmacyList(LanguageProvider language, bool compact) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(language.translate('retry')),
            ),
          ],
        ),
      );
    }
    final pharmacies = _pharmacies;
    if (pharmacies.isEmpty) {
      return Center(child: Text(language.translate('platformNoPharmacies')));
    }
    final list = compact
        ? ListView.separated(
            itemCount: pharmacies.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _buildPharmacyCard(pharmacies[index], language),
          )
        : Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: DataTable(
                columns: [
                  DataColumn(label: Text(language.translate('name'))),
                  DataColumn(label: Text(language.translate('platformCode'))),
                  DataColumn(label: Text(language.translate('platformCity'))),
                  DataColumn(label: Text(language.translate('platformPlan'))),
                  DataColumn(
                    label: Text(language.translate('platformMaxUsers')),
                  ),
                  DataColumn(label: Text(language.translate('status'))),
                  DataColumn(label: Text(language.translate('actions'))),
                ],
                rows: pharmacies.map((pharmacy) {
                  return DataRow(
                    cells: [
                      DataCell(Text(pharmacy.name)),
                      DataCell(Text(pharmacy.code)),
                      DataCell(Text(pharmacy.city ?? '—')),
                      DataCell(Text(pharmacy.plan.toUpperCase())),
                      DataCell(Text('${pharmacy.maxUsers}')),
                      DataCell(
                        Switch.adaptive(
                          value: pharmacy.isActive,
                          onChanged: (value) => _toggleStatus(pharmacy, value),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: language.translate('edit'),
                          onPressed: () =>
                              _showPharmacyForm(pharmacy: pharmacy),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
    return Column(
      children: [
        Expanded(child: list),
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: language.translate('platformPreviousPage'),
                  onPressed: _isLoading || _currentPage <= 1
                      ? null
                      : () => _load(page: _currentPage - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  language
                      .translate('platformPageStatus')
                      .replaceAll('{page}', '$_currentPage')
                      .replaceAll('{total}', '$_totalPages'),
                ),
                IconButton(
                  tooltip: language.translate('platformNextPage'),
                  onPressed: _isLoading || _currentPage >= _totalPages
                      ? null
                      : () => _load(page: _currentPage + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 8),
                Text('($_totalPharmacies)'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPharmacyCard(Pharmacy pharmacy, LanguageProvider language) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pharmacy.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: language.translate('edit'),
                  onPressed: () => _showPharmacyForm(pharmacy: pharmacy),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            Text('${pharmacy.code} · ${pharmacy.city ?? '—'}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(label: Text(pharmacy.plan.toUpperCase())),
                const SizedBox(width: 8),
                Text(
                  '${pharmacy.maxUsers} ${language.translate('platformUsers').toLowerCase()}',
                ),
                const Spacer(),
                Switch.adaptive(
                  value: pharmacy.isActive,
                  onChanged: (value) => _toggleStatus(pharmacy, value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
