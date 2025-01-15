#!/bin/bash

# Point d'entrée du script
main() {

    # Journalise le lancement du script
    log_evt "********StartScript********"

    # Vérifier les privilèges root
    if [ "$(id -u)" -ne 0 ]; then
        echo "Ce script nécessite des privilèges root. Utilisez sudo."
        exit 1
    fi

    # Vérifier la présence de dialog
    if ! command -v dialog &> /dev/null; then
        echo "le packet Dialog est requis. Installation..."
        sudo apt-get install dialog -y
        exit 1
    fi
    
    # Vérifier la présence de sshpass
    if ! command -v sshpass &> /dev/null; then
        echo "Le paquet 'sshpass' est requis. Installation..."
        sudo apt-get install sshpass -y
        exit 1
    fi
    
    menu_intro
}


# Fonction pour journaliser les événements dans log_evt.log
log_evt(){
    local user_action="\$1"
    local target_host="${IP:-Non défini}"  # Utilise "Non défini" si IP n'est pas définie
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local username="${Utilisateur:-Système}"  # Utilise "Système" si Utilisateur n'est pas défini
    local log_file="/var/log/log_evt.log"
    
    # Créer le répertoire de logs s'il n'existe pas
    mkdir -p "$(dirname "$log_file")"
    
    # Vérifier les permissions du fichier de log
    if [ ! -f "$log_file" ]; then
        touch "$log_file"
        chmod 640 "$log_file"  # Permissions restrictives pour la sécurité
    fi

    # Format du log : [TIMESTAMP] USERNAME@HOST - ACTION (STATUS)
    if [[ "$user_action" == *"Connexion SSH"* ]]; then
        # Pour les événements SSH, ajouter plus de détails
        local status="${user_action#*- }"  # Extrait le statut après le tiret
        local connection_details="Port: ${Port:-22}"
        echo "[$timestamp] ${username}@${target_host} - ${user_action} (${connection_details})" >> "$log_file"
    else
        # Pour les autres événements, format standard
        echo "[$timestamp] ${username}@${target_host} - ${user_action}" >> "$log_file"
    fi

    # Rotation des logs si le fichier dépasse 5MB
    if [ -f "$log_file" ] && [ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file") -gt 5242880 ]; then
        local backup_file="${log_file}.$(date +%Y%m%d-%H%M%S).bak"
        mv "$log_file" "$backup_file"
        gzip "$backup_file" &  # Compression en arrière-plan
        touch "$log_file"
        chmod 640 "$log_file"
    fi
}
# Fonction menu intro
menu_intro() {
    local choix=$(dialog --stdout \
        --title "Menu de démarrage du script" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Gestion des utilisateurs ou ordinateurs" \
        2 "Affichage des logs" )

    case $choix in
        1)
            connexion_ssh
            ;;
        2)
            log_evt "Accès au menu des logs"
	    view_logs
            ;;
        *)
            clear
            exit 0
            ;;
    esac
}

# Fonction pour afficher les logs
view_logs() {
    local log_file="/var/log/log_evt.log"
    
    if [ -f "$log_file" ]; then
        dialog --title "Journal des actions" \
               --textbox "$log_file" 20 80
    else
        dialog --msgbox "Aucun journal trouvé." 8 40
    fi
    clear
}

# Fonction pour se connecter à un ordinateur distant via SSH
connexion_ssh() {
    log_evt "Accès à la fonction de connexion SSH"
    local choix=$(dialog --stdout \
    --title "Connexion SSH" \
    --menu "Veuillez choisir une option :" 15 50 6 \
    1 "Connexion en SSH à un poste client" )

    case $choix in
    1)
        # Demander le nom d'utilisateur du client
        Utilisateur=$(dialog --stdout --inputbox "Entrez le nom d'utilisateur client" 8 40)
        
        # Demander l'adresse IP
        IP=$(dialog --stdout --inputbox "Entrez l'adresse IP de l'ordinateur distant" 8 40)
        
        # Définir le port SSH
        Port=22
        
        # Demander le mot de passe pour SSH
        MotDePasse=$(dialog --stdout --insecure --passwordbox "Entrez le mot de passe pour ${Utilisateur}" 8 40)

        # Test de connexion SSH avec timeout
        if sshpass -p "${MotDePasse}" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ${Utilisateur}@${IP} -p ${Port} "echo 'Test connection'" &>/dev/null; then
            log_evt "Connexion SSH réussie à ${IP}"
            dialog --msgbox "Connexion SSH établie avec succès" 8 40
            menu_principal
        else
            log_evt "Échec de connexion SSH à ${IP}"
            dialog --msgbox "Échec de la connexion SSH. Vérifiez:\n- L'adresse IP\n- Le nom d'utilisateur\n- Le mot de passe\n- Que le service SSH est actif sur la machine distante" 12 60
            clear
            connexion_ssh
        fi
        ;;
    *)
        clear
        exit 0
        ;;
    esac
}


