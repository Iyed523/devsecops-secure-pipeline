# Threat Model — Release Metadata API & DevSecOps Pipeline

**Projet :** DevSecOps Pipeline — CI/CD sécurisé\
**Version :** 0.1\
**Date :** 10 octobre 2026\
**Statut :** Accepté — Version initiale\
**Référence architecturale :** ADR-001\
**Responsable :** Propriétaire du projet / Security Lead

---

## 1. Objectif du document

Ce document identifie, analyse et priorise les menaces de sécurité applicables à Release Metadata API et à sa future chaîne de livraison DevSecOps.

Il sert à :

- Définir les actifs à protéger.
- Comprendre les frontières de confiance.
- Identifier les scénarios d'attaque plausibles.
- Prioriser les risques.
- Proposer les contrôles de sécurité nécessaires.
- Relier les menaces aux tests et aux validations CI.
- Documenter les risques résiduels.
- Orienter les décisions techniques futures.

Le modèle sera réévalué pendant le développement et lors des évolutions importantes de l'architecture.

## 2. Périmètre

### 2.1 Application

Release Metadata API est une API REST développée avec FastAPI.

Elle possède deux endpoints :

- `GET /health` : vérification élémentaire de disponibilité.
- `POST /api/v1/releases/evaluate` : validation et évaluation de cohérence des métadonnées de release.

Le second endpoint reçoit cinq champs : `service`, `version`, `channel`, `sha256` et `size_bytes`.

L'application valide le format des champs et vérifie la cohérence entre le canal de publication et le numéro de version.

Elle ne vérifie pas l'authenticité ou le contenu réel d'un artefact.

### 2.2 Hypothèses retenues

- L'application est stateless.
- Aucune base de données n'est utilisée.
- Aucune authentification n'est prévue initialement.
- Aucun secret applicatif n'est nécessaire.
- Aucun stockage de fichiers n'est prévu.
- Aucune commande système ne doit être exécutée à partir des entrées utilisateur.
- Aucun appel réseau externe n'est nécessaire pour le fonctionnement de l'API.
- L'application n'est pas destinée à être exposée publiquement sur Internet dans le périmètre initial.

### 2.3 Chaîne DevSecOps

Le périmètre comprend également :

- Le repository GitHub public.
- Les branches et Pull Requests.
- Les workflows GitHub Actions.
- Les runners CI.
- Les outils d'analyse de sécurité.
- Les dépendances Python et les actions tierces.
- Les images de base Docker.
- La construction et l'analyse des images.
- Les rapports CI.
- Les SBOM.
- La future publication sur GHCR.

GHCR constitue un composant cible de l'architecture, non un service déjà configuré.

### 2.4 Hors périmètre initial

- Infrastructure Kubernetes.
- Infrastructure cloud de production.
- Base de données.
- Authentification et gestion des utilisateurs applicatifs.
- Données personnelles métier.
- Déploiement public permanent.
- Supervision d'un environnement de production.

Ces éléments devront être intégrés à une nouvelle analyse s'ils sont ajoutés au projet.

## 3. Actifs à protéger

| ID | Actif | Propriété prioritaire |
|---|---|---|
| A01 | Code source | Intégrité |
| A02 | Branche `main` | Intégrité |
| A03 | Workflows GitHub Actions | Intégrité |
| A04 | GITHUB_TOKEN et identifiants éventuels | Confidentialité et limitation des privilèges |
| A05 | Dépendances Python | Intégrité |
| A06 | Runners et environnement de build | Isolation et intégrité |
| A07 | Image Docker | Intégrité |
| A08 | Rapports CI | Intégrité et confidentialité appropriée |
| A09 | SBOM | Intégrité et traçabilité |
| A10 | Package publié sur GHCR | Intégrité et authenticité de provenance |
| A11 | Disponibilité de l'API | Disponibilité |
| A12 | Politique de sécurité et historique des validations | Intégrité et traçabilité |

Le code source du repository étant public, sa confidentialité n'est pas un objectif général. Les secrets, tokens, données privées et informations de sécurité sensibles constituent néanmoins des actifs confidentiels.

## 4. Acteurs et sources de menaces

Les acteurs considérés sont :

**Utilisateur de l'API :** peut envoyer des requêtes HTTP valides ou malformées, volontairement ou accidentellement.

**Contributeur externe :** peut proposer une Pull Request contenant du code, des tests ou des configurations potentiellement malveillants.

