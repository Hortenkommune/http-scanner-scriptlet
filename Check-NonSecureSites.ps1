## TODO: Checks for redirection to https, does NOT check if final destination actually _requires_ https...! Also, javascript or multi-redirect is not supported by this scriptlet.
# Scriptlet to test http(non-s) call for an IP-subnet or any of the domains registered to an organization, through domeneshop API.
# Creator: Alexander Hatlen for Horten Kommune.
# Copyright: none!

# USAGE:
# Set config params
# Run scriptfile as a whole. Notice variables in bottom, they'll hold the results if you need to re-access them. Results will also be printed directly when completed.

## CONFIG PARAMS START

# DNS Scan settings, only Domeneshop API supported. Point to file that holds Domeneshop API key.
# https://api.domeneshop.no/docs/
$domeneshopAPIkey = Get-Content .\.domeneshop-api

# IP Scan settings. Cannot be larger than /24 as we're doing this as string...
$subnet = "91.90.66." #/24
$hostStart = 64 # 91.90.66.64/26
$hostEnd = 127 # 91.90.66.64/26 (=64-127)

## CONFIG PARAMS END


# Helper function for Get-BadHTTPStatus
function Get-WebStatus {
    param($domain)
    try {
        $webStatus = Invoke-WebRequest http://$domain -DisableKeepAlive -TimeoutSec 1 -ErrorAction SilentlyContinue -MaximumRedirection 0
    }
    catch {
        return $false
    }
    return $webStatus
}

# Main function that return null ("nothing to add") if URL gets redirection, else return domain+status. Also verified that redir-url startsWith https://.
function Get-BadHTTPStatus {
    param($domain)
    $webStatus = Get-WebStatus -domain $domain
    # Quickly exit if WebStatus return false instead of object
    if ($webStatus -eq $false) {
        return $null
    }
    $statusCode = $webStatus.StatusCode

    # Check that url was actually reachable, else return null implicit in bottom
    if ($statusCode -ne $false) {
        # Check for redirection, if not redir then return domain+statuscode
        if ( $statusCode -le 399 -and $statusCode -ge 300 ) {
            if ($webStatus.Headers.Location.ToLower().StartsWith("https://") -eq $true) { # This may throw an error if webStatus exists but redirection header is not sent.
                return $null;
            } else {
            return "$($domain)=REDIRECTS-TO-NON-HTTPS"
            }
        } else {
            return "$($domain)=$($statusCode)"
        }
    }
    return $null
}

# Loop through Hortens external IPs and do a check
function Get-HTTPSitesByIP {
# Moved this section to global for easier config when sharing scriptlet
#    $subnet = "91.90.66." #/24
#    $hostStart = 64 # 91.90.66.64/26
#    $hostEnd = 127 # 91.90.66.64/26 (=64-127)
    $failed = @()

    $doingIPs = $true
    $curIP = $hostStart
    while($doingIPs -eq $true) {
        if ($curIP -le $hostEnd) {
            Write-Progress -Id 1 -Activity "Checking sites by IP" -CurrentOperation "Testing $subnet$curIP" -PercentComplete (($curIP - $hostStart) / ($hostEnd - $hostStart) * 100)
            $domain = $subnet + $curIP
            $failed += Get-BadHTTPStatus $domain

            # Increment current IP
            $curIP++
        }
        else {
            $doingIPs = $false
        }
    }

    return $failed
}

# Grab DNS from Domeneshop and loop through each domain and then again each record. Tests each record.
function Get-HTTPSitesByDNS {
    $failed = @()
    # Prepare authorization header for Domeneshop DNS scraping API
    $domeneshopHeaders = @{Authorization="Basic ${domeneshopAPIkey}"}
    # Domeneshop will throw error 400 and script will return that error if auth fails. Should be looked for!

    # Get all domains we're scraping records for
    $domains = Invoke-RestMethod https://api.domeneshop.no/v0/domains/ -Headers $domeneshopHeaders

    # Loop through each domain
    foreach ($domain in $domains) {
        # Add progress bar
        Write-Progress -Id 1 -Activity "Checking sites by DNS" -CurrentOperation "Checking $($domain.domain)" -PercentComplete ($domains.IndexOf($domain) / $domains.Count * 100)
        # Continue loop only if domain has DNS
        if ($domain.services.dns -eq "True") { # -and $domain.id -eq 1348024
            # Grab domain's records
            $records = Invoke-RestMethod https://api.domeneshop.no/v0/domains/$($domain.id)/dns -Headers $domeneshopHeaders
            # ... and loop through them if type is A, AAAA or CNAME
            foreach ($record in ($records | Where-Object type -CIn "A","AAAA","CNAME")) {
                # Add a new progress bar for the domain-record fetch status
                Write-Progress -Id 2 -Activity "Checking DNS records on site..." -CurrentOperation "Testing sub-domain: $($record.host)" -PercentComplete (($records.IndexOf($record) / $records.Count) * 100)
                # Test each record on the domain
                $failed += Get-BadHTTPStatus "$($record.host).$($domain.domain)"
            }
        }
    }

    return $failed
}


$failed_IP = Get-HTTPSitesByIP
$failed_DNS = Get-HTTPSitesByDNS
$failed = $failed_IP + $failed_DNS
$failed