# Fonction pour exécuter une commande via SSH sans répétition dans chaque sous-menu
executer_commande() {
    # Passez la commande à exécuter sur la machine distante comme argument
    local commande="$1"
    local description="\$2"  # Description optionnelle de la commande
    
    # Journaliser la commande
    if [ -z "$description" ]; then
        log_evt "Exécution: $commande"
    fi
    
    # Exécution de la commande via SSH sans répéter sshpass
    sshpass -p "${MotDePasse}" ssh ${Utilisateur}@${IP} -p ${Port} "$commande" 2>&1
}

# Fonction menu principal
menu_principal() {
    log_evt "Accès au menu principal"
    local choix=$(dialog --stdout \
        --title "Menu Principal" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Gestion des utilisateurs" \
        2 "Gestion des ordinateurs" )

    case $choix in
        1)
            log_evt "Accès à la gestion des utilisateurs"
            menu_users
            ;;
        2)
            log_evt "Accès à la gestion des ordinateurs"
            menu_ordi
            ;;
        *)
            log_evt "Sortie du script"
            clear
            exit 0
            ;;
    esac
}


# Fonctions menu utilisateur

# Fonction pour sauvegarder le contenu dans un fichier
save_to_file() {
    local content="$1"
    local type="$2"
    local user="$3"
    
    # Créer un répertoire de sauvegarde s'il n'existe pas
    local save_dir="/var/log/user_activity_logs"
    mkdir -p "$save_dir"
    
    # Générer un nom de fichier avec date et heure
    local timestamp=$(date "+%d-%m-%Y_%H-%M-%S")
    local filename="${save_dir}/${user}_${type}_${timestamp}.txt"
    
    # Sauvegarder le contenu
    echo "$content" > "$filename"
    
    # Afficher un message de confirmation
    dialog --msgbox "Fichier sauvegardé :\n$filename" 10 50
}

# Fonction du menu principal
menu_users() {
    local choix=$(dialog --stdout \
        --title "Menu Principal de Gestion des Utilisateurs" \
        --menu "Veuillez choisir une option :" 30 100 15 \
        1 "Afficher la liste des utilisateurs" \
        2 "Créer un compte utilisateur" \
        3 "Modifier le mot de passe" \
        4 "Supprimer un compte utilisateur" \
        5 "Modifier les utilisateurs d'un groupe" \
        6 "Historique d'activité d'un utilisateur" \
	7 "Retour menu principal")
    
    case $choix in
        1)
            list_users
            menu_users ;;
        2)    
            create_user
            menu_users ;;
        3)
            modify_password
            menu_users ;;
        4)
            delete_user
            menu_users ;;
        5)
            modify_group_rights
            menu_users ;;
        6)
            user_selection
            menu_users ;;
        7)
	    menu_principal ;;
        *)
            clear
            exit 0 ;;
    esac
}


# Fonction pour afficher la liste des utilisateurs
list_users() {
    # Créer un fichier temporaire pour stocker la liste des utilisateurs
    local temp_file=$(mktemp)
    
    # Récupérer la liste des utilisateurs humains (UID >= 1000 et < 60000)
    local resultat=$(executer_commande "getent passwd | awk -F: '\$3 >= 1000 && \$3 < 60000 { printf \"%s:%s:%s:%s:%s:%s:%s\\n\", \$1, \$2, \$3, \$4, \$5, \$6, \$7 }'") 
    
    # Vérifier si des utilisateurs ont été trouvés
    if [ -z "$resultat" ]; then
        dialog --msgbox "Aucun utilisateur trouvé." 10 40
        return 1
    fi
    
    #Sauvegarder le résultat dans le fichier temporaire
    echo "$resultat" > "$temp_file"

    # Chemin pour sauvegarder la liste des utilisateurs
    local log_dir="/var/log/user_activity_logs"
    mkdir -p "$log_dir"

    # Afficher la liste avec des boutons d'action
       dialog --extra-button \
        --extra-label "Sauvegarder" \
        --cancel-label "Retour" \
        --textbox "$temp_file" 20 100 \
        2>&1 >/dev/tty

    # Gérer les actions
    local exit_status=$?
    if [ $exit_status -eq 3 ]; then
          
    # Bouton Sauvegarder
        local timestamp=$(date "+%d-%m-%Y_%H-%M-%S")
        local output_file="${log_dir}/utilisateurs_${timestamp}.txt"
           
        if cp "$temp_file" "$output_file"; then
           dialog --msgbox "Liste sauvegardée dans :\n$output_file" 10 50
        else
           dialog --msgbox "Erreur lors de la sauvegarde du fichier." 10 40
        fi
    fi        
  
    # Nettoyer le fichier temporaire
    rm "$temp_file"
}

