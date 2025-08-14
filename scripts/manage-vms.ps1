param 
(
    [Parameter(Mandatory=$true)]
    [String] $AzureVMList,
 
    [Parameter(Mandatory=$true)]
    [ValidateSet("Start","Stop")]
    [String] $Action,
 
    [Parameter(Mandatory=$false)]
    [String] $ResourceGroupName
)
 
# Connect to Azure with system-assigned managed identity
#$AzureContext = (Connect-AzAccount -Identity).context
 
# Set and store context
#$AzureContext = Set-AzContext -SubscriptionName $AzureContext.subscription -DefaultProfile $AzureContext
 
foreach ($AzureVM in $AzureVMList -split ",") 
{ 
    if($ResourceGroupName)
    {
        $vm = Get-AzVM -Name $AzureVM -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    }
    else
    {
        $vm = Get-AzVM -Name $AzureVM -Status -ErrorAction SilentlyContinue
    }
 
    if(-not $vm) 
    { 
        throw "AzureVM : [$AzureVM] - Does not exist! - Check your inputs" 
    } 
    else
    {
        if($Action -eq "Stop") 
        { 
            Write-Output "Stopping VM: $AzureVM"
            Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
        } 
        elseif($Action -eq "Start")
        { 
            Write-Output "Starting VM: $AzureVM"
            Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name
        }
    }
}