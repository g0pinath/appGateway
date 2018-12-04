<#
The main purpose of this script is to generate an input parameters file dynamically - Parameters4Deployment.json

For example, if the user chose the option as create ApplicationGatewayOnly then it will build the parameters file for AppGW only - Parameters4Deployment.json.
This dynamic parameters file is created based off a master file that contains parameters for all the resources in the project - ParametersMaster.json
The master parameters file is ParametersMaster.json
Based on this master file, and using the CSV input file, a parameters file called Parameters4Deployment.json will be created.
TemplateMaster.JSON file will execute the AppGW child template  and will use the Parameters4Deployment.json
#>

#Refer https://github.com/PowerShell/PowerShell/issues/2736 - without this function the converted JSON is having spaces all over the places, which New-AzureRmResourceGroupDeployment can handle but its not pretty/hard to read.


<###############################################################################################
VMSettings are being build as a single hashtable of arrays, for example  100 VM's will have a single hashtable that will contain VMnames as an array.
"VMSettings": {
      "value": {
        "domainJoinOptions": 3,
        "GDiskSizeinGB": [
          "80",
          "80"
        ],
        "osSKU": [
          "2016-Datacenter",
          "2016-Datacenter"
        ]
 }

 AppGWSettings are being built as an array of hash tables, where 5 AppGW will be listed as an array of 5 AppGW's with their properties represented as hashtables.
 This is because VM settings are simple and mostly repetitive, whereas AppGW settings are complex.
 The resources of VM like NIC, Disk can be constructed independently and then attached to the VM however the properties(ex resource type /routingrules) cant
 be created separately and then attached to AppGW, they need to fed at the time of creation.

###############################################################################################>

function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
  $indent = 0;
  ($json -Split '\n' |
    % {
      if ($_ -match '[\}\]]') {
        # This line contains  ] or }, decrement the indentation level
        $indent--
      }
      $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
      if ($_ -match '[\{\[]') {
        # This line contains [ or {, increment the indentation level
        $indent++
      }
      $line
  }) -Join "`n"
}

$Choice = Read-Host "Enter your choice

1 ----> Build Application Gateway ONLY.
2 ----> Build VM (DEVBUILD).
3 ----> Build ASE.
4 ----> All of the above.
"




$ParmatersMasterPath = "C:\Repos1\AppGW\ParametersMaster.json"
$TemplateMasterPath = "C:\Repos1\AppGW\TemplateMaster.json" 
$AllResourcesFinalJSON = (Get-Content $ParmatersMasterPath) -join "`n" | ConvertFrom-Json
[string]$Parameters4DeploymentPath="C:\Repos1\AppGW\Parameters4Deployment.json"
$parametersCSV=@()