# Fonction pour créer un compte utilisateur
create_user() {
    # Demander le nom d'utilisateur
    dialog --inputbox "Entrez le nom d'utilisateur à créer :" 10 40 2> /tmp/username.txt
    username=$(cat /tmp/username.txt)
    
    # Vérifier que le nom d'utilisateur n'est pas vide
    if [ -z "$username" ]; then
        dialog --msgbox "Nom d'utilisateur invalide." 10 40
        return 1
    fi

    # Demander le prénom et nom complet
    dialog --inputbox "Entrez le prénom et nom complet de l'utilisateur :" 10 40 2> /tmp/fullname.txt
    fullname=$(cat /tmp/fullname.txt)

    # Demander le poste de l'utilisateur
    local poste_choices=(
        "Administration" "Informatique" "Comptabilité" 
        "Commercial" "Production" "Marketing" 
        "Ressources Humaines" "Service Client"
    )
    
    local menu_items=()
    for ((i=0; i<${#poste_choices[@]}; i++)); do
        menu_items+=($((i+1)) "${poste_choices[i]}")
    done
    
    local poste_choice=$(dialog --menu "Sélectionnez le poste de l'utilisateur :" 20 50 9 \
        "${menu_items[@]}" \
        2>&1 >/dev/tty)
    
    # Récupérer le poste sélectionné
    if [ -n "$poste_choice" ]; then
        poste="${poste_choices[$((poste_choice-1))]}"
    else
        poste="Non spécifié"
    fi

    # Demander le mot de passe
    dialog --passwordbox "Entrez le mot de passe pour $username :" 10 40 2> /tmp/userpass.txt
    userpass=$(cat /tmp/userpass.txt)

    # Nettoyer les fichiers temporaires
    rm -f /tmp/username.txt /tmp/fullname.txt /tmp/userpass.txt

    # Construire la commande pour la machine distante
    local commande="
        sudo useradd -c \"${fullname} - ${poste}\" -m \"${username}\" && \
        echo \"${username}:${userpass}\" | sudo chpasswd && \
        sudo mkhomedir_helper \"${username}\" && \
        echo \"Compte créé : Nom d'utilisateur=${username}, Nom complet=${fullname}, Poste=${poste}\"
    "

    # Exécution de la commande via SSH
    local resultat=$(executer_commande "$commande")

    # Vérifier si la commande a réussi
    if echo "$resultat" | grep -q "Compte créé"; then
        dialog --msgbox "Compte créé avec succès :\n\n$resultat" 14 50
    else
        dialog --msgbox "Erreur lors de la création de l'utilisateur :\n\n$resultat" 14 50
    fi
}

# Fonction pour modifier le mot de passe d'un compte
modify_password() {
    # Demander le nom d'utilisateur
    dialog --inputbox "Entrez le nom d'utilisateur dont vous voulez modifier le mot de passe :" 10 40 2> /tmp/username.txt
    username=$(cat /tmp/username.txt)
    
    # Vérifier que l'utilisateur existe
    if [ -z "$username" ]; then
        dialog --msgbox "Erreur : L'utilisateur $username n'existe pas." 8 40
        return 1
    fi
    
    # Vérifier que l'utilisateur existe sur la machine distante
    local check_user="id $username >/dev/null 2>&1"
    if ! executer_commande "$check_user"; then
        dialog --msgbox "Erreur : L'utilisateur $username n'existe pas sur la machine distante." 8 50
        return 1
    fi

    # Boucle pour la saisie et confirmation du mot de passe
    while true; do
        # Premier mot de passe
        dialog --passwordbox "Entrez le nouveau mot de passe pour $username :" 10 40 2> /tmp/pass1.txt
        pass1=$(cat /tmp/pass1.txt)
        rm -f /tmp/pass1.txt
        
        # Vérifier si le mot de passe est vide
        if [ -z "$pass1" ]; then
            dialog --msgbox "Le mot de passe ne peut pas être vide." 8 40
            continue
        fi
        
        # Confirmation du mot de passe
        dialog --passwordbox "Confirmez le nouveau mot de passe pour $username :" 10 40 2> /tmp/pass2.txt
        pass2=$(cat /tmp/pass2.txt)
        rm -f /tmp/pass2.txt
        
        # Vérifier si les mots de passe correspondent
        if [ "$pass1" = "$pass2" ]; then
            
        # Changer le mot de passe
        local change_pass="echo '$username:$pass1' | sudo chpasswd"
        local resultat=$(executer_commande "$change_pass")
            
         # Vérifier si la commande a réussi
            if [ $? -eq 0 ]; then
                dialog --msgbox "Le mot de passe de l'utilisateur $username a été modifié avec succès sur la machine distante." 8 50
                break
            else
                dialog --msgbox "Erreur lors de la modification du mot de passe :\n\n$resultat" 10 50
                return 1
            fi
        else
            dialog --msgbox "Les mots de passe ne correspondent pas. Veuillez réessayer." 8 50
        fi
    done

}


# Fonction pour supprimer un compte utilisateur distant
delete_user() {
    # Demander le nom d'utilisateur
    dialog --inputbox "Entrez le nom d'utilisateur à supprimer :" 10 40 2> /tmp/username.txt
    username=$(cat /tmp/username.txt)
    rm -f /tmp/username.txt

    # Vérifier que le nom d'utilisateur n'est pas vide
    if [ -z "$username" ]; then
        dialog --msgbox "Le nom d'utilisateur ne peut pas être vide." 8 40
        return 1
    fi

    # Vérifier si l'utilisateur existe sur la machine distante
    local check_user="id $username >/dev/null 2>&1"
    if ! executer_commande "$check_user"; then
        dialog --msgbox "Erreur : L'utilisateur $username n'existe pas sur la machine distante." 8 50
        return 1
    fi

    # Confirmation avant suppression
    dialog --yesno "Êtes-vous sûr de vouloir supprimer l'utilisateur $username ? Cette action est irréversible." 10 50
    local response=$?
    if [ $response -ne 0 ]; then
        dialog --msgbox "Annulation de la suppression." 8 40
        return
    fi

    # Commande pour supprimer l'utilisateur sur la machine distante
    local delete_user_cmd="sudo userdel -r $username"
    local resultat=$(executer_commande "$delete_user_cmd")

    # Vérifier si la commande a réussi
    if [ $? -eq 0 ]; then
        dialog --msgbox "Le compte utilisateur $username a été supprimé avec succès sur la machine distante." 10 50
    else
        dialog --msgbox "Erreur lors de la suppression de l'utilisateur $username :\n\n$resultat" 10 50
    fi
}


# Fonction pour modifier les utilisateurs d'un groupe distant
modify_group_rights() {
    # Demander le nom du groupe
    dialog --inputbox "Entrez le nom du groupe dont vous voulez modifier les utilisateurs :" 10 40 2> /tmp/groupname.txt
    groupname=$(cat /tmp/groupname.txt)
    rm -f /tmp/groupname.txt

    # Vérifier si le groupe existe sur la machine distante
    if ! executer_commande "getent group $groupname >/dev/null 2>&1"; then
        dialog --msgbox "Erreur : Le groupe $groupname n'existe pas sur la machine distante." 8 50
        return 1
    fi

    # Menu des options
    local group_choice=$(dialog --menu "Options pour le groupe $groupname" 15 50 4 \
        1 "Ajouter un utilisateur au groupe" \
        2 "Supprimer un utilisateur du groupe" \
        3 "Annuler" \
        2>&1 >/dev/tty)

    if [ $? -ne 0 ]; then
        dialog --msgbox "Annulation de l'opération." 8 40
        return
    fi

    case $group_choice in
        1)
            # Ajouter un utilisateur au groupe
            dialog --inputbox "Entrez le nom de l'utilisateur à ajouter au groupe :" 10 40 2> /tmp/username.txt
            username=$(cat /tmp/username.txt)
            rm -f /tmp/username.txt

            # Vérifier si l'utilisateur existe
            if ! executer_commande "id $username >/dev/null 2>&1"; then
                dialog --msgbox "Erreur : L'utilisateur $username n'existe pas sur la machine distante." 8 50
                return 1
            fi

            # Ajouter l'utilisateur au groupe
            local add_cmd="sudo usermod -a -G $groupname $username"
            local resultat=$(executer_commande "$add_cmd")

            if [ $? -eq 0 ]; then
                dialog --msgbox "L'utilisateur $username a été ajouté au groupe $groupname avec succès." 10 50
            else
                dialog --msgbox "Erreur lors de l'ajout de l'utilisateur au groupe :\n\n$resultat" 10 50
            fi
            ;;
        2)
            # Supprimer un utilisateur du groupe
            dialog --inputbox "Entrez le nom de l'utilisateur à supprimer du groupe :" 10 40 2> /tmp/username.txt
            username=$(cat /tmp/username.txt)
            rm -f /tmp/username.txt

            # Vérifier si l'utilisateur existe
            if ! executer_commande "id $username >/dev/null 2>&1"; then
                dialog --msgbox "Erreur : L'utilisateur $username n'existe pas sur la machine distante." 8 50
                return 1
            fi

            # Supprimer l'utilisateur du groupe
            local remove_cmd="sudo gpasswd -d $username $groupname"
            local resultat=$(executer_commande "$remove_cmd")

            if [ $? -eq 0 ]; then
                dialog --msgbox "L'utilisateur $username a été retiré du groupe $groupname avec succès." 10 50
            else
                dialog --msgbox "Erreur lors de la suppression de l'utilisateur du groupe :\n\n$resultat" 10 50
            fi
            ;;
        3)
            # Annulation
            dialog --msgbox "Opération annulée." 8 40
            return
            ;;
    esac
}


