# PharmaERP : guide d'intégration du design

## Comment l'utiliser dans votre code existant
1. Ajoutez la police dans `<head>` :
   `<link href="https://fonts.googleapis.com/css2?family=Figtree:wght@400;500;600;700&family=Sora:wght@500;600;700&display=swap" rel="stylesheet">`
2. Importez `pharmaerp-design.css` (ou collez-le dans votre feuille globale).
3. Remplacez les classes de vos composants par celles ci-dessous. Tout passe par des variables CSS, donc le thème sombre fonctionne tout seul (`<html data-theme="dark">`, ou automatique selon le système).
4. `apercu-design.html` montre le rendu final et sert de modèle de balisage.

## Ce qui change par rapport à votre design actuel
| Avant | Après |
|---|---|
| Menu actif bleu avec halo lumineux, cartes de couleurs différentes | Un seul accent (vert-teal pharmacie), menu actif plein, couleurs réservées aux états (rouge, orange, vert, bleu) |
| Titre de page « Tableau de bord » sur toutes les pages | Le titre suit la page affichée |
| Pastilles de statut qui se coupent sur 2 lignes, boutons qui chevauchent le texte | `white-space:nowrap`, hauteurs fixes, grilles flex/grid |
| Statut par la couleur seule | Pastille = point + texte (accessible) |
| Barre de défilement horizontale dans les alertes | Cartes d'alerte en pile, plus de scroll interne |
| Cartes KPI avec barre colorée en haut | Barre latérale fine + icône teintée |
| Pas de thème sombre | Thème sombre complet |

## Variables (couleurs, polices)
`--brand` (accent), `--bg`, `--surface`, `--ink`, `--mute`, `--line`, `--side` (menu latéral),
états : `--crit` `--warn` `--good` `--info` (+ `-50` pour le fond clair),
graphiques : `--c1` à `--c5` (vérifiées daltonisme et contraste, claires et sombres).
Polices : `--f-disp` (Sora, titres et gros chiffres), `--f-body` (Figtree).

## Composants et balisage
**Carte KPI**
```html
<div class="card kpi" style="--k:var(--crit);--kb:var(--crit-50)">
  <div class="ico"><!-- icône --></div>
  <div class="lab">Alertes critiques</div><div class="val">4</div>
  <div class="foot"><span>…</span><span class="delta up">+12,5 %</span></div>
</div>
```
**Pastilles d'état** : `<span class="pill crit|warn|good|info">Critique</span>` · étiquette : `<span class="tag">Diabète</span>` · ordonnance : `<span class="rx">Rx</span>`
**Boutons** : `.btn`, `.btn primary`, `.btn danger`, `.btn ghost`, taille `.btn sm`
**Sélecteur segmenté (Semaine / Mois / Année, filtres)** :
```html
<div class="seg"><button aria-pressed="true">Semaine<span class="n">7</span></button><button aria-pressed="false">Mois</button></div>
```
**Alerte** : `<div class="alert crit|warn|info"><div class="ai">icône</div><div><b>Titre</b><p>Détail</p><div class="ft">boutons</div></div></div>`
**Tableau** : `.tw > table`, ligne critique `<tr class="hl">`, jauge de stock `<div class="meter"><i style="width:40%;background:var(--warn)"></i></div>`
**Champs** : `.field` (barre de recherche), `.input`, `.select`, `.textarea`, `label.lb`
**Interrupteur** (remplace les cases à cocher brutes des Paramètres) : `<label class="sw"><input type="checkbox"><i></i></label>`
**Fenêtre modale** (commande, ajout) : `#modal.open > .dlg > .dh / .db / .df`, estimation de coût dans `.estimate`
**Point de vente** : `.pos` (grille + panier), `.pgrid > .prod`, `.cart`, `.line`, `.qty`, `.tot`
**Infobulle de graphique** : élément `#tip` + attribut `data-tip` sur les barres (voir le CSS)

## Corrections de contenu repérées dans vos captures
1. **Dates incohérentes** : « 15 août 2027 », « 2026-12-20 », « 15 mai 2026 ». Utilisez un seul format (`Intl.DateTimeFormat('fr-FR')`).
2. **Péremptions contradictoires** : l'Aspirine est « Expiré (15 mai 2026) » dans un écran et « expire dans 15 jours » dans un autre ; Losartan « il reste 25 jours » avec une date de mai 2026 alors que nous sommes en octobre. Calculez les jours restants à partir de la date.
3. **Compteurs qui ne concordent pas** : alertes critiques 8 / 4 / 2, expirations 23 / 7 / 12. Dérivez tous les badges de la même fonction.
4. **Libellés en anglais** : Mon…Sun, Jan…Jun, « Revenu / Profit » mélangés à « Recettes / Bénéfice ». Passez-les en français (lun., janv.…).
5. **Colonne « ACTION »** dans l'inventaire qui contient le stock : renommez en « Stock ».
6. **« Total » affiché deux fois** dans le panier : « Sous-total », puis « Total TTC ».
7. **Icône calendrier** sur « Espèces » : utilisez une icône de billets.
8. **Date des rapports** (30 avril 2026) alors que la date du jour est octobre 2026.
9. **Tableau de bord** : le bloc « Alertes intelligentes » fait doublon avec le Centre d'alertes. Fusionnez-les.

