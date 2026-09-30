import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'PharmaGest'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de Bord'**
  String get dashboard;

  /// No description provided for @stock.
  ///
  /// In fr, this message translates to:
  /// **'Stock'**
  String get stock;

  /// No description provided for @pos.
  ///
  /// In fr, this message translates to:
  /// **'Point de Vente'**
  String get pos;

  /// No description provided for @salesHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get salesHistory;

  /// No description provided for @suppliers.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseurs'**
  String get suppliers;

  /// No description provided for @users.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get users;

  /// No description provided for @reports.
  ///
  /// In fr, this message translates to:
  /// **'Rapports'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get logout;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loading;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement...'**
  String get saving;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get search;

  /// No description provided for @actions.
  ///
  /// In fr, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @status.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get status;

  /// No description provided for @date.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @price.
  ///
  /// In fr, this message translates to:
  /// **'Prix'**
  String get price;

  /// No description provided for @quantity.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get quantity;

  /// No description provided for @total.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In fr, this message translates to:
  /// **'Sous-total'**
  String get subtotal;

  /// No description provided for @name.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get name;

  /// No description provided for @description.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @code.
  ///
  /// In fr, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @phone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get phone;

  /// No description provided for @address.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get address;

  /// No description provided for @yes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get no;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @errorPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get errorPrefix;

  /// No description provided for @success.
  ///
  /// In fr, this message translates to:
  /// **'Succès'**
  String get success;

  /// No description provided for @error.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get error;

  /// No description provided for @warning.
  ///
  /// In fr, this message translates to:
  /// **'Attention'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In fr, this message translates to:
  /// **'Information'**
  String get info;

  /// No description provided for @dashboardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de Bord'**
  String get dashboardTitle;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble de votre pharmacie'**
  String get dashboardSubtitle;

  /// No description provided for @revenue.
  ///
  /// In fr, this message translates to:
  /// **'Chiffre d\'Affaires'**
  String get revenue;

  /// No description provided for @sales.
  ///
  /// In fr, this message translates to:
  /// **'Ventes'**
  String get sales;

  /// No description provided for @products.
  ///
  /// In fr, this message translates to:
  /// **'Produits'**
  String get products;

  /// No description provided for @lowStockItems.
  ///
  /// In fr, this message translates to:
  /// **'Articles en Stock Faible'**
  String get lowStockItems;

  /// No description provided for @expiringProducts.
  ///
  /// In fr, this message translates to:
  /// **'Produits Expirant Bientôt'**
  String get expiringProducts;

  /// No description provided for @recentSales.
  ///
  /// In fr, this message translates to:
  /// **'Ventes Récentes'**
  String get recentSales;

  /// No description provided for @topProducts.
  ///
  /// In fr, this message translates to:
  /// **'Produits les Plus Vendus'**
  String get topProducts;

  /// No description provided for @stockManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion du Stock'**
  String get stockManagement;

  /// No description provided for @stockSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérez vos médicaments et inventaire'**
  String get stockSubtitle;

  /// No description provided for @addMedicine.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un médicament'**
  String get addMedicine;

  /// No description provided for @editMedicine.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le médicament'**
  String get editMedicine;

  /// No description provided for @packaging.
  ///
  /// In fr, this message translates to:
  /// **'Conditionnement'**
  String get packaging;

  /// No description provided for @form.
  ///
  /// In fr, this message translates to:
  /// **'Forme'**
  String get form;

  /// No description provided for @expiryDate.
  ///
  /// In fr, this message translates to:
  /// **'Date d\'expiration'**
  String get expiryDate;

  /// No description provided for @details.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get details;

  /// No description provided for @lowStock.
  ///
  /// In fr, this message translates to:
  /// **'Stock Faible'**
  String get lowStock;

  /// No description provided for @expired.
  ///
  /// In fr, this message translates to:
  /// **'Expiré'**
  String get expired;

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @noMedicinesFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun médicament trouvé'**
  String get noMedicinesFound;

  /// No description provided for @loadingMedicines.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des médicaments...'**
  String get loadingMedicines;

  /// No description provided for @errorLoadingMedicines.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les médicaments'**
  String get errorLoadingMedicines;

  /// No description provided for @buyPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix d\'achat (Boîte)'**
  String get buyPrice;

  /// No description provided for @sellPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix de vente (Boîte)'**
  String get sellPrice;

  /// No description provided for @initialQuantity.
  ///
  /// In fr, this message translates to:
  /// **'Quantité initiale (Cartons)'**
  String get initialQuantity;

  /// No description provided for @nameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Nom requis'**
  String get nameRequired;

  /// No description provided for @priceRequired.
  ///
  /// In fr, this message translates to:
  /// **'Prix requis'**
  String get priceRequired;

  /// No description provided for @quantityRequired.
  ///
  /// In fr, this message translates to:
  /// **'Quantité requise'**
  String get quantityRequired;

  /// No description provided for @create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get create;

  /// No description provided for @update.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour'**
  String get update;

  /// No description provided for @deleteError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la suppression'**
  String get deleteError;

  /// No description provided for @confirmDelete.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir supprimer'**
  String get confirmDelete;

  /// No description provided for @posTitle.
  ///
  /// In fr, this message translates to:
  /// **'Point de Vente'**
  String get posTitle;

  /// No description provided for @posSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Effectuez des ventes rapidement'**
  String get posSubtitle;

  /// No description provided for @cart.
  ///
  /// In fr, this message translates to:
  /// **'Panier'**
  String get cart;

  /// No description provided for @emptyCart.
  ///
  /// In fr, this message translates to:
  /// **'Panier vide'**
  String get emptyCart;

  /// No description provided for @clearCart.
  ///
  /// In fr, this message translates to:
  /// **'Vider'**
  String get clearCart;

  /// No description provided for @searchMedicine.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un médicament (nom ou code)...'**
  String get searchMedicine;

  /// No description provided for @cartIsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Le panier est vide'**
  String get cartIsEmpty;

  /// No description provided for @customerInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations Client'**
  String get customerInfo;

  /// No description provided for @firstName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get lastName;

  /// No description provided for @checkout.
  ///
  /// In fr, this message translates to:
  /// **'Payer'**
  String get checkout;

  /// No description provided for @payment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get payment;

  /// No description provided for @cash.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get cash;

  /// No description provided for @mobileMoney.
  ///
  /// In fr, this message translates to:
  /// **'Mobile Money'**
  String get mobileMoney;

  /// No description provided for @creditCard.
  ///
  /// In fr, this message translates to:
  /// **'Carte Bancaire'**
  String get creditCard;

  /// No description provided for @unitPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix Unitaire'**
  String get unitPrice;

  /// No description provided for @discount.
  ///
  /// In fr, this message translates to:
  /// **'Remise'**
  String get discount;

  /// No description provided for @stockLevel.
  ///
  /// In fr, this message translates to:
  /// **'Stock'**
  String get stockLevel;

  /// No description provided for @noProducts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun produit trouvé'**
  String get noProducts;

  /// No description provided for @salesHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique des Ventes'**
  String get salesHistoryTitle;

  /// No description provided for @salesHistorySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Consultez toutes vos ventes'**
  String get salesHistorySubtitle;

  /// No description provided for @filters.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get filters;

  /// No description provided for @startDate.
  ///
  /// In fr, this message translates to:
  /// **'Date début'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In fr, this message translates to:
  /// **'Date fin'**
  String get endDate;

  /// No description provided for @minAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant min'**
  String get minAmount;

  /// No description provided for @maxAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant max'**
  String get maxAmount;

  /// No description provided for @unlimited.
  ///
  /// In fr, this message translates to:
  /// **'Illimité'**
  String get unlimited;

  /// No description provided for @resetFilters.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser les filtres'**
  String get resetFilters;

  /// No description provided for @medicines.
  ///
  /// In fr, this message translates to:
  /// **'Médicaments'**
  String get medicines;

  /// No description provided for @statusLabel.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get statusLabel;

  /// No description provided for @cancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get cancelled;

  /// No description provided for @completed.
  ///
  /// In fr, this message translates to:
  /// **'Complété'**
  String get completed;

  /// No description provided for @downloadInvoice.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger la facture'**
  String get downloadInvoice;

  /// No description provided for @cancelSale.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la vente'**
  String get cancelSale;

  /// No description provided for @confirmCancelSale.
  ///
  /// In fr, this message translates to:
  /// **'Êtes-vous sûr de vouloir annuler cette vente ? Le stock sera remis à jour.'**
  String get confirmCancelSale;

  /// No description provided for @errorCancelling.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'annulation'**
  String get errorCancelling;

  /// No description provided for @errorDownloadingInvoice.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du téléchargement de la facture'**
  String get errorDownloadingInvoice;

  /// No description provided for @errorLoadingSalesHistory.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger l\'historique des ventes'**
  String get errorLoadingSalesHistory;

  /// No description provided for @noSales.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vente trouvée'**
  String get noSales;

  /// No description provided for @totalSalesDisplayed.
  ///
  /// In fr, this message translates to:
  /// **'Total des ventes affichées'**
  String get totalSalesDisplayed;

  /// No description provided for @salesTotal.
  ///
  /// In fr, this message translates to:
  /// **'ventes au total'**
  String get salesTotal;

  /// No description provided for @currentPage.
  ///
  /// In fr, this message translates to:
  /// **'Page actuelle'**
  String get currentPage;

  /// No description provided for @suppliersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fournisseurs'**
  String get suppliersTitle;

  /// No description provided for @suppliersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérez vos fournisseurs'**
  String get suppliersSubtitle;

  /// No description provided for @addSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un fournisseur'**
  String get addSupplier;

  /// No description provided for @editSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le fournisseur'**
  String get editSupplier;

  /// No description provided for @contact.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @noSuppliers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fournisseur trouvé'**
  String get noSuppliers;

  /// No description provided for @errorLoadingSuppliers.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les fournisseurs'**
  String get errorLoadingSuppliers;

  /// No description provided for @confirmDeleteSupplier.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment supprimer'**
  String get confirmDeleteSupplier;

  /// No description provided for @contactPerson.
  ///
  /// In fr, this message translates to:
  /// **'Personne de contact'**
  String get contactPerson;

  /// No description provided for @fullAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse complète du fournisseur...'**
  String get fullAddress;

  /// No description provided for @userManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des Utilisateurs'**
  String get userManagement;

  /// No description provided for @usersCount.
  ///
  /// In fr, this message translates to:
  /// **'utilisateur(s)'**
  String get usersCount;

  /// No description provided for @newUser.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel Utilisateur'**
  String get newUser;

  /// No description provided for @searchByUsername.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom d\'utilisateur...'**
  String get searchByUsername;

  /// No description provided for @all.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get all;

  /// No description provided for @active.
  ///
  /// In fr, this message translates to:
  /// **'Actifs'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In fr, this message translates to:
  /// **'Inactifs'**
  String get inactive;

  /// No description provided for @role.
  ///
  /// In fr, this message translates to:
  /// **'Rôle'**
  String get role;

  /// No description provided for @createdOn.
  ///
  /// In fr, this message translates to:
  /// **'Créé le'**
  String get createdOn;

  /// No description provided for @administrator.
  ///
  /// In fr, this message translates to:
  /// **'Administrateur'**
  String get administrator;

  /// No description provided for @pharmacist.
  ///
  /// In fr, this message translates to:
  /// **'Pharmacien'**
  String get pharmacist;

  /// No description provided for @viewStats.
  ///
  /// In fr, this message translates to:
  /// **'Voir les statistiques'**
  String get viewStats;

  /// No description provided for @deactivate.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver'**
  String get deactivate;

  /// No description provided for @activate.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get activate;

  /// No description provided for @noUsersFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur trouvé'**
  String get noUsersFound;

  /// No description provided for @errorLoadingUsers.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement des utilisateurs'**
  String get errorLoadingUsers;

  /// No description provided for @user.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get user;

  /// No description provided for @username.
  ///
  /// In fr, this message translates to:
  /// **'Nom d\'utilisateur'**
  String get username;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get password;

  /// No description provided for @newPassword.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get newPassword;

  /// No description provided for @changePassword.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get changePassword;

  /// No description provided for @reportsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez les rapports de gestion en Excel ou PDF'**
  String get reportsSubtitle;

  /// No description provided for @formatPDF.
  ///
  /// In fr, this message translates to:
  /// **'Format PDF'**
  String get formatPDF;

  /// No description provided for @stockReport.
  ///
  /// In fr, this message translates to:
  /// **'Rapport de Stock'**
  String get stockReport;

  /// No description provided for @salesReport.
  ///
  /// In fr, this message translates to:
  /// **'Rapport des Ventes'**
  String get salesReport;

  /// No description provided for @financialReport.
  ///
  /// In fr, this message translates to:
  /// **'Rapport Financier'**
  String get financialReport;

  /// No description provided for @stockReportDesc.
  ///
  /// In fr, this message translates to:
  /// **'Liste complète de tous les médicaments en stock'**
  String get stockReportDesc;

  /// No description provided for @salesReportDesc.
  ///
  /// In fr, this message translates to:
  /// **'Historique détaillé des ventes avec filtres de période'**
  String get salesReportDesc;

  /// No description provided for @financialReportDesc.
  ///
  /// In fr, this message translates to:
  /// **'Analyse financière : revenus, bénéfices, tendances'**
  String get financialReportDesc;

  /// No description provided for @downloadPDF.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger PDF'**
  String get downloadPDF;

  /// No description provided for @downloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement...'**
  String get downloading;

  /// No description provided for @information.
  ///
  /// In fr, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @reportInfo.
  ///
  /// In fr, this message translates to:
  /// **'Les rapports de ventes et financiers peuvent être filtrés par période. Laissez les champs vides pour télécharger toutes les données disponibles.'**
  String get reportInfo;

  /// No description provided for @settingsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Configurez votre application'**
  String get settingsSubtitle;

  /// No description provided for @general.
  ///
  /// In fr, this message translates to:
  /// **'Général'**
  String get general;

  /// No description provided for @administration.
  ///
  /// In fr, this message translates to:
  /// **'Administration'**
  String get administration;

  /// No description provided for @pharmacyIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité de la Pharmacie'**
  String get pharmacyIdentity;

  /// No description provided for @pharmacyName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la Pharmacie'**
  String get pharmacyName;

  /// No description provided for @salesConfig.
  ///
  /// In fr, this message translates to:
  /// **'Configuration des Ventes'**
  String get salesConfig;

  /// No description provided for @currency.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get currency;

  /// No description provided for @logoPath.
  ///
  /// In fr, this message translates to:
  /// **'Logo (URL ou chemin local)'**
  String get logoPath;

  /// No description provided for @logoHelp.
  ///
  /// In fr, this message translates to:
  /// **'Placez votre image dans le dossier public et entrez le chemin (ex: /logo.png)'**
  String get logoHelp;

  /// No description provided for @settingsUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres mis à jour avec succès'**
  String get settingsUpdated;

  /// No description provided for @errorUpdating.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la mise à jour'**
  String get errorUpdating;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @french.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get french;

  /// No description provided for @english.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @darkMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode Sombre'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode Clair'**
  String get lightMode;

  /// No description provided for @login.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get login;

  /// No description provided for @loginSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à votre compte'**
  String get loginSubtitle;

  /// No description provided for @loginButton.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get loginButton;

  /// No description provided for @loggingIn.
  ///
  /// In fr, this message translates to:
  /// **'Connexion...'**
  String get loggingIn;

  /// No description provided for @invalidCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Identifiants invalides'**
  String get invalidCredentials;

  /// No description provided for @loginError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de connexion'**
  String get loginError;

  /// No description provided for @loadingError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de chargement'**
  String get loadingError;

  /// No description provided for @tryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get tryAgain;

  /// No description provided for @noDataAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée disponible'**
  String get noDataAvailable;

  /// No description provided for @selectLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner la langue'**
  String get selectLanguage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