# Fonction pour sélectionner un utilisateur et le stocker dans une variable
user_selection() {
    # Créer un fichier temporaire pour stocker la liste des utilisateurs
    local temp_file=$(mktemp)
    
    # Récupérer la liste des utilisateurs humains sur la machine distante
    local resultat=$(executer_commande "getent passwd | awk -F: '\$3 >= 1000 && \$3 < 60000 { printf \"%s \\\"%s\\\" \\n\", \$1, \$5 }'")
    
    # Vérifier si la commande a réussi
    if [ $? -ne 0 ] || [ -z "$resultat" ]; then
        dialog --msgbox "Erreur : Impossible de récupérer la liste des utilisateurs sur la machine distante." 10 50
        return 1
    fi

    # Écrire le résultat dans le fichier temporaire
    echo "$resultat" > "$temp_file"
    
    # Sélection de l'utilisateur 
    local user=$(dialog --title "Sélection de l'utilisateur" \
        --menu "Choisissez un utilisateur :" 20 50 10 \
        --file "$temp_file" \
        2>&1 >/dev/tty)

    # Vérifier si un utilisateur est sélectionné
    if [ -n "$user" ]; then
        selected_user="$user"
        dialog --msgbox "Utilisateur sélectionné : $selected_user" 10 40
        
    else
        dialog --msgbox "Aucun utilisateur sélectionné." 8 40
        return
    fi

    # Nettoyer le fichier temporaire
        rm "$temp_file"


# Fonction pour afficher l'historique de l'utilisateur
    local user="$selected_user"
    
    # Vérifier si l'utilisateur existe
    if executer_commande "! id '$user' &>/dev/null"; then
        dialog --msgbox "Utilisateur $user inexistant." 8 40
        else
    

    # Boucle du menu
        while true; do
        # Créer un menu avec dialog
        local choix=$(dialog --clear --title "Historique des activités de $user" \
            --menu "Sélectionnez une option:" 40 50 20 \
            1 "Informations générales" \
            2 "Historique des commandes" \
            3 "Historique des connexions" \
            4 "Processus en cours" \
            5 "Activité réseau" \
            6 "Fichiers récents" \
            0 "Quitter" \
            2>&1 >/dev/tty)

        # Gestion du choix
        case $choix in
            1)
                create_info_display "$user" "header" ;;
            2)
                create_info_display "$user" "commands" ;;
            3)
                create_info_display "$user" "logins" ;;
            4)
                create_info_display "$user" "processes" ;;
            5)
                create_info_display "$user" "network" ;;
            6)
                create_info_display "$user" "files" ;;
            0)
                return ;;
            *)
                dialog --msgbox "Option invalide" 10 30 ;;
        esac
        done
    fi
}


