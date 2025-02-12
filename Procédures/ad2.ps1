# Fonction pour harmoniser les noms de fonction
function Harmoniser-Groupes {
    param ([string]$Fonction)

    # Remplacer les variantes féminines par la version masculine
    $Harmonisations = @{
        "Technicienne maintenance"   = "Technicien maintenance"
        "Conductrice de machines"    = "Conducteur de machines"
        "Employée administrative"    = "Employé administratif"
        "Chargée de mission"         = "Chargé de mission"
        "Directrice Admin. & Fin."   = "Directeur Administratif et Financier"
    }

    foreach ($key in $Harmonisations.Keys) {
        $Fonction = $Fonction -replace [regex]::Escape($key), $Harmonisations[$key]
    }

    # Retirer les chiffres à la fin de la fonction (s'il y en a)
    $Fonction = $Fonction -replace "\s*\d+$", ""

    return $Fonction
}

# Chemin du fichier CSV
$CSVFile = "C:\temp\ecosolarsolutions.csv"
$CSVData = Import-CSV -Path $CSVFile -Delimiter ";" -Encoding UTF8

# Liste des groupes déjà créés pour éviter les doublons
$GroupesGlobauxTraités = @{}

# Initialiser le compteur pour la barre de progression
$Count = 0

# Boucle pour chaque utilisateur
Foreach ($Utilisateur in $CSVData) {

    # Incrémenter le compteur
    $Count++

    # Mettre à jour la barre de progression
    Write-Progress -Activity "Création des OU, des groupes et des utilisateurs" `
        -Status "$Count sur $($CSVData.Length)" `
        -PercentComplete ($Count / $CSVData.Length * 100)

    $UtilisateurPrenom = $Utilisateur.prenom
    $UtilisateurNom = $Utilisateur.nom
    $UtilisateurLogin = ($UtilisateurPrenom).Substring(0, 1) + "." + $UtilisateurNom
    $UtilisateurEmail = "$UtilisateurLogin@ecosolar.fr"
    $UtilisateurMotDePasse = "Azerty1*"
    $UtilisateurFonction = $Utilisateur.fonction
    $UtilisateurService = $Utilisateur.service

    # Harmoniser la fonction pour obtenir une version unique masculine/neutre
    $FonctionPrincipale = Harmoniser-Groupes $UtilisateurFonction

    # Nom du groupe global
    $GroupeGlobalNom = "$FonctionPrincipale"

    # Définir le chemin de l'OU spécifique au service
    $OUPath = "OU=$UtilisateurService,DC=ecosolarsolutions,DC=local"

    # Création de l'OU pour le service (si elle n'existe pas)
    if (-not (Get-ADOrganizationalUnit -Filter * | Where-Object { $_.Name -eq $UtilisateurService })) {
        try {
            New-ADOrganizationalUnit -Name $UtilisateurService -Path "DC=ecosolarsolutions,DC=local" -Confirm:$false
            Write-Host "Création de l'OU : $UtilisateurService" -ForegroundColor Green
        }
        catch {
            Write-Warning "Erreur lors de la création de l'OU $UtilisateurService : $_"
        }
    }

    # Vérifier si le groupe global existe déjà, sinon le créer
    if (-not $GroupesGlobauxTraités.ContainsKey($FonctionPrincipale)) {
        $GroupesGlobauxTraités[$FonctionPrincipale] = $true

        if (-not (Get-ADGroup -Filter * | Where-Object { $_.Name -eq $GroupeGlobalNom })) {
            try {
                New-ADGroup -Name $GroupeGlobalNom -SamAccountName $GroupeGlobalNom `
                    -GroupCategory Security -GroupScope Global `
                    -Path $OUPath
                Write-Host "Création du groupe : $GroupeGlobalNom" -ForegroundColor Green
            }
            catch {
                Write-Warning "Erreur lors de la création du groupe $GroupeGlobalNom : $_"
            }
        }
        else {
            Write-Host "Le groupe $GroupeGlobalNom existe déjà." -ForegroundColor Yellow
        }
    }

    # Vérifier la présence de l'utilisateur dans l'AD
    if (-not (Get-ADUser -Filter * | Where-Object { $_.SamAccountName -eq $UtilisateurLogin })) {
        try {
            # Création de l'utilisateur s'il n'existe pas
            New-ADUser -Name "$UtilisateurNom $UtilisateurPrenom" `
                -DisplayName "$UtilisateurNom $UtilisateurPrenom" `
                -GivenName $UtilisateurPrenom `
                -Surname $UtilisateurNom `
                -SamAccountName $UtilisateurLogin `
                -UserPrincipalName "$UtilisateurLogin@ecosolarsolutions.fr" `
                -EmailAddress $UtilisateurEmail `
                -Title $UtilisateurFonction `
                -Path $OUPath `
                -AccountPassword (ConvertTo-SecureString $UtilisateurMotDePasse -AsPlainText -Force) `
                -ChangePasswordAtLogon $true `
                -Enabled $true

            Write-Host "Création de l'utilisateur : $UtilisateurLogin ($UtilisateurNom $UtilisateurPrenom)" -ForegroundColor Green
        }
        catch {
            Write-Warning "Erreur lors de la création de l'utilisateur $UtilisateurLogin : $_"
        }
    }
    else {
        Write-Host "L'utilisateur $UtilisateurLogin existe déjà dans l'AD." -ForegroundColor Yellow
    }

    # Ajouter l'utilisateur dans le groupe global
    try {
        Add-ADGroupMember -Identity $GroupeGlobalNom -Members $UtilisateurLogin -ErrorAction Stop
        Write-Host "Ajout de $UtilisateurLogin au groupe $GroupeGlobalNom" -ForegroundColor Green
    }
    catch {
        Write-Warning "Impossible d'ajouter $UtilisateurLogin au groupe $GroupeGlobalNom : $_"
    }
}
