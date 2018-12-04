# appGateway
Deploying Multiple Application Gateways hosting multiple apps with a single template

Summary: This scenario is to route traffic to two or more webapps that is behind an application gateway. You can deploy 3 application gateways, one with 3 apps, another with 5 and another with 10. You don't need to edit the parameters file each time, simply input the CSV file and run the script to generate the parameters file.

What is the Challenge?: As far as I have checked there are no templates to do this with a single template, while not having to construct the parameters file manually each time. The actual challenge is that JSON templates cant have a nested for loop. The sub-resources section doesnt exist in Microsoft.Network/applicationGateways unlike Microsoft.Compute/virtualMachines, so there is no way for you to precreate the sub-resources and attach them to the main resource. For instance, you can create FDisk and GDisk independently and attach it to a VM, but app GW needs to have its listners,probes etc fed at the time of creation.

What are the steps?

Creae a folder repos1 in C:\ and pull the below repo.

Input the CSV file with appropriate values and run the createresources.ps1 script that generates the parameters4deployment.json dynamically based on the input CSV file. 

Execute the TemplateMaster.json with parameters4deployment.json

Pre-requisites

A key vault and a certificate.

You need to have a certificate(.cer) with only the public portion of the key pair. A password protected PFX certificate with the private portion of the key pair.

Both of these certs needs to uploaded to a keyvault in binary 64 format, once uploaded, update the parametersmaster.json file.

For example, use the below command to upload the pfx cert to key vault, repeat this for .cer file too.

az keyvault secret set --vault-name <KeyvaultName> --encoding base64 --description text/plain --name SSLwpvtkey --file "C:\Repos1\AppGW\selfsigned.pfx"
Refer https://github.com/Azure/azure-quickstart-templates/tree/master/201-web-app-certificate-from-key-vault
