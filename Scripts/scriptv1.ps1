# Point d'entrée du script
function Start-Script {

# Importer les assemblies nécessaires pour Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Variables globales
$script:currentUser = $null
$script:currentHost = $null
$script:sshSession = $null

# Démarrer le menu principal
Show-MainMenu
}

# Appel initial
try {
    Start-Script
}
catch {
    [System.Windows.Forms.MessageBox]::Show("Erreur lors du démarrage : $_", "Erreur")
}

# Fonction de logging
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Information', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Information'
    )

    # Définir le chemin du fichier de log
    $LogPath = Join-Path $env:USERPROFILE "AdminTools_Logs"
    $LogFile = Join-Path $LogPath ("AdminTools_" + (Get-Date -Format "yyyy-MM") + ".log")

    # Créer le dossier de logs s'il n'existe pas
    if (!(Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath | Out-Null
    }

    # Formater le message de log
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$TimeStamp [$Level] - $Message"

    # Écrire dans le fichier de log
    Add-Content -Path $LogFile -Value $LogMessage
}

# Fonction pour visualiser les logs
function Show-Logs {
    param(
        [int]$LastLines = 50,
        [string]$Filter
    )

    $LogPath = Join-Path $env:USERPROFILE "AdminTools_Logs"
    $CurrentLogFile = Join-Path $LogPath ("AdminTools_" + (Get-Date -Format "yyyy-MM") + ".log")

    if (!(Test-Path $CurrentLogFile)) {
        [System.Windows.Forms.MessageBox]::Show("Aucun fichier de log trouvé.", "Information")
        return
    }

    $logs = Get-Content $CurrentLogFile -Tail $LastLines
    if ($Filter) {
        $logs = $logs | Where-Object { $_ -match $Filter }
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Journaux d'activité"
    $form.Size = New-Object System.Drawing.Size(800,600)
    $form.StartPosition = "CenterScreen"

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $true
    $textBox.ScrollBars = "Vertical"
    $textBox.Size = New-Object System.Drawing.Size(760,480)
    $textBox.Location = New-Object System.Drawing.Point(10,10)
    $textBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    $textBox.Text = $logs | Out-String
    $form.Controls.Add($textBox)

    # Bouton Rafraîchir
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Location = New-Object System.Drawing.Point(10,500)
    $refreshButton.Size = New-Object System.Drawing.Size(100,30)
    $refreshButton.Text = "Rafraîchir"
    $refreshButton.Add_Click({
        $logs = Get-Content $CurrentLogFile -Tail $LastLines
        if ($Filter) {
            $logs = $logs | Where-Object { $_ -match $Filter }
        }
        $textBox.Text = $logs | Out-String
    })
    $form.Controls.Add($refreshButton)

    # Bouton Exporter
    $exportButton = New-Object System.Windows.Forms.Button
    $exportButton.Location = New-Object System.Drawing.Point(120,500)
    $exportButton.Size = New-Object System.Drawing.Size(100,30)
    $exportButton.Text = "Exporter"
    $exportButton.Add_Click({
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "Fichiers log (*.log)|*.log|Tous les fichiers (*.*)|*.*"
        $saveDialog.DefaultExt = "log"
        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $textBox.Text | Out-File $saveDialog.FileName
            [System.Windows.Forms.MessageBox]::Show("Logs exportés avec succès!", "Succès")
        }
    })
    $form.Controls.Add($exportButton)

    # Bouton Fermer
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(670,500)
    $closeButton.Size = New-Object System.Drawing.Size(100,30)
    $closeButton.Text = "Fermer"
    $closeButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($closeButton)

    $form.ShowDialog()
}

# Fonction pour créer une boîte de dialogue personnalisée
function Show-CustomDialog {
    param (
        [string]$Title,
        [string]$Message,
        [string[]]$Options
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(400,300)
    $form.StartPosition = "CenterScreen"

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(380,20)
    $label.Text = $Message
    $form.Controls.Add($label)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(10,50)
    $listBox.Size = New-Object System.Drawing.Size(360,180)
    $listBox.Height = 180

    foreach($option in $Options) {
        [void] $listBox.Items.Add($option)
    }

    $form.Controls.Add($listBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75,240)
    $okButton.Size = New-Object System.Drawing.Size(75,23)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(250,240)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = "Annuler"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)

    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $listBox.SelectedItem
    }
    return $null
}

# Fonction pour afficher une boîte de saisie
function Show-InputDialog {
    param (
        [string]$Title,
        [string]$Message,
        [bool]$IsPassword = $false
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(400,200)
    $form.StartPosition = "CenterScreen"

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(380,20)
    $label.Text = $Message
    $form.Controls.Add($label)

    if ($IsPassword) {
        $textBox = New-Object System.Windows.Forms.MaskedTextBox
        $textBox.PasswordChar = '*'
    } else {
        $textBox = New-Object System.Windows.Forms.TextBox
    }
    
    $textBox.Location = New-Object System.Drawing.Point(10,50)
    $textBox.Size = New-Object System.Drawing.Size(360,20)
    $form.Controls.Add($textBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75,120)
    $okButton.Size = New-Object System.Drawing.Size(75,23)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(250,120)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = "Annuler"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)

    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $textBox.Text
    }
    return $null
}

