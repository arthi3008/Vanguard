param (
    [Parameter(Mandatory=$true)]
    [string]$sourceKeyVaultName,
 
    [Parameter(Mandatory=$true)]
    [string]$targetKeyVaultName
)
 
 
# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context
 
# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.subscription -DefaultProfile $AzureContext
 
 
if (-not $sourceKeyVaultName -or -not $targetKeyVaultName) {
    Write-Host "Please provide both source and target Key Vault names."
    exit
}
 
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
        $sourceSecretValue = (Get-AzKeyVaultSecret -VaultName $sourceKeyVaultName -Name $secret.Name).SecretValue
        $targetSecret = Get-AzKeyVaultSecret -VaultName $targetKeyVaultName -Name $secret.Name -ErrorAction SilentlyContinue
 
        $sourceSecretPlainText = ConvertTo-PlainString($sourceSecretValue)
        $targetSecretPlainText = if ($targetSecret) { ConvertTo-PlainString($targetSecret.SecretValue) } else { $null }
 
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
