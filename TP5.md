# EX.1 — Questions de cours CI/CD

## Partie A — Définitions et distinctions

### Q1 — Staging vs Production

Le staging et la production sont deux environnements distincts, mais le staging est censé être le "faux jumeau" de la prod. Concrètement, le staging c'est l'endroit où on teste l'application dans des conditions qui ressemblent à la réalité, mais sans mettre en danger de vrais utilisateurs. La production, c'est le vrai environnement, là où les gens utilisent vraiment l'appli.

**Exemple concret :** L'URL de base de données (`DB_URL`) est différente entre les deux. En staging on pointe vers une base de test, en prod vers la vraie base. Si on faisait une erreur de migration en staging, ça ne casse rien pour les utilisateurs. En prod, c'est un gros problème.

---

### Q2 — Les Protection Rules sur GitHub Environments

Une protection rule c'est une règle qu'on configure sur un environnement GitHub pour contrôler qui peut déployer, quand, et sous quelles conditions. Il y en a plusieurs types : les **required reviewers** (quelqu'un doit approuver avant que le job parte), le **wait timer** (un délai minimum avant que ça démarre), et les **deployment branches** (seules certaines branches ont le droit de déployer).

Le problème concret qu'elles résolvent : sans protection rules, n'importe qui peut pousser du code et déclencher un déploiement en production immédiatement, même si le code est buggé ou non validé. Avec une protection rule "required reviewers" sur la prod, le pipeline se met en pause et attend qu'un tech lead ou un PO donne son accord avant de continuer. Ça évite le classique "déploiement du vendredi à 17h sans filet".

---

### Q3 — Cycle complet d'un déploiement avec approbation manuelle

Voilà ce qui se passe de bout en bout :

1. Le développeur fait un `git push` sur la branche `main`
2. GitHub Actions se déclenche automatiquement
3. Les jobs de CI tournent en parallèle : lint, tests unitaires, etc.
4. Si la CI est verte, le job de déploiement **staging** se lance automatiquement (pas de protection rule dessus)
5. L'application est déployée sur staging, un health-check vérifie que ça répond bien
6. Le job de déploiement **production** se met en attente — GitHub envoie une notification aux reviewers désignés
7. Un tech lead (ou le PO) va sur GitHub Actions, vérifie que staging est OK, et clique sur "Approve"
8. S'il y a un wait timer (ex : 5 minutes), on attend encore ce délai
9. Le job de déploiement production se lance, déclenche le Deploy Hook vers Render
10. Un health-check vérifie que la prod répond correctement
11. Si tout est vert, le pipeline est terminé ✓ — si le health-check échoue, on rollback

---

## Partie B — Vrai / Faux

### 1. FAUX
> *"Le staging doit être configuré différemment de la production pour mieux simuler les erreurs."*

C'est faux, et c'est même l'erreur classique à éviter. Le staging doit être le **miroir le plus fidèle possible de la production** : même infrastructure, même configuration, mêmes variables d'environnement (sauf les données sensibles). Si on le configure différemment, on perd tout l'intérêt du staging. Un bug qui n'apparaît qu'en prod parce que la config de staging était différente, c'est exactement ce qu'on veut éviter.

---

### 2. VRAI
> *"Avec Blue/Green, si la version 'Green' a un bug critique, le rollback est instantané."*

Vrai. C'est justement le gros avantage du Blue/Green. L'environnement "Blue" (l'ancienne version) reste actif et intact pendant tout le déploiement de "Green". Si Green a un problème après la bascule du load balancer, on rebascule vers Blue en une seule commande — en moins de 30 secondes en général. L'ancienne version n'a jamais été éteinte, donc elle est prête à reprendre le trafic immédiatement.

---

### 3. FAUX
> *"Un Canary Release déploie la nouvelle version à 100% du trafic dès le début."*

C'est faux, c'est même l'opposé du principe du Canary. L'idée du Canary c'est de déployer progressivement : on commence par envoyer un tout petit pourcentage du trafic (ex : 5%) vers la nouvelle version, on surveille les métriques (taux d'erreur, latence, CPU...), et si tout va bien on augmente progressivement (25%, 50%, 100%). Si un problème apparaît à 5%, seuls 5% des utilisateurs ont été impactés, pas tous.

---

### 4. VRAI
> *"Dans GitHub Actions, les secrets d'un environnement sont prioritaires sur les secrets du repo."*

Vrai. GitHub Actions gère une hiérarchie de priorité : les secrets définis au niveau d'un environnement spécifique écrasent les secrets du même nom définis au niveau du repo. C'est ce qui permet d'avoir par exemple un `DB_URL` avec une valeur différente en staging et en prod, sans changer le nom de la variable dans le YAML. Le workflow utilise toujours `secrets.DB_URL`, mais la valeur injectée dépend de l'environnement dans lequel le job tourne.

---

### 5. FAUX
> *"Le mot-clé `environment:` dans un job GitHub Actions ne sert qu'à donner un nom affiché dans l'interface."*

Faux. Le mot-clé `environment:` fait bien plus que ça. Il **active toutes les protection rules** configurées pour cet environnement dans les Settings du repo : vérification des reviewers, application du wait timer, contrôle des branches autorisées. Il donne aussi accès aux secrets spécifiques à cet environnement (les environment secrets). Et en bonus, oui, il affiche aussi une URL cliquable dans l'interface si on renseigne `url:`, mais c'est le côté le moins important de la fonctionnalité.

---
 
## EX.2 — GitHub Environments
 
### Q4 — Paramètres choisis pour l'environnement staging
 
Voilà le choix que j'ai fait lors de la configuration de l'environnement `staging` dans Settings → Environments :
 
- **Required reviewers → non configuré** : le staging doit se déployer automatiquement à chaque merge sur main, une approbation manuelle ralentirait inutilement le feedback.
- **Wait timer → non configuré** : pas de délai, l'objectif du staging c'est de voir vite si ça tourne.
- **Deployment branches → Selected branches → `main`** : c'est le seul paramètre que j'ai configuré. On restreint à la branche main pour éviter qu'une branche de feature soit déployée en staging par erreur — si quelqu'un pousse sur une autre branche, le déploiement est bloqué automatiquement par GitHub.
- **Environment secrets → non configuré pour l'instant** : à ajouter plus tard quand on connectera Render.
---
 
### Q5 — Reviewer désigné sur production
 
J'ai désigné **mon propre compte GitHub** comme reviewer sur l'environnement `production`. En solo sur un TP c'est la seule option possible, mais dans un contexte réel d'équipe ce rôle irait au **tech lead** ou au **product owner** — les personnes qui ont la responsabilité de valider qu'une feature est prête à partir en prod et qui comprennent à la fois les enjeux techniques et business. L'idée c'est que la personne qui approuve ne soit pas la même que celle qui a écrit le code, pour avoir un regard extérieur.
 
---
 
### Q6 — Scénario concret pour le wait timer
 
Le wait timer est utile quand on veut s'assurer que le staging a eu le temps d'être observé avant qu'on puisse approuver la prod. Avec **10 minutes de délai** par exemple : le pipeline déploie sur staging, les 10 minutes commencent à tourner, et pendant ce temps le reviewer vérifie que l'app répond bien, que les logs ne montrent pas d'erreur, que les métriques sont stables. Sans ce délai, un reviewer pressé pourrait approuver la prod 5 secondes après le déploiement staging alors que l'app n'a pas encore vraiment "chauffé". C'est un garde-fou contre la précipitation.
 
---
 
### Q7 — Structure du job deploy-staging
 
Voilà ce que j'ai ajouté dans `ci.yml` après le job `docker` :
 
```yaml
deploy-staging:
  name: 🚀 Deploy — Staging
  runs-on: ubuntu-latest
  needs: [ docker ]
  if: github.ref == 'refs/heads/main'
  environment:
    name: staging
    url: ${{ vars.RENDER_STAGING_URL }}
  steps:
    - name: Déclencher le déploiement staging
      run: curl -s -X POST '${{ secrets.RENDER_STAGING_HOOK }}'
 
    - name: Health-check staging (10 tentatives, 15s entre chaque)
      run: |
        for i in {1..10}; do
          CODE=$(curl -s -o /dev/null -w '%{http_code}' '${{ vars.RENDER_STAGING_URL }}/health')
          [ "$CODE" = "200" ] && echo "✓ Staging OK" && exit 0
          echo "Tentative $i/10 — code $CODE — attente 15s..." && sleep 15
        done
        echo "✗ Timeout — staging ne répond pas" && exit 1
```
 
- `needs: [docker]` : le staging ne démarre que si le build Docker est vert — on déploie l'image qu'on vient de construire.
- `environment: name: staging` : active les protection rules de l'environnement staging et donne accès à son secret `RENDER_STAGING_HOOK`.
- `curl -X POST` : déclenche le Deploy Hook Render, qui lance le redéploiement de l'app.
- Le health-check boucle 10 fois avec 15s d'attente — si `/health` ne répond pas 200 en 150s, le job échoue et la prod ne peut pas démarrer.
---
 
### Q8 — Comportement observé sur GitHub Actions après le push
 
Après avoir poussé le commit sur main, voilà ce qui se passe dans l'interface GitHub Actions :
 
1. Les jobs `lint`, `test` (×2 pour Node 18 et 20) et `docker` démarrent et tournent
2. Une fois `docker` vert, `deploy-staging` se lance automatiquement — aucune intervention requise
3. Une fois `deploy-staging` vert, le job `deploy-production` apparaît avec un **indicateur jaune "Waiting"**
4. GitHub envoie une notification par email au reviewer désigné
5. Dans l'interface, un bandeau apparaît avec un bouton **"Review deployments"** — c'est là que l'approbation est demandée, juste avant que le job production puisse démarrer
6. Tant que personne n'approuve, le job reste en pause indéfiniment (jusqu'au timeout configuré)
L'approbation est donc demandée **entre la fin de deploy-staging et le début de deploy-production** — exactement au bon moment dans la chaîne.
 
