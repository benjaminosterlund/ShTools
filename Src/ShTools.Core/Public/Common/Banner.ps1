
function Show-ShToolsBanner {
    [CmdletBinding()]
    param(
        [string]$Version = "1.0.0",
        [string]$ToolName = "ShTools",
        [string]$Subtitle = "Project Architecture Tooling",
        [string]$Author = "Benjamin Österlund",
        [string]$Repo = "github.com/benjaminosterlund/ShTools",
        [switch]$NoColor
    )

    $width = 54

    function Format-Line {
        param([string]$Text)
        $contentWidth = $width - 4
        $padded = $Text.PadRight($contentWidth)
        return "│  $padded  │"
    }

    $top    = "┌" + ("─" * ($width - 2)) + "┐"
    $bottom = "└" + ("─" * ($width - 2)) + "┘"

    $lines = @(
        $top
        (Format-Line $ToolName)
        (Format-Line $Subtitle)
        (Format-Line "")
        (Format-Line "Version : $Version")
        (Format-Line "Author  : $Author")
        (Format-Line "Repo    : $Repo")
        $bottom
    )

    if (-not $NoColor -and $PSStyle) {
        $accent = $PSStyle.Foreground.BrightCyan
        $reset  = $PSStyle.Reset
        $lines = $lines | ForEach-Object {
            if ($_ -match "ShTools") {
                $_ -replace $ToolName, "$accent$ToolName$reset"
            }
            else { $_ }
        }
    }

    $lines -join "`n"
}