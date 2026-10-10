# ADR-001 — Architecture initiale du projet DevSecOps Pipeline

**Projet :** DevSecOps Pipeline — CI/CD sécurisé

**Date :** 10 octobre 2026

**Statut :** Accepté

**Décideur :** Propriétaire du projet

**Responsabilité architecturale :** Tech Lead / DevSecOps Architect / Security Lead

**Portée :** Architecture initiale et choix technologiques structurants

---

## 1. Contexte

Le projet **DevSecOps Pipeline — CI/CD sécurisé** a pour objectif de concevoir et de démontrer une chaîne d'intégration et de livraison logicielle intégrant des contrôles automatisés de qualité et de sécurité.

Le projet doit constituer une réalisation professionnelle présentable sur GitHub, dans un portfolio et lors d'entretiens techniques pour des postes ou missions DevOps, DevSecOps et cybersécurité.

Il doit notamment démontrer les compétences suivantes :

- Gestion de code source avec Git et GitHub.
- Intégration continue avec GitHub Actions.
- Tests automatisés et analyse statique.
- Détection de secrets et de dépendances vulnérables.
- Construction et analyse de conteneurs Docker.
- Génération de Software Bill of Materials (SBOM).
- Définition et application de politiques de sécurité.
- Sécurisation de la chaîne de développement logiciel.
- Gestion professionnelle des Pull Requests.
- Documentation des décisions et des contrôles.

L'application utilisée est un support de démonstration. L'objectif principal du projet reste la conception, la sécurisation et la validation de la pipeline.

Six décisions structurantes ont été examinées et validées avant le développement.

## 2. Décision 1 — Application Python dédiée

**Décision :** créer une application Python spécifiquement dédiée au projet DevSecOps.

### Alternatives étudiées

**A. Réutiliser SecureVault**

Avantages :

- Valorisation d'une application existante.
- Possibilité d'analyser un projet applicatif plus représentatif.

Inconvénients :

- Couplage entre deux projets.
- Complexité potentiellement supérieure.
- Risque de détourner l'objectif principal vers la maintenance applicative.

**B. Créer une application Python dédiée — Retenu**

Avantages :

- Périmètre fonctionnel maîtrisé.
- Dépendances limitées.
- Tests simples et reproductibles.
- Scénarios de sécurité contrôlés.
- Indépendance du portfolio.

Inconvénient :

- Application moins représentative d'un système métier complexe.

**C. Créer un sous-projet applicatif indépendant**

Avantages :

- Séparation organisationnelle explicite.
- Possibilité d'évoluer vers plusieurs composants.

Inconvénients :

- Organisation plus complexe.
- Bénéfice limité pour un seul service.

### Justification

Une application dédiée permet de concentrer les efforts sur les mécanismes DevSecOps plutôt que sur le développement de fonctionnalités métier complexes.

### Conséquences

L'application devra :

- Rester minimaliste et testable.
- Présenter des comportements fonctionnels vérifiables.
- Permettre des démonstrations contrôlées des scanners.
- Fonctionner localement et en conteneur.
- Ne pas dépendre initialement d'une base de données ni de services externes.

SecureVault restera indépendant et pourra éventuellement constituer un futur cas d'utilisation complémentaire.

## 3. Décision 2 — FastAPI comme framework

**Décision :** développer l'application support avec FastAPI.

### Alternatives étudiées

- Bibliothèque standard Python : dépendances limitées, mais davantage d'implémentation HTTP manuelle.
- Flask : framework léger et approprié à une API simple.
- FastAPI : API HTTP, validation des entrées et outils de test adaptés à notre objectif.

### Justification

FastAPI fournit une structure applicative claire, une gestion des entrées et des réponses, et une surface technique suffisante pour les tests et analyses de sécurité.

Il offre un compromis satisfaisant entre simplicité et réalisme.

### Conséquences