Function BuildParam4DeployFile_AppGWs($parametersCSV,$serverParam)
{
#Variables for AppGW

$applicationGatewayName	=@();$virtualNetworkName=@();$vnetResourceGroupName	=@();$subnetName=@()
$applicationGatewaySize=@();$applicationGatewayInstanceCount=@();$frontendPort=@()
$backendPort=@();$cookieBasedAffinity=@();$NumofWebApps=@();$WebAppDomainnames=@(@());$isInternetFacing=@()
$backEndFQDN=@();$ApplicationGateWaySettingsFinalarray=@();

#$serverParam = (Get-Content $ParmatersMasterPath) -join "`n" | ConvertFrom-Json

Foreach($row in $parametersCSV)
{

#We are building an army of arrays that will fed into a single file parameters4deployment based on the csv file.
#Parameters like VMnames will need to be captured as array.
#$ResourceGroupName = $row.ResourceGroupName
#Converting string to array example, web1.example.com;web2.example.com will be split to [web1.example.com, web2.example.com]
$WebAppDomainnamesstr=$row.WebAppDomainnames
$AppGWName = $row.applicationGatewayName
$WebAppDomainnamessplit=@()
$WebAppDomainnamessplit = $WebAppDomainnamesstr -split ";" 
$WebAppDomainnames=$WebAppDomainnamessplit # comma if you need to add the array into an array Ex: @(("web1appgw1","web2appgw1),("web1appgw2","web2appgw2))
$backEndFQDN+=,$WebAppDomainnamessplit
$ProbesArray=@();$BackendhttpsettingcollectionArray=@();$httplistenersArray=@();$requestRoutingRulesArray=@();$BackedFQDNarray=@()
$ApplicationGateWaySettingsarray=@()
$WebAppDomainnamesArray=@()


Foreach($webapp in $WebAppDomainnames)
{

$currentprobe =@(@{
            name= "$webapp";
            properties=@{
              host="$webapp";
              path= "/";
              protocol= "Https";
              timeout= 30;
              unhealthyThreshold= 3;
              interval= 30;
              match=@{statusCodes=@("200-399")}
          }
        }
        )
$ProbesArray+=$currentprobe

$currentBackendhttpsettingcollection = @(@{
          name= "$webapp";
            properties= @{
              "Port"= "443";
              "Protocol"= "Https";
              "CookieBasedAffinity"= "Disabled";
              "authenticationCertificates"= @(
                @{
                  "id"= "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/applicationGateways/$AppGWName/authenticationCertificates/backEndPublicKeyOnly"           
                }
              );
              probe= @{
                id= "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/applicationGateways/$AppGWName/probes/$webapp"}           
            }
          }
        )
$currentListener= @(
          @{
            name= "$webapp";
            properties= @{
              FrontendIpConfiguration= @{
                Id= "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/applicationGateways/$AppGWName/frontendIPConfigurations/appGatewayFrontendIP2"
              };
              hostName= "$webapp";
              FrontendPort= @{
                Id= "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/applicationGateways/$AppGWName/frontendPorts/appGatewayFrontendPorthhtps"
              };
              Protocol= "Https";
              SslCertificate= @{
                id= "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/applicationGateways/$AppGWName/sslCertificates/sslFrontEndCertwPvtKey" 
              }
            }
          }
        )
$currentrequestRoutingRules=@(
@{
            Name= "$webapp";
            properties= @{
            RuleType= "Basic";
            httpListener= @{
            name= "$webapp";
            
                id= "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/applicationGateways/$AppGWName/httpListeners/$webapp"
               
              };
              backendAddressPool= @{
                id= "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/applicationGateways/$AppGWName/backendAddressPools/appGatewayBackendPool"
              };
              backendHttpSettings= @{
                id= "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/applicationGateways/$AppGWName/backendHttpSettingsCollection/$webapp"
              }
            }
          }
)
$currentBackedFQDN = @(@{fqdn= "$webapp"})


$BackendhttpsettingcollectionArray+=$currentBackendhttpsettingcollection
$httplistenersArray+=$currentListener
$requestRoutingRulesArray+=$currentrequestRoutingRules
$BackedFQDNarray+=$currentBackedFQDN
$WebAppDomainnamesArray+=@{name= "$webapp"}
}
$VNETName = $row.virtualNetworkName
$AppGWRGName= $row.ResourceGroupName
$SubnetName = $row.subnetName
[string]$appGatewayFrontendIP =  "/subscriptions/"+ "$subscriptionID"+ "/resourceGroups/"+ "$resourceGroupName"+ "/providers/Microsoft.Network/virtualNetworks/"+ $VNEName+"/subnets/"+$SubnetName

[string]$authenticationCertificatesID = "/subscriptions/"+$subscriptionID+"/resourceGroups/"+$ResourceGroupName+"/providers/Microsoft.Network/applicationGateways/"+$AppGWName+"/authenticationCertificates/backEndPublicKeyOnly"


$ApplicationGateWaySettingsarray=@(
         @{
        applicationGatewayName="$AppGWName";
        appGatewayFrontendIP= "$appGatewayFrontendIP";
        authenticationCertificatesID="$authenticationCertificatesID";
        virtualNetworkName="$VNETName";
        ResourceGroupName="$AppGWRGName";
        subnetName="$SubnetName";
        applicationGatewaySize="Standard_Small";
        applicationGatewayInstanceCount=  1;
        frontendPort=  80;
        frontendporthttps= 443;
        backendPort=  80;        
        cookieBasedAffinity= "Disabled";
        NumofWebApps= ($WebAppDomainnames |Measure).Count;
        WebAppDomainnames= @($WebAppDomainnamesArray);
        isInternetFacing= "TRUE";
        
        backendHttpSettingsCollection=@($BackendhttpsettingcollectionArray);
        probes= @($ProbesArray);
        httpListeners= @($httplistenersArray);
        requestRoutingRules = @($requestRoutingRulesArray);
        backEndFQDN=  @($BackedFQDNarray)
         }
          )
$ApplicationGateWaySettingsFinalarray+=$ApplicationGateWaySettingsarray

}


$AllResourcesFinalJSON.parameters.ApplicationGateWaySettings.value=$ApplicationGateWaySettingsFinalarray
Return $AllResourcesFinalJSON
}
#Dynamic parameter template for deployment - uses ParametersMaster.json for reference.

