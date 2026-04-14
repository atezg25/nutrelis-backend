# PROCÉDURE DE REPRISE APRÈS SINISTRE — NUTRELIS

> Dernière mise à jour : 2026-04-14
> Temps estimé de reprise complète : 30-60 minutes

---

## ARCHITECTURE À RESTAURER

| Service        | Plateforme | URL                                                        |
|----------------|------------|------------------------------------------------------------|
| Frontend       | Vercel     | https://nutrelis.bio                                       |
| Backend Medusa | Railway    | https://nutrelis-backend-production.up.railway.app         |
| Base de données| Railway    | PostgreSQL 18 dans projet "clever_curiosity"               |
| Domaine        | Registrar  | nutrelis.bio (A + CNAME vers Vercel)                       |
| Code frontend  | GitHub     | github.com/atezg25/Nutrelis                                |
| Code backend   | GitHub     | github.com/atezg25/nutrelis-backend                        |

---

## SCÉNARIO 1 — LA BASE DE DONNÉES EST PERDUE

C'est le scénario le plus critique (déjà survenu le 2026-04-14).

### Étape 1 : Récupérer le fichier backup

Le backup le plus récent se trouve dans :
- **Local** : `\\wsl.localhost\Ubuntu\home\anicet\nutrelis-backups\`
- **Google Drive** : dossier personnel (copie du .sql.gz)

Fichier : `nutrelis_backup_YYYY-MM-DD_HH-MM.sql.gz` (~38 Ko)

### Étape 2 : Obtenir la nouvelle DATABASE_URL

Si Railway a créé une nouvelle base (nouveau projet ou nouveau service Postgres) :
1. Aller sur https://railway.com → projet concerné → service Postgres
2. Onglet **Variables** → copier `DATABASE_URL`
3. **IMPORTANT** : utiliser l'URL **publique** (pas l'URL interne), elle ressemble à :
   ```
   postgresql://postgres:MOTDEPASSE@HOTE.proxy.rlwy.net:PORT/railway
   ```

Si la base existe encore (même projet "clever_curiosity") :
```
postgresql://postgres:pmoEdQeGBhFNlRaFewyNGelMXiHSSaTu@maglev.proxy.rlwy.net:23301/railway
```

### Étape 3 : Restaurer la base

Ouvrir un terminal WSL Ubuntu et exécuter :

```bash
# S'assurer que psql v18 est dans le PATH
export PATH="/usr/lib/postgresql/18/bin:$PATH"

# Vérifier la version
psql --version
# Doit afficher : psql (PostgreSQL) 18.x

# Restaurer (REMPLACE toutes les données actuelles)
gunzip -c ~/nutrelis-backups/nutrelis_backup_2026-04-14_16-55.sql.gz | psql "postgresql://postgres:pmoEdQeGBhFNlRaFewyNGelMXiHSSaTu@maglev.proxy.rlwy.net:23301/railway" --quiet
```

Ou via le script :
```bash
export PATH="/usr/lib/postgresql/18/bin:$PATH"
cd ~/projets/nutrelis-backend
bash scripts/restore.sh ~/nutrelis-backups/nutrelis_backup_2026-04-14_16-55.sql.gz "postgresql://postgres:pmoEdQeGBhFNlRaFewyNGelMXiHSSaTu@maglev.proxy.rlwy.net:23301/railway"
# Taper "oui" pour confirmer
```

### Étape 4 : Mettre à jour DATABASE_URL sur Railway (si l'URL a changé)

1. Railway → projet → service backend (pas le Postgres)
2. Variables → modifier `DATABASE_URL` avec la nouvelle URL publique
3. **Ne PAS ajouter REDIS_URL** (ça fait crasher si pas de Redis)

### Étape 5 : Redémarrer le backend

Railway → service backend → **Deployments** → **Restart**

Ou via CLI :
```bash
# Si railway CLI installé
railway up
```

### Étape 6 : Vérifier

```bash
# Tester que l'API répond
curl -s https://nutrelis-backend-production.up.railway.app/health

# Tester que les produits existent
curl -s https://nutrelis-backend-production.up.railway.app/store/products | head -100