---
 
### Q9 — Que se passe-t-il si un reviewer refuse ?
 
Si le reviewer clique sur "Reject", le job `deploy-production` est **annulé immédiatement** — il passe en statut "cancelled". Le job n'est pas perdu pour autant : on peut le **relancer manuellement** depuis GitHub Actions en cliquant sur "Re-run job" sur le job deploy-production, sans avoir à repousser du code. Ça redéclenche la demande d'approbation. C'est utile si le refus était une erreur, ou si on a eu le temps de corriger un problème sur staging entre-temps.
 
---
 
## EX.3 — Déploiement sur Render
 
### Q10 — Les 4 informations configurées dans Render
 
1. **Le repo GitHub connecté** : Render a besoin de savoir où est le code source pour le récupérer et le builder à chaque déploiement.
2. **La commande de build** (`npm ci --omit=dev`) : Render doit savoir comment installer les dépendances — sans ça il ne sait pas quoi faire du code.
3. **La commande de démarrage** (`node src/server.js`) : c'est la commande qui lance réellement le serveur — Render en a besoin pour faire tourner l'application une fois buildée.
4. **Les variables d'environnement** (`PORT=3000`, `NODE_ENV=production`) : l'app a besoin de savoir sur quel port écouter et dans quel mode tourner — sans `PORT`, Render ne sait pas sur quelle entrée router le trafic.
---
 
