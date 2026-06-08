# TP6 — Qualité du Code & Versioning

## EX.1 — Questions de cours

### Partie A — Concepts fondamentaux

**Q1 — Différence entre ESLint et Prettier, peuvent-ils entrer en conflit ?**

ESLint c'est un linter : il analyse le code pour trouver des erreurs de logique ou des mauvaises pratiques. Par exemple il va te signaler qu'une variable est déclarée mais jamais utilisée, ou que tu utilises `==` à la place de `===`. Prettier c'est un formatter : lui il s'en fout de la logique, il reformate juste le code pour qu'il soit toujours présenté de la même façon (indentation, guillemets, virgules...).

Oui ils peuvent entrer en conflit parce que ESLint a aussi des règles de style (comme imposer les guillemets simples), et si Prettier a une config différente, les deux outils vont se contredire. Pour résoudre ça on installe `eslint-config-prettier` qui désactive toutes les règles ESLint qui gèrent le style, et on laisse Prettier s'en charger.

---

**Q2 — Les 3 composantes de SemVer avec exemples pour l'API calculatrice**

Le format c'est `MAJOR.MINOR.PATCH`.

- **PATCH** : correction d'un bug sans changer le comportement visible. Exemple : on avait un bug dans `divide()` qui renvoyait `NaN` au lieu de lancer une erreur quand `b = 0`, on le corrige → `1.0.0` → `1.0.1`
- **MINOR** : ajout d'une nouvelle fonctionnalité qui ne casse rien. Exemple : on ajoute une fonction `modulo(a, b)` à l'API → `1.0.1` → `1.1.0`
- **MAJOR** : changement qui casse la compatibilité avec la version précédente. Exemple : on renomme `add(a, b)` en `addition(a, b)`, les gens qui appelaient `add()` avant vont avoir une erreur → `1.1.0` → `2.0.0`

---

**Q3 — Conventional Commits et lien avec CHANGELOG + versioning automatique**

Un Conventional Commit c'est un format de message de commit structuré : `type(scope): description`. Les types principaux sont `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `ci`. Il y a aussi la notion de breaking change avec `BREAKING CHANGE:` dans le corps ou `feat!:`.

Le lien avec le CHANGELOG et le versioning c'est direct : des outils comme `git-cliff` ou `semantic-release` lisent les commits et en déduisent automatiquement la prochaine version. Si y'a des `feat` → bump MINOR, si y'a des `fix` → bump PATCH, si y'a un `BREAKING CHANGE` → bump MAJOR. Et ils génèrent le CHANGELOG en regroupant les commits par type. Donc pas besoin de l'écrire à la main.

---

### Partie B — Vrai / Faux

**1. FAUX** — `npm run lint` peut échouer même si le code s'exécute parfaitement. Le code peut tourner sans erreur runtime mais avoir des violations de règles ESLint (variable non utilisée, utilisation de `var`, `==` à la place de `===`...). ESLint analyse statiquement le code, il n'exécute rien.

**2. FAUX** — Prettier n'analyse pas la logique du code du tout. Il reformate juste la présentation. Seul ESLint détecte des problèmes de logique ou des mauvaises pratiques. Les deux ensemble couvrent style + qualité, mais ce sont deux rôles bien distincts.

**3. VRAI** — Un commit `fix:` déclenche bien un bump PATCH selon les règles SemVer + Conventional Commits. Le README est du code source du projet, donc corriger une typo dedans avec un commit `fix:` → version `1.0.0` → `1.0.1`. Même si c'est juste une typo dans la doc, le format `fix:` suffit pour déclencher le PATCH.

**4. VRAI** — Oui c'est même recommandé. Dans le workflow de release, on peut très bien builder l'image Docker et la tagger `:v2.0.0` ET `:latest` dans le même pipeline, déclenché par le tag Git `v2.0.0`. Les deux sont cohérents et produits en même temps.

**5. FAUX** — Par défaut `git push` n'envoie pas les tags. Il faut soit faire `git push --tags` pour tous les envoyer, soit `git push origin v1.0.0` pour en pousser un spécifique. C'est un piège classique : le tag est créé localement mais n'arrive jamais sur GitHub.

---

## EX.2 — ESLint + Prettier dans le pipeline

### 2.1 — Installation et configuration

**Q4 — Commandes ESLint et choix à l'init**

