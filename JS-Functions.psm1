#param(
##    [parameter(Position=0,Mandatory=$true)][int]$CSType,
#    [parameter(Position=1,Mandatory=$true)][string]$MutexName,
#	[parameter(Position=2,Mandatory=$true)][string]$Logfile,
#	[parameter(Position=3,Mandatory=$true)][string]$CSURL
#	[parameter(Position=4,Mandatory=$true)][string]$Guidthread
#)


$global:CSType = $args[0]
$SecureModulePath = "C:\work\secureStringFunctions.psm1"
$global:Debug = $false

$global:MutexName =  $args[1]
$Logfile =  $args[2]
$global:CSURL =  $args[3]


if ($args[4]) 
{
$global:Guidthread =  $args[4]
}
else
{
$global:Guidthread = "NOT SET"
}
$logFileMain = $Logfile 


Import-Module $SecureModulePath -Force -Verbose
Import-Module C:\work\LoggingFunction.psm1 -Force -Verbose

Initialize-Log -FilePath  $logFileMain -NewMutex $global:MutexName 
Write-Log -FilePath $logFileMain -Level "Info" -Message "|$($global:Guidthread)|JSFunct Log Function loaded"  -MutexName $global:MutexName


Function Set-CScredentials
{
   <# 
   .SYNOPSIS 
    Create Credentials File
  
.DESCRIPTION 
    TODO
    
   .PARAMETER LogPath 
    TODO
    
    
   .INPUTS 
    Parameters above 
  
   .OUTPUTS 
     SecureString File $secureStringPath

   .EXAMPLE 
     Set-CScredentials -secureStringPath "C:\Windows\Temp\Test_Script.dat"
   #> 
    
   [CmdletBinding()] 
    
   Param ([Parameter(Mandatory=$true)][string]$secureStringPath)

	Write-Log -FilePath  $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|Execute funtion $($MyInvocation.MyCommand)"  -Mutex $global:MutexName 

	
	# Prompt the user to enter a password
	$secureString = Read-Host -AsSecureString "Enter a secret password"
	$secureString | ConvertFrom-SecureString | Out-File $secureStringPath -Force
}

Function CS-Authenticate
{
	<# 
   .SYNOPSIS 
    Create Credentials File
  
	.DESCRIPTION 
    Retrive Authentication ticket via REST 
    
   .PARAMETER SecureStringFile 
    Set-CScredentials File
    
   .PARAMETER CSUser 
	UserName, Password will be retrieved from SecureStringFile
  
   .PARAMETER CSURL 
	ContentServer ROOT URL for REST API http://SERVER/OTCS/cs.exe/api/v1/
    
    
   .INPUTS 
      Parameters above 
  
   .OUTPUTS 
     AuthTicket 

   .EXAMPLE 
     CSAuthenticate -SecureStringFile "C:\Windows\Temp\Test_Script.dat" CSUser "Admin" -EmailTo "aaaaa@xxxx.xxxx"-CSURL "http://SERVER/OTCS/cs.exe/api/v1/" 
    #> 
    
   [CmdletBinding()] 
    
   Param ([Parameter(Mandatory=$true)][string]$SecureStringFile, [Parameter(Mandatory=$true)][string]$CSUser, [Parameter(Mandatory=$true)][string]$CSURL) 
    
	Process
	{
		
		
	   Write-Log -FilePath  $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"  -Mutex $global:MutexName 

		$restFunct = "auth" 
		 
		$AuthURL = $CSURL + $restFunct
		
		Write-Verbose "Authentication URL:$($AuthURL)"
		
		Import-Module $SecureModulePath
		
		#Region LoadSecureString
			if ((Test-Path -Path $SecureStringFile) -eq $false) # Test file with password 
			{
		 
				Write-Log -FilePath  $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Not found $($secureString)"  -Mutex $global:MutexName 

				Exit -100	
			}
			$secureString = Get-Content $SecureStringFile | ConvertTo-SecureString
			$pass  = $secureString | ConvertFrom-SecureString -AsPlainText -Force
		#EndRegion
	 
		Write-Log -FilePath  $logFileMain -Level "Info" -Message "|$($global:Guidthread)|CS URL $($AuthURL)"   -Mutex $global:MutexName 
	    
		$body = @{
	    username = $CSUser
	    password =$pass
	    domain = ""
	    }

		Write-Verbose "Body:$($body.GetEnumerator() |% { "key={0}, value={1}" -f $_.key, $_.value })"

	    $outRest = ""
	   
		try
		{
			$outRest = Invoke-RestMethod -Method Post -Uri $AuthURL -Body $body  
			$ticket = $outRest.ticket
		}
		catch
		{
			$err= "Error: Problem with auth ticket $($_.Exception.Message)" 
		   
		  Write-Log -FilePath  $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|$($err)"  -Mutex $global:MutexName 
	 
		  	Throw $err
		}
		
		
		Write-Verbose "Ticket:$($ticket)"  
		if (($ticket.Length -ge 10) -eq $true) #todo regex check
		{
			return $ticket
		}
		else 
		{
		 
			Write-Log -FilePath  $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Ticket is empty - exit"  -Mutex $global:MutexName  
 
		  	Throw "Problem with auth ticket"
		}
	}
}