# Tester le site
curl -s -o /dev/null -w "%{http_code}" https://nutrelis.bio
# Doit retourner : 200
```

---

## SCÉNARIO 2 — LE BACKEND RAILWAY EST SUPPRIMÉ

### Étape 1 : Recréer le service sur Railway

1. https://railway.com → **New Project** → **Deploy from GitHub repo**
2. Sélectionner `atezg25/nutrelis-backend`
3. Ajouter un service **PostgreSQL** dans le même projet

### Étape 2 : Configurer les variables d'environnement

Dans Railway → service backend → Variables, ajouter **toutes** ces variables :

```env
DATABASE_URL=<URL PUBLIQUE du nouveau Postgres>
JWT_SECRET=b5d918dc<reste du secret — voir backup des variables>
COOKIE_SECRET=6a64e0e5<reste du secret — voir backup des variables>
NODE_ENV=production
STORE_CORS=https://nutrelis.bio,https://www.nutrelis.bio,https://nutrelis-v76z.vercel.app
ADMIN_CORS=https://<nouvelle-url-railway>
AUTH_CORS=https://nutrelis.bio,https://www.nutrelis.bio,https://nutrelis-v76z.vercel.app,https://<nouvelle-url-railway>
```

**NE PAS AJOUTER** : `REDIS_URL` (crash si absent)

### Étape 3 : Restaurer la base

Suivre les étapes 2-3-5-6 du Scénario 1.

### Étape 4 : Mettre à jour le frontend (si l'URL Railway a changé)

1. Vercel → projet Nutrelis → Settings → Environment Variables
2. Modifier `NEXT_PUBLIC_MEDUSA_BACKEND_URL` avec la nouvelle URL Railway
3. **Redéployer** le frontend : Vercel → Deployments → Redeploy

### Étape 5 : Mettre à jour le webhook Notchpay

Si l'URL backend a changé, aller sur le dashboard Notchpay et mettre à jour l'URL du webhook.

---

## SCÉNARIO 3 — LE FRONTEND VERCEL EST SUPPRIMÉ

### Étape 1 : Redéployer depuis GitHub

1. https://vercel.com → **Add New** → **Project** → importer `atezg25/Nutrelis`
2. Framework : **Next.js**

### Étape 2 : Configurer les variables d'environnement

Dans Vercel → Settings → Environment Variables :

```env
NEXT_PUBLIC_URL=https://nutrelis.bio
NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://nutrelis-backend-production.up.railway.app
NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_658f5e64c031fa4c79d374f65da3688b13a92fc695e9cccaa6ec41ed12607f65
NEXT_PUBLIC_GOOGLE_CLIENT_ID=141147213471-...
NOTCHPAY_PUBLIC_KEY=pk_test.rFULK...
NOTCHPAY_SECRET_KEY=sk_test.zejAn...
RESEND_API_KEY=re_cATJdw...
MEDUSA_REGION_ID=reg_01KP6P8GQM37FW4H0PEVAV2V6S
WHATSAPP_ENABLED=false
SMS_ENABLED=false
```

### Étape 3 : Reconnecter le domaine

1. Vercel → Settings → Domains → ajouter `nutrelis.bio` et `www.nutrelis.bio`
2. Vérifier les DNS chez le registrar :
   - `A @ → 76.76.21.21` (ou l'IP que Vercel indique)
   - `CNAME www → cname.vercel-dns.com` (ou celui que Vercel indique)

---

## SCÉNARIO 4 — LE DOMAINE NUTRELIS.BIO EXPIRE OU DNS CASSÉ

### Vérifier les DNS actuels :
```bash
nslookup nutrelis.bio
nslookup www.nutrelis.bio
```

### DNS corrects à configurer :
| Type  | Nom  | Valeur                                        |
|-------|------|-----------------------------------------------|
| A     | @    | 216.198.79.1                                  |
| CNAME | www  | 34881675f58b16b3.vercel-dns-017.com           |

Plus les enregistrements email Resend (SPF/DKIM/DMARC).

---

## PROCÉDURE DE BACKUP RÉGULIER

### Backup manuel (à faire au minimum 1x/semaine) :

```bash
wsl.exe bash -c 'export PATH="/usr/lib/postgresql/18/bin:${PATH}" && cd /home/anicet/projets/nutrelis-backend && bash scripts/backup.sh "postgresql://postgres:pmoEdQeGBhFNlRaFewyNGelMXiHSSaTu@maglev.proxy.rlwy.net:23301/railway"'
```

Puis copier le fichier sur Google Drive depuis :
```
\\wsl.localhost\Ubuntu\home\anicet\nutrelis-backups\
```

Le script garde automatiquement les **10 derniers** backups.

### Vérifier qu'un backup est valide :

```bash
wsl.exe bash -c 'gunzip -c ~/nutrelis-backups/nutrelis_backup_YYYY-MM-DD_HH-MM.sql.gz | head -5'
```

Doit afficher :
```
--
-- PostgreSQL database dump
--
```

Si le fichier fait **moins de 1 Ko**, il est vide/corrompu → refaire le backup.

---

## IDENTIFIANTS MEDUSA (après restauration)

Ces IDs sont dans le backup et seront restaurés automatiquement :

| Ressource       | ID                                          |
|-----------------|---------------------------------------------|
| Région Cameroun | reg_01KP6P8GQM37FW4H0PEVAV2V6S             |
| Sales Channel   | sc_01KP6P8H5V10KASKT1GGGT0T2K              |
| Produit         | prod_01KP6P8K8S7GS849F23BKQ12ZG            |
| Variant 1 pot   | variant_01KP6P8KBNK8FHKTHASCGR52N9         |
| Variant 2 pots  | variant_01KP6P8KBP8MRCKMT3H11HSEA9         |
| Variant 3 pots  | variant_01KP6P8KBQ00FRQP9GDVWC1ERX         |

Admin Medusa : `atezg25@gmail.com` / `Papaisrael@777`

---

## PIÈGES CONNUS

1. **CORS** : toujours inclure `https://nutrelis.bio` ET `https://www.nutrelis.bio`
2. **REDIS_URL** : ne JAMAIS l'ajouter si pas de Redis → crash Knex timeout
3. **DATABASE_URL** : utiliser l'URL **publique** (proxy), pas l'URL interne Railway
4. **sales_channel_id** : le cart Medusa nécessite le sales_channel_id à la création
5. **pg_dump** : doit être v18+ pour dump/restore le serveur PostgreSQL 18
6. **Notchpay** : les clés sont encore en mode TEST → les changer avant de vendre
