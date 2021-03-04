<#VMware Cloud on AWS Sizing PowerShell Script
Copyright 2021 VMware, Inc.

This product is licensed to you under the BSD-2 license (the "License"). You may not use this product except in compliance with the BSD-2 License.  

This product may include a number of subcomponents with separate copyright notices and license terms. Your use of these subcomponents is subject to the terms and conditions of the subcomponent's license, as noted in the LICENSE file.#> 

param (
    [Parameter(Position=0,mandatory=$true,HelpMessage="Enter the vCenter FQDN or IP address which you would like to gather sizing information from.")]
    [string] $vcenterfqdn, 
    [Parameter(Position=1,mandatory=$true,HelpMessage="Enter the VMC instance type you would like to size for, i3 or i3en")]
    [string] $instancetype,
    [Parameter(Position=2,mandatory=$false,HelpMessage="Enter the vCPU to Core Ratio you want to use, if you specify nothing then the default value will be 4")]
    [int] $vcpuspercore = 4,
    [Parameter(Position=3,mandatory=$false,HelpMessage="Enter the vRAM to Physical RAM Ratio you want to use, if you specify nothing then the default value will be 1.25")]
    [decimal] $targetramratio = 1.25,
    [Parameter(Position=4,mandatory=$false,HelpMessage="Enter the CPU Utililization, if you specify nothing the default value will be 30")]
    [int] $cpuutilization = 30,
    [Parameter(Position=5,mandatory=$false,HelpMessage="Enter the Memory Utililization, if you specify nothing the default value will be 100")]
    [int] $memoryutilization = 100)

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
Connect-VIServer -Server $vcenterfqdn

## Get VM Metrics

Write-Host "Collecting Allocated VMDK Size Data, this may take some time `n" -ForegroundColor Green

$disks = @()
foreach ($vm in Get-Vm)
{
  foreach ($vmHardDisk in $vm| Get-HardDisk)
  {
  $disk = "" | Select-Object harddiskname,HardDiskCapacityGb
  $disk.HardDiskName = $vmHardDisk.Name
  $disk.HardDiskCapacityGb = [System.Math]::Round($vmHardDisk.CapacityGB, 0)
  $disks += $disk
  }
}

$diskSum = @($disks | Select-Object -Expand HardDiskCapacityGb) | Measure-Object -Sum -Average -Maximum -Minimum

Write-Host "Collecting vCPU and Memory details along with a count of all VMs`n" -ForegroundColor Green

$myCol = @()
foreach ($cluster in Get-Cluster)
    {
        foreach($vmhost in ($cluster | Get-VMHost))
        {
            foreach($vm in (Get-VM -Location $vmhost)){
                $VMView = $vm | Get-View
                $VMSummary = "" | Select-Object VMName,VMSockets,VMCores, VMMemory
                $VMSummary.VMName = $vm.Name
                $VMSummary.VMSockets = $VMView.Config.Hardware.NumCpu
                $VMSummary.VMCores = $VMView.Config.Hardware.NumCoresPerSocket
                $VMSummary.VMMemory =$VMView.Config.Hardware.MemoryMB
                $myCol += $VMSummary
            }
        }
    }

$vmCount = @($myCol | Select-Object -Expand VMName).Count
$cpuCount = @($myCol | Select-Object -Expand VMSockets) | Measure-Object -Sum -Average -Maximum -Minimum
$memoryCountMb = @($myCol | Select-Object -Expand VMMemory) | Measure-Object -Sum -Average -Maximum -Minimum

$memoryCountGB = [math]::Round($memoryCountMb.Sum / 1024)

# Average out the metrics ready for API call

## Get Average CPU per VM
$averageCPUPerVM = $cpuCount.Sum / $vmCount
$averageCPUPerVM = [math]::Ceiling($averageCPUPerVM)

## Get Average vRAM per VM
$averageMemoryPerVM = $memoryCountGB / $vmCount
$averageMemoryPerVM = [math]::Round($averageMemoryPerVM)

## Get Average Storage per VM
$averageStoragePerVM = $diskSum.Sum / $vmCount
$averageStoragePerVM = [math]::Ceiling($averageStoragePerVM)

