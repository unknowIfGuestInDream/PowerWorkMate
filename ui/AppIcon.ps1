<#
.SYNOPSIS
    AppIcon - builds the shared PowerWorkMate application icon.

.DESCRIPTION
    Renders a small "P" monogram on a blue rounded-square background with GDI+
    and returns it as a System.Drawing.Icon. The same icon is used for the main
    window title bar and for the system-tray (NotifyIcon) logo, so the program
    has a single, consistent visual identity without shipping a binary asset.

    Requires System.Drawing and therefore only runs on Windows with a desktop
    session; callers in the UI layer already depend on Windows Forms / Drawing.
#>

Set-StrictMode -Version Latest

function New-PwmAppIcon {
    <#
    .SYNOPSIS
        Creates and returns the PowerWorkMate application icon.

    .OUTPUTS
        System.Drawing.Icon
    #>
    [CmdletBinding()]
    [OutputType([System.Drawing.Icon])]
    param(
        [ValidateRange(16, 256)]
        [int]$Size = 32
    )

    Add-Type -AssemblyName System.Drawing

    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $graphics.Clear([System.Drawing.Color]::Transparent)

        $rect = New-Object System.Drawing.Rectangle(0, 0, ($Size - 1), ($Size - 1))
        $radius = [Math]::Max(2, [int]($Size / 5))
        $diameter = $radius * 2

        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        try {
            $path.AddArc($rect.X, $rect.Y, $diameter, $diameter, 180, 90)
            $path.AddArc(($rect.Right - $diameter), $rect.Y, $diameter, $diameter, 270, 90)
            $path.AddArc(($rect.Right - $diameter), ($rect.Bottom - $diameter), $diameter, $diameter, 0, 90)
            $path.AddArc($rect.X, ($rect.Bottom - $diameter), $diameter, $diameter, 90, 90)
            $path.CloseFigure()

            $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
                $rect,
                [System.Drawing.Color]::FromArgb(0, 120, 215),
                [System.Drawing.Color]::FromArgb(0, 78, 152),
                [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)
            try {
                $graphics.FillPath($brush, $path)
            }
            finally {
                $brush.Dispose()
            }
        }
        finally {
            $path.Dispose()
        }

        $font = New-Object System.Drawing.Font(
            'Segoe UI', ($Size * 0.58), [System.Drawing.FontStyle]::Bold,
            [System.Drawing.GraphicsUnit]::Pixel)
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        try {
            $layout = New-Object System.Drawing.RectangleF(0, 0, $Size, $Size)
            $graphics.DrawString('P', $font, [System.Drawing.Brushes]::White, $layout, $format)
        }
        finally {
            $font.Dispose()
            $format.Dispose()
        }

        $handle = $bitmap.GetHicon()
        return [System.Drawing.Icon]::FromHandle($handle)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}