**Attaquant de la supply chain :** peut tenter de compromettre une bibliothèque, une action GitHub ou une image utilisée par le projet.

**Compte GitHub compromis :** peut disposer de droits de modification sur le repository ou ses paramètres.

**Mainteneur légitime :** peut introduire accidentellement une vulnérabilité, une mauvaise configuration ou une exception injustifiée.

Aucune malveillance du propriétaire n'est présumée. Cependant, une erreur ou une compromission de son compte fait partie des scénarios à considérer.

## 5. Flux de données et frontières de confiance

### 5.1 Flux applicatif

Client HTTP → FastAPI → Validation Pydantic → Service métier → Réponse JSON

**Frontière TB-01 : Client HTTP / Application**

Les données reçues du client ne sont pas fiables.

Les champs doivent être validés avant leur traitement.

### 5.2 Flux de développement

Développeur ou contributeur → GitHub → Pull Request → GitHub Actions → Résultats CI

**Frontière TB-02 : Contribution non validée / Repository protégé**

Une Pull Request représente une proposition de modification, et non du code automatiquement digne de confiance.

### 5.3 Flux de construction

Runner CI → Sources et dépendances externes → Construction Docker → Analyse de l'image → SBOM

**Frontière TB-03 : Environnement de build / Fournisseurs externes**

Les bibliothèques, actions GitHub et images de base sont des composants tiers pouvant être vulnérables ou compromis.

### 5.4 Flux de publication

Commit intégré → Contrôles de sécurité → Image candidate → GHCR

**Frontière TB-04 : Environnement de validation / Registre de distribution**

La publication exige des permissions plus élevées que les simples contrôles CI.

Les jobs exécutant du code non fiable ne doivent pas disposer de ces permissions.

### 5.5 Flux des résultats

Scanners → Rapports et SBOM → Artefacts GitHub Actions → Consultation

**Frontière TB-05 : Résultats techniques / Informations conservées ou diffusées**

Les rapports peuvent contenir des chemins, des extraits de code, des versions de composants ou des informations sensibles.

Leur publication et leur conservation doivent être contrôlées.

## 6. Méthodologie d'analyse

Nous utilisons STRIDE comme grille d'identification des menaces :

- **S — Spoofing :** usurpation d'identité.
- **T — Tampering :** altération des données ou composants.
- **R — Repudiation :** impossibilité d'attribuer ou de retracer une action.
- **I — Information Disclosure :** divulgation d'informations.
- **D — Denial of Service :** atteinte à la disponibilité.
- **E — Elevation of Privilege :** élévation de privilèges.

STRIDE sert à explorer les scénarios possibles. Il ne constitue pas à lui seul une mesure quantitative du risque.

### Priorisation initiale

Chaque menace est évaluée selon deux dimensions :

**Probabilité :** faible, moyenne ou élevée.

**Impact :** faible, moyen ou élevé.

Les priorités proposées sont :

- **P1 — Haute :** risque nécessitant un contrôle obligatoire avant l'utilisation de la fonction concernée dans le périmètre final.
- **P2 — Moyenne :** risque à traiter avant la livraison finale ou à accepter explicitement avec justification.
- **P3 — Faible :** risque à documenter et surveiller.

Ces priorités sont des estimations de conception, avant la mise en place des mesures de réduction. Elles ne représentent pas des vulnérabilités déjà constatées.

## 7. Menaces applicatives

### TH-API-01 — Contournement des validations

**Catégorie :** Tampering\
**Actif :** A11 et comportement métier\
**Probabilité :** Moyenne\
**Impact :** Moyen\
**Priorité :** P2

**Scénario :** un client fournit des champs incorrects, des valeurs ambiguës ou des combinaisons de métadonnées incohérentes pour provoquer un résultat métier inattendu.

**Contrôles envisagés :**
- Validation stricte avec Pydantic.
- Champs requis et typés.
- Rejet des champs supplémentaires.
- Limites sur les longueurs.
- Logique métier testée indépendamment de HTTP.

**Validation attendue :** tests unitaires et HTTP sur les entrées invalides, ambiguës et les cas limites.

### TH-API-02 — Consommation excessive de ressources

**Catégorie :** Denial of Service\
**Actif :** A11\
**Probabilité :** Faible en environnement local contrôlé, plus élevée en cas d'exposition publique\
**Impact :** Moyen\
**Priorité :** P2

