# Fonction pour générer le nom du PC
function Generer-NomPC {
    param (
        [string]$TypePC, # P = Portable, B = Bureau
        [string]$Lieu, # I = Interne, E = Externe
        [int]$Numero      # Numéro unique
    )

    # Formatage du numéro pour qu'il soit sur 4 chiffres
    $NumeroFormatte = $Numero.ToString("D4")
    return "PC-$TypePC$Lieu-$NumeroFormatte"
}

# Chemin du fichier CSV (assurez-vous qu'il contient les informations nécessaires)
$CSVFile = "C:\temp\ecosolarsolutions.csv"
$CSVData = Import-CSV -Path $CSVFile -Delimiter ";" -Encoding UTF8

# Liste pour suivre les numéros uniques
$CompteurPC = 1

# Vérifier si l'OU "PC" existe, sinon la créer
$OUPCPath = "OU=PC,DC=ecosolarsolutions,DC=local"
if (-not (Get-ADOrganizationalUnit -Filter { Name -eq "PC" })) {
    New-ADOrganizationalUnit -Name "PC" -Path "DC=ecosolarsolutions,DC=local"
    Write-Host "Création de l'OU : PC" -ForegroundColor Green
}

# Boucle pour chaque utilisateur
foreach ($Utilisateur in $CSVData) {
    # Récupérer les informations de l'utilisateur
    $UtilisateurPrenom = $Utilisateur.prenom
    $UtilisateurNom = $Utilisateur.nom
    $UtilisateurLogin = ($UtilisateurPrenom).Substring(0, 1) + "." + $UtilisateurNom

    # Définir si c'est un portable ou un bureau
    $TypePC = "P"  # Par défaut, Portable
    if ($Utilisateur.service -match "bureau") {
        $TypePC = "B"
    }

    # Définir si c'est interne ou externe (exemple basé sur service)
    $Lieu = "I"  # Par défaut, Interne
    if ($Utilisateur.fonction -match "externe") {
        $Lieu = "E"
    }

    # Générer le nom unique du PC avec un numéro formaté sur 4 chiffres
    $NomPC = Generer-NomPC -TypePC $TypePC -Lieu $Lieu -Numero $CompteurPC
    $NomCompletPC = "$NomPC ($UtilisateurNom $UtilisateurPrenom)"

    # Incrémenter le compteur pour le prochain PC
    $CompteurPC++

    # Vérifier si l'ordinateur existe déjà dans l'AD
    if (-not (Get-ADComputer -Filter { Name -eq $NomPC })) {
        # Créer le PC dans l'OU "PC"
        New-ADComputer -Name $NomPC `
            -SamAccountName $NomPC `
            -DNSHostName "$NomPC.ecosolarsolutions.local" `
            -Description "Ordinateur assigné à $UtilisateurNom $UtilisateurPrenom" `
            -Path $OUPCPath `
            -Enabled $true

        Write-Host "Création de l'ordinateur : $NomCompletPC" -ForegroundColor Green
    }
    else {
        Write-Host "L'ordinateur $NomPC existe déjà." -ForegroundColor Red
    }
}
