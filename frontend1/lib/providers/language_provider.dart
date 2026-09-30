import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider pour gérer la langue de l'application (FR/EN)
class LanguageProvider with ChangeNotifier {
  Locale _locale = const Locale('fr', 'FR');
  static const String _localeKey = 'app_locale';

  /// Traductions complètes FR/EN (enrichies depuis les fichiers .arb)
  static const Map<String, Map<String, String>> _translations = {
    'fr': {
      // Application
      'appTitle': 'PharmaGest',
      'dashboard': 'Tableau de bord',
      'stock': 'Stock',
      'pos': 'Point de Vente',
      'salesHistory': 'Historique',
      'suppliers': 'Contacts',
      'users': 'Utilisateurs',
      'reports': 'Rapports',
      'settings': 'Paramètres',
      'superAdmin': 'Super Admin',
      'logout': 'Déconnexion',

      // Common
      'loading': 'Chargement...',
      'save': 'Enregistrer',
      'saving': 'Enregistrement...',
      'cancel': 'Annuler',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'add': 'Ajouter',
      'search': 'Rechercher',
      'actions': 'Actions',
      'status': 'Statut',
      'date': 'Date',
      'price': 'Prix',
      'quantity': 'Quantité',
      'total': 'Total',
      'subtotal': 'Sous-total',
      'name': 'Nom',
      'description': 'Description',
      'code': 'Code',
      'email': 'Email',
      'phone': 'Téléphone',
      'address': 'Adresse',
      'yes': 'Oui',
      'no': 'Non',
      'close': 'Fermer',
      'confirm': 'Confirmer',
      'errorPrefix': 'Erreur',
      'success': 'Succès',
      'error': 'Erreur',
      'warning': 'Attention',
      'info': 'Information',

      // Dashboard
      'dashboardTitle': 'Tableau de Bord',
      'dashboardSubtitle': 'Vue d\'ensemble de votre pharmacie',
      'revenue': 'Chiffre d\'Affaires',
      'weeklySales': 'Ventes (7j)',
      'sales': 'Ventes',
      'products': 'Produits',
      'lowStockItems': 'Articles en Stock Faible',
      'expiringProducts': 'Produits Expirant Bientôt',
      'recentSales': 'Ventes Récentes',
      'topProducts': 'Produits les Plus Vendus',
      'totalSales': 'Total Ventes',
      'totalMedicines': 'Total Médicaments',
      'expiringSoon': 'Expirant Bientôt',
      'lowStock': 'Stock Faible',

      // Stock
      'stockManagement': 'Médicaments',
      'stockSubtitle': 'Gérez vos médicaments et inventaire',
      'addMedicine': 'Ajouter un médicament',
      'editMedicine': 'Modifier le médicament',
      'packaging': 'Conditionnement',
      'form': 'Forme',
      'expiryDate': 'Date d\'expiration',
      'details': 'Détails',
      'expired': 'Expiré',
      'ok': 'OK',
      'noMedicinesFound': 'Aucun médicament trouvé',
      'loadingMedicines': 'Chargement des médicaments...',
      'errorLoadingMedicines': 'Impossible de charger les médicaments',
      'buyPrice': 'Prix d\'achat (Boîte)',
      'sellPrice': 'Prix de vente (Boîte)',
      'initialQuantity': 'Quantité initiale (Cartons)',
      'nameRequired': 'Nom requis',
      'priceRequired': 'Prix requis',
      'quantityRequired': 'Quantité requise',
      'create': 'Créer',
      'update': 'Mettre à jour',
      'deleteError': 'Erreur lors de la suppression',
      'confirmDelete': 'Êtes-vous sûr de vouloir supprimer',

      // POS
      'posTitle': 'Point de Vente',
      'posSubtitle': 'Effectuez des ventes rapidement',
      'cart': 'Panier',
      'emptyCart': 'Panier vide',
      'clearCart': 'Vider',
      'searchMedicine': 'Rechercher un médicament (nom ou code)...',
      'cartIsEmpty': 'Le panier est vide',
      'customerInfo': 'Informations Client',
      'firstName': 'Prénom',
      'lastName': 'Nom',
      'checkout': 'Payer',
      'payment': 'Paiement',
      'cash': 'Espèces',
      'mobileMoney': 'Mobile Money',
      'creditCard': 'Carte Bancaire',
      'unitPrice': 'Prix Unitaire',
      'discount': 'Remise',
      'stockLevel': 'Stock',
      'noProducts': 'Aucun produit trouvé',
      'insurance': 'Assurance',
      'pay': 'Payer',
      'paymentMethod': 'Mode de paiement',
      'saleSuccess': 'Vente réussie !',
      'invoiceGenerated': 'Facture générée avec succès',
      'printInvoice': 'Imprimer la facture',
      'invoicePreview': 'Aperçu Facture',
      'nif': 'NIF',

      // Sales History
      'salesHistoryTitle': 'Historique des Ventes',
      'salesHistorySubtitle': 'Consultez toutes vos ventes',
      'filters': 'Filtres',
      'startDate': 'Date début',
      'endDate': 'Date fin',
      'minAmount': 'Montant min',
      'maxAmount': 'Montant max',
      'unlimited': 'Illimité',
      'resetFilters': 'Réinitialiser les filtres',
      'medicines': 'Médicaments',
      'statusLabel': 'Statut',
      'cancelled': 'Annulé',
      'completed': 'Complété',
      'downloadInvoice': 'Télécharger la facture',
      'cancelSale': 'Annuler la vente',
      'cancelledBy': 'Annulé par',
      'cancelledAt': 'Annulé le',
      'cancelledSaleDetails': 'Détails annulation',
      'confirmCancelSale':
          'Êtes-vous sûr de vouloir annuler cette vente ? Le stock sera remis à jour.',
      'errorCancelling': 'Erreur lors de l\'annulation',
      'errorDownloadingInvoice': 'Erreur lors du téléchargement de la facture',
      'errorLoadingSalesHistory':
          'Impossible de charger l\'historique des ventes',
      'noSales': 'Aucune vente trouvée',
      'totalSalesDisplayed': 'Total des ventes affichées',
      'salesTotal': 'ventes au total',
      'currentPage': 'Page actuelle',

      // Contacts (Ex-Suppliers)
      'suppliersTitle': 'Contacts',
      'suppliersSubtitle': 'Gérez vos contacts',
      'addSupplier': 'Ajouter un contact',
      'editSupplier': 'Modifier le contact',
      'contact': 'Contact',
      'noSuppliers': 'Aucun contact trouvé',
      'errorLoadingSuppliers': 'Impossible de charger les contacts',
      'confirmDeleteSupplier': 'Voulez-vous vraiment supprimer',
      'contactPerson': 'Personne de contact',
      'fullAddress': 'Adresse complète du contact...',

      // Users
      'userManagement': 'Gestion des Utilisateurs',
      'usersCount': 'utilisateur(s)',
      'newUser': 'Nouvel Utilisateur',
      'searchByUsername': 'Rechercher par nom d\'utilisateur...',
      'all': 'Tous',
      'active': 'Actifs',
      'inactive': 'Inactifs',
      'role': 'Rôle',
      'createdOn': 'Créé le',
      'administrator': 'Administrateur',
      'pharmacist': 'Pharmacien',
      'viewStats': 'Voir les statistiques',
      'deactivate': 'Désactiver',
      'activate': 'Activer',
      'noUsersFound': 'Aucun utilisateur trouvé',
      'errorLoadingUsers': 'Erreur de chargement des utilisateurs',
      'user': 'Utilisateur',
      'username': 'Nom d\'utilisateur',
      'password': 'Mot de passe',
      'newPassword': 'Nouveau mot de passe',
      'changePassword': 'Changer le mot de passe',

      // Reports
      'reportsSubtitle': 'Téléchargez les rapports de gestion en Excel ou PDF',
      'formatPDF': 'Format PDF',
      'stockReport': 'Rapport de Stock',
      'salesReport': 'Rapport des Ventes',
      'financialReport': 'Rapport Financier',
      'stockReportDesc': 'Liste complète de tous les médicaments en stock',
      'salesReportDesc':
          'Historique détaillé des ventes avec filtres de période',
      'financialReportDesc':
          'Analyse financière : revenus, bénéfices, tendances',
      'downloadPDF': 'Télécharger PDF',
      'downloading': 'Téléchargement...',
      'information': 'Information',
      'reportInfo':
          'Les rapports de ventes et financiers peuvent être filtrés par période. Laissez les champs vides pour télécharger toutes les données disponibles.',

      // Settings
      'settingsSubtitle': 'Configurez votre application',
      'general': 'Général',
      'administration': 'Administration',
      'pharmacyIdentity': 'Identité de la Pharmacie',
      'pharmacyName': 'Nom de la Pharmacie',
      'salesConfig': 'Configuration des Ventes',
      'currency': 'Devise',
      'logoPath': 'Logo (URL ou chemin local)',
      'logoHelp':
          'Placez votre image dans le dossier public et entrez le chemin (ex: /logo.png)',
      'settingsUpdated': 'Paramètres mis à jour avec succès',
      'errorUpdating': 'Erreur lors de la mise à jour',
      'language': 'Langue',
      'french': 'Français',
      'english': 'English',
      'darkMode': 'Mode Sombre',
      'lightMode': 'Mode Clair',

      // Auth
      'login': 'Connexion',
      'loginSubtitle': 'Entrez vos identifiants pour accéder à votre compte',
      'loginButton': 'Se connecter',
      'loggingIn': 'Connexion...',
      'invalidCredentials': 'Identifiants invalides',
      'loginError': 'Erreur de connexion',
      'adminMode': 'Mode Administrateur',
      'pharmacistMode': 'Mode Pharmacien',

      // Notifications
      'notifications': 'Notifications',
      'markAllAsRead': 'Tout marquer comme lu',

      // Days
      'days': 'jours',
      'monday': 'lundi',
      'tuesday': 'mardi',
      'wednesday': 'mercredi',
      'thursday': 'jeudi',
      'friday': 'vendredi',
      'saturday': 'samedi',
      'sunday': 'dimanche',

      // Months
      'january': 'janvier',
      'february': 'février',
      'march': 'mars',
      'april': 'avril',
      'may': 'mai',
      'june': 'juin',
      'july': 'juillet',
      'august': 'août',
      'september': 'septembre',
      'october': 'octobre',
      'november': 'novembre',
      'december': 'décembre',

      // Misc
      'loadingError': 'Erreur de chargement',
      'tryAgain': 'Réessayer',
      'noDataAvailable': 'Aucune donnée disponible',
      'selectLanguage': 'Sélectionner la langue',

      // Super Admin
      'accessDeniedSuperAdmin': 'Accès refusé: Réservé Super Admin',
      'errorLoadingLicense': 'Erreur chargement licence',
      'licenseUpdated': 'Licence mise à jour',
      'updateError': 'Erreur update',
      'softwareLicenseManagement': 'Gestion de la licence logicielle',
      'currentLicenseStatus': 'État actuel de la licence',
      'expiresOn': 'Expire le',
      'valid': 'VALIDE',
      'daysRemaining': 'jours restants',
      'newExpirationDate': 'Nouvelle date d\'expiration',
      'updateLicense': 'Mettre à jour la licence',

      // Reports Extras
      'generating': 'Génération',
      'fileSavedSuccess': 'Fichier enregistré avec succès',
      'open': 'Ouvrir',
      'downloadCancelled': 'Téléchargement annulé',
      'financial': 'Financier',
      'start': 'Début',
      'end': 'Fin',

      // User Stats
      'salesStats': 'Statistiques de vente',
      'top10Products': 'Top 10 Produits Vendus',
      'noSalesPeriod': 'Aucune vente sur cette période',
      'chooseDates': 'Choisir des dates',
      'noData': 'Pas de données',
      'clients': 'Clients',
      'avgCart': 'Panier Moyen',
      'salesEvolution': 'Évolution des Ventes',

      // Misc Users
      'searchByName': 'Rechercher par nom...',
      'confirmAction': 'Voulez-vous vraiment',

      // Danger Zone
      'dangerZone': 'Zone de Danger',
      'irreversibleActions': 'Ces actions sont irréversibles.',
      'selectDataToDelete': 'Sélectionnez les données à supprimer :',
      'clearSalesHistory': 'Vider l\'historique des ventes',
      'clearStock': 'Vider le stock (Tous les produits)',
      'clearUsers': 'Supprimer les utilisateurs (Sauf Super Admin)',
      'confirmDeleteButton': 'CONFIRMER LA SUPPRESSION',
      'dataResetSuccess': 'Données réinitialisées',
      'deleteIrreversibleConfirm': 'Suppression Irréversible',
      'deleteDataConfirm': 'Voulez-vous vraiment supprimer ces données ?',
    },
    'en': {
      // Application
      'appTitle': 'PharmaGest',
      'dashboard': 'Dashboard',
      'stock': 'Stock',
      'pos': 'Point of Sale',
      'salesHistory': 'History',
      'suppliers': 'Contacts',
      'users': 'Users',
      'reports': 'Reports',
      'settings': 'Settings',
      'superAdmin': 'Super Admin',
      'logout': 'Logout',

      // Common
      'loading': 'Loading...',
      'save': 'Save',
      'saving': 'Saving...',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'search': 'Search',
      'actions': 'Actions',
      'status': 'Status',
      'date': 'Date',
      'price': 'Price',
      'quantity': 'Quantity',
      'total': 'Total',
      'subtotal': 'Subtotal',
      'name': 'Name',
      'description': 'Description',
      'code': 'Code',
      'email': 'Email',
      'phone': 'Phone',
      'address': 'Address',
      'yes': 'Yes',
      'no': 'No',
      'close': 'Close',
      'confirm': 'Confirm',
      'errorPrefix': 'Error',
      'success': 'Success',
      'error': 'Error',
      'warning': 'Warning',
      'info': 'Information',

      // Dashboard
      'dashboardTitle': 'Dashboard',
      'dashboardSubtitle': 'Overview of your pharmacy',
      'revenue': 'Revenue',
      'weeklySales': 'Sales (7d)',
      'sales': 'Sales',
      'products': 'Products',
      'lowStockItems': 'Low Stock Items',
      'expiringProducts': 'Expiring Products Soon',
      'recentSales': 'Recent Sales',
      'topProducts': 'Top Selling Products',
      'totalSales': 'Total Sales',
      'totalMedicines': 'Total Medicines',
      'expiringSoon': 'Expiring Soon',
      'lowStock': 'Low Stock',

      // Stock
      'stockManagement': 'Stock Management',
      'stockSubtitle': 'Manage your medicines and inventory',
      'addMedicine': 'Add Medicine',
      'editMedicine': 'Edit Medicine',
      'packaging': 'Packaging',
      'form': 'Form',
      'expiryDate': 'Expiry Date',
      'details': 'Details',
      'expired': 'Expired',
      'ok': 'OK',
      'noMedicinesFound': 'No medicines found',
      'loadingMedicines': 'Loading medicines...',
      'errorLoadingMedicines': 'Unable to load medicines',
      'buyPrice': 'Purchase Price (Box)',
      'sellPrice': 'Selling Price (Box)',
      'initialQuantity': 'Initial Quantity (Cartons)',
      'nameRequired': 'Name required',
      'priceRequired': 'Price required',
      'quantityRequired': 'Quantity required',
      'create': 'Create',
      'update': 'Update',
      'deleteError': 'Error during deletion',
      'confirmDelete': 'Are you sure you want to delete',

      // POS
      'posTitle': 'Point of Sale',
      'posSubtitle': 'Process sales quickly',
      'cart': 'Cart',
      'emptyCart': 'Empty cart',
      'clearCart': 'Clear',
      'searchMedicine': 'Search for a medicine (name or code)...',
      'cartIsEmpty': 'Cart is empty',
      'customerInfo': 'Customer Information',
      'firstName': 'First Name',
      'lastName': 'Last Name',
      'checkout': 'Checkout',
      'payment': 'Payment',
      'cash': 'Cash',
      'mobileMoney': 'Mobile Money',
      'creditCard': 'Credit Card',
      'unitPrice': 'Unit Price',
      'discount': 'Discount',
      'stockLevel': 'Stock',
      'noProducts': 'No products found',
      'insurance': 'Insurance',
      'pay': 'Pay',
      'paymentMethod': 'Payment Method',
      'saleSuccess': 'Sale successful!',
      'invoiceGenerated': 'Invoice generated successfully',
      'printInvoice': 'Print invoice',
      'invoicePreview': 'Invoice Preview',
      'nif': 'TIN',

      // Sales History
      'salesHistoryTitle': 'Sales History',
      'salesHistorySubtitle': 'View all your sales',
      'filters': 'Filters',
      'startDate': 'Start date',
      'endDate': 'End date',
      'minAmount': 'Min amount',
      'maxAmount': 'Max amount',
      'unlimited': 'Unlimited',
      'resetFilters': 'Reset filters',
      'medicines': 'Medicines',
      'statusLabel': 'Status',
      'cancelled': 'Cancelled',
      'completed': 'Completed',
      'downloadInvoice': 'Download invoice',
      'cancelSale': 'Cancel sale',
      'cancelledBy': 'Cancelled by',
      'cancelledAt': 'Cancelled at',
      'cancelledSaleDetails': 'Cancellation details',
      'confirmCancelSale':
          'Are you sure you want to cancel this sale? Stock will be updated.',
      'errorCancelling': 'Error during cancellation',
      'errorDownloadingInvoice': 'Error downloading invoice',
      'errorLoadingSalesHistory': 'Unable to load sales history',
      'noSales': 'No sales found',
      'totalSalesDisplayed': 'Total displayed sales',
      'salesTotal': 'sales total',
      'currentPage': 'Current page',

      // Suppliers
      'suppliersTitle': 'Contacts',
      'suppliersSubtitle': 'Manage your suppliers',
      'addSupplier': 'Add Supplier',
      'editSupplier': 'Edit Supplier',
      'contact': 'Contact',
      'noSuppliers': 'No suppliers found',
      'errorLoadingSuppliers': 'Unable to load suppliers',
      'confirmDeleteSupplier': 'Do you really want to delete',
      'contactPerson': 'Contact Person',
      'fullAddress': 'Full supplier address...',

      // Users
      'userManagement': 'User Management',
      'usersCount': 'user(s)',
      'newUser': 'New User',
      'searchByUsername': 'Search by username...',
      'all': 'All',
      'active': 'Active',
      'inactive': 'Inactive',
      'role': 'Role',
      'createdOn': 'Created on',
      'administrator': 'Administrator',
      'pharmacist': 'Pharmacist',
      'viewStats': 'View statistics',
      'deactivate': 'Deactivate',
      'activate': 'Activate',
      'noUsersFound': 'No users found',
      'errorLoadingUsers': 'Error loading users',
      'user': 'User',
      'username': 'Username',
      'password': 'Password',
      'newPassword': 'New password',
      'changePassword': 'Change password',

      // Reports
      'reportsSubtitle': 'Download management reports in Excel or PDF',
      'formatPDF': 'PDF Format',
      'stockReport': 'Stock Report',
      'salesReport': 'Sales Report',
      'financialReport': 'Financial Report',
      'stockReportDesc': 'Complete list of all medicines in stock',
      'salesReportDesc': 'Detailed sales history with period filters',
      'financialReportDesc': 'Financial analysis: revenue, profits, trends',
      'downloadPDF': 'Download PDF',
      'downloading': 'Downloading...',
      'information': 'Information',
      'reportInfo':
          'Sales and financial reports can be filtered by period. Leave fields empty to download all available data.',

      // Settings
      'settingsSubtitle': 'Configure your application',
      'general': 'General',
      'administration': 'Administration',
      'pharmacyIdentity': 'Pharmacy Identity',
      'pharmacyName': 'Pharmacy Name',
      'salesConfig': 'Sales Configuration',
      'currency': 'Currency',
      'logoPath': 'Logo (URL or local path)',
      'logoHelp':
          'Place your image in the public folder and enter the path (e.g. /logo.png)',
      'settingsUpdated': 'Settings updated successfully',
      'errorUpdating': 'Error updating',
      'language': 'Language',
      'french': 'Français',
      'english': 'English',
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',

      // Auth
      'login': 'Login',
      'loginSubtitle': 'Sign in to your account',
      'loginButton': 'Sign in',
      'loggingIn': 'Signing in...',
      'invalidCredentials': 'Invalid credentials',
      'loginError': 'Login error',
      'adminMode': 'Administrator Mode',
      'pharmacistMode': 'Pharmacist Mode',

      // Notifications
      'notifications': 'Notifications',
      'markAllAsRead': 'Mark all as read',

      // Days
      'days': 'days',
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',

      // Months
      'january': 'January',
      'february': 'February',
      'march': 'March',
      'april': 'April',
      'may': 'May',
      'june': 'June',
      'july': 'July',
      'august': 'August',
      'september': 'September',
      'october': 'October',
      'november': 'November',
      'december': 'December',

      // Misc
      'loadingError': 'Loading error',
      'tryAgain': 'Try again',
      'noDataAvailable': 'No data available',
      'selectLanguage': 'Select language',

      // Super Admin
      'accessDeniedSuperAdmin': 'Access Denied: Super Admin Only',
      'errorLoadingLicense': 'Error loading license',
      'licenseUpdated': 'License updated',
      'updateError': 'Update error',
      'softwareLicenseManagement': 'Software License Management',
      'currentLicenseStatus': 'Current License Status',
      'expiresOn': 'Expires on',
      'valid': 'VALID',
      'daysRemaining': 'days remaining',
      'newExpirationDate': 'New Expiration Date',
      'updateLicense': 'Update License',

      // Reports Extras
      'generating': 'Generating',
      'fileSavedSuccess': 'File saved successfully',
      'open': 'Open',
      'downloadCancelled': 'Download cancelled',
      'financial': 'Financial',
      'start': 'Start',
      'end': 'End',

      // User Stats
      'salesStats': 'Sales Statistics',
      'top10Products': 'Top 10 Selling Products',
      'noSalesPeriod': 'No sales this period',
      'chooseDates': 'Choose dates',
      'noData': 'No data',
      'clients': 'Customers',
      'avgCart': 'Avg Cart',
      'salesEvolution': 'Sales Evolution',

      // Misc Users
      'searchByName': 'Search by name...',
      'confirmAction': 'Do you really want to',

      // Suppliers Extras
      'manageSuppliersDescription': 'Manage your suppliers',
      'orders': 'Orders',
      'confirmation': 'Confirmation',
      'supplierDeleted': 'Supplier deleted',
      'supplierAdded': 'Supplier added',
      'supplierUpdated': 'Supplier updated',
      'invalidEmail': 'Invalid email',
      'invalidPhone': 'Invalid phone',
      'fieldRequired': 'This field is required',

      // Danger Zone
      'dangerZone': 'Danger Zone',
      'irreversibleActions': 'These actions are irreversible.',
      'selectDataToDelete': 'Select data to delete:',
      'clearSalesHistory': 'Clear Sales History',
      'clearStock': 'Clear Stock (All products)',
      'clearUsers': 'Delete Users (Except Super Admin)',
      'confirmDeleteButton': 'CONFIRM DELETION',
      'dataResetSuccess': 'Data reset successfully',
      'deleteIrreversibleConfirm': 'Irreversible Deletion',
      'deleteDataConfirm': 'Do you really want to delete these data?',
    },
  };

