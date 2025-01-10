

# 📜Guide d'utilisation du script Bash avec `dialog`

## 🎯Introduction
Ce script utilise la commande `dialog` pour créer une interface utilisateur interactive dans le terminal. Il inclut des menus pour :
- 👤La gestion des utilisateurs.
- 💻La gestion des ordinateurs.
- 🔐Une connexion SSH sécurisée.

---

## Fonctionnement général
# Les étapes

### 🔐**Connexion SSH**

```

local choix=$(dialog --stdout \
        --title "Connexion SSH" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Connexion en SSH à un poste client")

    case $choix in
    1)
        # Demande des informations de connexion
        Utilisateur=$(dialog --stdout --inputbox "Entrez le nom d'utilisateur client" 8 40)
        IP=$(dialog --stdout --inputbox "Entrez l'adresse IP de l'ordinateur distant" 8 40)
        Port=22
        MotDePasse=$(dialog --stdout --insecure --passwordbox "Entrez le mot de passe pour ${Utilisateur}" 8 40)

        # Exécution de la commande SSH
        resultat=$(sshpass -p "${MotDePasse}" ssh ${Utilisateur}@${IP} -p ${Port} "echo 'Connexion SSH réussie à ${Utilisateur}@${IP}'")

        # Affichage du résultat
        dialog --msgbox "$resultat" 8 40
        ;;
    *)
        # Quitter le script en cas d'option invalide
        clear
        exit 0
        ;;
    esac
}
```  


Option	Fonctionnalité :  

* --inputbox: Permet à l'utilisateur de saisir du texte, généralement utilisé pour demander le nom d'utilisateur et l'adresse IP dans ce contexte.  
* --passwordbox: Assure une saisie sécurisée du mot de passe, masquant les caractères saisis pour des raisons de confidentialité.  
* sshpass: Un utilitaire externe qui automatise la saisie du mot de passe pour les commandes SSH, rendant la connexion plus fluide.  


### 🏠Menu Principal

```menu_principal() {
    local choix=$(dialog --stdout \
        --title "Menu Principal" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Gestion des utilisateurs" \
        2 "Gestion des ordinateurs")

    case $choix in
    1)
        menu_util
        ;;
    2)
        menu_ordi
        ;;
    *)
        clear
        exit 0
        ;;
    esac
}
```

Options principales :
* --title : Titre de la fenêtre.
* --menu : Affiche des options avec un menu interactif.
* 15 50 6 : Définit la taille de la fenêtre (15 lignes, 50 colonnes) et le nombre maximal d'options visibles.

### Sous-menus

## 👤 Menu Utilisateur

```menu_util() {
    local choix=$(dialog --stdout \
        --title "Menu Utilisateur" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Informations utilisateur" \
        2 "Actions sur les utilisateurs" \
        3 "Retour au menu principal")
    ...
}
```

Ce menu offre des options pour :

Afficher des informations utilisateur.
Gérer les comptes utilisateur (création, suppression, modification).

## 💾Menu Ordinateur

```menu_ordi() {
    local choix=$(dialog --stdout \
        --title "Menu Ordinateur" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Obtenir des informations sur l'ordinateur" \
        2 "Effectuer des actions sur l'ordinateur" \
        3 "Retour au menu précédent")
    ...
}
```

Inclut des fonctionnalités pour :

Afficher les informations du système (disques, RAM, système d'exploitation).
Gérer l'alimentation, les répertoires, et les logiciels.

## 🔧Exécution de commandes distantes

```
executer_commande() {
    local commande="$1"
    sshpass -p "${MotDePasse}" ssh ${Utilisateur}@${IP} -p ${Port} "$commande" 2>&1
}
```

Cette fonction centralise l'exécution de commandes sur une machine distante via SSH.

### 📂Gestion des Répertoires
## 📂Création d'un répertoire

```menu_gestion_repertoires() {
    local chemin=$(dialog --stdout --inputbox "Entrez le chemin du répertoire à créer :" 8 40)
    if [ -n "$chemin" ]; then
        if executer_commande "mkdir -p '$chemin'"; then
            dialog --msgbox "Répertoire '$chemin' créé avec succès." 8 40
        else
            dialog --msgbox "Échec de la création du répertoire '$chemin'." 8 40
        fi
    else
        dialog --msgbox "Chemin non fourni." 8 40
    fi
}
```

### ⚡ Gestion des Logiciels

## 🛠️ Installer un logiciel

```menu_gestion_logiciels() {
    local logiciel=$(dialog --stdout --inputbox "Entrez le nom du logiciel à installer :" 8 40)
    if [ -n "$logiciel" ]; then
        if executer_commande "sudo apt install -y '$logiciel'"; then
            dialog --msgbox "Logiciel '$logiciel' installé avec succès." 8 40
        else
            dialog --msgbox "Échec de l'installation de '$logiciel'." 8 40
        fi
    else
        dialog --msgbox "Nom du logiciel non fourni." 8 40
    fi
}
```

Résumé des principales commandes dialog

## ✨ Options	Description
* --title	Définit le titre de la fenêtre.
* --menu	Affiche un menu avec des options.
* --inputbox	Demande une saisie utilisateur.
* --msgbox	Affiche un message d'information.
* --passwordbox	Permet une saisie sécurisée du mot de passe.
* --yesno	Affiche une boîte de dialogue Oui/Non.

### 🚀 Lancement du script
Pour exécuter le script, utilisez la commande suivante :

```
chmod +x script.sh
./script.sh
```
📜Guide d'utilisation du script Powershell avec windows form