**Scénario :** un client envoie des requêtes très volumineuses ou multiplie les requêtes afin d'épuiser les ressources disponibles.

**Contrôles envisagés :**
- Limites sur les champs applicatifs.
- Taille maximale du corps HTTP à imposer au niveau approprié.
- Timeouts adaptés.
- Limitation des ressources du conteneur lorsque pertinent.
- Réévaluation d'un mécanisme de rate limiting en cas d'exposition publique.

Les limites sur les champs Pydantic ne remplacent pas une limite globale de la taille des requêtes.

**Validation attendue :** tests contrôlés sur les tailles de requêtes et vérification des limites d'exécution retenues.

### TH-API-03 — Divulgation par les erreurs ou les logs

**Catégorie :** Information Disclosure\
**Actif :** A08\
**Probabilité :** Moyenne\
**Impact :** Moyen\
**Priorité :** P2

**Scénario :** une requête inattendue provoque une erreur exposant des informations internes, des détails de configuration ou des données envoyées par le client.

**Contrôles envisagés :**
- Réponses d'erreur maîtrisées.
- Absence de traces techniques détaillées dans les réponses de production.
- Aucun logging systématique des corps de requêtes.
- Vérification des messages de validation.
- Aucun secret applicatif ou de test dans les journaux.

**Validation attendue :** tests de réponses d'erreur et inspection des logs.

### TH-API-04 — Fausse interprétation de la validation des métadonnées

**Catégorie :** Spoofing / Tampering\
**Actif :** A07 et confiance dans les résultats\
**Probabilité :** Moyenne\
**Impact :** Élevé si le résultat est utilisé comme autorisation de publication\
**Priorité :** P1 pour tout usage comme contrôle d'intégrité

**Scénario :** un utilisateur fournit un SHA-256 bien formé mais ne correspondant à aucun artefact réel. Le résultat positif de l'API est interprété à tort comme une preuve d'authenticité ou d'intégrité.

**Contrôles envisagés :**
- Séparer explicitement validation de format et vérification cryptographique.
- Documenter les garanties réelles de l'API.
- Ne jamais utiliser son résultat comme unique autorisation de publication.
- Confier la validation des artefacts à la pipeline de livraison.

**Validation attendue :** tests démontrant qu'un SHA-256 arbitraire mais correctement formé peut être accepté comme métadonnée, sans être présenté comme vérifié.

## 8. Menaces GitHub et supply chain

### TH-CI-01 — Exécution de code non fiable avec des privilèges élevés

**Catégorie :** Elevation of Privilege\
**Actifs :** A03, A04 et A06\
**Probabilité :** Moyenne\
**Impact :** Élevé\
**Priorité :** P1

**Scénario :** une Pull Request contient un script malveillant exécuté par un workflow disposant de droits d'écriture ou d'accès à des secrets.

**Contrôles envisagés :**
- Utiliser `pull_request` pour les validations ordinaires.
- Éviter `pull_request_target` pour l'exécution du code proposé.
- Aucun secret de publication dans les jobs de PR.
- Permissions du GITHUB_TOKEN explicitement limitées.
- Runners GitHub hébergés et isolés pour les validations.
- Ne pas exécuter d'artefacts non fiables dans un job privilégié.

**Validation attendue :** revue des déclencheurs, des permissions et des frontières entre jobs non privilégiés et jobs de publication.

### TH-CI-02 — Compromission d'une action GitHub tierce

**Catégorie :** Tampering / Elevation of Privilege\
**Actifs :** A03 et A06\
**Probabilité :** Moyenne\
**Impact :** Élevé\
**Priorité :** P1

**Scénario :** une action externe compromise introduit un comportement malveillant dans la CI.

**Contrôles envisagés :**
- Sélectionner des actions maintenues et nécessaires.
- Épingler les actions tierces sur des SHA de commit complets.
- Examiner les permissions accordées.
- Vérifier les mises à jour avant adoption.
- Limiter le nombre d'actions utilisées.

**Validation attendue :** revue des dépendances GitHub Actions et de leurs références.

### TH-CI-03 — Permissions excessives du GITHUB_TOKEN

**Catégorie :** Elevation of Privilege\
**Actifs :** A02, A04 et A10\
**Probabilité :** Moyenne\
**Impact :** Élevé\
**Priorité :** P1

