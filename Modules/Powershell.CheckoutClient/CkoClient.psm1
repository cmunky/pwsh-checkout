# CKO REST Client 

class CkoClient {
    [string] hidden $BaseUri ="https://api.sandbox.checkout.com"
    [string] hidden $RequestMethod = "POST"

    [bool] $Enable3DS = $false
    [bool] $EnableCapture = $false
    [string] $SuccessUrl = "https://example.com/3ds/auth?result=pass" 
    [string] $FailureUrl = "https://example.com/3ds/auth?result=fail"

    CkoClient() {}
    [string] hidden EnsurePaymentToken([string] $PaymentToken) {
        if (-not $PaymentToken) {
            $PaymentToken = $env:CKO_PAYMENT_TOKEN
        }
        if (-not $PaymentToken) {
            throw "`$env:CKO_PAYMENT_TOKEN` has not been properly configured"

        }
        return $PaymentToken
    }

    [psobject] hidden MakeRequest([string] $Uri, [string] $Body, [bool] $Authenticated) {
        $Headers = @{
            'Accept' = '*/*'
            'Authorization' = $Authenticated ? "Bearer $env:CKO_PRIVATE_KEY" : "$env:CKO_PUBLIC_KEY"
        }
        if (-not $env:CKO_PUBLIC_KEY) {
            throw "`$env:CKO_PUBLIC_KEY` has not been configured - Try calling New-CkoChannel"
        }
        if (-not $env:CKO_PRIVATE_KEY) {
            throw "`$env:CKO_PRIVATE_KEY` has not been configured - Try calling New-CkoChannel"
        }        
        return Invoke-RestMethod -Method $this.RequestMethod -ContentType "application/json" -Uri $Uri -Header $Headers -Body $Body    
    }

    [psobject[]] GetPayments([string] $Reference, [int] $Limit, [int] $Skip ) { 
        throw "GetPayments has not been implemented - API call continues to fail :-("
        $this.RequestMethod = "GET"
        $Reference = [System.Net.WebUtility]::UrlEncode($Reference)
        $queryString = "limit=$($Limit)&skip=$($Skip)&reference=$Reference"
        $Response = $this.MakeRequest("$($this.BaseUri)/payments?$queryString", $null, $true)
        # TODO This does NOT work - keeps returning 404, could be the data or formatting, more testing needed
        return $Response
     }

    [psobject] GetPayment([string] $PaymentToken) { 
        $this.RequestMethod = "GET"
        $PaymentToken = $this.EnsurePaymentToken($PaymentToken)
        return $this.MakeRequest("$($this.BaseUri)/payments/$PaymentToken", $null, $true)
    }

    [psobject[]] GetPaymentActions([string] $PaymentToken) { 
        $this.RequestMethod = "GET"
        $PaymentToken = $this.EnsurePaymentToken($PaymentToken)
        return $this.MakeRequest("$($this.BaseUri)/payments/$PaymentToken/actions", $null, $true)
     }

    [string] AcquireCardToken([string] $CardNumber, [int] $ExpiryMonth, [int]$ExpiryYear, [string] $CVV,[string] $CardHolderName) { 
        $Body = @{
            type = "card"
            number = $CardNumber
            expiry_month = $ExpiryMonth
            expiry_year = $ExpiryYear
            name = $CardHolderName
            cvv = $CVV
        } | ConvertTo-Json

        $Response = $this.MakeRequest("$($this.BaseUri)/tokens", $Body, $false)        
        return $Response.Token
    }

    [string] AuthorizePayment([decimal] $Amount, [string] $CurrencyCode, [string] $ChannelId, [string] $CardToken) {
        $Body = @{
            amount = $Amount
            currency = $CurrencyCode
            '3ds' = @{
                enabled = $this.Enable3DS
            }
            capture = $this.EnableCapture
            processing_channel_id = $ChannelId
            source = @{
                type = "token"
                token = $CardToken
            }
        } | ConvertTo-Json

        $Response = $this.MakeRequest("$($this.BaseUri)/payments", $Body, $true)        
        return $Response.Id
    }

    [string] CapturePayment([decimal]$Amount, [string]$PaymentToken, [string]$Reference) {
        $Body = @{
            amount = $Amount
            reference = $Reference
        } | ConvertTo-Json
        $PaymentToken = $this.EnsurePaymentToken($PaymentToken)
        $Response = $this.MakeRequest("$($this.BaseUri)/payments/$PaymentToken/captures", $Body, $true)
        return $Response.action_id
    }
    
    [string] RefundPayment([decimal]$Amount, [string]$PaymentToken, [string]$Reference, [string]$Metadata) {
        $Body = @{
            amount = $Amount
            reference = $Reference
            metadata = $Metadata
        } | ConvertTo-Json
        $PaymentToken = $this.EnsurePaymentToken($PaymentToken)
        $Response = $this.MakeRequest("$($this.BaseUri)/payments/$PaymentToken/refunds", $Body, $true)
        return $Response.action_id
    }
    
    [string] VoidPayment([decimal]$Amount, [string]$PaymentToken, [string]$Reference) {
        $Body = @{
            amount = $Amount
            reference = $Reference
        } | ConvertTo-Json
        $PaymentToken = $this.EnsurePaymentToken($PaymentToken)
        $Response = $this.MakeRequest("$($this.BaseUri)/payments/$PaymentToken/voids", $Body, $true)
        return $Response.action_id
    }
}