# Write Collected data out to the Console to check the data
Write-Host "This is the Sum of VMDK Disks in this vCenter: "-ForegroundColor Gray -NoNewline
Write-Host  $diskSum.Sum"GB" -ForegroundColor Green
Write-Host "This is the number of VMs in this vCenter which will be sized for (No Templates taken into consideration): "-ForegroundColor Gray -NoNewline
write-Host $vmCount -ForegroundColor Green
Write-Host "This is the Sum of vCPUs: "-ForegroundColor Gray -NoNewline
Write-Host $cpuCount.Sum-ForegroundColor Green
Write-Host "This is the Sum of Memory: "-ForegroundColor Gray -NoNewline
Write-Host $memoryCountGB"GB" -ForegroundColor Green
Write-Host "This is the Sum of VMDK Disks in this vCenter: "-ForegroundColor Gray -NoNewline
Write-Host $diskSum.Sum"GB `n"-ForegroundColor Green
Write-Host "The Sizer will use an Average vCPU per VM of: " -ForegroundColor Gray -NoNewline
Write-Host $averageCPUPerVM "CPUs" -ForegroundColor Green
Write-Host "The Sizer will use an Average Memory per VM of: " -ForegroundColor Gray -NoNewline
Write-Host $averageMemoryPerVM"GB" -ForegroundColor Green
Write-Host "The Sizer will use an Average Storage per VM of: " -ForegroundColor Gray -NoNewline
Write-Host $averageStoragePerVM"GB `n" -ForegroundColor Green

# Write out the Workload information used
Write-Host "The Sizer will use vCPU to Core Ratio of: " -ForegroundColor Gray -NoNewline
Write-Host $vcpuspercore -ForegroundColor Green
Write-Host "The Sizer will use vRAM to Physical RAM Ratio of: " -ForegroundColor Gray -NoNewline
Write-Host $targetramratio -ForegroundColor Green
Write-Host "The Sizer will use the following CPU Utilizaton value of: " -ForegroundColor Gray -NoNewline
Write-Host $cpuutilization -ForegroundColor Green
Write-Host "The Sizer will use the following Memory Utilizaton value of: " -ForegroundColor Gray -NoNewline
Write-Host $memoryutilization -ForegroundColor Green

# Choose Host Type and set the Profile Mode code used
if ($instancetype -eq "i3en"){
    $profileModeCode = "FDS"
}else {
    $profileModeCode = "FS"
}

$uri = 'https://vmc.vmware.com/vmc/sizer/api/v2/recommendation'

$headers = @{
    'content-type' = 'application/json'
}

$body = Get-Content -Path ".\json_template.json" | ConvertFrom-JSON

$body.clusterConfiguration.profileModeCode = $profileModeCode
$body.clusterConfiguration.instanceType = $instanceType

$body.workloads.vmProfile.vCpusPerCore = $vcpuspercore
$body.workloads.vmProfile.targetRAMRatio = $targetramratio
$body.workloads.vmProfile.resourceUtilization.cpuUtilization.value = $cpuutilization
$body.workloads.vmProfile.resourceUtilization.memoryUtilization.value = $memoryutilization
$body.workloads.vmProfile.vCpusPerVM = $averageCPUPerVM
$body.workloads.vmProfile.vRAMPerVM.value = $averageMemoryPerVM
$body.workloads.vmProfile.vmsNum = $vmCount
$body.workloads.vmProfile.vmdkSize.value = $averageStoragePerVM

$bodyPost = $body | ConvertTo-Json -Depth 6

$sizingJson = Invoke-RestMethod -Uri $uri -Headers $headers -Body $bodyPost -Method Post

$sizingJson.genericResponse.clusterConfiguration.sddcInformation | Format-List

Write-Host "Sizing Recommendations"
write-host "You need" $sizingJson.genericResponse.clusterConfiguration.sddcInformation.nodesSize "Hosts of type" $sizingJson.genericResponse.instanceType "and the workload is" $sizingJson.genericResponse.recommendationType