**Scénario :** un job exécutant du code non fiable possède des permissions d'écriture lui permettant de modifier le repository ou de publier un package.

**Contrôles envisagés :**
- Permissions minimales au niveau des workflows.
- Permissions supplémentaires uniquement pour les jobs qui en ont besoin.
- Séparation entre validation et publication.
- Absence de Personal Access Token permanent lorsque GITHUB_TOKEN suffit.

**Validation attendue :** inspection des permissions effectives des jobs.

### TH-CI-04 — Contournement de la politique de sécurité

**Catégorie :** Tampering / Repudiation\
**Actifs :** A02, A03 et A12\
**Probabilité :** Moyenne\
**Impact :** Élevé\
**Priorité :** P1

**Scénario :** un contrôle échoue, mais la pipeline finale apparaît comme validée en raison d'une condition incorrecte, d'un job ignoré ou d'une règle non bloquante.

**Contrôles envisagés :**
- Security Gate final obligatoire.
- Gestion explicite des résultats des jobs.
- Aucun usage généralisé de `continue-on-error`.
- Noms de checks stables.
- Protection de `main`.
- Revue des modifications des workflows.

**Validation attendue :** démonstrations contrôlées d'échec de test, de scanner, de job ignoré et d'erreur d'exécution.

### TH-SC-01 — Dépendance Python vulnérable ou compromise

**Catégorie :** Tampering\
**Actifs :** A05 et A07\
**Probabilité :** Moyenne\
**Impact :** Élevé\
**Priorité :** P1

**Scénario :** le projet installe une dépendance affectée par une vulnérabilité connue ou une version malveillante.

**Contrôles envisagés :**
- Dépendances verrouillées.
- Vérification de l'intégrité des packages lorsque applicable.
- Utilisation de sources de packages approuvées.
- Analyse avec pip-audit.
- Revue des mises à jour.
- Réduction des dépendances inutiles.

**Validation attendue :** audit automatisé et analyse du résultat.

Une absence d'alerte pip-audit n'exclut pas une compromission inconnue d'un package.

### TH-SC-02 — Image Docker vulnérable ou mal configurée

**Catégorie :** Tampering / Elevation of Privilege\
**Actifs :** A06 et A07\
**Probabilité :** Moyenne\
**Impact :** Élevé\
**Priorité :** P1

**Scénario :** l'image finale contient une vulnérabilité critique, exécute l'application avec des permissions excessives ou embarque des fichiers inutiles.

**Contrôles envisagés :**
- Image de base minimale et maintenue.
- Version ou digest de base maîtrisé.
- Utilisateur non-root.
- `.dockerignore`.
- Exclusion des secrets et fichiers inutiles.
- Analyse Trivy.
- Politique documentée sur les vulnérabilités HIGH et CRITICAL.

**Validation attendue :** inspection de l'image, vérification de l'utilisateur effectif et rapports Trivy.

### TH-SC-03 — Image publiée différente de l'image analysée

**Catégorie :** Tampering\
**Actifs :** A07 et A10\
**Probabilité :** Moyenne\
**Impact :** Élevé\
**Priorité :** P1

**Scénario :** l'image est reconstruite ou substituée entre son analyse de sécurité et sa publication.

**Contrôles envisagés :**
- Construire, analyser et publier une même image candidate.
- Éviter une reconstruction non contrôlée après les scans.
- Identifier l'image finale par digest.
- Associer les résultats de sécurité à cet artefact précis.

**Validation attendue :** comparaison et traçabilité de l'identité de l'image analysée et de l'image publiée.

### TH-SC-04 — SBOM incorrecte, incomplète ou mal associée

**Catégorie :** Tampering / Repudiation\
**Actifs :** A09 et A10\
**Probabilité :** Moyenne\
**Impact :** Moyen\
**Priorité :** P2

**Scénario :** une SBOM est générée à partir d'une mauvaise image, contient des données incomplètes ou ne peut pas être reliée à une version publiée.

**Contrôles envisagés :**
- Génération avec Syft depuis l'image construite.
- Format CycloneDX JSON.
- Validation structurelle.
- Association au digest de l'image.
- Conservation contrôlée.
- Traçabilité des versions des outils.

**Validation attendue :** vérification du format, de l'image source et de la présence des métadonnées nécessaires.

### TH-SC-05 — Publication GHCR non autorisée