Function VMSettingsJSON($parametersCSV, $AllResourcesFinalJSON)
{

$VMSettingsFinalHT=@{};$virtualMachineName=@();$virtualMachineSize=@();
$virtualNetworkName=@();$rgName=@();$vmimagetype=@();$networkSecurityGroupName=@();$isPublicIPRequired=@();
$publicIpAddressType=@();$publicIpAddressSku=@();$FDiskSizeinGB=@();$FDiskCreateOption=@();$FDiskAccountType=@();
$osType=@();$osPublisher=@();$osOffer=@();$osSKU=@();$GDiskSizeinGB=@();
$GDiskCreateOption=@();$GDiskAccountType=@();$storageAccountName=@();$diagnosticsStorageAccountName=@();
$subnetName=@();$privateIpAddress=@()

Foreach($row in $parametersCSV)
{
$virtualMachineName+=$row.virtualMachineName; $virtualMachineSize+=$row.virtualMachineSize; $virtualNetworkName+=$row.virtualNetworkName
$rgName+=$row.rgName; $vmimagetype+=$row.vmimagetype; $networkSecurityGroupName+=$row.networkSecurityGroupName
$isPublicIPRequired+=$row.isPublicIPRequired; $publicIpAddressType+=$row.publicIpAddressType; $publicIpAddressSku+=$row.publicIpAddressSku
$FDiskSizeinGB+=$row.FDiskSizeinGB; $FDiskCreateOption+=$row.FDiskCreateOption

$FDiskAccountType+=$row.FDiskAccountType; $osType+=$row.osType; $osPublisher+=$row.osPublisher
$osOffer+=$row.osOffer; $osSKU+=$row.osSKU; $GDiskSizeinGB+=$row.GDiskSizeinGB
$GDiskCreateOption+=$row.GDiskCreateOption; $GDiskAccountType+=$row.GDiskAccountType; $storageAccountName+=$row.storageAccountName
$diagnosticsStorageAccountName+=$row.diagnosticsStorageAccountName;$subnetName+=$row.subnetName;$privateIpAddress+=$row.privateIpAddress;


}#End of FOR
$VMSettingsJSONHashTable=
        @{
         virtualMachineName= @($virtualMachineName);
            virtualMachineSize= @($virtualMachineSize);
            virtualNetworkName= @($virtualNetworkName);
            rgName= @($rgName);
            vmimagetype= @($vmimagetype);
            networkSecurityGroupName= @($networkSecurityGroupName);          
            isPublicIPRequired= @($isPublicIPRequired);
            publicIpAddressType= @($publicIpAddressType);
            publicIpAddressSku= @($publicIpAddressSku);
            FDiskSizeinGB= @($FDiskSizeinGB);
            FDiskCreateOption= @($FDiskCreateOption);
            domainJoinOptions= 3;
            localadminusername="sysadmin"
            FDiskAccountType= @($FDiskAccountType);
            osType= @($osType);
            osPublisher= @($osPublisher);
            osOffer= @($osOffer);
            osSKU= @($osSKU);
            GDiskSizeinGB= @($GDiskSizeinGB);
            GDiskCreateOption= @($GDiskCreateOption);
            GDiskAccountType= @($GDiskAccountType);
            storageAccountName= @($storageAccountName);
            diagnosticsStorageAccountName= @($diagnosticsStorageAccountName);
            privateIpAddress= @($privateIpAddress);
            subnetName= @($subnetName);
        
         }
         #$VMSettingsFinalarray+=$VMSettingsJSONHashTable
         $VMSettingsFinalHT+=$VMSettingsJSONHashTable


      
      $AllResourcesFinalJSON.parameters.VMSettings.value=$VMSettingsFinalHT
      Return $AllResourcesFinalJSON
}

