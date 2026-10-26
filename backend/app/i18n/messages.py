"""
Centralized message strings for PharmaGest (French).
"""

class Msg:
    # Auth & Sessions
    AUTH_INVALID_CREDENTIALS = "Nom d'utilisateur ou mot de passe incorrect."
    AUTH_INACTIVE_ACCOUNT = "Votre compte est désactivé. Veuillez contacter l'administrateur."
    AUTH_EXPIRED_TOKEN = "Session expirée. Veuillez vous reconnecter."
    AUTH_INVALID_REFRESH = "Jeton de rafraîchissement invalide ou expiré."
    AUTH_UNAUTHORIZED = "Accès non autorisé."
    AUTH_FORBIDDEN = "Vous n'avez pas les permissions suffisantes pour effectuer cette action."
    AUTH_PWD_MISMATCH = "Les mots de passe ne correspondent pas."
    AUTH_PWD_CHANGED = "Mot de passe modifié avec succès."
    AUTH_FIRST_PWD_REQUIRED = "Vous devez modifier votre mot de passe lors de la première connexion."
    AUTH_MULTIPLE_PHARMACIES = "Ce compte existe dans plusieurs pharmacies. Veuillez renseigner le code pharmacie."

    # Users
    USER_NOT_FOUND = "Utilisateur introuvable."
    USER_EXISTS = "Ce nom d'utilisateur existe déjà."
    USER_CANNOT_DELETE_SELF = "Vous ne pouvez pas supprimer votre propre compte."
    USER_CANNOT_MODIFY_SUPERADMIN = "Impossible de modifier le compte Super Administrateur."
    USER_CANNOT_MODIFY_OTHER_PHARMACY = "Impossible de modifier un utilisateur d'une autre pharmacie."
    USER_CAPACITY_EXCEEDED = "Nombre maximal d'utilisateurs actifs atteint pour votre plan."

    # POS & Stock
    STOCK_INSUFFICIENT = "Stock insuffisant pour ce produit."
    BATCH_NOT_FOUND = "Lot de médicament introuvable."
    SALE_NOT_FOUND = "Vente introuvable."
    SALE_ALREADY_CANCELLED = "Cette vente a déjà été annulée."
    CASH_REGISTER_CLOSED = "Aucune session de caisse ouverte pour enregistrer des paiements."

    # License
    LICENSE_EXPIRED = "La licence de votre pharmacie a expiré. Veuillez contacter le support."
    LICENSE_TRIAL_EXPIRED = "La période d'essai de votre pharmacie a expiré."
    FEATURE_NOT_IN_PLAN = "Cette fonctionnalité n'est pas incluse dans votre formule d'abonnement."