### Q11 — URL publique et route /health
 
L'URL publique générée par Render ressemble à : `https://calculator-api-xxxx.onrender.com`
 
Pour que `/health` réponde 200, j'avais déjà la route définie dans `src/server.js` :
 
```javascript
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});
```
 
J'ai aussi renseigné `healthCheckPath: /health` dans le `render.yaml` pour que Render surveille cette route et considère le déploiement comme réussi uniquement si elle répond 200.
 
---
 
### Q12 — Deux solutions contre la mise en veille (cold start)
 
1. **Passer sur un plan payant Render** (Starter ~$7/mois) : la mise en veille est désactivée, le service reste actif en permanence. C'est la solution la plus simple et la plus fiable pour une vraie production.
2. **Mettre en place un ping automatique** : un service externe comme UptimeRobot envoie une requête HTTP sur `/health` toutes les 10 minutes, maintenant le service "éveillé" artificiellement. C'est un contournement gratuit mais qui dépend d'un outil tiers.
---
 
### Q13 — Approche choisie pour connecter GitHub Actions à Render
 
J'ai choisi **Deploy Hook** plutôt qu'`autoDeploy: true`, parce qu'elle garantit que le déploiement ne se déclenche que si la CI est entièrement verte.
 
Étapes suivies :
1. Dashboard Render → Settings du service → **Deploy Hook** → copier l'URL générée
2. GitHub → Settings du repo → Environments → `staging` → **Add secret** → `RENDER_STAGING_HOOK` = l'URL copiée
3. Même chose pour `production` avec `RENDER_PROD_HOOK`
4. Dans `ci.yml`, le step de déploiement fait `curl -s -X POST '${{ secrets.RENDER_STAGING_HOOK }}'`
---
 
### Q14 — Health-check post-déploiement
 
