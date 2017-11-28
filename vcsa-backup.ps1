###########################################
#
#   Name    : VCSA Backup
#   Date    : 09/10/2017
#   Author  : Raphael TANI
#   Purpose : VCSA Backup
#   Keyword : VCSA,backup,restore,REST api
#
#   0.1 initial release
#   0.2 use REST API and remove SOAP API calls
#
###########################################

Set-StrictMode -Version Latest

[String] $PSC_ = "PSC"
[String] $VCT_ = "VCT"

[String] $BACKUP_ = "backup"
[String] $STATUS_ = "status"


<#
    Helper function to allow self-signed certificates for HTTPS connections
    This is required when using RESTful API calls over PowerShell
#>

function Unblock-SelfSignedCert() 
{
  Write-Verbose -Message 'Allowing self-signed certificates'
    
  if ([System.Net.ServicePointManager]::CertificatePolicy -notlike 'TrustAllCertsPolicy') 
  {
    Add-Type -TypeDefinition @"
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
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy
  }
}

<#
    Priinter function to indicate sript usage
#>

function PrintUsage{
    Write-Host "Argument -f and existing configuration file name required"
    Write-Host "USAGE: vcsa-backup.ps1" 
    Write-Host "      -f|--file <configuration file name>" 
    Write-Host "      -o|--operation [backup | status [-m|--mail]]" 

}

<#
    Helper function to retrieve JSON from input file
#>

function GetJSONTreeFromFile{
    [OutputType([System.Object])]
    param(
        [String]
        $File
    )
    process{
        try{
            #[System.Object]$root = [System.Object]::new()
            [System.Object]$root = New-Object -TypeName System.Object
            $root = Get-Content -Path $File -Raw | ConvertFrom-Json
            return $root
        }
        catch{
           
                <#
                    You can have multiple catch blocks (for different exceptions), or one single catch.
                    The last error record is available inside the catch block under the $_ variable.
                    Code inside this block is used for error handling. Examples include logging an error,
                    sending an email, writing to the event log, performing a recovery action, etc.
                    In this example I'm just printing the exception type and message to the screen.
                #>
                write-host "Caught an exception:" -ForegroundColor Red
                write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red 
                exit 1
        }
    }
}

<#
    Helper function to testif a config file exists and is a file
#>

function GetConfigFilePath{
    [OutputType([String])]
    param(
        [String]
        $File
    )
    process{
        try{
            [String] $path = [String]::Empty
            $path = Resolve-Path $File
            if(Test-Path -Path $path -PathType Leaf){
                return $path   
            }else{
                #PrintUsage
                [System.Exception]$e = [System.Exception]::new()
                #exit 1
            }
        }
        catch{

                <#
                    You can have multiple catch blocks (for different exceptions), or one single catch.
                    The last error record is available inside the catch block under the $_ variable.
                    Code inside this block is used for error handling. Examples include logging an error,
                    sending an email, writing to the event log, performing a recovery action, etc.
                    In this example I'm just printing the exception type and message to the screen.
                #>
                write-host "Caught an exception:" -ForegroundColor Red
                write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
                exit 1
        }
    }
}

<#
    Getter function to retrieve vCenter server hostname
#>

function GetVcenterServer{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    )
    process{
        [String] $ServerName = [String]::Empty
        $ServerName = $Tree.vcenter.server
        return $ServerName
    }
}

<#
    Getter function to retrieve vCenter server username
#>

function GetVcenterUser{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    )
    process{
        [String] $user = [String]::Empty
        $user = $Tree.vcenter.user
        return $user
    }
}

<#
    Getter function to retrieve vCenter user password
#>

function GetVcenterPassword{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    )
    process{
        [String] $password = [String]::Empty
        $password = $Tree.vcenter.password
        return $password
    }
}

<#
    Getter function to retrieve FTP server hostname
#>


function GetFTPServer{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    )
    process{
        [String]$server = [String]::Empty
        $server = $Tree.transfert.server
        return $server
    }    
}

<#
    Getter function to retrieve FTP server username
#>

function GetFTPUser{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    )
    process{
        [String]$user = [String]::Empty
        $user = $Tree.transfert.user
        return $user
    }    
}

<#
    Getter function to retrieve FTP user passwword
#>

function GetFTPPassword{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    )
    process{
        [String]$password = [String]::Empty
        $password = $Tree.transfert.password
        return $password
    }    
}

<#
    Getter function to retrieve SMTP server hostname
#>

function GetSMTPServer{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    )
    process{
        [String]$server = [String]::Empty
        $server = $Tree.smtp.server
        return $server
    } 
}
<#
    Getter function to retrieve SMTP sender
#>