- Utilisation de Python avec une version explicitement définie.
- Tests automatisés avec Pytest.
- Tests HTTP avec HTTPX.
- Gestion reproductible des dépendances.
- Application REST minimale.
- Conteneurisation avec Docker.

FastAPI ne sera pas considéré comme une garantie automatique de sécurité.

La version exacte de Python, les endpoints et la méthode définitive de verrouillage des dépendances seront précisés lors de la conception détaillée.

## 4. Décision 3 — Repository GitHub public indépendant

**Décision :** héberger le projet dans un repository GitHub public distinct des autres projets.

### Alternatives étudiées

- Repository privé : contrôle de visibilité plus strict, mais consultation limitée pour le portfolio.
- Intégration dans un repository existant : centralisation, mais couplage avec un autre projet.
- Repository public indépendant : séparation et visibilité professionnelles.

### Justification

Un repository public permet de présenter directement :

- Le code source.
- L'architecture.
- Les workflows GitHub Actions.
- Les Pull Requests.
- Les contrôles de sécurité.
- Les résultats des démonstrations.
- La documentation technique.

### Conséquences

Le repository suivra une stratégie de développement basée sur :

- Une branche principale stable `main`.
- Des branches de travail courtes.
- Des Pull Requests pour les changements significatifs.
- Des checks CI obligatoires.
- Une fusion par Squash Merge.
- Une documentation régulièrement mise à jour.

Des protections GitHub seront appliquées progressivement, dès que les contrôles correspondants pourront être configurés et vérifiés.

### Exigences de sécurité

- Aucun véritable secret dans le repository.
- Permissions GitHub Actions minimales.
- Contrôle des actions tierces.
- Protection de la branche principale.
- Revue des rapports et artefacts avant publication.
- Utilisation exclusive de données fictives pour les démonstrations.

La visibilité publique du repository constitue une contrainte de sécurité explicite.

## 5. Décision 4 — CI complète avant publication GHCR

**Décision :** construire d'abord une pipeline CI DevSecOps complète, puis ajouter une publication contrôlée d'image Docker vers GitHub Container Registry (GHCR).

### Alternatives étudiées

**CI uniquement**

Solution simple, mais ne démontre pas la distribution d'un artefact validé.

**CI complète puis publication GHCR — Retenu**

Permet de séparer validation du code et distribution des images.

**CI avec déploiement cloud immédiat**

Démonstration plus large, mais ajout d'une infrastructure, de permissions et de risques non nécessaires au périmètre initial.

### Justification

La publication ne doit intervenir qu'après validation de la qualité et des contrôles de sécurité requis.

Le projet démontrera ainsi une chaîne de livraison logicielle contrôlée.

### Architecture logique

**Pull Request :**

1. Analyse de qualité.
2. Tests automatisés.
3. Analyses SAST.
4. Détection de secrets.
5. Analyse des dépendances.
6. Construction Docker.
7. Analyse de l'image.
8. Génération de la SBOM.
9. Validation des contrôles obligatoires.

**Après fusion sur main :**

1. Nouvelle validation du commit intégré.
2. Construction de l'image finale.
3. Analyse de l'image finale.
4. Génération de la SBOM.
5. Vérification des conditions de publication.
6. Publication sur GHCR.

L'architecture devra garantir que l'image publiée correspond à l'image analysée, sans reconstruction non contrôlée entre ces opérations.

### Conséquences de sécurité

- Aucun droit de publication accordé inutilement aux workflows de Pull Request.
- Permissions GHCR limitées aux jobs autorisés.
- Publication impossible en cas de contrôle obligatoire non satisfait.
- Identification des images par commit et digest.
- Traçabilité entre code source, contrôles CI et image publiée.

### Hors périmètre initial

- Déploiement Kubernetes.
- Infrastructure cloud de production.
- Déploiement continu en production.
- Gestion d'un environnement de production hautement disponible.

Une publication GHCR ne sera pas présentée comme un déploiement continu complet.