  LanguageProvider() {
    _loadLocale();
  }

  /// Locale actuel
  Locale get locale => _locale;

  /// Code de langue actuel (fr ou en)
  String get languageCode => _locale.languageCode;

  /// Nom de la langue pour affichage
  String get languageName => languageCode == 'fr' ? 'Français' : 'English';

  /// Change la langue
  void setLanguage(String code) {
    final newLocale = code == 'en'
        ? const Locale('en', 'US')
        : const Locale('fr', 'FR');

    if (_locale != newLocale) {
      _locale = newLocale;
      _saveLocale();
      notifyListeners();
    }
  }

  /// Traduit une clé donnée
  String translate(String key) {
    return _translations[languageCode]?[key] ?? key;
  }

  /// Alias court pour translate
  String t(String key) => translate(key);

  /// Charge la langue sauvegardée
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_localeKey);

      if (savedLanguage != null) {
        _locale = savedLanguage == 'en'
            ? const Locale('en', 'US')
            : const Locale('fr', 'FR');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[LanguageProvider] Erreur lors du chargement de la langue: $e');
    }
  }

  /// Sauvegarde la langue
  Future<void> _saveLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, languageCode);
    } catch (e) {
      debugPrint('[LanguageProvider] Erreur lors de la sauvegarde de la langue: $e');
    }
  }
}
