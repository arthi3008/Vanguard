# Log in to Azure
Connect-AzAccount
 
# Set source and target Key Vault names
$sourceKeyVaultName = "AzureDRKV2"
$targetKeyVaultName = "AzureDRKV1"
 
# Function to convert SecureString to plain string
function ConvertTo-PlainString($secureString) {
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
    return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
}
 
# Function to convert plain string to SecureString
function ConvertTo-SecureStringFromPlain($plainString) {
    $secureString = New-Object -TypeName System.Security.SecureString
    $plainString.ToCharArray() | ForEach-Object { $secureString.AppendChar($_) }
    return $secureString
}
 
foreach ($secret in (Get-AzKeyVaultSecret -VaultName $sourceKeyVaultName)) {
    try {
        # Retrieve secret values from source and target Key Vaults
        $sourceSecretValue = (Get-AzKeyVaultSecret -VaultName $sourceKeyVaultName -Name $secret.Name).SecretValue
        $targetSecret = Get-AzKeyVaultSecret -VaultName $targetKeyVaultName -Name $secret.Name -ErrorAction SilentlyContinue
 
        # Convert source secret to plain text for comparison
        $sourceSecretPlainText = ConvertTo-PlainString($sourceSecretValue)
        $targetSecretPlainText = if ($targetSecret) { ConvertTo-PlainString($targetSecret.SecretValue) } else { $null }
 
        # If the secret is missing or different, update/create it in the target Key Vault
        if (-not $targetSecret -or $sourceSecretPlainText -ne $targetSecretPlainText) {
            Set-AzKeyVaultSecret -VaultName $targetKeyVaultName -Name $secret.Name -SecretValue (ConvertTo-SecureStringFromPlain $sourceSecretPlainText)
            Write-Host "Secret '$($secret.Name)' has been $(if ($targetSecret) {'updated'} else {'copied'}) in target Key Vault."
        } else {
            Write-Host "Secret '$($secret.Name)' is already up to date."
        }
    }
    catch {
        Write-Host "Error processing secret '$($secret.Name)': $_"
    }
}
 
Write-Host "Completed processing secrets from $sourceKeyVaultName to $targetKeyVaultName."