function GetSMTPSender{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    )
    process{
        [String]$sender = [String]::Empty
        $sender = $Tree.smtp.sender
        return $sender
    } 
}
<#
    Getter function to retrieve SMTP recipient
#>

function GetSMTPRecipient{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    )
    process{
        [String]$recipient = [String]::Empty
        $recipient = $Tree.smtp.recipient
        return $recipient
    } 
}

<#
    Function to open REST API session with appliance,
    return an authentication token if authentication successfull, or an empty string
#>


function OpenRESTSession{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    )
    process{
        [String] $user =[String]::Empty
        [String] $password =[String]::Empty
        [String] $server =[String]::Empty
        $user = GetVcenterUser -Tree $Tree
        $password = GetVcenterPassword -Tree $Tree
        $server = GetVcenterServer -Tree $Tree
        $auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($user+':'+$password))
        $head = @{
            'Authorization' = "Basic $auth"
        }

        $uri = "https://" + $server + "/rest/com/vmware/cis/session"
        $r = Invoke-WebRequest -Uri $uri -Headers $head -Method Post

        $token = (ConvertFrom-Json $r.Content).value
        return $token
    }
}
<#
    Function to close RESTAPI session
#>

function CloseRESTSession{
    param(
        [System.Object]
        $Tree
    ,
        [String]
        $Token
    )
    process{
        [String] $server =[String]::Empty
        $headers = @{}
        $headers.Add('Accept','application/json')
        $headers.Add('vmware-api-session-id', $Token)
        $server = GetVcenterServer -Tree $Tree
        #Close the connexion
        $uri = "https://" + $server + "/rest/com/vmware/cis/session"
        $r = Invoke-WebRequest -Uri $uri  -Headers $headers -Method Delete
    } 
}

<#
    Getter function to retrieve vCenter installation type
#>


function GetVcenterType{
    [OutputType([String])]
    param(
        [System.Object]
        $Tree
    ,
        [String]
        $Token
    )
    process{
        
        [String] $vc_type = "vCenter Server with an external Platform Services Controller"
        [String] $vcepsc_type = "vCenter Server with an embedded Platform Services Controller"
        [String] $psc_type = "VMware Platform Services Controller"

        [String] $server =[String]::Empty
        $headers = @{}
        $headers.Add('Accept','application/json')
        $headers.Add('vmware-api-session-id', $Token)
        $server = GetVcenterServer -Tree $Tree
        #Get vCenter installation type
        $uri = "https://" + $server + "/rest/appliance/system/version"
        $r = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get
        $value = (ConvertFrom-Json $r.Content).value
        [String] $type = $value.type
        if($type.Equals($vc_type)){
            return $VCT_
        }elseif($type.Equals($psc_type)){
            return $PSC_
	}elseif($type.Equals($vcepsc_type)){
	    return $VCT_
        }else{ 
            return [String]::Empty
        }
    }
}
<#
    Getter function to retrieve backup job list
#>

function GetBackupJobList{
    [OutputType([String[]])]
    param(
        [System.Object]
        $Tree
    ,
        [String]
        $Token
    )
    process{
        [String] $server =[String]::Empty
        $headers = @{}
        $headers.Add('Accept','application/json')
        $headers.Add('vmware-api-session-id', $Token)
        $server = GetVcenterServer -Tree $Tree
        #Get list of backup jobs
        $uri = "https://" + $server + "/rest/appliance/recovery/backup/job"
        $r = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get
        $list = (ConvertFrom-Json $r.Content).value
        return $list
    }
}
<#
    Getter function to retrieve properties for a given backup job
#>

function GetBackupJobInfo{
    [OutputType([System.Object])]
    param(
        [System.Object]
        $Tree
    ,
        [String]
        $Token
    ,
        [String]
        $JobID        
    )
    process{
        [String] $server =[String]::Empty
        $headers = @{}
        $headers.Add('Accept','application/json')
        $headers.Add('vmware-api-session-id', $Token)
        $server = GetVcenterServer -Tree $Tree
        $uri = "https://" + $server + "/rest/appliance/recovery/backup/job/" + $JobID
        $r = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get
        $props = (ConvertFrom-Json $r.Content).value
        return $props
    }
}
<#
    Getter function to retrieve a summary of backup jobs,
    return an array with the backup jobs list 
    and information on each job (ID, 
                                Status, 
                                Start Time, 
                                End Time (if properties is available) 
                                and Progress percentage)
#>

