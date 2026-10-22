$ErrorActionPreference = 'Stop'

$outputPath = Join-Path $PSScriptRoot '..\..\HomeOps360_Business_Model.pptx'
$renderDir = Join-Path $PSScriptRoot 'rendered'
$logoPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')) 'web\icons\Icon-512.png'

function Rgb([string]$hex) {
  $clean = $hex.TrimStart('#')
  $r = [Convert]::ToInt32($clean.Substring(0, 2), 16)
  $g = [Convert]::ToInt32($clean.Substring(2, 2), 16)
  $b = [Convert]::ToInt32($clean.Substring(4, 2), 16)
  return $r + ($g * 256) + ($b * 65536)
}

function Add-TextBox {
  param(
    $Slide,
    [string]$Text,
    [double]$Left,
    [double]$Top,
    [double]$Width,
    [double]$Height,
    [double]$FontSize,
    [string]$Color = '#0E1B33',
    [bool]$Bold = $false,
    [string]$Font = 'Aptos',
    [int]$Align = 1,
    [double]$Margin = 0,
    [string]$Name = ''
  )
  $shape = $Slide.Shapes.AddTextbox(1, $Left, $Top, $Width, $Height)
  if ($Name) { $shape.Name = $Name }
  $shape.Line.Visible = 0
  $shape.Fill.Visible = 0
  $shape.TextFrame.MarginLeft = $Margin
  $shape.TextFrame.MarginRight = $Margin
  $shape.TextFrame.MarginTop = $Margin
  $shape.TextFrame.MarginBottom = $Margin
  $shape.TextFrame.WordWrap = -1
  $shape.TextFrame.AutoSize = 0
  $shape.TextFrame.TextRange.Text = $Text
  $shape.TextFrame.TextRange.Font.Name = $Font
  $shape.TextFrame.TextRange.Font.Size = $FontSize
  $shape.TextFrame.TextRange.Font.Bold = $(if ($Bold) { -1 } else { 0 })
  $shape.TextFrame.TextRange.Font.Color.RGB = Rgb $Color
  $shape.TextFrame.TextRange.ParagraphFormat.Alignment = $Align
  return $shape
}

function Add-Rect {
  param($Slide, [double]$Left, [double]$Top, [double]$Width, [double]$Height, [string]$Fill, [string]$Name = '')
  $shape = $Slide.Shapes.AddShape(1, $Left, $Top, $Width, $Height)
  if ($Name) { $shape.Name = $Name }
  $shape.Line.Visible = 0
  $shape.Fill.Solid()
  $shape.Fill.ForeColor.RGB = Rgb $Fill
  return $shape
}

function Add-Line {
  param($Slide, [double]$X1, [double]$Y1, [double]$X2, [double]$Y2, [string]$Color, [double]$Weight = 1)
  $line = $Slide.Shapes.AddLine($X1, $Y1, $X2, $Y2)
  $line.Line.ForeColor.RGB = Rgb $Color
  $line.Line.Weight = $Weight
  return $line
}