Function TestFileName([string]$FileName)
{
	
	Write-Log -FilePath  $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|Execute funtion $($MyInvocation.MyCommand)"  -Mutex $global:MutexName  
	 
    if ($FileName -like '*#*' -or $FileName -like '*%*'-or $FileName -like '*/*'  -or  $FileName -like '*]*' -or  $FileName -like '*`[*') 
        {
          
            Write-Log -FilePath $logFileMain -Level "Error" -Message   "|$($global:Guidthread)|Soubor obsahuje nepovolene znaky |$($FileName.ToString())"  -MutexName $MutexName 
            $FileName= $FileName.Replace("#","_")
            $FileName= $FileName.Replace("/","_")
            $FileName= $FileName.Replace("%","_")
            $FileName= $FileName.Replace("[","(")
            $FileName= $FileName.Replace("]",")")


           
        }
    
    If ($FileName -notlike "*.*") 
    {   
        Write-Log -FilePath $logFileMain -Level "Error" -Message "|$($global:Guidthread)|Soubor neobsahuje tec�ku |$($FileName.ToString())" -MutexName $MutexName 
    }

 	Write-Log -FilePath  $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|Execute funtion $($MyInvocation.MyCommand) vysledek $FileName "  -Mutex $global:MutexName  
	
    return $FileName
}


Function CS-Nodes-ID-Name {


	param (
		[string]$ticket = $(throw "need"),
		[string]$ParentNodeid, 
		[string]$CSURL,
		[string]$FileName
	)
		
		$restFunct = "nodes"
		$headerX = @{ 
		otcsticket = $ticket
	}
 
	Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|Execute funtion $($MyInvocation.MyCommand)"  -Mutex $global:MutexName  

	
    $tmpURI = $CSURL + $restFunct + "/" + $ParentNodeid + "/nodes?where_name=" + $FileName

 
	Write-Log -FilePath $logFileMain -Level "Error" -Message "|$($global:Guidthread)|jsFunct $($MyInvocation.MyCommand)  REST URL: $($tmpURI)"  -Mutex $global:MutexName  
 



    $outRestNodesinfo = "" 

    $outRestNodesinfo = Invoke-RestMethod -Method Get -Uri $tmpURI -Headers $headerX
 	 
	
	Write-Verbose "CSTypeName: $CSTypeName"
	Write-Verbose "CSTypeID: $CSTypeID"


	
	Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct CSTypeName: $CSTypeName"    -Mutex $global:MutexName 
 
	Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct CSTypeID: $CSTypeID"   -Mutex $global:MutexName 
 
 

	$TotalCount = $outRestNodesinfo.total_count 
	$data = $outRestNodesinfo.data
	 
    return @{'TotalCount'=$TotalCount 
	'data'=$data} 
}