# Fonction pour créer et afficher les informations avec option de sauvegarde
create_info_display() {
    local user="$1"
    local type="$2"
    local filename=$(mktemp)

    # Générer le contenu
    case "$type" in
        "header")
            echo "===== Informations détaillées sur l'utilisateur $user =====" > "$filename"
            echo "Date : $(date)" >> "$filename"
            echo "Informations de base :" >> "$filename"
            resultat=$(executer_commande "getent passwd "$user" && id "$user"")
            echo "$resultat" >> "$filename"
	   ;;
        "commands")
            echo "--- Historique des commandes récentes de $user ---" > "$filename"
            local resultat=$(executer_commande "tail -n 50 /home/$user/.bash_history 2>/dev/null")
            if [ -z "$resultat" ]; then
                echo "Aucun historique de commandes trouvé pour $user" >> "$filename"
            else
                echo "$resultat" >> "$filename"
            fi
           ;;
        "logins")
            echo "--- Historique des connexions de $user ---" > "$filename"
            resultat=$(executer_commande "last -a | grep "$user" | head -n 20")
            echo "$resultat" >> "$filename"
         ;;
        "processes")
            echo "--- Processus en cours de $user ---" > "$filename"
            resultat=$(executer_commande "ps aux | grep "$user"")
            echo "$resultat" >> "$filename"
         ;;
        "network")
            echo "--- Activité réseau de $user ---" > "$filename"
            resultat=$(executer_commande "netstat -anp | grep -v unix")
            echo "$resultat" >> "$filename"
         ;;
        "files")
            echo "--- Fichiers récemment modifiés par $user ---" > "$filename"
            resultat=$(executer_commande "find "/home/$user" -type f -mtime -7 | head -n 50")
            echo "$resultat" >> "$filename"

            echo -e "\n=== Fichiers récemment créés par $user ===" >> "$filename"
            resultat=$(executer_commande "find "/home/$user" -type f -ctime -7 | sort -r | head -n 50") 
            echo "$resultat" >> "$filename"
          ;;
        *)
            dialog --msgbox "Type d'information invalide" 8 40
            rm "$filename"
            return 1
          ;;
    esac

    # Lire le contenu du fichier
    local content=$(cat "$filename")

    # Afficher le contenu avec des options supplémentaires
    local choix
    choix=$(dialog --extra-button \
        --extra-label "Sauvegarder" \
        --textbox "$filename" 20 80 \
        2>&1 >/dev/tty)

    # Gestion du bouton supplémentaire
    local exit_status=$?
    if [ $exit_status -eq 3 ]; then
        # Bouton "Sauvegarder" a été pressé
        save_to_file "$content" "$type" "$user"
    fi

    # Supprimer le fichier temporaire
    rm "$filename"
}