$ppt = $null
$pres = $null
try {
  $ppt = New-Object -ComObject PowerPoint.Application
  $ppt.Visible = -1
  $pres = $ppt.Presentations.Add()
  $pres.PageSetup.SlideWidth = 960
  $pres.PageSetup.SlideHeight = 540
  $slide = $pres.Slides.Add(1, 12)
  $slide.FollowMasterBackground = 0
  $slide.Background.Fill.Solid()
  $slide.Background.Fill.ForeColor.RGB = Rgb '#F7FAFC'

  # Brand lockup
  $slide.Shapes.AddPicture($logoPath, 0, -1, 42, 24, 28, 28) | Out-Null
  Add-TextBox $slide 'HomeOps' 76 24 88 26 16 '#0E1B33' $true 'Aptos Display' 1 0 'brand-homeops' | Out-Null
  Add-TextBox $slide '360' 151 24 38 26 16 '#2E6BFF' $true 'Aptos Display' 1 0 'brand-360' | Out-Null
  Add-TextBox $slide 'BUSINESS MODEL' 746 28 172 18 10 '#54617A' $true 'Aptos' 3 0 'eyebrow' | Out-Null

  # Takeaway title
  Add-TextBox $slide 'HomeOps360 turns rental workflows into recurring revenue' 42 74 876 46 35 '#0E1B33' $true 'Aptos Display' 1 0 'title' | Out-Null
  Add-TextBox $slide 'Owners pay to run the portfolio; every monthly workflow deepens retention and opens expansion revenue.' 42 127 876 24 16 '#54617A' $false 'Aptos' 1 0 'subtitle' | Out-Null
  Add-Line $slide 42 170 918 170 '#D9E1EA' 1 | Out-Null

  # Three-part operating model; the dark center is the product engine.
  Add-Rect $slide 42 196 248 266 '#FFFFFF' 'customer-region' | Out-Null
  Add-Rect $slide 342 196 276 266 '#0E1B33' 'platform-region' | Out-Null
  Add-Rect $slide 670 196 248 266 '#FFFFFF' 'revenue-region' | Out-Null
  Add-Rect $slide 42 196 248 5 '#10C8B0' | Out-Null
  Add-Rect $slide 342 196 276 5 '#2E6BFF' | Out-Null
  Add-Rect $slide 670 196 248 5 '#2E6BFF' | Out-Null

  Add-TextBox $slide '01' 60 220 42 24 12 '#10C8B0' $true 'Aptos' 1 0 | Out-Null
  Add-TextBox $slide 'WHO PAYS' 60 246 190 24 12 '#54617A' $true 'Aptos' 1 0 | Out-Null
  Add-TextBox $slide 'Owners & property agents' 60 277 200 58 24 '#0E1B33' $true 'Aptos Display' 1 0 | Out-Null
  Add-TextBox $slide "Manage more units with less admin:`r`n`r`n• Properties & tenancies`r`n• Rent, utilities & expenses`r`n• Payment proof & reporting" 60 342 202 102 16 '#54617A' $false 'Aptos' 1 0 | Out-Null

  Add-TextBox $slide '02' 362 220 42 24 12 '#10C8B0' $true 'Aptos' 1 0 | Out-Null
  Add-TextBox $slide 'THE OPERATING LAYER' 362 246 220 24 12 '#B8C7DD' $true 'Aptos' 1 0 | Out-Null
  Add-TextBox $slide 'One workspace for the full rental cycle' 362 277 226 59 24 '#FFFFFF' $true 'Aptos Display' 1 0 | Out-Null
  Add-TextBox $slide "OWNER APP`r`nPortfolio • billing • approvals`r`nTENANT PORTAL`r`nBills • proof • requests`r`nEXPLORE`r`nVerified room discovery" 362 340 226 116 16 '#DDE7F5' $false 'Aptos' 1 0 | Out-Null

  Add-TextBox $slide '03' 690 220 42 24 12 '#2E6BFF' $true 'Aptos' 1 0 | Out-Null
  Add-TextBox $slide 'HOW IT MONETIZES' 690 246 190 24 12 '#54617A' $true 'Aptos' 1 0 | Out-Null
  Add-TextBox $slide 'Land with SaaS. Expand with usage.' 690 277 202 58 24 '#0E1B33' $true 'Aptos Display' 1 0 | Out-Null
  Add-TextBox $slide "1  Tiered subscription`r`n    Units • tenants • features`r`n2  Promoted listings`r`n    Paid Explore visibility`r`n3  Future service fees`r`n    Payments • partners" 690 340 202 116 16 '#54617A' $false 'Aptos' 1 0 | Out-Null

  # Directional arrows sit in the gutters and remain behind no labels.
  Add-TextBox $slide '→' 294 304 44 40 28 '#A8B5C5' $false 'Aptos Display' 2 0 'arrow-one' | Out-Null
  Add-TextBox $slide '→' 622 304 44 40 28 '#A8B5C5' $false 'Aptos Display' 2 0 'arrow-two' | Out-Null

  # Flywheel band
  Add-Rect $slide 42 482 876 32 '#DDF8F4' 'flywheel-band' | Out-Null
  Add-TextBox $slide 'LAND-AND-EXPAND ENGINE' 56 490 166 14 10 '#067F72' $true 'Aptos' 1 0 | Out-Null
  Add-TextBox $slide 'More managed units  →  more recurring workflows  →  higher retention  →  subscription expansion' 228 488 668 18 13 '#0E1B33' $true 'Aptos' 1 0 | Out-Null
  Add-TextBox $slide 'Proposed monetization model; final packaging and pricing to be validated with pilot customers.' 42 516 876 10 9 '#748197' $false 'Aptos' 1 0 'assumption-note' | Out-Null

  # Speaker notes with repository provenance.
  $notesText = "[Sources]`r`n- README.md (product roles and workflows)`r`n- lib/branding/homeops_brand.dart (brand colors and naming)`r`n- lib/explore/room_explore.dart (Explore marketplace and promotion capability)`r`n- docs/admin-portal-deployment.md (owner limits and feature access)`r`n[/Sources]`r`n`r`nPricing and transaction-fee streams are proposed; the repository does not define commercial rates."
  foreach ($shape in $slide.NotesPage.Shapes) {
    if ($shape.PlaceholderFormat.Type -eq 2) {
      $shape.TextFrame.TextRange.Text = $notesText
      break
    }
  }

  # Boundary QA before save.
  $issues = @()
  foreach ($shape in $slide.Shapes) {
    if ($shape.Left -lt -0.5 -or $shape.Top -lt -0.5 -or ($shape.Left + $shape.Width) -gt 960.5 -or ($shape.Top + $shape.Height) -gt 540.5) {
      $issues += "Out of bounds: $($shape.Name)"
    }
  }
  if ($issues.Count -gt 0) { throw ($issues -join "`n") }

  $pres.SaveAs($outputPath, 24)
  New-Item -ItemType Directory -Path $renderDir -Force | Out-Null
  $pres.Export($renderDir, 'PNG', 1920, 1080)
  Write-Output "PPTX=$outputPath"
  Write-Output "RENDER=$renderDir\Slide1.PNG"
  Write-Output "SHAPES=$($slide.Shapes.Count)"
}
finally {
  if ($pres) { $pres.Close() }
  if ($ppt) { $ppt.Quit() }
  if ($slide) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($slide) }
  if ($pres) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($pres) }
  if ($ppt) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($ppt) }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}