Function CS-Node-Download-version-ToFile {
	param (
		[string]$ticket = $(throw "need"),
		[string]$nodeid,
		[string]$verNumber,
 		[string]$CSURL,
        [string]$FileOut
	)
		   
		Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"  -Mutex $global:MutexName  

		$restFunct = "nodes"
		
		$headerX = @{ 
		otcsticket = $ticket
	} 
		$tmpURI = $CSURL + $restFunct + "/" + $nodeid + "/versions/" + $verNumber +  "/content" 
		
		write-host $tmpURI  -ForegroundColor Green
		Write-Log -FilePath $logFileMain -Level "Info" -Message "|$($global:Guidthread)|jsFunct $($MyInvocation.MyCommand)  REST URL: $($tmpURI)" -Mutex $global:MutexName 


  $outRestNodeContent = "" 
  	if ((Test-Path -LiteralPath $FileOut) -eq $false) 
	{

	try 
		{
			   $outRestNodeContent =Invoke-WebRequest -Method Get -Uri $tmpURI -Headers $headerX -OutFile  $FileOut
		 } 
		catch 
		{
 

		   Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Error: $($MyInvocation.MyCommand)  $($_.Exception.Message)"  -Mutex $global:MutexName 
		}
    }
	else
	{
		Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Error: $($MyInvocation.MyCommand)  File $FileOut already exists"  -Mutex $global:MutexName 
 
	 
	}

	
		return $outRestNodeContent



}







Function CS-Node-Download-version {
	param (
		[string]$ticket = $(throw "need"),
		[string]$nodeid,
		[string]$verNumber,
 		[string]$CSURL
	)
		   
		Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"  -Mutex $global:MutexName  

		$restFunct = "nodes"
		
		$headerX = @{ 
		otcsticket = $ticket
	} 
		$tmpURI = $CSURL + $restFunct + "/" + $nodeid + "/versions/" + $verNumber +  "/content" 
		
		write-host $tmpURI  -ForegroundColor Green
		Write-Log -FilePath $logFileMain -Level "Info" -Message "|$($global:Guidthread)|jsFunct $($MyInvocation.MyCommand)  REST URL: $($tmpURI)" -Mutex $global:MutexName 

		try 
		{
			   $outRestNodeContent =Invoke-WebRequest -Method Get -Uri $tmpURI -Headers $headerX
		 } 
		catch 
		{
 

		   Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Error: $($MyInvocation.MyCommand)  $($_.Exception.Message)"  -Mutex $global:MutexName 
		}
		return $outRestNodeContent

		
	}




Function CS-Node-Download {
param (
    [string]$ticket = $(throw "need"),
    [string]$nodeid, 
	[string]$CSURL,
	[string]$FileOut
)
   	
Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"  -Mutex $global:MutexName 

	
    $restFunct = "nodes"
	
    $headerX = @{ 
    otcsticket = $ticket
} 
    $tmpURI = $CSURL + $restFunct + "/" + $nodeid + "/content" 
	
	write-host $tmpURI  -ForegroundColor Green
 

	Write-Log -FilePath $logFileMain -Level "Info" -Message "|$($global:Guidthread)|jsFunct $($MyInvocation.MyCommand)  REST URL: $($tmpURI)"   -Mutex $global:MutexName 




    $outRestNodeContent = "" 
	
	if ((Test-Path -LiteralPath $FileOut) -eq $false) 
	{
		try 
		{
	   		$outRestNodeContent = Invoke-RestMethod -Method Get -Uri $tmpURI -Headers $headerX -OutFile $FileOut 
	 	} 
		catch 
		{
		   Write-Log -FilePath $logFileMain -Level "Error" -Message "|$($global:Guidthread)|jsFunct Error: $($MyInvocation.MyCommand) $($_.Exception.Message)"    -Mutex $global:MutexName 
 
		}
	}
	else
	{
		Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Error: $($MyInvocation.MyCommand)  File $FileOut already exists"  -Mutex $global:MutexName 
 
	 
	}
	
	
}

Function CS-Node-Download-withoutSave {
	param (
		[string]$ticket = $(throw "need"),
		[string]$nodeid, 
		[string]$CSURL
		 
	)
		   
	Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"  -Mutex $global:MutexName 

		
		$restFunct = "nodes"
		
		$headerX = @{ 
		otcsticket = $ticket
	} 
		$tmpURI = $CSURL + $restFunct + "/" + $nodeid + "/content"+ "?action=download" 
			
		Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct $($MyInvocation.MyCommand) REST URL: $($tmpURI)"  -Mutex $global:MutexName 
 
	 
			try 
			{
				   $outRestNodeContent =Invoke-WebRequest -Method Get -Uri $tmpURI -Headers $headerX
			 } 
			catch 
			{
				Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Error: $($MyInvocation.MyCommand) $($_.Exception.Message)"   -Mutex $global:MutexName 
	 
			}
			return $outRestNodeContent
	
		}
	
