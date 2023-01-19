# CKO Payment Channel API commands

using module "./CkoClient.psm1" # required for classes
# Import-Module "./CkoClient.psm1"

function New-CkoChannel() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] 
        [string]
        $PublicKey, 
        [Parameter(Mandatory=$true)] 
        [string]
        $PrivateKey, 
        [Parameter(Mandatory=$true)] 
        [string]
        $ChannelId
    )
    $env:CKO_PUBLIC_KEY =  $PublicKey
    $env:CKO_PRIVATE_KEY = $PrivateKey
    $env:CKO_CHANNEL_ID = $ChannelId
    return $ChannelId
}

<# *** -ALL- PaymentChannel methods depend on CkoClient::MakeRequest ***

CkoClient::MakeRequest 
    !!! Depends on  $env:CKO_PUBLIC_KEY, $env:CKO_PRIVATE_KEY

New-CardToken - default params provided for test CC
    writes response to  $env:CKO_CARD_TOKEN 

Request-PaymentAuthorization
    accepts optional ChannelId, CardToken params
    validates null params, uses $env:CKO_CHANNEL_ID, $env:CKO_CARD_TOKEN as defaults 
    writes response to  $env:CKO_PAYMENT_TOKEN
#>

<# https://www.checkout.com/docs/testing/test-cards #>
function New-CardToken() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $CardNumber,
        [Parameter(Mandatory=$true)]
        [int]
        $ExpiryMonth,
        [Parameter(Mandatory=$true)]
        [int]
        $ExpiryYear,
        [Parameter(Mandatory=$true)]
        [string]
        $CVV,
        [Parameter(Mandatory=$true)]
        [string]
        $CardHolderName
    )
    $env:CKO_CARD_TOKEN = [CkoClient]::new().AcquireCardToken($CardNumber, $ExpiryMonth, $ExpiryYear, $CVV, $CardHolderName)    
}

function Request-PaymentAuthorization() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [decimal]
        $Amount,
        [Parameter(Mandatory=$true)]
        [string]
        $CurrencyCode,
        [Parameter(Mandatory=$false)]
        [string]
        $ChannelId = $null,
        [Parameter(Mandatory=$false)]
        [string]
        $CardToken = $null,
        [Parameter(Mandatory=$false)]
        [bool]
        $Enable3DS = $false,
        [Parameter(Mandatory=$false)]
        [bool]
        $EnableCapture = $false,
        [Parameter(Mandatory=$false)]
        [string]
        $SuccessUrl,
        [Parameter(Mandatory=$false)]
        [string]
        $FailureUrl
    )

    if (-not $ChannelId ) {
        $ChannelId = $env:CKO_CHANNEL_ID
    }
    if (-not $CardToken) {
        $CardToken = $env:CKO_CARD_TOKEN
    }
    if (-not $ChannelId) {
        Write-Error "`$ChannelId` has not been properly configured - Try calling New-CkoChannel"
        return
    }
    if (-not $CardToken) {
        Write-Error "`$CardToken` has not been properly configured"
        return
    }

    $cko = [CkoClient]::new()
    # helper method or overloaded constructor to tidy this up a bit ?
    $cko.Enable3DS = $Enable3DS
    $cko.EnableCapture = $EnableCapture
    $cko.SuccessUrl = $SuccessUrl
    $cko.FailureUrl = $FailureUrl
    $env:CKO_PAYMENT_TOKEN = $cko.AuthorizePayment($Amount, $CurrencyCode, $ChannelId, $CardToken)
}

function Get-PaymentDetails() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $PaymentToken = $null
    )
    $Payment = [CkoClient]::new().GetPayment($PaymentToken)
    return (WrapResult $Payment) | Select-Object -Property * -ExcludeProperty _links
}

function Get-PaymentActions() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]
        $PaymentToken = $null
    )
    $Result = @()
    $Actions = [CkoClient]::new().GetPaymentActions($PaymentToken)
    if ($Actions.Length -eq 0) { throw "Unable to load actions for $PaymentToken" }
    $Actions | ForEach-Object { 
        $Result += (WrapResult $_)
    }
    return $Result
}

function Get-Payments() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Reference,
        [Parameter(Mandatory=$false)]
        [int]
        $Limit = 10,
        [Parameter(Mandatory=$false)]
        [int]
        $Skip = 0
    )
    $Result = @()
    $Payments = [CkoClient]::new().GetPayments($Reference, $Limit, $Skip)
    if ($Payments.Length -eq 0) { throw "Unable to load payments for $Reference" }
    $Payments | ForEach-Object { 
        $Result += (WrapResult $_)
    }
    return $Result
}

function Request-PaymentCapture() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [decimal]
        $Amount,
        [Parameter(Mandatory=$true)]
        [string]
        $Reference,
        [Parameter(Mandatory=$false)]
        [string]
        $PaymentToken = $null
    )
    return [CkoClient]::new().CapturePayment($Amount, $PaymentToken, $Reference)
}

function Request-PaymentVoid() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [decimal]
        $Amount,
        [Parameter(Mandatory=$true)]
        [string]
        $Reference,
        [Parameter(Mandatory=$false)]
        [string]
        $PaymentToken = $null
    )
    return [CkoClient]::new().VoidPayment($Amount, $PaymentToken, $Reference)
}

function Request-PaymentRefund() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [decimal]
        $Amount,
        [Parameter(Mandatory=$true)]
        [string]
        $Reference,
        [Parameter(Mandatory=$false)]
        [psobject]
        $Metadata = $null,
        [Parameter(Mandatory=$false)]
        [string]
        $PaymentToken = $null
    )
    return [CkoClient]::new().RefundPayment($Amount, $PaymentToken, $Reference, $Metadata)
}

# Inspired by https://gist.github.com/awakecoding/acc626741704e8885da8892b0ac6ce64
function ConvertTo-PascalCase
{
    param(
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [string] $Value
    )

    # https://devblogs.microsoft.com/oldnewthing/20190909-00/?p=102844
    return [regex]::replace($Value.ToLower(), '(^|_)(.)', { $args[0].Groups[2].Value.ToUpper()})
}

function WrapResult() {
    param([psobject] $item)
    $Wrapper = New-Object PSObject
    $item.PSObject.Properties |
        Sort-Object Name |
        ForEach-Object {
            $Wrapper | Add-Member -MemberType NoteProperty -Name $($_.Name | ConvertTo-PascalCase) `
                -Value ($_.TypeNameOfValue.Contains('PSCustomObject') ? (WrapResult $_.Value) :  $_.Value)
        }
    return $Wrapper
}

Export-ModuleMember -Function New-CkoChannel, New-CardToken, Request-PaymentAuthorization, Request-PaymentCapture, Request-PaymentVoid, Request-PaymentRefund, Get-PaymentDetails, Get-PaymentActions, Get-Payments 