## Fonctions à ajouter, vues dans vos écrans ou propres à une pharmacie
- Stock calculé à partir des **lots** (numéro de lot + date de péremption), vente selon FEFO (premier expiré, premier sorti) et blocage des lots périmés en caisse.
- Drapeau **ordonnance (Rx)** sur les médicaments soumis à prescription, avec confirmation en caisse.
- Recherche globale (médicaments, code-barres, clients, factures) et rôles qui masquent les menus non autorisés.
- Recommandation de réapprovisionnement calculée sur les ventes des 30 derniers jours (plutôt qu'un pourcentage de « confiance IA » non vérifiable).
- Réception de commande fournisseur qui crée un lot, retrait des lots périmés avec valeur perdue.
- Arabe et affichage de droite à gauche (RTL), utile pour le marché égyptien : utilisez les propriétés logiques CSS (`margin-inline-start`) quand vous adapterez le code.

---

# Section « Gestion » (ajout)

Fichiers : `apercu-gestion.html` (les 5 pages, cliquez dans le menu), `pharmaerp-charts.js` (graphiques), et le bloc « Section Gestion » à la fin de `pharmaerp-design.css`.

## Graphiques (Analytique)
Ajoutez `<div id="tip"></div>` dans le `<body>` puis chargez `pharmaerp-charts.js`.
```js
PharmaCharts.barChart([{label:'mai',long:'mai 2026',rev:45000,pf:12000}, …],
  [{key:'rev',color:'var(--c1)',name:'Revenu'},{key:'pf',color:'var(--c2)',name:'Bénéfice'}]);  // {target:true} ajoute les barres d'objectif
PharmaCharts.lineChart([{label:'lun.',v:28}, …]);
PharmaCharts.donut([{name:'Douleur',v:114800,color:'var(--c1)'}, …]);
```
Chaque fonction renvoie du SVG : `el.innerHTML = …`. Infobulle au survol, grille discrète, extrémités arrondies, couleurs vérifiées pour le daltonisme. Si vous utilisez déjà Recharts ou Chart.js, reprenez seulement les couleurs `--c1` à `--c5`, des libellés français et l'infobulle (`.tip`).

## Composants par page
- **Analytique** : `.pagehead` + `.seg` (période) ; 4 `.card.kpi` avec `.delta up|down` ; `.chartgrid` (graphique + anneau) ; légende de l'anneau `.legend.col` ; classement `.toplist > .toprow` avec `.rank`.
- **Rapports de vente** : 3 KPI (`.grid3`) ; `table` dans `.tw`, lignes cliquables `tr.click` ; montant en `td.right.num`.
- **Fournisseurs** : `.cards3 > .card.sup` avec `<dl>` (contact, téléphone, produits, délai) et un bouton. Les nombres de produits doivent venir de vos données, pas être saisis à la main.
- **Accès du personnel** : `.staff` (avatar `.av`, `.rolepill admin|pharma|inv|cash`, `.pill good` Actif, bouton Gérer) ; matrice `table.perm` avec `input.chk`.
- **Paramètres** : `.setgroup` (icône + titre + description) ; lignes `.setrow` avec interrupteur `.sw` (fini les cases à cocher noires) ; champs `.input` / `.select` avec `label.lb`.

## Ce qui change dans ces pages
| Avant | Après |
|---|---|
| Titre « Tableau de bord » sur toutes les pages | Titre de la page courante |
| Mon…Sun, Jan…Jun, « Recettes / Revenu » mélangés | Libellés français cohérents |
| Case à cocher noire (Rapports de vente) | Interrupteur teal |
| Bloc Fournisseurs avec 145 / 98 articles écrits en dur | Compter les médicaments liés au fournisseur |
| Rôle seulement affiché | Rôle qui masque réellement les menus (matrice de permissions) |
| Pas de réglage TVA / objectif / seuil de péremption | Section « Pharmacie » qui alimente caisse, graphiques et alertes |

---

# Aperçu complet interactif

`apercu-complet.html` réunit les 10 pages, et chaque bouton y a un effet. Les écrans partagent les mêmes données : un changement dans l'un se voit dans les autres. Le code (`src/app.js`) sert de référence pour la logique à reproduire dans votre application.

| Bouton | Effet |
|---|---|
| Tableau de bord : Traiter, Commander, Revoir le lot, Ignorer | Défilement vers les alertes, fenêtre de commande, page Suivi d'expiration, alerte masquée |
| Actions rapides | Ajout de médicament, caisse, ajout de client, rapport copiable |
| Exporter, Exporter en CSV | Fenêtre avec le CSV et bouton Copier |
| Point de vente | Ajout au panier (stock limité), quantités, ordonnance obligatoire pour les articles Rx, Espèces ou Carte, monnaie à rendre, Encaisser : reçu, stock déduit par lot le plus proche de la péremption, facture ajoutée aux ventes |
| Inventaire : Modifier, Ajouter, Commander, Commander les critiques, Revue des actions | Formulaires validés, commandes fournisseurs, puis Réceptionner qui crée un lot et lève l'alerte |
| Clients | Recherche, détail, Ajouter (téléphone unique), Nouvelle vente pour ce client |
| Suivi d'expiration | Filtres, Retirer du stock avec confirmation et valeur passée en perte |
| Analytique, Rapports de vente | Semaine, Mois, Année recalculent KPI et graphiques ; filtres paiement et recherche ; clic sur une ligne : reçu |
| Fournisseurs, Accès du personnel | Détails (produits liés, commandes), ajout ; Gérer un rôle ; matrice de permissions qui masque vraiment les menus ; changement d'utilisateur depuis le menu du profil |
| Paramètres | Interrupteurs qui modifient les alertes, TVA et délai de péremption qui recalculent caisse et alertes, thème, mot de passe (validation seulement) |
| Barre de recherche, cloche, thème | Résultats groupés (médicaments, clients, factures), alertes critiques, thème clair ou sombre |

Dans l'aperçu, rien n'est enregistré : tout revient à l'état initial au rechargement.