Après le `curl` qui déclenche le Deploy Hook, j'ai ajouté ce step :
 
```yaml
- name: Health-check (10 tentatives, 15s entre chaque)
  run: |
    for i in {1..10}; do
      CODE=$(curl -s -o /dev/null -w '%{http_code}' '${{ vars.RENDER_STAGING_URL }}/health')
      [ "$CODE" = "200" ] && echo "✓ Déploiement OK" && exit 0
      echo "Tentative $i/10 — code $CODE — attente 15s..." && sleep 15
    done
    echo "✗ Timeout — health-check échoué" && exit 1
```
 
On boucle jusqu'à 10 fois avec 15s d'attente (150s max). Dès que `/health` répond 200, le job continue. Sinon il échoue avec `exit 1`, ce qui bloque automatiquement le job de production grâce au `needs: [deploy-staging]`.
 
---
 
### Q15 — autoDeploy vs Deploy Hook
 
**autoDeploy: true** — Render surveille directement GitHub et redéploie à chaque push.
- Avantages : zéro configuration CI/CD, immédiat à mettre en place
- Inconvénients : déploie même si les tests ont échoué, pas de contrôle sur l'ordre, pas de health-check intégré côté pipeline
**Deploy Hook** — GitHub Actions appelle Render via webhook après CI verte.
- Avantages : ordre garanti (tests → docker → staging → prod), health-check possible, tout est tracé dans GitHub Actions
- Inconvénients : configuration un peu plus longue, un secret supplémentaire à gérer
En production réelle, Deploy Hook est clairement préférable dès qu'on a une CI sérieuse.
 
---
 
## EX.4 — Réflexion & Trade-offs
 
### Q16 — Réponse au dev senior qui veut supprimer le staging
 
Je comprends l'argument — moins de complexité, plus de vitesse. Mais supprimer le staging revient à supprimer le seul filet de sécurité entre le code et les utilisateurs réels.
 
Les tests unitaires valident la logique du code, pas le comportement du système complet. Un bug d'intégration — une variable d'environnement manquante, un timeout réseau vers une API externe, une migration de base de données qui se passe mal — n'apparaît jamais dans les tests unitaires. Il apparaît uniquement quand on déploie sur une vraie infrastructure. Sans staging, il apparaît directement en prod, devant les utilisateurs.
 
Autre argument : la confiance. Avec un staging, l'équipe déploie sereinement parce qu'elle a déjà vu l'app tourner dans des conditions similaires. Sans staging, chaque déploiement prod est un saut dans le vide. Sur le long terme ça crée du stress, des déploiements retardés, et paradoxalement on va moins vite — pas plus vite.
 
---
 
### Q17 — Stratégie de déploiement pour une fonctionnalité de paiement critique
 
Je choisirais **Canary Release**.
 
