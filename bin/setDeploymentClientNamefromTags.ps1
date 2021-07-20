$headers = @{}
$headers.Authorization = "Splunk ${SplunkSessionKey}"

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$deploymentInfo = Invoke-RestMethod -Uri https://localhost:8089/servicesNS/-/-/deployment/client/config?output_mode=json -Headers $headers
$clientName = $deploymentInfo.entry[0].content.clientName

$meta = Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01"
$subscriptionId = $meta.subscriptionId
$resourceGroupName = $meta.resourceGroupName
$name = $meta.name

$tags = @{}
foreach($tag in $meta.tagsList) {
  $tags[$tag.name] = $tag.value
}
$project = if ($tags.ContainsKey('project')) { $tags.project } else { 'unknown' }
$family = if ($tags.ContainsKey('family')) { $tags.family } else { 'unknown' }
$app = if ($tags.ContainsKey('app')) { $tags.app } else { 'unknown' }
$service = if ($tags.ContainsKey('service')) { $tags.service } else { 'unknown' }

$desiredClientName = "cloud.azure.$project.$family.$app.$service.$name"

if ($clientName -ne $desiredClientName) {
  $deploymentInfo = Invoke-RestMethod -Method Post -Uri https://localhost:8089/servicesNS/-/-/deployment/client/config?output_mode=json -Headers $headers -Body @{clientName=$desiredClientName}
  $clientName = $deploymentInfo.entry[0].content.clientName
  Write-Host "$clientName"
}