# Fonction pour établir une connexion SSH avec clé
function Connect-SSHWithKey {
    param (
        [string]$Username,
        [string]$Hostname,
        [string]$KeyPath
    )

    try {
        # Vérifier si le module SSH est installé
        if (!(Get-Module -ListAvailable -Name Posh-SSH)) {
            Install-Module -Name Posh-SSH -Force -Scope CurrentUser
        }

        # Importer le module
        Import-Module Posh-SSH -ErrorAction Stop

        # Vérifier si le fichier de clé existe
        if (!(Test-Path $KeyPath)) {
            throw "Le fichier de clé SSH n'existe pas: $KeyPath"
        }

        # Établir la connexion SSH
        $sshSession = New-SSHSession -ComputerName $Hostname -Username $Username -KeyFile $KeyPath -AcceptKey -ErrorAction Stop  

        if ($sshSession.Connected) {
            $global:sshSession = $sshSession
            $global:currentUser = $Username
            $global:currentHost = $Hostname
            return $true
        }
         throw "Échec de la connexion SSH"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Erreur de connexion SSH: $_", "Erreur", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
}
}

# Fonction pour exécuter une commande SSH
function Invoke-RemoteCommand {
    param (
        [string]$Command
    )

    try {
        if ($global:sshSession -and $global:sshSession.Connected) {
            $result = Invoke-SSHCommand -SSHSession $global:sshSession -Command $Command
            return $result.Output
        }
        else {
            throw "Pas de session SSH active"
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Erreur d'exécution de commande: $_", "Erreur", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $null
    }
}

# Menu Principal
function Show-MainMenu {
    while ($true) {
        $choice = Show-CustomDialog -Title "Menu Principal" -Message "Choisissez une option:" -Options @(
            "1. Connexion SSH",
            "2. Gestion des utilisateurs",
            "3. Gestion des ordinateurs",
            "4. Afficher les logs",
            "5. Quitter"
        )

        switch ($choice) {
            "1. Connexion SSH" { Connect-ToRemoteHost }
            "2. Gestion des utilisateurs" { if ($global:sshSession) { Show-UserManagementMenu } }
            "3. Gestion des ordinateurs" { if ($global:sshSession) { Show-ComputerManagementMenu } }
            "4. Afficher les logs" { Show-Logs }
            "5. Quitter" { exit }
            default { return }
        }
    }
}

# Fonction de connexion SSH
function Connect-ToRemoteHost {
    $username = Show-InputDialog -Title "Connexion SSH" -Message "Nom d'utilisateur:"
    if (!$username) { return }

    $hostname = Show-InputDialog -Title "Connexion SSH" -Message "Adresse IP:"
    if (!$hostname) { return }

    $keyPath = Show-InputDialog -Title "Connexion SSH" -Message "Chemin de la clé SSH:"
    if (!$keyPath) { return }

    if (Connect-SSHWithKey -Username $username -Hostname $hostname -KeyPath $keyPath) {
        [System.Windows.Forms.MessageBox]::Show("Connexion SSH établie avec succès!", "Succès", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
}

# Point d'entrée du script
function Start-Script {
    Show-MainMenu
}

# Menu de gestion des utilisateurs
function Show-UserManagementMenu {
    while ($true) {
        $choice = Show-CustomDialog -Title "Gestion des Utilisateurs" -Message "Choisissez une option:" -Options @(
            "1. Liste des utilisateurs",
            "2. Créer un utilisateur",
            "3. Modifier mot de passe",
            "4. Supprimer un utilisateur",
            "5. Gérer les groupes",
            "6. Historique d'activité",
            "7. Retour au menu principal"
        )

        switch ($choice) {
            "1. Liste des utilisateurs" { Get-RemoteUsers }
            "2. Créer un utilisateur" { New-RemoteUser }
            "3. Modifier mot de passe" { Set-RemoteUserPassword }
            "4. Supprimer un utilisateur" { Remove-RemoteUser }
            "5. Gérer les groupes" { Show-GroupManagementMenu }
            "6. Historique d'activité" { Get-UserActivityHistory }
            "7. Retour au menu principal" { return }
            default { return }
        }
    }
}

# Fonction pour lister les utilisateurs distants
function Get-RemoteUsers {
    try {
        $result = Invoke-RemoteCommand "Get-LocalUser | Select-Object Name, Enabled, LastLogon, Description | Format-Table -AutoSize"
        
        if ($result) {
            $form = New-Object System.Windows.Forms.Form
            $form.Text = "Liste des Utilisateurs"
            $form.Size = New-Object System.Drawing.Size(600,400)
            $form.StartPosition = "CenterScreen"

            $textBox = New-Object System.Windows.Forms.TextBox
            $textBox.Multiline = $true
            $textBox.ScrollBars = "Vertical"
            $textBox.Size = New-Object System.Drawing.Size(580,320)
            $textBox.Location = New-Object System.Drawing.Point(10,10)
            $textBox.Text = $result
            $form.Controls.Add($textBox)

            $saveButton = New-Object System.Windows.Forms.Button
            $saveButton.Location = New-Object System.Drawing.Point(10,340)
            $saveButton.Size = New-Object System.Drawing.Size(75,23)
            $saveButton.Text = "Sauvegarder"
            $saveButton.Add_Click({
                $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
                $saveDialog.Filter = "Fichiers texte (*.txt)|*.txt"
                if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                    $textBox.Text | Out-File $saveDialog.FileName
                    [System.Windows.Forms.MessageBox]::Show("Liste sauvegardée avec succès!", "Sauvegarde")
                }
            })
            $form.Controls.Add($saveButton)

            $closeButton = New-Object System.Windows.Forms.Button
            $closeButton.Location = New-Object System.Drawing.Point(95,340)
            $closeButton.Size = New-Object System.Drawing.Size(75,23)
            $closeButton.Text = "Fermer"
            $closeButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Controls.Add($closeButton)

            $form.ShowDialog()
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Aucun utilisateur trouvé.", "Information")
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Erreur lors de la récupération des utilisateurs: $_", "Erreur")
    }
}

# Fonction pour créer un nouvel utilisateur distant
function New-RemoteUser {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Création d'un nouvel utilisateur"
    $form.Size = New-Object System.Drawing.Size(400,400)
    $form.StartPosition = "CenterScreen"

    # Nom d'utilisateur
    $userLabel = New-Object System.Windows.Forms.Label
    $userLabel.Location = New-Object System.Drawing.Point(10,20)
    $userLabel.Size = New-Object System.Drawing.Size(120,20)
    $userLabel.Text = "Nom d'utilisateur:"
    $form.Controls.Add($userLabel)

    $userBox = New-Object System.Windows.Forms.TextBox
    $userBox.Location = New-Object System.Drawing.Point(140,20)
    $userBox.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($userBox)

    # Nom complet
    $fullNameLabel = New-Object System.Windows.Forms.Label
    $fullNameLabel.Location = New-Object System.Drawing.Point(10,50)
    $fullNameLabel.Size = New-Object System.Drawing.Size(120,20)
    $fullNameLabel.Text = "Nom complet:"
    $form.Controls.Add($fullNameLabel)

    $fullNameBox = New-Object System.Windows.Forms.TextBox
    $fullNameBox.Location = New-Object System.Drawing.Point(140,50)
    $fullNameBox.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($fullNameBox)

    # Poste
    $positionLabel = New-Object System.Windows.Forms.Label
    $positionLabel.Location = New-Object System.Drawing.Point(10,80)
    $positionLabel.Size = New-Object System.Drawing.Size(120,20)
    $positionLabel.Text = "Poste:"
    $form.Controls.Add($positionLabel)

    $positionBox = New-Object System.Windows.Forms.ComboBox
    $positionBox.Location = New-Object System.Drawing.Point(140,80)
    $positionBox.Size = New-Object System.Drawing.Size(200,20)
    $positions = @(
        "Administration",
        "Informatique",
        "Comptabilité",
        "Commercial",
        "Production",
        "Marketing",
        "Ressources Humaines",
        "Service Client"
    )
    $positionBox.Items.AddRange($positions)
    $form.Controls.Add($positionBox)

    # Mot de passe
    $passwordLabel = New-Object System.Windows.Forms.Label
    $passwordLabel.Location = New-Object System.Drawing.Point(10,110)
    $passwordLabel.Size = New-Object System.Drawing.Size(120,20)
    $passwordLabel.Text = "Mot de passe:"
    $form.Controls.Add($passwordLabel)

    $passwordBox = New-Object System.Windows.Forms.MaskedTextBox
    $passwordBox.Location = New-Object System.Drawing.Point(140,110)
    $passwordBox.Size = New-Object System.Drawing.Size(200,20)
    $passwordBox.PasswordChar = '*'
    $form.Controls.Add($passwordBox)

    # Confirmation du mot de passe
    $confirmLabel = New-Object System.Windows.Forms.Label
    $confirmLabel.Location = New-Object System.Drawing.Point(10,140)
    $confirmLabel.Size = New-Object System.Drawing.Size(120,20)
    $confirmLabel.Text = "Confirmer MDP:"
    $form.Controls.Add($confirmLabel)

    $confirmBox = New-Object System.Windows.Forms.MaskedTextBox
    $confirmBox.Location = New-Object System.Drawing.Point(140,140)
    $confirmBox.Size = New-Object System.Drawing.Size(200,20)
    $confirmBox.PasswordChar = '*'
    $form.Controls.Add($confirmBox)

    # Boutons
    $createButton = New-Object System.Windows.Forms.Button
    $createButton.Location = New-Object System.Drawing.Point(140,200)
    $createButton.Size = New-Object System.Drawing.Size(75,23)
    $createButton.Text = "Créer"
    $createButton.Add_Click({
        if ($passwordBox.Text -ne $confirmBox.Text) {
            [System.Windows.Forms.MessageBox]::Show("Les mots de passe ne correspondent pas.", "Erreur")
            return
        }

        if ([string]::IsNullOrWhiteSpace($userBox.Text) -or 
            [string]::IsNullOrWhiteSpace($fullNameBox.Text) -or 
            [string]::IsNullOrWhiteSpace($positionBox.Text) -or 
            [string]::IsNullOrWhiteSpace($passwordBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Tous les champs sont obligatoires.", "Erreur")
            return
        }

        try {
            $command = @"
            New-LocalUser -Name '$($userBox.Text)' -FullName '$($fullNameBox.Text)' -Description '$($positionBox.Text)' -Password (ConvertTo-SecureString -String '$($passwordBox.Text)' -AsPlainText -Force) -AccountNeverExpires
            Add-LocalGroupMember -Group 'Users' -Member '$($userBox.Text)'
"@
            $result = Invoke-RemoteCommand $command
            [System.Windows.Forms.MessageBox]::Show("Utilisateur créé avec succès!", "Succès")
            $form.Close()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Erreur lors de la création de l'utilisateur: $_", "Erreur")
        }
    })
    $form.Controls.Add($createButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(225,200)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = "Annuler"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)

    $form.ShowDialog()
}

# Fonction pour modifier le mot de passe d'un utilisateur distant
function Set-RemoteUserPassword {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Modification du mot de passe"
    $form.Size = New-Object System.Drawing.Size(400,250)
    $form.StartPosition = "CenterScreen"

    # Liste des utilisateurs
    $userLabel = New-Object System.Windows.Forms.Label
    $userLabel.Location = New-Object System.Drawing.Point(10,20)
    $userLabel.Size = New-Object System.Drawing.Size(120,20)
    $userLabel.Text = "Utilisateur:"
    $form.Controls.Add($userLabel)

    $userBox = New-Object System.Windows.Forms.ComboBox
    $userBox.Location = New-Object System.Drawing.Point(140,20)
    $userBox.Size = New-Object System.Drawing.Size(200,20)
    
    # Récupérer la liste des utilisateurs
    $users = Invoke-RemoteCommand "Get-LocalUser | Select-Object -ExpandProperty Name"
    $userBox.Items.AddRange($users)
    $form.Controls.Add($userBox)

    # Nouveau mot de passe
    $passwordLabel = New-Object System.Windows.Forms.Label
    $passwordLabel.Location = New-Object System.Drawing.Point(10,50)
    $passwordLabel.Size = New-Object System.Drawing.Size(120,20)
    $passwordLabel.Text = "Nouveau MDP:"
    $form.Controls.Add($passwordLabel)

    $passwordBox = New-Object System.Windows.Forms.MaskedTextBox
    $passwordBox.Location = New-Object System.Drawing.Point(140,50)
    $passwordBox.Size = New-Object System.Drawing.Size(200,20)
    $passwordBox.PasswordChar = '*'
    $form.Controls.Add($passwordBox)

    # Confirmation
    $confirmLabel = New-Object System.Windows.Forms.Label
    $confirmLabel.Location = New-Object System.Drawing.Point(10,80)
    $confirmLabel.Size = New-Object System.Drawing.Size(120,20)
    $confirmLabel.Text = "Confirmer MDP:"
    $form.Controls.Add($confirmLabel)

    $confirmBox = New-Object System.Windows.Forms.MaskedTextBox
    $confirmBox.Location = New-Object System.Drawing.Point(140,80)
    $confirmBox.Size = New-Object System.Drawing.Size(200,20)
    $confirmBox.PasswordChar = '*'
    $form.Controls.Add($confirmBox)

    # Boutons
    $changeButton = New-Object System.Windows.Forms.Button
    $changeButton.Location = New-Object System.Drawing.Point(140,120)
    $changeButton.Size = New-Object System.Drawing.Size(75,23)
    $changeButton.Text = "Modifier"
    $changeButton.Add_Click({
        if ($passwordBox.Text -ne $confirmBox.Text) {
            [System.Windows.Forms.MessageBox]::Show("Les mots de passe ne correspondent pas.", "Erreur")
            return
        }

        if ([string]::IsNullOrWhiteSpace($userBox.Text) -or 
            [string]::IsNullOrWhiteSpace($passwordBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Tous les champs sont obligatoires.", "Erreur")
            return
        }

        try {
            $command = "Set-LocalUser -Name '$($userBox.Text)' -Password (ConvertTo-SecureString -String '$($passwordBox.Text)' -AsPlainText -Force)"
            $result = Invoke-RemoteCommand $command
            [System.Windows.Forms.MessageBox]::Show("Mot de passe modifié avec succès!", "Succès")
            $form.Close()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Erreur lors de la modification du mot de passe: $_", "Erreur")
        }
    })
    $form.Controls.Add($changeButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(225,120)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = "Annuler"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)

    $form.ShowDialog()
}
# Fonction pour afficher l'historique d'activité d'un utilisateur
function Get-UserActivityHistory {
    param (
        [string]$Username = $null
    )

    # Si aucun utilisateur n'est spécifié, demander à l'utilisateur d'en sélectionner un
    if (-not $Username) {
        $users = Invoke-RemoteCommand "Get-LocalUser | Select-Object -ExpandProperty Name"
        $Username = Show-CustomDialog -Title "Sélection d'utilisateur" -Message "Choisissez un utilisateur :" -Options $users.Split("`n")
        if (-not $Username) { return }
    }

    while ($true) {
        $choice = Show-CustomDialog -Title "Historique d'activité - $Username" -Message "Choisissez une option :" -Options @(
            "1. Informations générales",
            "2. Historique des connexions",
            "3. Processus en cours",
            "4. Fichiers récents",
            "5. Retour"
        )

        switch ($choice) {
            "1. Informations générales" { Show-UserGeneralInfo -Username $Username }
            "2. Historique des connexions" { Show-UserLoginHistory -Username $Username }
            "3. Processus en cours" { Show-UserProcesses -Username $Username }
            "4. Fichiers récents" { Show-UserRecentFiles -Username $Username }
            "5. Retour" { return }
            default { return }
        }
    }
}

# Fonction pour afficher les informations générales d'un utilisateur
function Show-UserGeneralInfo {
    param ([string]$Username)

    $info = Invoke-RemoteCommand @"
        `$user = Get-LocalUser -Name '$Username'
        `$groups = Get-LocalGroup | Where-Object { (Get-LocalGroupMember -Group `$_.Name -ErrorAction SilentlyContinue).Name -match '$Username' }
        @{
            Name = `$user.Name
            Enabled = `$user.Enabled
            LastLogon = `$user.LastLogon
            PasswordLastSet = `$user.PasswordLastSet
            Groups = (`$groups | Select-Object -ExpandProperty Name) -join ', '
        } | ConvertTo-Json
"@

    try {
        $userInfo = $info | ConvertFrom-Json
        $message = @"
Informations sur l'utilisateur $Username :
----------------------------------------
État du compte : $($userInfo.Enabled)
Dernière connexion : $($userInfo.LastLogon)
Dernier changement de mot de passe : $($userInfo.PasswordLastSet)
Groupes : $($userInfo.Groups)
"@
        Show-CustomDialog -Title "Informations utilisateur" -Message $message -Options @("OK")
    }
    catch {
        Show-CustomDialog -Title "Erreur" -Message "Erreur lors de la récupération des informations : $_" -Options @("OK")
    }
}

# Fonction pour afficher l'historique des connexions
function Show-UserLoginHistory {
    param ([string]$Username)

    $loginHistory = Invoke-RemoteCommand @"
        Get-EventLog -LogName Security -InstanceId 4624 -Newest 50 |
        Where-Object { `$_.Message -match '$Username' } |
        Select-Object TimeGenerated, Message |
        Format-Table -AutoSize | Out-String
"@

    if ($loginHistory) {
        Show-CustomDialog -Title "Historique des connexions - $Username" -Message $loginHistory -Options @("OK")
    }
    else {
        Show-CustomDialog -Title "Information" -Message "Aucun historique de connexion trouvé pour $Username" -Options @("OK")
    }
}

# Fonction pour afficher les processus en cours d'un utilisateur
function Show-UserProcesses {
    param ([string]$Username)

    $processes = Invoke-RemoteCommand @"
        Get-Process -IncludeUserName | 
        Where-Object { `$_.UserName -match '$Username' } |
        Select-Object Name, Id, CPU, WorkingSet, UserName |
        Format-Table -AutoSize | Out-String
"@

    if ($processes) {
        Show-CustomDialog -Title "Processus en cours - $Username" -Message $processes -Options @("OK")
    }
    else {
        Show-CustomDialog -Title "Information" -Message "Aucun processus en cours pour $Username" -Options @("OK")
    }
}

# Fonction pour afficher les fichiers récents d'un utilisateur
function Show-UserRecentFiles {
    param ([string]$Username)

    $recentFiles = Invoke-RemoteCommand @"
        Get-ChildItem "C:\Users\$Username\AppData\Roaming\Microsoft\Windows\Recent" -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object Name, LastWriteTime |
        Format-Table -AutoSize | Out-String
"@

    if ($recentFiles) {
        Show-CustomDialog -Title "Fichiers récents - $Username" -Message $recentFiles -Options @("OK")
    }
    else {
        Show-CustomDialog -Title "Information" -Message "Aucun fichier récent trouvé pour $Username" -Options @("OK")
    }
}

# Menu de gestion des groupes
function Show-GroupManagementMenu {
    while ($true) {
        $choice = Show-CustomDialog -Title "Gestion des Groupes" -Message "Choisissez une option :" -Options @(
            "1. Liste des groupes",
            "2. Créer un groupe",
            "3. Supprimer un groupe",
            "4. Ajouter un utilisateur à un groupe",
            "5. Retirer un utilisateur d'un groupe",
            "6. Retour"
        )

        switch ($choice) {
            "1. Liste des groupes" { Show-GroupList }
            "2. Créer un groupe" { New-CustomGroup }
            "3. Supprimer un groupe" { Remove-CustomGroup }
            "4. Ajouter un utilisateur à un groupe" { Add-UserToGroup }
            "5. Retirer un utilisateur d'un groupe" { Remove-UserFromGroup }
            "6. Retour" { return }
            default { return }
        }
    }
}

# Fonction pour afficher la liste des groupes
function Show-GroupList {
    $groups = Invoke-RemoteCommand "Get-LocalGroup | Select-Object Name, Description | Format-Table -AutoSize | Out-String"
    Show-CustomDialog -Title "Liste des Groupes" -Message $groups -Options @("OK")
}

# Fonction pour créer un nouveau groupe
function New-CustomGroup {
    $groupName = Show-InputDialog -Title "Création de Groupe" -Message "Entrez le nom du nouveau groupe :"
    if (-not $groupName) { return }

    $description = Show-InputDialog -Title "Description du Groupe" -Message "Entrez la description du groupe :"
    
    try {
        $result = Invoke-RemoteCommand "New-LocalGroup -Name '$groupName' -Description '$description'"
        Show-CustomDialog -Title "Succès" -Message "Groupe '$groupName' créé avec succès." -Options @("OK")
    }
    catch {
        Show-CustomDialog -Title "Erreur" -Message "Erreur lors de la création du groupe : $_" -Options @("OK")
    }
}

# Fonction pour supprimer un groupe
function Remove-CustomGroup {
    $groups = Invoke-RemoteCommand "Get-LocalGroup | Select-Object -ExpandProperty Name"
    $groupName = Show-CustomDialog -Title "Suppression de Groupe" -Message "Choisissez le groupe à supprimer :" -Options $groups.Split("`n")
    
    if ($groupName) {
        if (Show-YesNoDialog -Title "Confirmation" -Message "Êtes-vous sûr de vouloir supprimer le groupe '$groupName' ?") {
            try {
                $result = Invoke-RemoteCommand "Remove-LocalGroup -Name '$groupName'"
                Show-CustomDialog -Title "Succès" -Message "Groupe '$groupName' supprimé avec succès." -Options @("OK")
            }
            catch {
                Show-CustomDialog -Title "Erreur" -Message "Erreur lors de la suppression du groupe : $_" -Options @("OK")
            }
        }
    }
}

# Fonction pour ajouter un utilisateur à un groupe
function Add-UserToGroup {
    $users = Invoke-RemoteCommand "Get-LocalUser | Select-Object -ExpandProperty Name"
    $groups = Invoke-RemoteCommand "Get-LocalGroup | Select-Object -ExpandProperty Name"

    $userName = Show-CustomDialog -Title "Sélection d'utilisateur" -Message "Choisissez un utilisateur :" -Options $users.Split("`n")
    if (-not $userName) { return }

    $groupName = Show-CustomDialog -Title "Sélection de groupe" -Message "Choisissez un groupe :" -Options $groups.Split("`n")
    if (-not $groupName) { return }

    try {
        $result = Invoke-RemoteCommand "Add-LocalGroupMember -Group '$groupName' -Member '$userName'"
        Show-CustomDialog -Title "Succès" -Message "Utilisateur '$userName' ajouté au groupe '$groupName' avec succès." -Options @("OK")
    }
    catch {
        Show-CustomDialog -Title "Erreur" -Message "Erreur lors de l'ajout de l'utilisateur au groupe : $_" -Options @("OK")
    }
}

# Fonction pour retirer un utilisateur d'un groupe
function Remove-UserFromGroup {
    $groups = Invoke-RemoteCommand "Get-LocalGroup | Select-Object -ExpandProperty Name"
    $groupName = Show-CustomDialog -Title "Sélection de groupe" -Message "Choisissez un groupe :" -Options $groups.Split("`n")
    if (-not $groupName) { return }

    $groupMembers = Invoke-RemoteCommand "Get-LocalGroupMember -Group '$groupName' | Select-Object -ExpandProperty Name"
    $userName = Show-CustomDialog -Title "Sélection d'utilisateur" -Message "Choisissez un utilisateur à retirer :" -Options $groupMembers.Split("`n")
    if (-not $userName) { return }

    try {
        $result = Invoke-RemoteCommand "Remove-LocalGroupMember -Group '$groupName' -Member '$userName'"
        Show-CustomDialog -Title "Succès" -Message "Utilisateur '$userName' retiré du groupe '$groupName' avec succès." -Options @("OK")
    }
    catch {
        Show-CustomDialog -Title "Erreur" -Message "Erreur lors du retrait de l'utilisateur du groupe : $_" -Options @("OK")
    }
}
# Menu de gestion des ordinateurs
function Show-ComputerManagementMenu {
    while ($true) {
        $choice = Show-CustomDialog -Title "Gestion des Ordinateurs" -Message "Choisissez une option:" -Options @(
            "1. Informations système",
            "2. Gestion de l'alimentation",
            "3. Gestion des répertoires",
            "4. Gestion des logiciels",
            "5. Mise à jour système",
            "6. Retour au menu principal"
        )

        switch ($choice) {
            "1. Informations système" { Show-SystemInfoMenu }
            "2. Gestion de l'alimentation" { Show-PowerManagementMenu }
            "3. Gestion des répertoires" { Show-DirectoryManagementMenu }
            "4. Gestion des logiciels" { Show-SoftwareManagementMenu }
            "5. Mise à jour système" { Update-RemoteSystem }
            "6. Retour au menu principal" { return }
            default { return }
        }
    }
}

# Menu d'informations système
function Show-SystemInfoMenu {
    while ($true) {
        $choice = Show-CustomDialog -Title "Informations Système" -Message "Choisissez une option:" -Options @(
            "1. Version du système",
            "2. Informations disque et RAM",
            "3. Activité système",
            "4. Retour"
        )

        switch ($choice) {
            "1. Version du système" { 
                $result = Invoke-RemoteCommand "Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsHardwareAbstractionLayer"
                Show-CustomDialog -Title "Version du Système" -Message $result -Options @("OK")
            }
            "2. Informations disque et RAM" { Show-DiskAndRAMInfo }
            "3. Activité système" { Show-SystemActivity }
            "4. Retour" { return }
            default { return }
        }
    }
}

# Fonction pour afficher les informations disque et RAM
function Show-DiskAndRAMInfo {
    while ($true) {
        $choice = Show-CustomDialog -Title "Disque et RAM" -Message "Choisissez une option:" -Options @(
            "1. Liste des disques",
            "2. Informations de partition",
            "3. Espace disque disponible",
            "4. État de la RAM",
            "5. Retour"
        )

        switch ($choice) {
            "1. Liste des disques" {
                $result = Invoke-RemoteCommand "Get-Disk | Format-Table -AutoSize"
                Show-CustomDialog -Title "Liste des Disques" -Message $result -Options @("OK")
            }
            "2. Informations de partition" {
                $result = Invoke-RemoteCommand "Get-Partition | Format-Table -AutoSize"
                Show-CustomDialog -Title "Informations de Partition" -Message $result -Options @("OK")
            }
            "3. Espace disque disponible" {
                $result = Invoke-RemoteCommand "Get-Volume | Format-Table -AutoSize"
                Show-CustomDialog -Title "Espace Disque" -Message $result -Options @("OK")
            }
            "4. État de la RAM" {
                $result = Invoke-RemoteCommand @"
                    Get-CimInstance Win32_OperatingSystem | 
                    Select-Object @{Name="TotalRAM(GB)";Expression={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}},
                                @{Name="FreeRAM(GB)";Expression={[math]::Round($_.FreePhysicalMemory/1MB,2)}}
"@
                Show-CustomDialog -Title "État de la RAM" -Message $result -Options @("OK")
            }
            "5. Retour" { return }
            default { return }
        }
    }
}

# Menu de gestion de l'alimentation
function Show-PowerManagementMenu {
    while ($true) {
        $choice = Show-CustomDialog -Title "Gestion de l'Alimentation" -Message "Choisissez une option:" -Options @(
            "1. Arrêter l'ordinateur",
            "2. Redémarrer l'ordinateur",
            "3. Mettre en veille",
            "4. Verrouiller la session",
            "5. Retour"
        )

        switch ($choice) {
            "1. Arrêter l'ordinateur" {
                if (Show-YesNoDialog -Title "Confirmation" -Message "Voulez-vous vraiment arrêter l'ordinateur ?") {
                    Invoke-RemoteCommand "Stop-Computer -Force"
                }
            }
            "2. Redémarrer l'ordinateur" {
                if (Show-YesNoDialog -Title "Confirmation" -Message "Voulez-vous vraiment redémarrer l'ordinateur ?") {
                    Invoke-RemoteCommand "Restart-Computer -Force"
                }
            }
            "3. Mettre en veille" {
                if (Show-YesNoDialog -Title "Confirmation" -Message "Voulez-vous mettre l'ordinateur en veille ?") {
                    Invoke-RemoteCommand "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false)"
                }
            }
            "4. Verrouiller la session" {
                if (Show-YesNoDialog -Title "Confirmation" -Message "Voulez-vous verrouiller la session ?") {
                    Invoke-RemoteCommand "rundll32.exe user32.dll,LockWorkStation"
                }
            }
            "5. Retour" { return }
            default { return }
        }
    }
}

# Fonction dialogue Oui/Non
function Show-YesNoDialog {
    param (
        [string]$Title,
        [string]$Message
    )

    $result = [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    return $result -eq [System.Windows.Forms.DialogResult]::Yes
}

# Menu de gestion des répertoires
function Show-DirectoryManagementMenu {
    while ($true) {
        $choice = Show-CustomDialog -Title "Gestion des Répertoires" -Message "Choisissez une option:" -Options @(
            "1. Créer un répertoire",
            "2. Renommer un répertoire",
            "3. Supprimer un répertoire",
            "4. Retour"
        )

        switch ($choice) {
            "1. Créer un répertoire" {
                $path = Show-InputDialog -Title "Création de Répertoire" -Message "Entrez le chemin du nouveau répertoire:"
                if ($path) {
                    $result = Invoke-RemoteCommand "New-Item -Path '$path' -ItemType Directory -Force"
                    Show-CustomDialog -Title "Résultat" -Message "Répertoire créé : $result" -Options @("OK")
                }
            }
            "2. Renommer un répertoire" {
                $oldPath = Show-InputDialog -Title "Renommer Répertoire" -Message "Entrez le chemin actuel:"
                if ($oldPath) {
                    $newPath = Show-InputDialog -Title "Renommer Répertoire" -Message "Entrez le nouveau chemin:"
                    if ($newPath) {
                        $result = Invoke-RemoteCommand "Rename-Item -Path '$oldPath' -NewName '$newPath' -Force"
                        Show-CustomDialog -Title "Résultat" -Message "Répertoire renommé" -Options @("OK")
                    }
                }
            }
            "3. Supprimer un répertoire" {
                $path = Show-InputDialog -Title "Supprimer Répertoire" -Message "Entrez le chemin du répertoire à supprimer:"
                if ($path) {
                    if (Show-YesNoDialog -Title "Confirmation" -Message "Voulez-vous vraiment supprimer ce répertoire ?") {
                        $result = Invoke-RemoteCommand "Remove-Item -Path '$path' -Recurse -Force"
                        Show-CustomDialog -Title "Résultat" -Message "Répertoire supprimé" -Options @("OK")
                    }
                }
            }
            "4. Retour" { return }
            default { return }
        }
    }
}



# Menu Gestion des Logiciels
function Show-SoftwareManagementMenu {
    while ($true) {
        $choice = Show-CustomDialog -Title "Gestion des Logiciels" -Message "Choisissez une option :" -Options @(
            "1. Installer un logiciel",
            "2. Désinstaller un logiciel",
            "3. Démarrer un logiciel",
            "4. Arrêter un logiciel",
            "5. Retour au menu précédent"
        )

        switch ($choice) {
            "1. Installer un logiciel" {
                $software = Show-InputDialog -Title "Installer un Logiciel" -Message "Entrez le nom du logiciel à installer :"
                if ($software) {
                    try {
                        $result = Start-Process -FilePath "winget" -ArgumentList "install -e --id $software" -Wait -NoNewWindow -PassThru
                        if ($result.ExitCode -eq 0) {
                            [System.Windows.Forms.MessageBox]::Show("Logiciel '$software' installé avec succès.", "Succès")
                        } else {
                            [System.Windows.Forms.MessageBox]::Show("Échec de l'installation de '$software'.", "Erreur")
                        }
                    }
                    catch {
                        [System.Windows.Forms.MessageBox]::Show("Erreur lors de l'installation : $_", "Erreur")
                    }
                }
            }
            "2. Désinstaller un logiciel" {
                $software = Show-InputDialog -Title "Désinstaller un Logiciel" -Message "Entrez le nom du logiciel à désinstaller :"
                if ($software) {
                    try {
                        $result = Start-Process -FilePath "winget" -ArgumentList "uninstall -e --id $software" -Wait -NoNewWindow -PassThru
                        if ($result.ExitCode -eq 0) {
                            [System.Windows.Forms.MessageBox]::Show("Logiciel '$software' désinstallé avec succès.", "Succès")
                        } else {
                            [System.Windows.Forms.MessageBox]::Show("Échec de la désinstallation de '$software'.", "Erreur")
                        }
                    }
                    catch {
                        [System.Windows.Forms.MessageBox]::Show("Erreur lors de la désinstallation : $_", "Erreur")
                    }
                }
            }
        
               
            "3. Démarrer un logiciel" {
                $software = Show-InputDialog -Title "Démarrer un Logiciel" -Message "Entrez le nom du logiciel à démarrer :"
                if ($software) {
                    $result = Invoke-RemoteCommand Start-Process $software 
                    if ($result) {
                        [System.Windows.Forms.MessageBox]::Show("Logiciel '$software' démarré avec succès.", "Succès")
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("Échec du démarrage du logiciel '$software'.", "Erreur")
                    }
                }
            }
            "4. Arrêter un logiciel" {
                $software = Show-InputDialog -Title "Arrêter un Logiciel" -Message "Entrez le nom du logiciel à arrêter :"
                if ($software) {
                    $result = Invoke-RemoteCommand Stop-Process -Name $software -Force
                    if ($result) {
                        [System.Windows.Forms.MessageBox]::Show("Logiciel '$software' arrêté avec succès.", "Succès")
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("Échec de l'arrêt du logiciel '$software'.", "Erreur")
                    }
                }
            }
            "5. Retour au menu précédent" { return }
            default { return }
        }
    }
}



# Fonction pour mettre à jour le système
function Update-RemoteSystem {
    $confirmation = Show-YesNoDialog -Title "Mise à Jour Système" -Message "Voulez-vous vraiment mettre à jour le système ?"
    if ($confirmation) {
        try {
            $result = Start-Process -FilePath "wuauclt.exe" -ArgumentList "/updatenow" -Wait -NoNewWindow -PassThru
            if ($result.ExitCode -eq 0) {
                [System.Windows.Forms.MessageBox]::Show("Mise à jour du système lancée.", "Succès")
            } else {
                [System.Windows.Forms.MessageBox]::Show("Échec de la mise à jour du système.", "Erreur")
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Erreur lors de la mise à jour : $_", "Erreur")
        }
    }
}




# Menu Gestion des Répertoires
function Show-DirectoryManagementMenu {
    while ($true) {
        $choice = Show-CustomDialog -Title "Gestion des Répertoires" -Message "Choisissez une option :" -Options @(
            "1. Créer un répertoire",
            "2. Renommer un répertoire",
            "3. Supprimer un répertoire",
            "4. Retour au menu précédent"
        )

        switch ($choice) {
            "1. Créer un répertoire" {
                $path = Show-InputDialog -Title "Création de Répertoire" -Message "Entrez le chemin du nouveau répertoire :"
                if ($path) {
                    $result = Invoke-RemoteCommand "mkdir -p '$path'"
                    if ($result) {
                        [System.Windows.Forms.MessageBox]::Show("Répertoire '$path' créé avec succès.", "Succès")
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("Échec de la création du répertoire '$path'.", "Erreur")
                    }
                }
            }
            "2. Renommer un répertoire" {
                $oldPath = Show-InputDialog -Title "Renommer Répertoire" -Message "Entrez le chemin actuel du répertoire :"
                $newPath = Show-InputDialog -Title "Renommer Répertoire" -Message "Entrez le nouveau chemin du répertoire :"
                if ($oldPath -and $newPath) {
                    $result = Invoke-RemoteCommand "mv '$oldPath' '$newPath'"
                    if ($result) {
                        [System.Windows.Forms.MessageBox]::Show("Répertoire renommé de '$oldPath' à '$newPath' avec succès.", "Succès")
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("Échec du renommage du répertoire.", "Erreur")
                    }
                }
            }
            "3. Supprimer un répertoire" {
                $path = Show-InputDialog -Title "Supprimer Répertoire" -Message "Entrez le chemin du répertoire à supprimer :"
                if ($path) {
                    if (Show-YesNoDialog -Title "Confirmation" -Message "Voulez-vous vraiment supprimer ce répertoire ?") {
                        $result = Invoke-RemoteCommand "rm -r '$path'"
                        if ($result) {
                            [System.Windows.Forms.MessageBox]::Show("Répertoire '$path' supprimé avec succès.", "Succès")
                        } else {
                            [System.Windows.Forms.MessageBox]::Show("Échec de la suppression du répertoire '$path'.", "Erreur")
                        }
                    }
                }
            }
            "4. Retour au menu précédent" { return }
            default { return }
        }
    }
}