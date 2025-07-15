<#
.SYNOPSIS
    Gets standings and recent fixtures from an API and prints them to the console
.DESCRIPTION
    Gets standings and recent fixtures from an API and prints them to the console. API used is https://dashboard.api-football.com, free tier includes 100 api calls a day. API is queried every 24 hours to save on api calls.
.PARAMETER api_key
    API key for the API. Can be set as an environment variable "FootballAPIKey"
.PARAMETER league_id
    ID of the league to get standings for. Default is 218 for Austrian Bundesliga. List of all available IDs: https://dashboard.api-football.com/soccer/ids
.PARAMETER force_api_sync
    Force a sync with the API to circumvent the cache
.EXAMPLE
    C:\PS> Show-FootballStandings
.EXAMPLE
    C:\PS> Show-FootballStandings -league_id 218
.EXAMPLE
    C:\PS> Show-FootballStandings -api_key "my_api_key" -force_api_sync
.NOTES
    Author: Andreas P.
    Date: July 15, 2025
#>

[CmdletBinding()]
param (
    [Parameter(Position = 1, Mandatory = $false)]
    [string]
    $api_key = [Environment]::GetEnvironmentVariable("FootballAPIKey", "User"),
    [Parameter(Position = 0, Mandatory = $false)]
    [string]
    $league_id = 218, # List of all available IDs: https://dashboard.api-football.com/soccer/ids
    [Parameter(Mandatory = $false)]
    [switch]
    $force_api_sync = $false
)

if (-not $api_key) {
    $api_key = Read-Host -Prompt "Enter API Key"
    [Environment]::SetEnvironmentVariable("FootballAPIKey", $api_key, "User")
}
$path_to_local_cache = "$env:APPDATA\football_standings_ps\"
$last_request = Get-Date $([Environment]::GetEnvironmentVariable("FootballAPILastRequest", "User"))

if (! $(Test-Path $path_to_local_cache)) {
    New-Item -Path $path_to_local_cache -ItemType Directory | Out-Null
}
$current_year = Get-Date -Format "yyyy"

if ($force_api_sync -or $last_request -lt $(Get-Date).AddDays(-1) -or ! $(Test-Path "$path_to_local_cache\fixtures_last_round.json") -or ! $(Test-Path "$path_to_local_cache\fixtures_next_round.json") -or ! $(Test-Path "$path_to_local_cache\standings.json")) {
    $Uri = 'https://v3.football.api-sports.io'
    $headers = @{
        'x-rapidapi-host' = 'v3.football.api-sports.io'
        'x-rapidapi-key'  = $api_key
    }

    $endpoint_fixtures = "$Uri/fixtures"
    $body = @{
        league = $league_id
        season = $current_year
        last   = 6
    }
    $result = Invoke-RestMethod -Uri $endpoint_fixtures -Method Get -Headers $headers -Body $body

    $result | ConvertTo-Json -Depth 100 | Out-File "$path_to_local_cache\fixtures_last_round.json"

    $endpoint_fixtures = "$Uri/fixtures"
    $body = @{
        league = $league_id
        season = $current_year
        next   = 6
    }
    $result = Invoke-RestMethod -Uri $endpoint_fixtures -Method Get -Headers $headers -Body $body

    $result | ConvertTo-Json -Depth 100 | Out-File "$path_to_local_cache\fixtures_next_round.json"


    $endpoint_standings = "$Uri/standings"
    $body = @{
        league = $league_id
        season = $current_year
    }
    $result = Invoke-RestMethod -Uri $endpoint_standings -Method Get -Headers $headers -Body $body

    $result | ConvertTo-Json -Depth 100 | Out-File "$path_to_local_cache\standings.json"


    [Environment]::SetEnvironmentVariable("FootballAPILastRequest", $(Get-Date -Format "yyyy-MM-ddTHH:mm:ss"), "User")
}

$fixtures_last_round = Get-Content "$path_to_local_cache\fixtures_last_round.json" | ConvertFrom-Json
$fixtures_next_round = Get-Content "$path_to_local_cache\fixtures_next_round.json" | ConvertFrom-Json
$standings = Get-Content "$path_to_local_cache\standings.json" | ConvertFrom-Json

$teamWidth = 18
$scoreFormat = "{0,$teamWidth}  {1}  {2,-$teamWidth}"
$fixtureLineFormat = "{0}    ||    {1}"

$pastFixtures = $fixtures_last_round.response
$nextFixtures = $fixtures_next_round.response

$fixtureWidth = $teamWidth * 2 + 7

$leftHeader = "Last Round"
$rightHeader = "Next Round"
$leftPadding = [Math]::Floor(($fixtureWidth - $leftHeader.Length) / 2)
$rightPadding = [Math]::Floor(($fixtureWidth - $rightHeader.Length) / 2)
$headerLine = (" " * $leftPadding) + $leftHeader + (" " * ($fixtureWidth - $leftPadding - $leftHeader.Length)) +
"    ||    " +
(" " * $rightPadding) + $rightHeader + (" " * ($fixtureWidth - $rightPadding - $rightHeader.Length))

Write-Host $headerLine

$maxCount = [Math]::Max($pastFixtures.Count, $nextFixtures.Count)

for ($i = 0; $i -lt $maxCount; $i++) {
    if ($i -lt $pastFixtures.Count) {
        $p = $pastFixtures[$i]
        $ph = $p.teams.home.name
        $pa = $p.teams.away.name
        $phg = if ($null -eq $p.goals.home) { "-" } else { $p.goals.home }
        $pag = if ($null -eq $p.goals.away) { "-" } else { $p.goals.away }
        $pScore = "$phg`:$pag"
        $pastText = $scoreFormat -f $ph, $pScore, $pa
    }
    else {
        $pastText = " " * $fixtureWidth
    }

    if ($i -lt $nextFixtures.Count) {
        $n = $nextFixtures[$i]
        $nh = $n.teams.home.name
        $na = $n.teams.away.name
        $nhg = if ($null -eq $n.goals.home) { "-" } else { $n.goals.home }
        $nag = if ($null -eq $n.goals.away) { "-" } else { $n.goals.away }
        $nScore = "$nhg`:$nag"
        $nextText = $scoreFormat -f $nh, $nScore, $na
    }
    else {
        $nextText = " " * $fixtureWidth
    }

    Write-Host ($fixtureLineFormat -f $pastText, $nextText)
}


$headerFormat = "| {0,-4} | {1,-20} | {2,4} | {3,4} | {4,4} | {5,4} | {6,4} | {7,4} | {8,4} |"
$rowFormat = $headerFormat
$border = "+------+----------------------+------+------+------+------+------+------+------+"

for ($i = 0; $i -lt $standings.response.league.standings.Count; $i++) {
    Write-Host $standings.response.league.standings[$i].group[0]
    Write-Host $border
    Write-Host ($headerFormat -f "Pos", "Team", "W", "D", "L", "GF", "GA", "GD", "Pts")
    Write-Host $border

    foreach ($standing in $standings.response.league.standings[$i]) {
        $rank = $standing.rank
        $team = $standing.team.name
        $points = $standing.points
        $wins = $standing.all.win
        $losses = $standing.all.lose
        $draws = $standing.all.draw
        $goaldiff = $standing.goalsDiff
        $goals_for = $standing.all.goals.for
        $goals_against = $standing.all.goals.against

        Write-Host ($rowFormat -f $rank, $team, $wins, $draws, $losses, $goals_for, $goals_against, $goaldiff, $points)
    }

    Write-Host $border
    Write-Host ""
}