# Menu Ordinateur
menu_ordi() {
    local choix=$(dialog --stdout \
        --title "Menu Ordinateur" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Obtenir des informations sur l'ordinateur" \
        2 "Effectuer des actions sur l'ordinateur" \
        3 "Retour au menu précédent")

    case $choix in
        1)
            menu_info_ordi
            ;;
        2)
            menu_action_ordi
            ;;
        3)
            menu_principal
            ;;
        *)
            clear
            exit 0
            ;;
    esac
}

# Menu Information Ordinateur
menu_info_ordi() {
    local choix=$(dialog --stdout \
        --title "Menu Informations Ordinateur" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Version du système d'exploitation" \
        2 "Informations disque et RAM" \
        3 "Activité de l'ordinateur" \
        4 "Retour au menu précédent")

    case $choix in
        1)
           resultat=$(executer_commande "lsb_release -d")
           dialog --msgbox "Voici la version du système d'exploitation : $resultat " 8 40
           menu_info_ordi
            ;;
        2)
            menu_disque_ram
            ;;
        3)
            menu_activite_ordi
            ;;
        4)
            menu_ordi
            ;;
        *)
            clear
            exit 0
            ;;
    esac
}

# Menu Disque et RAM
menu_disque_ram() {
    local choix=$(dialog --stdout \
        --title "Menu Disque et RAM" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Afficher le nombre de disques" \
        2 "Afficher les informations de partition par disque" \
        3 "Afficher l'espace disque restant" \
        4 "Afficher l'état de la RAM" \
        5 "Retour au menu précédent")

    case $choix in
        1)
           resultat=$(executer_commande "lsblk -d | grep '^sda'")
           dialog --msgbox "Voici les disques présents : \n\n$resultat " 20 70
           menu_disque_ram
            ;;
        2)
           resultat=$(executer_commande "lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep '^sd'")
           dialog --msgbox "Voici les disques présents :\n\n $resultat " 20 70
           menu_disque_ram
            ;;
        3)
           local espace=$(executer_commande "df -h --output=source,size,used,avail,pcent | grep '^/dev'")
           dialog --msgbox "Espace disque restant :\n\n$espace" 20 70
           menu_disque_ram
            ;;
        4)
           local ram=$(executer_commande "free -h | awk 'NR==2{printf \"RAM Utilisée : %s/%s (%s%%)\", \$3, \$2, \$3*100/\$2}'")
           dialog --msgbox "$ram" 20 70
           menu_disque_ram
            ;;
        5)
            menu_info_ordi
            ;;
        *)
            clear
            exit 0
            ;;
    esac
}