ESLint était déjà installé dans le projet depuis le TP précédent. Il a été initialisé avec `npm init @eslint/config` et les choix faits étaient :
- "To check syntax and find problems" (pas de style, Prettier s'en charge)
- Module type : CommonJS (le projet utilise `require`/`module.exports`)
- Framework : None
- TypeScript : No
- Environment : Node

Le fichier `eslint.config.mjs` généré a été conservé et enrichi avec les règles `no-var` et `no-unused-vars`. J'ai ensuite ajouté `eslint-config-prettier` pour éviter les conflits avec Prettier :

```bash
npm install --save-dev prettier eslint-config-prettier
```

---

**Q5 — 3 violations ESLint dans calculator.js**

J'ai introduit ces 3 violations dans `src/calculator.js` :

```js
function add(a, b) {
    var result = a + b;       // violation 1 : var interdit (no-var)
    const unused = 42;        // violation 2 : variable non utilisée (no-unused-vars)
    if (result == 0) {}       // violation 3 : == à la place de === (eqeqeq)
    return result;
}
```

Résultat de `npm run lint` :

```
/src/calculator.js
  2:5   error  Unexpected var, use let or const instead  no-var
  3:11  error  'unused' is assigned a value but never used  no-unused-vars
  4:16  error  Expected '===' and instead saw '=='  eqeqeq

✖ 3 problems (3 errors, 0 warnings)
```

ESLint liste chaque violation avec la ligne, la colonne, le niveau (error/warning) et la règle concernée. Le process se termine avec un exit code non-zero, ce qui fait échouer le pipeline.

---

**Q6 — Configuration Prettier avec .prettierrc, 4 options justifiées**

```json
{
  "semi": true,
  "singleQuote": true,
  "printWidth": 80,
  "trailingComma": "es5"
}
```

- **`semi: true`** — je préfère les points-virgules explicites pour éviter les erreurs d'ASI (Automatic Semicolon Insertion) dans des cas limites
- **`singleQuote: true`** — guillemets simples cohérents avec la convention Node.js/CommonJS du projet
- **`printWidth: 80`** — largeur standard qui tient sur la plupart des écrans partagés et dans les diff GitHub
- **`trailingComma: "es5"`** — virgule finale sur les objets et tableaux multi-lignes, ça rend les diffs git plus propres (une ligne modifiée = une vraie modification)

Pour vérifier que `format:check` détecte un fichier mal formaté : j'ai ajouté des espaces aléatoires dans `calculator.js` et lancé `npm run format:check` → Prettier a bien signalé que le fichier ne respectait pas le format et aurait besoin d'être reformaté.

---

### 2.2 — Intégration dans le pipeline CI

**Q7 — Structure du job lint dans ci.yml**

```yaml
lint:
  name: 🔍 Lint ESLint + Prettier
  runs-on: ubuntu-latest
  steps:
    - name: Checkout          # 1. récupérer le code
      uses: actions/checkout@v4
    - name: Setup Node.js 18  # 2. installer Node
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
    - name: Installation des dépendances  # 3. npm ci (déterministe)
      run: npm ci
    - name: Vérification ESLint           # 4. lint avec --max-warnings=0
      run: npm run lint
    - name: Vérification Prettier         # 5. format check séparé
      run: npm run format:check
```

L'ordre est logique : sans checkout le code n'est pas là, sans Node on ne peut pas faire npm ci, sans dépendances on ne peut pas lancer eslint/prettier. J'ai mis ESLint avant Prettier parce que les erreurs ESLint sont plus critiques (logique du code) que le format.

---

**Q8 — Résultat d'un push avec violation ESLint**

J'ai poussé un commit avec une violation ESLint (variable non utilisée). Dans le pipeline :
1. Le job `lint` échoue à l'étape "Vérification ESLint" avec exit code 1
2. GitHub Actions marque le job `lint` en rouge ❌
3. Les jobs `test` tournent en parallèle et finissent normalement (ils ne dépendent pas de `lint`)
4. Le job `docker` est bloqué car il a `needs: [lint, test]` — comme `lint` a échoué, `docker` est `skipped`
5. `deploy-staging`, `deploy-production` et `summary` sont aussi bloqués en cascade

---

**Q9 — Réponse à la proposition --max-warnings=5**

Je lui dirais que c'est une mauvaise idée sur le long terme. Voilà pourquoi :

Avec `--max-warnings=5` on accepte d'avoir 5 warnings en permanence dans le code. Au bout de quelques semaines ces warnings deviennent du bruit de fond que plus personne ne lit. Quand y'en a 4, un dev dit "j'en rajoute un, c'est pas grave". Puis 5, 6, 10... On crée une dette technique silencieuse. Les warnings d'aujourd'hui sont souvent les bugs de demain.

Avec `--max-warnings=0` le pipeline échoue dès le premier warning. C'est strictement et ça oblige à traiter chaque problème immédiatement. C'est inconfortable au début mais ça maintient une base de code propre sur la durée. Dans un vrai projet en équipe c'est indispensable.

---

## EX.3 — SemVer & Conventional Commits

### 3.1 — Adopter les Conventional Commits

**Q10 — 4 commits Conventional Commits**

```
feat: ajouter Prettier et eslint-config-prettier pour le formatage automatique
```
→ `feat` parce que c'est une nouvelle fonctionnalité ajoutée au projet (nouvel outil de qualité)

```
fix: corriger les conflits de règles entre ESLint et Prettier
```
→ `fix` parce que c'est la correction d'un dysfonctionnement (les deux outils se contredisaient)

```
chore: ajouter Husky et commitlint pour valider les messages de commit
```
→ `chore` parce que c'est une tâche de maintenance/outillage, ça ne touche pas au code source du produit

```
refactor: réorganiser les scripts npm avec lint, format et format:check séparés
```
→ `refactor` parce qu'on réorganise sans changer le comportement final, juste la structure des scripts

---

**Q11 — Tentative de commit invalide avec commitlint**

J'ai essayé de commiter avec le message `ajout truc`. Avec Husky + commitlint configuré, le hook `commit-msg` s'est déclenché et a bloqué le commit :

```
⧺ Running commit-msg hook...
✖  subject may not be empty [subject-empty]
✖  type may not be empty [type-empty]

✖  found 2 problems, 0 warnings
```

Pour corriger j'ai relancé avec un message valide : `chore: ajout de la configuration commitlint`.

---

### 3.2 — Calculer la prochaine version

**Q12 — Calcul de la prochaine version depuis git log**

```bash
git log --oneline
```

En listant l'historique depuis le début du projet, on trouve les types de commits suivants :
- `feat:` (setup projet, jobs parallèles, matrice Node, seuil coverage, Dockerfile, semver+trivy, deploy staging/prod, Prettier...) → plusieurs MINOR
- `fix:` (bug add(), suppression variable, NODE_ENV, reset lockfile...) → plusieurs PATCH
- `test:` et `ci:` et `chore:` → pas d'impact sur la version
- Aucun `BREAKING CHANGE` → pas de MAJOR

Calcul : on part de `0.0.0`. Les `feat` font monter le MINOR. Il y a eu plusieurs feat donc MINOR > 0. Mais la convention SemVer dit qu'avant `v1.0.0` tout est considéré instable. Vu qu'on part d'un projet "premier CICD" avec des feat multiples, la prochaine version logique est **`v1.0.0`** — c'est la première release stable qu'on publie officiellement.

---

**Q13 — v1.3.2, ajout d'un paramètre optionnel : MINOR ou MAJOR ?**

C'est **moi qui ai raison**, c'est un MINOR. Voici pourquoi :

SemVer dit qu'un changement MAJOR c'est un changement qui **casse la compatibilité**. Si on ajoute un paramètre *optionnel* à un endpoint existant, les anciens clients qui n'envoient pas ce paramètre continuent de fonctionner exactement comme avant. Il n'y a aucune incompatibilité.

Un MAJOR ce serait : renommer l'endpoint, changer le format de la réponse, supprimer un champ, rendre obligatoire quelque chose qui était optionnel...

Donc : `v1.3.2` → `v1.4.0` (MINOR, reset du PATCH).

---

## EX.4 — Release automatique sur GitHub

### 4.1 — Créer le workflow de release

**Q14 — Structure de release.yml**

```yaml
on:
  push:
    tags:
      - 'v*.*.*'   # déclenché uniquement sur les tags qui matchent ce pattern
```

**Déclencheur** : push d'un tag `v*.*.*`. Ça évite de déclencher la release à chaque push sur main, seulement quand on tague explicitement.

**Permissions** :
```yaml
permissions:
  contents: write
```
`contents: write` est nécessaire pour que le workflow puisse créer la release GitHub (qui est liée au contenu du repo). Sans ça l'API GitHub répond 403.

**Étapes dans l'ordre** :
1. `actions/checkout@v4` avec `fetch-depth: 0` — il faut tout l'historique git pour que git-cliff puisse lire tous les commits
2. `orhun/git-cliff-action@v4` — génère le CHANGELOG depuis les commits conventionnels
3. `softprops/action-gh-release@v2` — crée la release GitHub en uploadant le CHANGELOG généré

---

**Q15 — Création du tag v1.0.0 et observation du pipeline**

```bash
git tag v1.0.0
git push origin v1.0.0
```

Dans le pipeline de release step par step :
1. **Checkout** : clone le repo avec tout l'historique (`fetch-depth: 0`)
2. **git-cliff** : lit tous les commits depuis le début, les regroupe par type (`feat`, `fix`, `ci`...), génère un fichier `CHANGELOG.md` formaté
3. **softprops/action-gh-release** : appelle l'API GitHub pour créer la release avec le tag `v1.0.0`, le titre "Release v1.0.0", et le contenu du CHANGELOG comme description

---

**Q16 — Contenu du CHANGELOG généré**

Le CHANGELOG contient tous les commits groupés par type : une section "✨ Features" avec tous les `feat:`, une section "🐛 Bug Fixes" avec les `fix:`, une section "⚙️ CI/CD" avec les `ci:`, etc. Chaque commit est listé avec son message et son hash raccourci.

Ce qui manque ou ce que j'améliorerais :
- Les commits `test:` et `chore:` sont là mais pas très utiles pour les utilisateurs → je les filtrerais dans `cliff.toml`
- Certains messages de commit ne sont pas très descriptifs ("chore: trigger pipeline") → ça montre l'importance d'avoir de bons messages dès le début
- J'ajouterais un lien vers la PR associée à chaque commit pour plus de contexte

---

**Q17 — Pourquoi maintenir les tags :v1.0.0 ET :latest**

`:v1.0.0` c'est un tag immuable — il pointe toujours exactement sur cette version précise de l'image. Si un utilisateur dit "j'utilise v1.0.0" dans son `docker-compose.yml`, dans 6 mois il aura toujours la même image. C'est indispensable pour la reproductibilité en prod.

`:latest` pointe toujours sur la version la plus récente. C'est pratique pour un environnement de dev où on veut toujours avoir le dernier truc sans se préoccuper du numéro de version.

En pratique : en **production** on utilise toujours `:v1.0.0` (version précise, pas de surprise), en **développement** ou **staging** on peut utiliser `:latest` pour toujours tester la dernière version.

---

## EX.5 — Réflexion & Recherche

### 5A — Réflexion

**Q18 — Convaincre un dev senior de adopter Prettier**

Le problème avec "mon style est parfaitement lisible" c'est que c'est subjectif. Dans une équipe de 5 devs, chacun pense que son style est le meilleur. Résultat : les diffs git sont pollués par des changements de style au lieu de vrais changements de logique.

Arguments concrets :
- **Les diffs sont plus propres** : si deux devs ont des styles différents, chaque merge génère du bruit de style. Avec Prettier, chaque diff ne contient que du code fonctionnel.
- **Ça retire une source de débat** : plus besoin de discuter en code review de "espace ou pas avant la parenthèse". Prettier décide, tout le monde passe à autre chose.
- **Ça s'intègre en 5 minutes** : `npm install prettier`, un `.prettierrc`, et un hook pre-commit. C'est pas une révolution.
- **Les grands projets l'utilisent** : React, Next.js, VS Code... tous utilisent Prettier. Si ça convient à ces équipes c'est que ça scale.

La vraie question c'est pas "est-ce que mon style est lisible", c'est "est-ce qu'on veut passer du temps à gérer le style ou se concentrer sur les vraies fonctionnalités".

---

**Q19 — v3.2.1, merge feature/new-auth avec breaking change**

On publie **v4.0.0**. C'est obligatoire : on a cassé la compatibilité avec l'API existante, c'est la définition d'un MAJOR selon SemVer.

Ce qu'on doit communiquer aux utilisateurs :
- Un **CHANGELOG clair** qui liste ce qui a changé et ce qui est cassé dans la section "Breaking Changes"
- Un **guide de migration** : "si vous utilisiez telle méthode, voici comment adapter votre code"
- Idéalement un **délai de dépréciation** : maintenir la v3.x en parallèle quelques semaines et prévenir les utilisateurs à l'avance

On doit pas juste pousser la v4.0.0 sans prévenir. Dans un contexte API publique c'est critique, les gens ont des applis en prod qui dépendent de notre version.

---

### 5B — Recherche autonome

**Q20 — semantic-release vs git-cliff**

`git-cliff` est un outil de génération de CHANGELOG. Il lit les commits conventionnels et produit un fichier Markdown bien formaté. Mais il ne crée pas le tag Git ni la release GitHub tout seul — c'est à nous de le faire dans le workflow.

`semantic-release` va plus loin : il automatise **entièrement** le cycle de release. Il analyse les commits, calcule la prochaine version, crée le tag Git, génère le CHANGELOG, crée la release GitHub, et peut publier sur npm. Tout ça sans intervention manuelle, juste avec un push sur main.

Donc c'est `semantic-release` qui automatise entièrement la création du tag ET de la release sans intervention manuelle.

---

**Q21 — Règle commitlint personnalisée + rôle du hook commit-msg**

Pour interdire les commits avec un message vide ou de moins de 10 caractères, on ajoute dans `commitlint.config.js` :

```js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'subject-min-length': [2, 'always', 10],
  },
};
```

Le niveau `2` = error (bloque le commit), `'always'` = la règle s'applique toujours, `10` = longueur minimale.

Le hook `commit-msg` de Husky s'exécute juste après que tu aies tapé ton message de commit, avant que le commit soit vraiment créé. Il reçoit en argument le fichier qui contient le message. Commitlint lit ce fichier et vérifie que le message respecte les règles. Si non, il affiche les erreurs et le commit est annulé. C'est le point de contrôle local avant que le code parte sur GitHub.
