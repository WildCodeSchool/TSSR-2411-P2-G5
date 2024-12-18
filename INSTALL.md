

# 🖥️ Les clients

## 💻 Client Windows 10
- **Nom** : CLIWIN01
- **Compte utilisateur** : wilder (dans le groupe des admins locaux)
- **Mot de passe** : Azerty1*
- **Adresse IP fixe** : 172.16.10.20/24

## 🐧 Client Ubuntu 22.04/24.04 LTS
- **Nom** : CLILIN01
- **Compte utilisateur** : wilder (dans le groupe sudo)
- **Mot de passe** : Azerty1*
- **Adresse IP fixe** : 172.16.10.30/24

# 🖲️ Les serveurs

## 🪟 Serveur Windows Server 2022
- **Nom** : SRVWIN01
- **Compte** : Administrator (dans le groupe des admins locaux)
- **Mot de passe** : Azerty1*
- **Adresse IP fixe** : 172.16.10.5/24

## 🐧 Serveur Debian 12
- **Nom** : SRVLX01
- **Compte** : root
- **Mot de passe** : Azerty1*
- **Adresse IP fixe** : 172.16.10.10/24
 # Etape script Bash
 
Nous avons choisi d'utiliser l'outil **Dialog** pour ce projet, car il offre une interface visuelle agréable, facile à configurer, et propose une ergonomie de menus adaptée à nos besoins. Cet outil nous a permis de concevoir des menus dotés de sous-menus, permettant d'activer différentes fonctions pour réaliser des actions variées sur un ordinateur distant, dans le cadre d'une architecture client-serveur.

### Les principales étapes et défis rencontrés :
1. **Apprentissage et configuration de Dialog**  
   La première difficulté a été d’apprendre à configurer correctement Dialog et à écrire les commandes adaptées pour obtenir l'affichage souhaité.
   ![](https://github.com/WildCodeSchool/TSSR-2411-P2-G5/blob/main/Picture/dialog%20capture.png)

3. **Connexion SSH pour l'accès distant**  
   Nous avons mis en place une connexion SSH afin d'accéder à l'ordinateur distant. Cela a permis d'exécuter diverses actions et de collecter toutes les informations demandées directement depuis le client.

4. **Implémentation de la gestion des logs**  
   Une étape délicate a été la mise en place d'un système de sauvegarde qui enregistre toutes les entrées et actions effectuées dans un fichier journal (**log file**). Ce mécanisme est essentiel pour assurer un suivi précis des opérations réalisées.

Grâce à ces étapes, nous avons pu créer une solution fonctionnelle et ergonomique pour gérer un système distant de manière efficace.