# Menu Activité de l'Ordinateur
menu_activite_ordi() {
    local choix=$(dialog --stdout \
        --title "Menu Activité de l'Ordinateur" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Liste des applications/paquets installés" \
        2 "Liste des services en exécution" \
        3 "Retour au menu précédent")

    case $choix in
        1)
           local apps=$(executer_commande "dpkg-query -l | awk '{print $2}' | tail -n +6")
           echo -e "Applications installées :\n\n$apps" > /tmp/apps_list.txt

           local packages=$(executer_commande "dpkg-query -l | awk '{print $1, $2}' | tail -n +6")
           echo -e "Paquets installés :\n\n$packages" > /tmp/packages_list.txt
           dialog --textbox /tmp/apps_list.txt 20 70
           dialog --textbox /tmp/packages_list.txt 20 70
           menu_activite_ordi
            ;;
        2)
           service_table
           menu_activite_ordi
            ;;
        3)
            menu_info_ordi
            ;;
        *)
            clear
            exit 0
            ;;
    esac
}

# Liste des services en cours d'exécution
service_table() {
      # Créer un fichier temporaire pour stocker les données
      filename=$(mktemp)
 
      # Extraire les données des services et les formater
      local resultat=$(executer_commande "systemctl list-units --type=service --no-pager")
     echo "$resultat" >> "$filename"
 
     # Vérifier si des services ont été trouvés
     if [ $(wc -l < "$resultat") -le 1 ]; then
         dialog --title "Services" --msgbox "Aucun service trouvé." 10 40
     else
         # Afficher les services dans une fenêtre dialog
         dialog --title "Services en cours d'exécution" \
                --backtitle "Gestionnaire de Services" \
                --ok-label "Retour" \
                --textbox "$filename" 30 120
     fi

     # Supprimer le fichier temporaire
     rm -f "$filename"
}

# Menu Actions sur l'Ordinateur
menu_action_ordi() {
    local choix=$(dialog --stdout \
        --title "Menu Actions sur l'Ordinateur" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Gestion de l'alimentation" \
        2 "Gestion des répertoires" \
        3 "Gestion des logiciels" \
        4 "Mise à jour système" \
        5 "Retour au menu précédent")

    case $choix in
        1)
            menu_gestion_alimentation
            ;;
        2)
            menu_gestion_repertoires
            ;;
        3)
            menu_gestion_logiciels
            ;;
        4)
           dialog --msgbox "Mise à jour du système en cours..." 8 40
           executer_commande "sudo apt update && sudo apt upgrade -y &&"
           dialog --msgbox "Mise à jour réussie." 8 40 ||
           dialog --msgbox "Erreur lors de la mise à jour." 8 40
           menu_action_ordi
            ;;
        5)
            menu_ordi
            ;;
        *)
            clear
            exit 0
            ;;
    esac
}

# Menu Gestion de l'Alimentation
menu_gestion_alimentation() {
    local choix=$(dialog --stdout \
        --title "Menu Gestion de l'Alimentation" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Arrêt de l'ordinateur" \
        2 "Redémarrer l'ordinateur" \
        3 "Mise en veille de l'ordinateur" \
        4 "Verrouiller l'ordinateur" \
        5 "Retour au menu précédent")

    case $choix in
        1)
           dialog --yesno "Voulez-vous vraiment éteindre l'ordinateur ?" 8 40
           if [ $? -eq 0 ]; then
              if executer_commande "echo $MotDePasse | sudo -S shutdown now"; then
                 dialog --msgbox "L'ordinateur a été éteint avec succès." 8 40
                else
                dialog --msgbox "Échec pour éteindre l'ordinateur" 8 40
             fi 
           fi
           menu_gestion_alimentation
            ;;
        2)
           dialog --yesno "Voulez-vous vraiment redémarrer l'ordinateur ?" 8 40
           if [ $? -eq 0 ]; then
              if executer_commande "echo $MotDePasse | sudo -S reboot"; then
                 dialog --msgbox "L'ordinateur redémarre avec succès"
              else
                 dialog --msgbox "Échec du redémarrage de l'ordinateur"
              fi 
           fi
           menu_gestion_alimentation
            ;;
        3)
           dialog --yesno "Voulez-vous mettre l'ordinateur en veille ?" 8 40
           if [ $? -eq 0 ]; then
              if executer_commande " echo $MotDePasse | sudo -S systemctl suspend"; then
                 dialog --msgbox "L'ordinateur a été mis en veille avec succès"
              else
                 dialog --msgb "Échec de la mise en veille de l'ordinateur"
              fi
           fi
           menu_gestion_alimentation
            ;;
        4)
           dialog --yesno "Voulez-vous verrouiller l'ordinateur ?" 8 40
           if [ $? -eq 0 ]; then
              if executer_commande "echo $MotDePasse | sudo -S loginctl lock-session"; then
                 dialog --msgbox "L'ordinateur s'est vérouillé avec succès"
              else
                 dialog --msgbox "Échec du vérouillage de l'ordinateur"
             fi
           fi
           menu_gestion_alimentation
            ;;
        5)
            menu_action_ordi
            ;;
        *)
            clear
            exit 0
            ;;
    esac
}