**Catégorie :** Elevation of Privilege / Tampering\
**Actifs :** A04 et A10\
**Probabilité :** Moyenne\
**Impact :** Élevé\
**Priorité :** P1

**Scénario :** un workflow non prévu ou une contribution non validée déclenche la publication d'une image.

**Contrôles envisagés :**
- Publication réservée aux événements autorisés sur `main`.
- Contrôles de sécurité obligatoires avant publication.
- Permissions `packages: write` exclusivement dans le contexte autorisé.
- Vérification de la provenance du commit.
- Identification des images par digest.

**Validation attendue :** vérifier qu'une Pull Request ne peut pas publier l'image officielle et qu'un échec de contrôle bloque la publication.

### TH-SC-06 — Compromission ou fuite d'informations par les artefacts CI

**Catégorie :** Information Disclosure / Tampering\
**Actifs :** A08 et A09\
**Probabilité :** Moyenne\
**Impact :** Moyen\
**Priorité :** P2

**Scénario :** un rapport contient une information sensible, ou un artefact non fiable est réutilisé sans vérification dans un workflow privilégié.

**Contrôles envisagés :**
- Inspection du contenu des rapports.
- Aucun véritable secret dans les démonstrations.
- Durées de conservation limitées.
- Permissions de lecture appropriées.
- Traitement des artefacts de PR comme des données non fiables.
- Aucune exécution automatique de contenu non validé.

**Validation attendue :** inspection des rapports, de la politique de conservation et des transferts entre jobs.

### TH-GOV-01 — Contournement administratif ou revue insuffisante

**Catégorie :** Repudiation / Tampering\
**Actifs :** A02 et A12\
**Probabilité :** Moyenne\
**Impact :** Élevé\
**Priorité :** P1 pour la protection de main, P2 pour le risque organisationnel résiduel

**Scénario :** une modification sensible est fusionnée ou un contrôle est désactivé sans analyse suffisante.

**Contrôles envisagés :**
- Pull Requests obligatoires.
- Security Gate obligatoire.
- Restriction maximale des bypass.
- Revue technique documentée.
- Documentation des exceptions.
- ADR pour les évolutions majeures.

**Validation attendue :** vérification des Rulesets, de l'historique des PR et de la traçabilité des décisions.

La revue en solo reste une limite organisationnelle explicitement acceptée. Elle ne constitue pas une revue indépendante.

## 9. Synthèse des risques prioritaires

Les risques de priorité P1 les plus structurants pour notre architecture concernent :

1. L'exécution de code non fiable avec des permissions élevées.
2. Les permissions excessives des workflows.
3. Le contournement des contrôles CI.
4. La compromission des dépendances et outils tiers.
5. La construction d'images vulnérables.
6. La publication d'une image différente de celle analysée.
7. La publication GHCR non autorisée.
8. L'insuffisance de protection de `main`.

La validation cryptographique réelle des artefacts constitue également une exigence P1 si une fonctionnalité est ultérieurement présentée comme garantissant leur intégrité.

L'ordre précis des implémentations suivra la roadmap. Les contrôles liés à GHCR devront impérativement être en place avant toute publication officielle.

## 10. Correspondance entre risques et contrôles

| Contrôle | Outil ou mécanisme | Menaces principalement concernées |
|---|---|---|
| Validation des requêtes | Pydantic | TH-API-01 |
| Tests unitaires et HTTP | Pytest | TH-API-01, TH-API-03, TH-API-04 |
| Vérification de qualité | Ruff | Défauts de code et erreurs de maintenance |
| SAST Python | Bandit | Certaines constructions dangereuses |
| SAST par règles | Semgrep | Certaines constructions et configurations dangereuses |
| Analyse des dépendances | pip-audit | TH-SC-01 |
| Détection de secrets | Gitleaks | Exposition d'identifiants dans le repository |
| Analyse d'image | Trivy | TH-SC-02 |
| Inventaire logiciel | Syft | TH-SC-04 |
| Contrôle des jobs | GitHub Actions Security Gate | TH-CI-04 |
| Permissions minimales | GitHub Actions | TH-CI-01, TH-CI-03 |
| Protection de main | GitHub Rulesets | TH-GOV-01 |
| Identité des images | Digest OCI | TH-SC-03, TH-SC-05 |
| Revue des artefacts | Procédure CI | TH-SC-06 |

Cette correspondance représente les contributions attendues de chaque contrôle. Aucun scanner unique ne couvre l'ensemble des menaces.

