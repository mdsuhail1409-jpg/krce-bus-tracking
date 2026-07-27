$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'
$urls = @(
    "https://krce-bus-tracking.onrender.com",
    "https://krce-bus.onrender.com",
    "https://krce-bus-production.onrender.com"
)
foreach ($url in $urls) {
    try {
        $req = [System.Net.HttpWebRequest]::Create("$url/healthz")
        $req.Timeout = 15000
        $req.Method = "GET"
        $resp = $req.GetResponse()
        $stream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        Write-Host "ALIVE: $url -> $([int]$resp.StatusCode) | $body"
        $resp.Close()
    } catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
            Write-Host "DEAD: $url -> HTTP $code"
        } else {
            Write-Host "UNREACHABLE: $url -> $($_.Exception.Message)"
        }
    }
}