# Menu Gestion des Répertoires
menu_gestion_repertoires() {
    local choix=$(dialog --stdout \
        --title "Menu Gestion des Répertoires" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Création d'un répertoire" \
        2 "Modifier un répertoire" \
        3 "Supprimer un répertoire" \
        4 "Retour au menu précédent")

    case $choix in
        1)
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
           menu_gestion_repertoires
            ;;
        2)
           local ancien_chemin=$(dialog --stdout --inputbox "Entrez le chemin actuel du répertoire :" 8 40)
           local nouveau_chemin=$(dialog --stdout --inputbox "Entrez le nouveau chemin du répertoire :" 8 40)
           if [ -n "$ancien_chemin" ] && [ -n "$nouveau_chemin" ]; then
              if executer_commande "mv '$ancien_chemin' '$nouveau_chemin'"; then
                    dialog --msgbox "Répertoire renommé de '$ancien_chemin' à '$nouveau_chemin' avec succès." 8 40
              else
                    dialog --msgbox "Échec du renommage du répertoire." 8 40
              fi
           else
             dialog --msgbox "Chemins non fournis." 8 40
           fi
           menu_gestion_repertoires
            ;;
        3)
            local chemin=$(dialog --stdout --inputbox "Entrez le chemin du répertoire à supprimer :" 8 40)
            if [ -n "$chemin" ]; then
                if executer_commande "rm -r '$chemin'"; then
                    dialog --msgbox "Répertoire '$chemin' supprimé avec succès." 8 40
                else
                    dialog --msgbox "Échec de la suppression du répertoire '$chemin'." 8 40
                fi
            else
              dialog --msgbox "Chemin non fourni." 8 40
            fi
            menu_gestion_repertoires
            ;;
        4)
            menu_action_ordi
            ;;
        *)
            clear
            exit 0
            ;;
    esac
}

# Menu Gestion des Logiciels
menu_gestion_logiciels() {
    local choix=$(dialog --stdout \
        --title "Menu Gestion des Logiciels" \
        --menu "Veuillez choisir une option :" 15 50 6 \
        1 "Installer un logiciel" \
        2 "Désinstaller un logiciel" \
		3 "Démarrer un logiciel" \
        4 "Arrêter un logiciel" \
        5 "Retour au menu précédent")

    case $choix in
        1)
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
              menu_gestion_logiciels
            ;;
        2)
            local logiciel=$(dialog --stdout --inputbox "Entrez le nom du logiciel à désinstaller :" 8 40)
            if [ -n "$logiciel" ]; then
                if executer_commande "sudo apt remove -y '$logiciel'"; then
                    dialog --msgbox "Logiciel '$logiciel' désinstallé avec succès." 8 40
                else
                    dialog --msgbox "Échec de la désinstallation de '$logiciel'." 8 40
                fi
            else
               dialog --msgbox "Nom du logiciel non fourni." 8 40
            fi
            menu_gestion_logiciels
            ;;

	  3)  #3)
			local logiciel=$(dialog --stdout --inputbox "Entrez le nom du logiciel à démarrer :" 8 40)
				if [ -n "$logiciel" ]; then
    		# Vérifier d'abord si le logiciel existe
    			if executer_commande "which '$logiciel' >/dev/null 2>&1"; then
        		if executer_commande "nohup '$logiciel' >/dev/null 2>&1 &"; then
           			 dialog --msgbox "Logiciel '$logiciel' démarré avec succès." 8 40
       			else
            dialog --msgbox "Échec du démarrage du logiciel '$logiciel'." 8 40
       			fi
    		else
        		dialog --msgbox "Le logiciel '$logiciel' n'est pas installé." 8 40
    		fi
			else
   				dialog --msgbox "Nom du logiciel non fourni." 8 40
			fi
			menu_gestion_logiciels
			;;

        4)
            local logiciel=$(dialog --stdout --inputbox "Entrez le nom du logiciel à arrêter :" 8 40)
            if [ -n "$logiciel" ]; then
               if executer_commande "pkill '$logiciel'"; then
                    dialog --msgbox "Logiciel '$logiciel' arrêté avec succès." 8 40
               else
                    dialog --msgbox "Échec de l'arrêt du logiciel '$logiciel'." 8 40
               fi
            else
              dialog --msgbox "Nom du logiciel non fourni." 8 40
            fi
            menu_gestion_logiciels
            ;;
        5)
            menu_action_ordi
            ;;
        *)
            clear
            exit 0
            ;;
    esac
}

main

log_evt "********EndScript********"