Une fonctionnalité de paiement est critique à deux niveaux : financièrement (un bug peut entraîner des pertes d'argent, des doubles débits) et en termes de confiance utilisateur (une erreur sur le paiement fait fuir les clients durablement). On ne peut pas se permettre de l'exposer à 100% du trafic d'un coup.
 
Avec le Canary, on commence par 5% du trafic. On surveille : taux d'erreur sur les transactions, latence, taux de conversion. Si tout va bien, on monte à 25%, 50%, 100%. À chaque palier, si une métrique dépasse son seuil, rollback immédiat — seuls 5% des utilisateurs ont été exposés.
 
Blue/Green serait trop risqué ici car la bascule expose 100% du trafic d'un coup. Rolling Update poserait des problèmes avec les migrations de base de données si deux versions coexistent simultanément — dangereux sur des données financières.
 
---
 
### Q18 — Procédure d'urgence : app en erreur 500 depuis 3 minutes
 
1. **Ne pas toucher au code** — pousser un fix en urgence sous le stress aggrave souvent la situation
2. **Aller sur GitHub Actions** → identifier le run du déploiement bugué
3. **Trouver le dernier run VERT** (avant le bug) → cliquer "Re-run all jobs" → l'ancienne version est redéployée en ~2 minutes via le même pipeline
4. **Surveiller le health-check** → dès que `/health` répond 200, confirmer que les 500 ont disparu
5. **Communiquer** → informer l'équipe et si nécessaire les utilisateurs
6. **Post-mortem** → une fois le service rétabli, analyser pourquoi le staging n'a pas détecté le bug
À éviter : `git reset --hard` sur main (réécrit l'historique en équipe) et déployer un hotfix non testé sous pression.
 
---
 
### Q19 — Stratégie d'organisation des secrets (3 envs, 2 services)
 
**Niveau repo** (valeurs identiques partout) :
- `GITHUB_TOKEN` : pour pusher les images Docker sur GHCR
- `SLACK_WEBHOOK_URL` : pour les notifications d'équipe
**Niveau environment `staging`** :
- `DB_URL` : URL de la base de données de staging
- `RENDER_STAGING_HOOK` : Deploy Hook du service staging
- `API_SECRET_KEY` : clé API de staging (différente de prod pour isoler les environnements)
**Niveau environment `production`** :
- `DB_URL` : même nom de variable, valeur différente — la priorité env > repo s'applique automatiquement
- `RENDER_PROD_HOOK` : Deploy Hook du service prod
- `API_SECRET_KEY` : clé API de prod
**Pour dev** : un fichier `.env` local non commité, jamais les secrets de staging ou prod en local.
 
Règle centrale : un secret identique dans tous les environnements → niveau repo. Un secret qui change → niveau environment. On ne duplique jamais inutilement.
 
---
 
## EX.5 — Recherche autonome
 
### Q20 — GitHub Deployments API
 
Source : [docs.github.com/en/rest/deployments](https://docs.github.com/en/rest/deployments)
 
La GitHub Deployments API est une API REST qui permet de créer et suivre des déploiements directement dans l'interface GitHub, indépendamment de l'outil de déploiement utilisé. Elle permet d'associer un commit ou une branche à un déploiement sur un environnement donné, et de mettre à jour son statut (pending, success, failure, inactive).
 
Dans un pipeline CI/CD, on peut l'utiliser pour créer un enregistrement de déploiement au début du job (`POST /repos/{owner}/{repo}/deployments`), puis mettre à jour son statut à la fin (`POST /repos/{owner}/{repo}/deployments/{deployment_id}/statuses`). Ces déploiements apparaissent dans l'onglet "Environments" du repo avec un historique cliquable et des liens vers les URLs déployées — on voit quel commit est déployé où, depuis quand, et avec quel résultat, directement dans GitHub sans chercher dans les logs.
 
---
 
### Q21 — Variables vs Secrets dans GitHub Actions
 
Source : [docs.github.com/en/actions/security-guides/using-secrets-in-github-actions](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
 
Les **secrets** (`secrets.*`) sont chiffrés côté GitHub et ne sont jamais affichés dans les logs — même si on essaie de les `echo`, GitHub les masque avec `***`. Les **variables** (`vars.*`) sont stockées en clair, visibles dans les logs et dans l'interface Settings.
 
Exemples pour les secrets :
- `RENDER_DEPLOY_HOOK` : une URL de webhook — si quelqu'un la récupère il peut déclencher un déploiement
- `DB_PASSWORD` : mot de passe de base de données — exposition directe = brèche de sécurité
Exemples pour les variables :
- `RENDER_STAGING_URL` = `https://mon-app-staging.onrender.com` — pas sensible, et la voir dans les logs facilite le debug
- `NODE_ENV=production` — valeur de configuration qu'on veut pouvoir modifier sans toucher au YAML
---
 
### Q22 — Render Preview Environments
 
Source : [docs.render.com/preview-environments](https://docs.render.com/preview-environments)
 
Les Preview Environments sur Render sont des environnements éphémères créés automatiquement à chaque ouverture d'une Pull Request. Quand un dev ouvre une PR, Render détecte l'événement via GitHub, déploie automatiquement la branche sur un environnement temporaire avec sa propre URL (ex: `https://mon-app-pr-42.onrender.com`), et détruit cet environnement quand la PR est fermée ou mergée.
 
C'est utile pour la revue de code parce que le reviewer n'a pas besoin de cloner la branche en local pour tester — il clique sur l'URL dans la PR et voit directement le résultat. C'est particulièrement efficace pour les reviewers non-techniques (designers, PO) qui peuvent valider visuellement une feature sans toucher à Git.
 
Est-ce que ça remplace le staging ? Non. Les Preview Environments sont isolés et éphémères — parfaits pour valider une feature spécifique en cours de PR, mais ils ne reproduisent pas l'état complet de la production (données réelles, charge, intégrations). Le staging reste nécessaire pour valider le système complet avant de partir en prod. Les deux sont complémentaires : Preview pour la revue de PR, staging pour la validation finale.