function GetBackupJobSummary{
    [OutputType([System.Object])]
    param(
        [System.Object]
        $Tree
    ,
        [String]
        $Token
    ,
        [System.Object[]]
        $List
    )
    process{
        $backups = @()
        foreach($jobid in $List){
            $backup = @{}
            $props = GetBackupJobInfo -Tree $obj -Token $Token -JobID $jobid
            $status = $props.state
            $start = $props.start_time
            $progress = $props.progress
            $end = "N/A"
            if($status.CompareTo("INPROGRESS") -eq 1){
                $end = $props.end_time
            }

            $backup.Add("ID",$jobid)
            $backup.Add("Status",$status)
            $backup.Add("Start Time",$start)
            $backup.Add("End Time",$end)
            $backup.Add("Progress %",$progress)

            $backups += $backup

        }
        return $backups
    }
}
<#
    Function to initiate a file backup level of the appliance
#>

function InitiateBackup{
    param(
        [System.Object]
        $Tree
    ,
        [String]
        $Token
    )
    process{
        $data = @{}
        $piece = @{}
        $parts = @()

        [String]$type = [String]::Empty
        [String]$location_user = [String]::Empty
        [String]$location = [String]::Empty
        [String]$location_password = [String]::Empty
        [String]$location_type = "FTP"
        [String]$location_directory = [String]::Empty

        $type = GetVcenterType -Tree $obj -Token $Token
        $server = GetVcenterServer -Tree $obj

        if($type.Equals($VCT_)){
            $parts = @("common","seat")
        }
        if($type.Equals($PSC_)){
            $parts = @("common")
        }

        $location_user = GetFTPUser -Tree $obj
        $location = GetFTPServer -Tree $obj
        $location_password = GetFTPPassword -Tree $obj
        $date = Get-Date
        $dateUTC = $date.ToUniversalTime() # Change to UTC to macth directory name with backup job query result
        $location_directory = Get-Date -Date $dateUTC -Format yyyyMMddTHHmmssffff-
        $location_directory += $server

        $piece.Add("parts",$parts)
        $piece.Add("location_user",$location_user)
        $piece.Add("location",$location + "/" + $location_directory)
        $piece.Add("location_password",$location_password)
        $piece.Add("location_type","FTP")
        $data.Add("piece",$piece)
        $dataJSON = ConvertTo-Json -InputObject $data

        $headers = @{}
        $headers.Add('Content-Type','application/json')
        $headers.Add('Accept','application/json')
        $headers.Add('vmware-api-session-id', $Token)

        $uri = "https://" + $server + "/rest/appliance/recovery/backup/job"
        
        if(!($type.Equals([String]::Empty))){
            $r = Invoke-WebRequest -Uri $uri -Headers $headers -Body $dataJSON -Method Post
        }
    }
}

#MAIN
Unblock-SelfSignedCert


if(($args.Count -eq 4) -or ($args.Count -eq 5)){
    if($args[0].Equals("-f") -or $args[0].Equals("--file")){
        if($args[2].Equals("-o") -or $args[2].Equals("--operation")){
            if($args[3].Equals($BACKUP_) -or $args[3].Equals($STATUS_)){

                [String] $token =[String]::Empty
                [String]$file = $args[1]
                $path = GetConfigFilePath -file $file
                [System.Object]$obj = GetJSONTreeFromFile -File $path
    
                [String]$operation = $args[3]

                $token = OpenRESTSession -Tree $obj

                switch($operation){
                    $BACKUP_{
                        if($args.Count -eq 4){
                            #Initiate backup
                            InitiateBackup -Tree $obj -Token $token
                        }
                    }
                    $STATUS_{
                        [String]$str = [String]::Empty 
                        $list = GetBackupJobList -Tree $obj -Token $token
                        $summary = GetBackupJobSummary -Tree $obj -Token $token -List $list
                        $table = $summary.foreach({[PSCustomObject]$_}) | Format-Table -Property "ID","Start Time","End Time","Status","Progress %" -AutoSize
                        $str = $table | Out-String
                        if($args.Count -eq 4){
                            Write-Host $str
                        }
                        if(($args.Count -eq 5) -and ($args[4].Equals("-m") -or $args[4].Equals("--mail"))){

                            $smtp = GetSMTPServer -Tree $obj
                            $sender = GetSMTPSender -Tree $obj
                            $server = GetVcenterServer -Tree $obj
                            $subject = "VCSA Backup Result for "
                            $subject += $server
                            $recipient = (GetSMTPRecipient -Tree $obj).Split(",") # In the configuration file, indicate one or more recipients comma separated

                            Send-MailMessage -SmtpServer "$smtp" -From "$sender" -To $recipient -Subject "$subject" -Body "$str"
                        }
                    }
                    default{
                        # operation not known
                    }
                }
                
                CloseRESTSession -Tree $obj -Token $token
            }else{
                PrintUsage
            }
        }else{
            PrintUsage
        }
    }else{
        PrintUsage
    }
}else{
    PrintUsage
}