Function CS-Nodes-info {
	param (
		[string]$ticket = $(throw "need"),
		[string]$nodeid, 
		[string]$CSURL
	)
	
     
    $restFunct = "nodes"
    $headerX = @{ 
    otcsticket = $ticket
	}
 
	Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"   -Mutex $global:MutexName 



    $tmpURI = $CSURL + $restFunct + "/" + $nodeid
 
 	Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct $($MyInvocation.MyCommand)  REST URL: $($tmpURI)"   -Mutex $global:MutexName 
	 


    $outRestNodeinfo = "" 


try 
	{
	    $outRestNodeinfo = Invoke-RestMethod -Method Get -Uri $tmpURI -Headers $headerX
	 	
		
	 

		Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct $($MyInvocation.MyCommand)  RestOut: $($outRestNodeinfo)"   -Mutex $global:MutexName 
	 
	



	 	
		$CSTypeName = $outRestNodeinfo.type_name
		$CSTypeID = $outRestNodeinfo.type
		$ObjectName = $outRestNodeinfo.Data.name
		

	 
		Write-Log -FilePath $logFileMain -Level "Info" -Message   "|$($global:Guidthread)|jsFunct CSTypeName: $CSTypeName"   -Mutex $global:MutexName 
	 
		Write-Log -FilePath $logFileMain -Level "Info" -Message   "|$($global:Guidthread)|jsFunct CSTypeID: $CSTypeID"    -Mutex $global:MutexName 


	    return @{'NodeTypeID'=$CSTypeID 
		'TypeName'=$CSTypeName
		'ObjectName'=$ObjectName
		}
	}
	catch 
	{
 
		Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Error: $($MyInvocation.MyCommand)  $($_.Exception.Message)"   -Mutex $global:MutexName 
	 
	}
	
	
}



Function ToWin1250($sourceString)
{
	Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"   -Mutex $global:MutexName 

	$iso = [System.Text.Encoding]::GetEncoding("Windows-1250")
	$utf8 = [System.Text.Encoding]::UTF8
	$utfBytes = $utf8.GetBytes($sourceString)
	$isoBytes =[System.Text.Encoding]::Convert($utf8,$iso,$utfBytes)
	$msg = $iso.GetString($isoBytes)
	return $msg
}