## 6. Décision 5 — SBOM avec Syft et CycloneDX JSON

**Décision :** utiliser Syft pour générer une Software Bill of Materials au format CycloneDX JSON.

### Alternatives étudiées

- Trivy SBOM.
- Syft avec SPDX JSON.
- Syft avec CycloneDX JSON — Retenu.

### Justification

Syft est un outil spécialisé dans l'identification des composants logiciels.

CycloneDX est un format standardisé pertinent pour les usages de sécurité logicielle et de gestion des composants.

Ce choix permet également de distinguer les responsabilités :

- **pip-audit :** analyse des vulnérabilités connues des dépendances Python.
- **Trivy :** analyse des vulnérabilités de l'image conteneur.
- **Syft :** inventaire des composants de l'image.
- **CycloneDX JSON :** représentation standardisée de l'inventaire.

### Conséquences

La SBOM devra :

- Être générée depuis l'image finale construite.
- Utiliser le format CycloneDX JSON.
- Être conservée comme artefact GitHub Actions.
- Être associée à une image identifiable.
- Pouvoir être consultée et exploitée.
- Ne pas contenir d'informations sensibles inappropriées.

La validité du format devra être vérifiée.

La génération de la SBOM constituera un contrôle obligatoire dans la pipeline finale.

### Limites

Une SBOM inventorie les composants identifiés.

Elle ne démontre ni l'absence de vulnérabilités ni l'exhaustivité parfaite de la détection des composants.

## 7. Décision 6 — Revue documentée en solo

**Décision :** adopter un processus de revue technique documentée, sans exiger une approbation GitHub par un second contributeur.

### Alternatives étudiées

**Approbation obligatoire par un reviewer indépendant**

Avantage : séparation des responsabilités.

Inconvénient : nécessite un second contributeur éligible.

**Revue documentée en solo — Retenu**

Adaptée au fonctionnement actuel du projet, avec des contrôles automatisés et une traçabilité explicite.

### Justification

Le propriétaire du projet prend les décisions finales.

Le développement est réalisé directement par le propriétaire.

Chaque changement significatif fait l’objet d’une revue du diff, des tests, de la sécurité et des résultats CI avant intégration. Le propriétaire exécute et valide les opérations Git/GitHub.

Les résultats des revues seront examinés par le propriétaire avant intégration.

### Workflow retenu

1. Définition et validation de la tâche.
2. Création d'une branche courte.
3. Implémentation.
4. Exécution des tests locaux.
5. Création d'une Pull Request.
6. Exécution de la CI.
7. Analyse du diff et des résultats.
8. Revue technique documentée.
9. Correction éventuelle.
10. Validation de tous les contrôles obligatoires.
11. Squash Merge.
12. Vérification de `main`.

### Garanties

- La création d'une Pull Request reste obligatoire pour le développement normal.
- Les contrôles CI requis doivent réussir.
- Une revue documentée doit être réalisée.
- Les exceptions de sécurité doivent être justifiées.
- Les changements d'architecture importants nécessitent une décision explicite du propriétaire.

### Limite reconnue

Une revue assistée par IA, puis validée par le propriétaire, n'équivaut pas à une revue humaine indépendante.

Cette limitation sera assumée et ne devra pas être masquée dans la présentation du projet.

## 8. Principes architecturaux transversaux

Les six décisions reposent sur les principes suivants :

**Security by Design :** prendre en compte les risques dès la conception.

**Shift Left Security :** détecter les problèmes le plus tôt possible.

**Least Privilege :** limiter les permissions aux opérations nécessaires.

**Fail Closed :** ne pas considérer comme validé un contrôle obligatoire qui échoue ou ne peut pas produire de résultat fiable.

**Defense in Depth :** utiliser plusieurs mécanismes de sécurité complémentaires.

**Reproducibility :** contrôler les versions et rendre les constructions reproductibles.