Function ASESettingsJSON($parametersCSV,$AllResourcesFinalJSON)
{


$ASESettingsFinalHT=@{};$ASEName=@();$ASELocation=@();$internalLoadBalancingMode=@();$dnsSuffix=@();
$vnetName=@();$subnetName=@();$appServicePlanName=@();$owner=@();$workerPool=@();$numberOfWorkersFromWorkerPool=@();

Foreach($row in $parametersCSV)
{

$ASEName+=$row.ASEName; $ASELocation+=$row.ASELocation; $internalLoadBalancingMode+=$row.internalLoadBalancingMode; $dnsSuffix+=$row.dnsSuffix; 
$vnetName+=$row.vnetName;$subnetName+=$row.subnetName;$appServicePlanName+=$row.appServicePlanName;$owner+=$row.owner;
$workerPool+=$row.workerPool;$numberOfWorkersFromWorkerPool+=$row.numberOfWorkersFromWorkerPool;
}#End of FOR
$ASESettingsJSONHashTable=
        @{
            ASEName=@($ASEName);
            ASELocation=@($ASELocation);
            internalLoadBalancingMode=@($internalLoadBalancingMode);
            dnsSuffix=@($dnsSuffix);
            vnetName=@($vnetName);
            subnetName=@($subnetName);
            appServicePlanName=@($appServicePlanName);
            owner=@($owner);
            workerPool=@($workerPool); 
            numberOfWorkersFromWorkerPool= @($numberOfWorkersFromWorkerPool);
           }
         #$VMSettingsFinalarray+=$VMSettingsJSONHashTable
         $ASESettingsFinalHT+=$ASESettingsJSONHashTable
         
      $AllResourcesFinalJSON.parameters.ASESettings.value=$ASESettingsFinalHT
      
     Return $AllResourcesFinalJSON
      

}
$subscriptionID = Read-Host "Enter the Subscription ID"
$ResourceGroupName = Read-Host "Enter the Resource Group Name"
$VNEName=Read-Host "Enter the VNET Name"

Write-host "Ensure that this keyvault has 3 secrets named SSLwpvtkey, pfxpassword, SSLpublickey"

Switch($choice)
{
"1" 
{
#Parameters Template - based on this a template will be created for deployment dynamically -Parameters4Deployment.json
#Template for the App GW - same for all resources
$TemplateMasterPath = "C:\repos1\AppGW\TemplateMaster.json" 
#Input fields
$parametersCSV = IMport-csv "C:\Repos1\AppGW\InputFiles\Param-AppGW.CSV"

$AppGWJSON = BuildParam4DeployFile_AppGWs  $parametersCSV $serverParam
$AllResourcesFinalJSON=$AppGWJSON

}
"2"
{
#Parameters Template - based on this a template will be created for deployment dynamically -Parameters4Deployment.json
#Template for the VM 

#Input fields
$parametersCSV = IMport-csv "C:\Repos1\AppGW\InputFiles\Param-BuildVMs.CSV"
$VMJSON = VMSettingsJSON  $parametersCSV $AllResourcesFinalJSON
$AllResourcesFinalJSON = $VMJSON
$AllResourcesFinalJSON | ConvertTo-Json -depth 100 | Format-Json | Set-Content $Parameters4DeploymentPath
}
"3"
{
#Input fields
$parametersCSV = IMport-csv "C:\Repos1\AppGW\InputFiles\Param-ASE.CSV"
$paramPath = "C:\Repos1\AppGW\InputFiles\Param-ASE.CSV"

$ASEJSON = ASESettingsJSON  $parametersCSV $AllResourcesFinalJSON
$AllResourcesFinalJSON = $ASEJSON
$AllResourcesFinalJSON | ConvertTo-Json -depth 100 | Format-Json | Set-Content $Parameters4DeploymentPath
#$AllResourcesFinalJSON = $ASEJSON
#$ASEJSON | ConvertTo-Json -depth 100 | Format-Json | Set-Content $Parameters4DeploymentPath
}
"4"
{
#Parameters Template - based on this a template will be created for deployment dynamically -Parameters4Deployment.json
#Template for the VM 

#Input fields
$parametersCSV = IMport-csv "C:\Repos1\AppGW\InputFiles\Param-AppGW.CSV"
$AppGWJSON = BuildParam4DeployFile_AppGWs  $parametersCSV $serverParam
$AppGWJSON| ConvertTo-Json -depth 100 | Format-Json | Set-Content $Parameters4DeploymentPath
#Intermediate step where I load AppGW JSON values and then pass it to VM function to append its values and send it back
$AllResourcesFinalJSON = (Get-Content $Parameters4DeploymentPath) -join "`n" | ConvertFrom-Json
$parametersCSV = IMport-csv "C:\Repos1\AppGW\InputFiles\Param-BuildVMs.CSV"
$AllResourcesFinalJSON = VMSettingsJSON  $parametersCSV $AllResourcesFinalJSON

$AllResourcesFinalJSON | ConvertTo-Json -depth 100 | Format-Json | Set-Content $Parameters4DeploymentPath

}

}

$AllResourcesFinalJSON | ConvertTo-Json -depth 100 | Format-Json | Set-Content $Parameters4DeploymentPath
#$AllResourcesFinalJSON| ConvertTo-Json -depth 100 | Format-Json | Set-Content $Parameters4DeploymentPath





#-TemplateParameterFile "$Parameters4DeploymentPath" -TemplateFile "$TemplateMasterPath"