function Remove-Diacritics {
param ([String]$src = [String]::Empty)
  $normalized = $src.Normalize( [Text.NormalizationForm]::FormD )
  $sb = new-object Text.StringBuilder
  $normalized.ToCharArray() | % { 
    if( [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$sb.Append($_)
    }
  }
  $sb.ToString()
}




Function CS-Upload
{
<# 
   .SYNOPSIS 
    Create Credentials File
  
	.DESCRIPTION 
    Retrive Authentication ticket via REST 
    
   .PARAMETER filePath 
    File for upload
    
   .PARAMETER CSParentNode 
	CSNodeName
  
    .PARAMETER CSType 
	CSNodeName
	
	   .PARAMETER CSNodeName 
	CSNodeName
  
  
   .PARAMETER CSURL 
	ContentServer ROOT URL for REST API http://SERVER/OTCS/cs.exe/api/v1/
    
    
   .INPUTS 
      Parameters above 
  
   .OUTPUTS 
     AuthTicket 

   .EXAMPLE 
     CSAuthenticate -filePath "C:\Windows\Temp\Test_Script.dat" CSUser "Admin" -EmailTo "aaaaa@xxxx.xxxx"-CSURL "http://SERVER/OTCS/cs.exe/api/v1/" 
    #> 
    
   [CmdletBinding()] 
    
   Param ([Parameter(Mandatory=$true)][string]$filePath, 
   [Parameter(Mandatory=$true)][string]$CSNodeName,
   [Parameter(Mandatory=$true)][int32]$CSParentNode,
   [Parameter(Mandatory=$true)][int32]$CSType,
   [Parameter(Mandatory=$true)][string]$CSURL,
   [Parameter(Mandatory=$true)][string]$CSAuthTicket
   ) 
    
	
#	$ticket = CS-Authenticate -CSURL $CSURL -CSUser $CSUser -SecureStringFile $secureStringPath -Verbose
	
	Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"   -Mutex $global:MutexName 


	$CODEPAGE = "iso-8859-1" # alternatives are ASCII, UTF-8, iso-8859-1
	$LF = "`r`n"
     
	
	$boundary ="----" + $([System.Guid]::NewGuid().ToString().Replace("-","")) + "xxx" 
	$boundaryhead = $boundary 

	$boundary = "--" + $boundary

 
	Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Upload type:$($CSType),ParentID:$($CSParentNode),Name:$($CSNodeName)"   -Mutex $global:MutexName 
	 
	
	if ((Test-Path ($filePath)) -eq $true)
	{
		$fileBin = [System.IO.File]::ReadAllBytes($filePath)
		$enc = [System.Text.Encoding]::GetEncoding($CODEPAGE)
		#$Bytes = [System.Text.Encoding]::Unicode.GetBytes($Text)
 		$EncodedText =[Convert]::ToBase64String($fileBin)
		$fileEnc = $enc.GetString($fileBin)
		$raw =  Get-Content($filePath) -Raw
	}

     $bodyLines = (
        $boundary,
		$LF,
		"Content-Disposition: form-data; name=`"type`"$LF",
		$LF,
		$CSType,
		$LF,
		$boundary,
		$LF,
		"Content-Disposition: form-data; name=`"parent_id`"$LF",
		$LF,
		$CSParentNode,
		$LF,
		$boundary,
		$LF,
		"Content-Disposition: form-data; name=`"name`"$LF",
		$LF,
		$CSNodeName,
		$LF,
		$boundary,
		$LF,
        "Content-Disposition: form-data; name=`"file`"; filename=`"$CSNodeName`"$LF",
		$(CS-ReturnContentType -fileName $CSNodeName),
       	$LF,
		$fileEnc,
		$LF,$LF,
        "$boundary--$LF") -join ""	
	 
 

		$contentType = "multipart/form-data; boundary=$($boundaryhead)" + $LF +$LF

		$header = @{ 
	    otcsticket = $CSAuthTicket
		Accept = "*/*" 
		'Accept-Encoding'= "gzip, deflate"
		} 
	
	$restFunctCreate = "nodes" 
	$UploadURI = $CSURL + $restFunctCreate 
	
	Write-Verbose "Upload URL:$($UploadURI)"

 
	
	Write-Log -FilePath $logFileMain -Level "Error" -Message "|$($global:Guidthread)|jsFunct Upload URL:$($UploadURI)"   -Mutex $global:MutexName 
	 
	$outRest2 = ""
  
   try 
	{
		$outRest2 = Invoke-RestMethod -Method Post -ContentType $contentType -Body $bodyLines  -Headers $header -Uri $UploadURI
	  	
		$docID = $outRest2.id

		Write-Log -FilePath $logFileMain -Level "Error" -Message "|$($global:Guidthread)|jsFunct Upload DocumentID:$($docID)"    -Mutex $global:MutexName 
	  
		Write-Host "Node ID " $docID -ForegroundColor Red
		Return $docID
	}
catch 
	{


		Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Error: move item error $($_.Exception.Message)"   -Mutex $global:MutexName 
		 
		Write-Error  "Error: move item error $($_.Exception.Message)"
		Exit -1
	}
}

function TranslateSID([string]$SID) {

	Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"   -Mutex $global:MutexName 


	if ($SID -like "S-1-*") {
		$objSID = New-Object System.Security.Principal.SecurityIdentifier($SID)
		try {
			$objUser = $objSID.Translate( [System.Security.Principal.NTAccount])
			return $objUser.Value
			}
		catch {	
			saythis "     ERROR: Unable to translate the SID: $SID " RED
			return $SID
			}
		}
		else {
			return $objUser.Value
		}
}


Function CS-ReturnContentType($fileName)
{

	Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"   -Mutex $global:MutexName 


	$ret = ""

 

	Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|Translate $($fileName) to Content-Type"   -Mutex $global:MutexName 



	switch -wildcard ($fileName) 
	{
		"*.html" {$ret="Content-Type: TEXT/html$LF"}
		"*.htm"  {$ret="Content-Type: TEXT/html$LF"}
		"*.txt"  {$ret="Content-Type: TEXT/html$LF"}
		"*.pdf"  {$ret="Content-Type: application/pdf$LF"}
		"*.docx"  {$ret="Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document$LF"}
		"*.xlsx"  {$ret="Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet$LF"}
		default {$ret="Content-Type: application/octet-stream$LF"}
	}
	
	Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Translate return $ret"   -Mutex $global:MutexName 

 
	return $ret

}


Function ModifyGroupReport ($GroupReportPath) 
{
		
	Write-Log -FilePath $LogFile -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"   -Mutex $global:MutexName 


	if ((Test-Path $GroupReportPath) -eq $true) 
	{
		$tmpSourceFileData = Get-Content -Path $GroupReportPath  
		$tmpSourceFileData.Replace("""resources/", """./resources/") | Set-Content -Force -Path $GroupReportPath
	}

}


Function GenerujFinalPathZFullName([string] $FullPath, [string] $JmenoFile, [string]$TargetLibrary,[string]$TargerLibraryFolder,[string]$FolerPrefixNull )
{

			
	Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)|$FullPath|$JmenoFile|$TargetLibrary|$TargerLibraryFolder|$FolerPrefixNull"   -Mutex $global:MutexName 
 
      #  $FullPath  = "Enterprise:CORPORATE:OFFICE MANAGEMENT:OM_SK:ASSISTANTS:RECEPCIA:Periodika:2022:Poradca:7080PORADCASRO_PO4315001674.pdf"
      # $JmenoFile = "7080PORADCASRO_PO4315001674.pdf"
      #  $FolerPrefixNull = "Enterprise:CORPORATE:OFFICE MANAGEMENT:OM_SK:ASSISTANTS:"
    #    $FolerPrefixNull = "Enterprise:CORPORATE:FINANCE:TREASURY:Financing Documentation:PRESUNUTE_NEMAZAT_02_Bonds:DRM_1708_Bonds_DRMF_Dr. Max 22_5:"
      # $TargerLibraryFolder  = "ASSISTANTS"
      # $TargetLibrary = "SK"


    #:Enterprise:CORPORATE:OFFICE MANAGEMENT:OM_SK:ASSISTANTS:RECEPCIA:Periodika:2022:Poradca:7080PORADCASRO_PO4315001674.pdf|TargetLibrary:SK|FolderPrefixNUll:Enterprise:CORPORATE:OFFICE MANAGEMENT:OM_SK:ASSISTANTS:|Folder:ASSISTANTS|itemName:7080PORADCASRO_PO4315001674.pdf| 


try {



	if (($FullPath.Substring(0,$FullPath.Length -$JmenoFile.Length))  -eq $FolerPrefixNull)
    {
         $pouzeCesta= $FullPath.Substring(0,$FullPath.Length -$JmenoFile.Length)
    }
    else {
        $pouzeCesta=  $FullPath.Substring(0,$FullPath.Length -1 -$JmenoFile.Length)
    }


 

      $path= $pouzeCesta.Substring($FolerPrefixNull.Length ,$pouzeCesta.Length - $FolerPrefixNull.Length).Replace(":","\") 

 

   
    $splittedPath = $path.split("\")

	if ($TargerLibraryFolder -eq "")
	{
		$targetTmpLibraryPath =  $TargetLibrary 
	} 
	else {
		$targetTmpLibraryPath =  $TargetLibrary + "/" + $TargerLibraryFolder + "/" 	
	}
    
    foreach ($tmp1 in $splittedPath) 
    {
        $targetTmpLibraryPath =  $targetTmpLibraryPath + "/" + $tmp1 + "/"
    }
  #  $targetTmpLibraryPath

  	$targetTmpLibraryPath= $targetTmpLibraryPath.Replace("//","/")

	}
	catch 
	{
		Write-Log -FilePath $logFileMain -Level "Error" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand) + " " + $($_.Exception.Message)"   -Mutex $global:MutexName 

	}
	$targetTmpLibraryPath = $targetTmpLibraryPath.Replace("//","/")
	$targetTmpLibraryPath = $targetTmpLibraryPath.Replace(" /","/")
	$targetTmpLibraryPath = $targetTmpLibraryPath.Replace("/ ","/")
	$targetTmpLibraryPath = $targetTmpLibraryPath.Replace("./","/")
	$targetTmpLibraryPath = $targetTmpLibraryPath.Replace("#","_")
	$targetTmpLibraryPath = $targetTmpLibraryPath.Replace("%","_percent_")


    #$targetTmpLibraryPath = $targetTmpLibraryPath.Replace(" ","%20")
    #$targetTmpLibraryPath = $targetTmpLibraryPath.Replace("/","%2F")
    #$targetTmpLibraryPath = $targetTmpLibraryPath.Replace(",","%2C")
    #$targetTmpLibraryPath = $targetTmpLibraryPath.Replace("+","%2B")



		
		Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)| Po uprave $targetTmpLibraryPath"   -Mutex $global:MutexName 
	
	return $targetTmpLibraryPath
}



function Remove-TextAfter {   
    param (
        [Parameter(Mandatory=$true)]
        $string, 
        [Parameter(Mandatory=$true)]
        $value,
        [Switch]$Insensitive
    )

    $comparison = [System.StringComparison]"Ordinal"
    if($Insensitive) {
        $comparison = [System.StringComparison]"OrdinalIgnoreCase"
    }

    $position = $string.IndexOf($value, $comparison)

    if($position -ge 0) {
        $string.Substring(0, $position + $value.Length)
    }
}




Function CS-Upload-Version
{
<# 
   .SYNOPSIS 
    Create new version in Content Server
  
	.DESCRIPTION 
    Create new version in Content Server via REST 
    
   .PARAMETER filePath 
    File for upload
    
   .PARAMETER CSParentNode 
	CSNodeName
  
    .PARAMETER CSType 
	CSNodeName
	
	.PARAMETER CSNodeID 
	CSNodeName
	
	.PARAMETER CSNodeName 
	CSNodeName
	
	.PARAMETER CSCreateMajorVersion 
	CSNodeName

  
   .PARAMETER CSURL 
	ContentServer ROOT URL for REST API http://SERVER/OTCS/cs.exe/api/v1/
    
    
   .INPUTS 
      Parameters above 
  
   .OUTPUTS 
     AuthTicket 

   .EXAMPLE 
     CSAuthenticate -filePath "C:\Windows\Temp\Test_Script.dat" CSUser "Admin" -EmailTo "aaaaa@xxxx.xxxx" -CSURL "http://SERVER/OTCS/cs.exe/api/v1/" -CSCreateMajorVersion $True -CSNodeID 2314
    #> 
    
   [CmdletBinding()] 
    
   Param ([Parameter(Mandatory=$true)][string]$filePath, 
   [Parameter(Mandatory=$true)][string]$CSNodeName,
   [Parameter(Mandatory=$true)][int32]$CSParentNode,
   [Parameter(Mandatory=$true)][int32]$CSType,
   [Parameter(Mandatory=$true)][string]$CSURL,
   [Parameter(Mandatory=$true)][string]$CSAuthTicket,
   [Parameter(Mandatory=$true)][bool]$CSCreateMajorVersion,
   [Parameter(Mandatory=$true)][int32]$CSNodeID
   ) 
    
   Write-Log -FilePath $LogFile -Level "Info" -Message  "|$($global:Guidthread)|jsFunct Execute funtion $($MyInvocation.MyCommand)"   -Mutex $global:MutexName 

 
	Write-Log -FilePath $LogFile -Level "Error" -Message "|$($global:Guidthread)|jsFunct CSNODEName : $($CSNodeName)"    -Mutex $global:MutexName 

	 
	$CODEPAGE = "iso-8859-1" # alternatives are ASCII, UTF-8, iso-8859-1
	$LF = "`r`n"
     
	$boundary ="----" + $([System.Guid]::NewGuid().ToString().Replace("-","")) + "xxx" 
	$boundaryhead = $boundary 

	$boundary = "--" + $boundary

	Write-Verbose "Upload type:$($CSType),ParentID:$($CSParentNode)"
	
	if ((Test-Path ($filePath)) -eq $true)
	{
		$fileBin = [System.IO.File]::ReadAllBytes($filePath)
		$enc = [System.Text.Encoding]::GetEncoding($CODEPAGE)
		#$Bytes = [System.Text.Encoding]::Unicode.GetBytes($Text)
 		$EncodedText =[Convert]::ToBase64String($fileBin)
		$fileEnc = $enc.GetString($fileBin)
		$raw =  Get-Content($filePath) -Raw
	}
	else 
	{
 

		Write-Log -FilePath $LogFile -Level "Error" -Message "|$($global:Guidthread)|jsFunct File doesnt Exists FullPath: $filePath"  -Mutex $global:MutexName 


		Exit -1
	}




$fileNameEncoded = Remove-Diacritics($CSNodeName)


     $bodyLines = (
        $boundary,
		$LF,
		"Content-Disposition: form-data; name=`"add_major_version`"$LF",
		$LF,
		$CSCreateMajorVersion,
		$LF,
		$boundary,
		$LF,
		"Content-Disposition: form-data; charset=UTF-8; name=`"name`"$LF",
		$LF,
		$CSNodeName,
		$LF,
		$boundary,
		$LF,
        "Content-Disposition: form-data; name=`"file`"; filename=`"$fileNameEncoded`"$LF",
		$(CS-ReturnContentType -fileName $CSNodeName),
       	$LF,
		$fileEnc,
		$LF,$LF,
        "$boundary--$LF") -join ""	
	 
 
		

		$contentType = "multipart/form-data; charset=utf-8; boundary=$($boundaryhead)" + $LF +$LF

		$header = @{ 
	    otcsticket = $CSAuthTicket
		Accept = "*/*"
		'Accept-Encoding'= "gzip, deflate"
		'Accept-Language' ="cs-CZ,cs;q=0.8,en;q=0.6"
		} 
	
	$restFunctCreate = "nodes/$($CSNodeID)/versions"
	$UploadURI = $CSURL + $restFunctCreate
	
	Write-Verbose "Upload URL:$($UploadURI)"
	
	$outRest2 = ""
  
   try 
	{
	
		
		$outRest2 = Invoke-RestMethod -Method Post -ContentType $contentType -Body $bodyLines -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::InternetExplorer) -Headers $header -Uri $UploadURI
	  	
		
		#$outRest2 = Invoke-RestMethod -Method Post -ContentType $contentType -Body $bodyLines  -Headers $header -Uri $UploadURI
	  	
		$docID = $outRest2.id	
		$version = $outRest2.version_number
		Write-Host "Node ID:" $docID -ForegroundColor Red #
		return $docID
	}
	catch 
	{
		Write-Log -FilePath $LogFile -Level "Error" -Message  "|$($global:Guidthread)|Error: move item error $($_.Exception.Message)"  -Mutex $global:MutexName 

		Write-Host -ForegroundColor Red "Error: move item error $($_.Exception.Message)" 
		Exit -1
	}
}


Export-ModuleMember -Function 'CS-Nodes-info'
Export-ModuleMember -Function 'CS-Node-Download'
Export-ModuleMember -Function 'ConvertFrom-TXTtoPDF'
Export-ModuleMember -Function 'Log-Email'
Export-ModuleMember -Function 'CS-Authenticate'
Export-ModuleMember -Function 'TestFileName'
Export-ModuleMember -Function 'CS-Upload-Version'
Export-ModuleMember -Function 'CS-Nodes-ID-Name'
Export-ModuleMember -Function 'CS-Node-Download-version'
Export-ModuleMember -Function 'CS-Node-Download-version-ToFile'
Export-ModuleMember -Function 'CS-Node-Download-withoutSave'
Export-ModuleMember -Function 'CS-Upload'
Export-ModuleMember -Function 'Set-CScredentials'
Export-ModuleMember -Function 'SetVariable' 
Export-ModuleMember -Function 'GenerujFinalPathZFullName'
Export-ModuleMember -Function 'Remove-TextAfter'