Notamment, l'analyse statique ne remplace pas la sécurisation des permissions GitHub, et la génération d'une SBOM ne remplace pas le contrôle d'intégrité de l'image.

## 11. Scénarios de validation de sécurité

Les démonstrations suivantes pourront être réalisées lorsque les contrôles correspondants seront disponibles.

### DEMO-01 — Échec d'un contrôle SAST

Introduire dans une branche pédagogique un motif dangereux reconnu par une règle activée.

Résultat attendu : Pull Request bloquée.

Après correction : CI validée.

### DEMO-02 — Détection d'un secret fictif

Introduire uniquement une chaîne factice adaptée à une règle Gitleaks connue.

Résultat attendu : contrôle bloquant.

Après suppression : nouveau scan validé.

### DEMO-03 — Rejet des entrées invalides

Envoyer des métadonnées incorrectes ou incohérentes.

Résultat attendu : rejet HTTP approprié ou évaluation négative selon le contrat de l'API.

### DEMO-04 — Propagation d'un échec CI

Provoquer volontairement l'échec d'un contrôle obligatoire.

Résultat attendu : Security Gate non validé et fusion bloquée.

### DEMO-05 — Vérification de la chaîne de publication

Lors de la phase GHCR, vérifier que :

- Une PR ne peut pas publier l'image officielle.
- Un contrôle obligatoire échoué bloque la publication.
- L'image publiée correspond à celle analysée.
- La SBOM correspond à l'artefact identifié.

Ces démonstrations seront contrôlées, documentées et réalisées sans véritables secrets.

## 12. Risques résiduels

Même après la mise en place des contrôles envisagés, plusieurs risques subsisteront :

- Les scanners peuvent produire des faux négatifs.
- Une vulnérabilité inconnue peut affecter une dépendance.
- Une action tierce peut être compromise malgré un pinning sur SHA.
- Un compte GitHub disposant de privilèges administratifs peut être compromis.
- La revue en solo ne fournit pas de séparation humaine indépendante des responsabilités.
- Une SBOM peut ne pas détecter tous les composants.
- Une CI verte ne garantit pas la sécurité complète de l'application.
- L'absence d'environnement de production limite les garanties de sécurité à l'exécution.

Ces risques devront être documentés et réévalués, sans prétendre qu'ils ont été éliminés.

Aucun niveau de risque résiduel ne sera considéré comme vérifié avant implémentation et exécution des contrôles concernés.

## 13. Suivi et maintenance

Ce document devra être mis à jour :

- Lorsqu'un nouveau composant est introduit.
- Lorsqu'une frontière de confiance change.
- Lorsqu'une nouvelle permission est accordée.
- Lorsqu'un workflow de publication est créé ou modifié.
- Lorsqu'une vulnérabilité importante est identifiée.
- Lorsqu'une exception de sécurité est acceptée.
- Lorsqu'une démonstration de sécurité révèle un risque non anticipé.
- Avant toute exposition publique de l'API sur Internet.

Chaque nouveau risque significatif recevra un identifiant et sera associé à une mesure de traitement ou à une décision explicite d'acceptation.

## 14. Conditions de validation du modèle

La première version du modèle sera considérée comme validée après :

- Confirmation des composants et frontières de confiance.
- Revue des actifs et des acteurs.
- Validation de la priorisation initiale.
- Acceptation du périmètre et des exclusions.
- Identification des contrôles qui devront être obligatoires.
- Accord sur la maintenance progressive du document.

Cette validation porte sur la conception du modèle, non sur l'efficacité technique des contrôles, qui reste à démontrer.

## 15. Conclusion

Le modèle de menaces initial montre que la sécurité du projet repose sur deux dimensions complémentaires.

La première concerne la sécurité applicative de Release Metadata API, notamment la validation des entrées, la maîtrise des erreurs et la disponibilité.

La seconde concerne la sécurité de la chaîne DevSecOps, notamment les permissions GitHub, l'intégrité du code, les dépendances, la construction des images et les conditions de publication.

Compte tenu du périmètre retenu, **la protection de la chaîne de développement et de livraison constitue le principal enjeu de sécurité du projet**.

Les contrôles proposés seront introduits progressivement, vérifiés par des tests et documentés.

Ce document constitue la base de référence pour les futures décisions de sécurité et pour la construction de la pipeline.