**Traceability :** conserver des éléments permettant de comprendre les validations, décisions et exceptions.

**Simplicity :** ne pas ajouter de technologies sans besoin identifié.

Une CI verte signifie que les contrôles requis ont satisfait leur politique d'acceptation. Elle ne constitue pas une garantie absolue de sécurité.

## 9. Risques résiduels acceptés

| Risque | Conséquence | Mesure envisagée |
|---|---|---|
| Application volontairement minimale | Réalisme métier limité | Scénarios de sécurité représentatifs |
| Repository public | Exposition des configurations et historiques | Contrôle strict du contenu publié |
| Revue en solo | Absence de séparation humaine des responsabilités | CI obligatoire et revue documentée |
| Dépendances tierces | Vulnérabilités ou compromission potentielles | Verrouillage et analyses automatisées |
| GitHub Actions | Compromission potentielle de la chaîne CI | Permissions minimales et hardening |
| Scanners imparfaits | Faux négatifs et faux positifs | Défense en profondeur et analyse des résultats |
| Absence de déploiement réel | Couverture CD limitée | Publication GHCR puis extension éventuelle |

Ces risques sont reconnus pour le périmètre initial. Ils devront être réévalués si l'architecture évolue.

## 10. Décisions non couvertes par cet ADR

Cet ADR ne fixe pas définitivement :

- La version exacte de Python.
- Le contrat fonctionnel des endpoints FastAPI.
- La stratégie détaillée de verrouillage des dépendances.
- Les règles et seuils SAST.
- La politique de gestion des vulnérabilités.
- Les exceptions de sécurité.
- Le découpage final des jobs GitHub Actions.
- La configuration détaillée des protections de branche.
- Les durées de rétention définitives.
- La stratégie de versions et de tags GHCR.
- La visibilité définitive des packages GHCR.
- Les modalités d'attestation et de vérification de provenance.

Ces sujets seront traités dans la conception détaillée, les politiques de sécurité ou des ADR complémentaires.

## 11. Conséquences sur la roadmap

Les décisions prises établissent l'ordre de progression suivant :

1. Finalisation de la conception technique et du premier modèle de menaces.
2. Initialisation du repository GitHub.
3. Création de l'application FastAPI minimale.
4. Mise en place de la première CI.
5. Protection de `main`.
6. Intégration progressive des contrôles DevSecOps.
7. Dockerisation et analyse de l'image.
8. Génération de la SBOM.
9. Consolidation de la sécurité des workflows.
10. Démonstrations de détection et correction.
11. Publication contrôlée sur GHCR.
12. Audit final et préparation portfolio.

Chaque évolution significative devra être traitée dans une Pull Request cohérente et vérifiable.

## 12. Critères de révision

Cet ADR pourra être réexaminé si :

- Une limitation technique importante est découverte.
- Les besoins du portfolio changent significativement.
- Une exigence de sécurité justifie une évolution architecturale.
- L'application support nécessite une complexité supplémentaire.
- Un véritable déploiement devient un objectif du projet.

Toute évolution majeure devra être documentée, idéalement dans un nouvel ADR, afin de préserver la traçabilité des décisions.

## 13. Conclusion

Le projet adopte une architecture centrée sur une API Python FastAPI dédiée, hébergée dans un repository GitHub public indépendant.

La validation sera assurée par une pipeline GitHub Actions intégrant progressivement les contrôles de qualité, de tests et de sécurité.

La distribution de l'application s'effectuera ultérieurement par une publication contrôlée d'image Docker sur GHCR.

La SBOM sera générée par Syft au format CycloneDX JSON.

Le processus de contribution reposera sur des branches courtes, des Pull Requests, une CI obligatoire, une revue documentée en solo et le Squash Merge.

**Cette architecture est acceptée comme référence initiale du projet DevSecOps Pipeline — CI/CD sécurisé.**

Le développement ne commencera qu'après validation du périmètre technique de la première mission.
