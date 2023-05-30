 param (
 [Parameter(Mandatory,  HelpMessage="Enter Library Name")][string]$TargetLibrary,
 [Parameter(HelpMessage="Enter Empty string or Folder Name ")][string]$TargerLibraryFolder,
 [Parameter(Mandatory, HelpMessage="Livelink URL prefix in format Enterprise:CORPORATE:Folder 1:Subfolder 2:")][string]$FolerPrefixNull,
 [Parameter(Mandatory, HelpMessage="Full sharepoint site collection URL")][string]$SiteURL,
 [Parameter(Mandatory, HelpMessage="Livelink folder ID. must match with URL prefix ")][int] $ParentIDSource, 
 [Parameter(Mandatory, HelpMessage="Maximum number of jobs ")][int]$NumberofJobs, 
 [Parameter(Mandatory, HelpMessage="Maximum number of jobs ")][bool]$MigrateVersions

)

<#
$TargetLibrary = "SomeDocumentLibrary"
$TargerLibraryFolder=""
$FolerPrefixNull="Enterprise:CORPORATE:subfolder:subfolder 1:"
$SiteURL="https://tenant.sharepoint.com/sites/sitename"
$ParentIDSource=785352
$NumberofJobs=1
$MigrateVersions=$false
#>


#variables
[string]$DB = "LivelinkPROD"
[string]$DBServerInstance= "SQLServer.domain.local" 
[string]$DBUser="DBUser"
[string]$DBPassword="somepassword"
[string]$CSUser = "admin"
[int]$CSType = 144
[string]$mutexName = "MutextLog1"
[string]$mutexName2 = "MutextLog2"


[string]$CSURL = "https://contentservername/OTCS/cs.exe/api/v1/" #idealy backend server in our case indexing server
 
#[string]$TargetLibrary = "TargetLibrary"
#[string]$TargerLibraryFolder = "" #"TargerLibraryFolder"
#[string]$FolerPrefixNull = "Enterprise:CORPORATE:TargerLibraryFolder:"
#[string]$SiteURL = "https://tenantname.sharepoint.com/sites/sitename/"




$secureStringPath = "C:\work\opentext\LLProd_password_Upload.txt"  # file to store secure string under current user context
 

#[int] $ParentIDSource = 70019  
[string]$logFileMain = "c:\work\shpLog_" + $ParentIDSource.ToString() + ".txt"
[string]$logFileMainexception = "c:\work\shpLog_exception_" + $ParentIDSource.ToString() + ".txt"


Import-Module c:\work\JS-Functions.psm1 -Force -Verbose  -ArgumentList ($CSType,$MutexName,$logFileMain,$CSURL,"##### Main")
Import-Module C:\work\LoggingFunction.psm1 -Force -Verbose


Initialize-Log -FilePath $logFileMain -NewMutex $MutexName
Initialize-Log -FilePath $logFileMainexception -NewMutex $MutexName2


Write-Log -FilePath $logFileMain -Level "Info" -Message "|Log Function loaded" -MutexName $MutexName 

Write-Log -FilePath $logFileMainexception  -Level "Error" -Message "|Log Function loaded" -MutexName $MutexName2 
      

##Region Login to content server
if ((Test-Path -Path $secureStringPath) -eq $false) # Test file with password 
{
    Set-CScredentials -secureStringPath $secureStringPath
}

try 
{
    $ticket=CS-Authenticate -CSURL $CSURL -CSUser $CSUser -SecureStringFile $secureStringPath # -verbose
    #LogWrite -logstring $ticket -LogFileFullPath $logFileMain
}
catch
{

    Write-Log -FilePath $logFileMain -Level "Error" -Message  "Error in funtion CS-Authenticate $($_.Exception.Message)"  -MutexName $MutexName 

    Exit -1
}

$ticket
#EndRegion Prihlaseni



#Function to Upload Large File to SharePoint Online Library
Function Upload-LargeFile($FilePath, $LibraryName, $FileChunkSize=10) #TODO not implemented
{

#Connect to SharePoint Online site
#Connect-PnPOnline "https://crescent.sharepoint.com/sites/marketing" -Interactive
#$Ctx = Get-PnPContext
 
#Call the function to Upload File
#Upload-LargeFile -FilePath "C:\Users\Thomas\Downloads\235021WFx64.rar" -LibraryName "Documents"


    Try {
        #Get File Name
        $FileName = [System.IO.Path]::GetFileName($FilePath)
        $UploadId = [GUID]::NewGuid()
 
        #Get the folder to upload
        $Library = $Ctx.Web.Lists.GetByTitle($LibraryName)
        $Ctx.Load($Library)
        $Ctx.Load($Library.RootFolder)
        $Ctx.ExecuteQuery()
 
        $BlockSize = $FileChunkSize * 1024 * 1024  
        $FileSize = (Get-Item $FilePath).length
        If($FileSize -le $BlockSize)
        {
            #Regular upload
            $FileStream = New-Object IO.FileStream($FilePath,[System.IO.FileMode]::Open)
            $FileCreationInfo = New-Object Microsoft.SharePoint.Client.FileCreationInformation
            $FileCreationInfo.Overwrite = $true
            $FileCreationInfo.ContentStream = $FileStream
            $FileCreationInfo.URL = $FileName
            $Upload = $Docs.RootFolder.Files.Add($FileCreationInfo)
            $ctx.Load($Upload)
            $ctx.ExecuteQuery()
        }
        Else
        {
            #Large File Upload in Chunks
            $ServerRelativeUrlOfRootFolder = $Library.RootFolder.ServerRelativeUrl
            [Microsoft.SharePoint.Client.File]$Upload
            $BytesUploaded = $null 
            $Filestream = $null
            $Filestream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $BinaryReader = New-Object System.IO.BinaryReader($Filestream)
            $Buffer = New-Object System.Byte[]($BlockSize)
            $LastBuffer = $null
            $Fileoffset = 0
            $TotalBytesRead = 0
            $BytesRead
            $First = $True
            $Last = $False
 
            #Read data from the file in blocks
            While(($BytesRead = $BinaryReader.Read($Buffer, 0, $Buffer.Length)) -gt 0)
            {  
                $TotalBytesRead = $TotalBytesRead + $BytesRead 
                If ($TotalBytesRead -eq $FileSize) 
                {  
                    $Last = $True
                    $LastBuffer = New-Object System.Byte[]($BytesRead)
                    [Array]::Copy($Buffer, 0, $LastBuffer, 0, $BytesRead)  
                }
                If($First) 
                {  
                    #Create the File in Target
                    $ContentStream = New-Object System.IO.MemoryStream
                    $FileCreationInfo = New-Object Microsoft.SharePoint.Client.FileCreationInformation
                    $FileCreationInfo.ContentStream = $ContentStream
                    $FileCreationInfo.Url = $FileName
                    $FileCreationInfo.Overwrite = $true
                    $Upload = $Library.RootFolder.Files.Add($FileCreationInfo)
                    $Ctx.Load($Upload)
 
                    #Start FIle upload by uploading the first slice
                    $s = new-object System.IO.MemoryStream(, $Buffer)  
                    $BytesUploaded = $Upload.StartUpload($UploadId, $s)
                    $Ctx.ExecuteQuery()  
                    $fileoffset = $BytesUploaded.Value  
                    $First = $False 
                }  
                Else
                {  
                    #Get the File Reference
                    $Upload = $ctx.Web.GetFileByServerRelativeUrl($Library.RootFolder.ServerRelativeUrl + [System.IO.Path]::AltDirectorySeparatorChar + $FileName);
                    If($Last) 
                    {
                        $s = [System.IO.MemoryStream]::new($LastBuffer)
                        $Upload = $Upload.FinishUpload($UploadId, $fileoffset, $s)
                        $Ctx.ExecuteQuery()
                        Write-Host "File Upload completed!" -f Green                        
                    }
                    Else
                    {
                        #Update fileoffset for the next slice
                        $s = [System.IO.MemoryStream]::new($buffer)
                        $BytesUploaded = $Upload.ContinueUpload($UploadId, $fileoffset, $s)
                        $Ctx.ExecuteQuery()
                        $fileoffset = $BytesUploaded.Value
                    }
                }
            }
        }
    }
    Catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    Finally {
        If($Filestream -ne $null)
        {
            $Filestream.Dispose()
        }
    }
}
 

  

Function LoadKuafData
{
    LogToJson -eventstring "Pripojuji do DB - KUAF data" -severity Low

    $KuafData = @{}

   $sql =  "SELECT   [ID],[MailAddress]   FROM [LivelinkPROD].[Livelink].[KUAF] where  [MailAddress] is not null " 

    $server =  $DBServerInstance
    $database = $DB
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$server;Database=$database;User Id=$DBUser;Password=$DBPassword;"
    Write-Host  $SqlConnection.ConnectionString
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $sql
    $SqlCmd.Connection = $SqlConnection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet
    $SqlAdapter.Fill($DataSet)
    $SqlConnection.Close()
   
   foreach ($d in  $DataSet.Tables[0])
     {
   
       $KuafData.Add($d.ID.ToString(),$d.MailAddress.ToString()) 

     }
     $DataSet.Dispose()
     LogToJson -eventstring "Ukoncuji dotaz do DB - KUAF data" -severity Low
return $KuafData

 
}



Function Get-DataForFolderStructure([int]$parentID)
{
   # $parentID = 1537165
 
   Write-Log -FilePath $logFileMain -Level "Info" -Message "|Pripojuji do DB - dtree data Get-DataForFolderStructure" -MutexName $MutexName 

#  $parentID = 3653879 



$sql = "select  distinct
 replace(replace([Livelink].[GetFullPath](DataID) + ':' + livelink.DTree.Name +':' ,'/','_'),'.:',':')  as onlyPath, LEN( replace([Livelink].[GetFullPath](DataID) + ':' + livelink.DTree.Name +':','/','_') ) as delka 
     from 
    livelink.DTree
    
  where 
  DataID in 
		(select DataID from [Custom_getChildren](1,$parentID))
and 
  (SubType=0)  
	order by 
	LEN( replace([Livelink].[GetFullPath](DataID) + ':' + livelink.DTree.Name +':','/','_') )"


    

    $server =  $DBServerInstance
    $database = $DB
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$server;Database=$database;User Id=$DBUser;Password=$DBPassword;"
  #  Write-Host  $SqlConnection.ConnectionString
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $sql
    $SqlCmd.Connection = $SqlConnection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet
    $rowCount=$SqlAdapter.Fill($DataSet)
    $SqlConnection.Close()
    Write-Log -FilePath $logFileMain -Level "Info" -Message "|Mam data z DB Folder structure|Pocet itemu k Zalozeni : $($DataSet.Tables[0].Rows.Count.ToString())" -MutexName $MutexName 

    return $DataSet.Tables[0]
}




Function Get-DataFromDBwithVersions([int]$parentID)
{
   # $parentID = 1537165
 
   Write-Log -FilePath $logFileMain -Level "Info" -Message "|Pripojuji do DB - dtree data" -MutexName $MutexName 


#  $parentID = 3653879 

    $sql = "select  
livelink.DTree.OwnerID , livelink.DTree.ParentID, livelink.DTree.DataID,DTree.SubType, dvers.FileName as Name, 
livelink.DTree.UserID, livelink.DTree.GroupID, livelink.DTree.CreatedBy, livelink.DTree.CreateDate,
dvers.VerCDate as CreateDate,
dvers.VerMDate as ModifyDate,  
dvers.*
  ,[Livelink].[GetFullPath](DataID) + ':' + dvers.FileName  as fullPath, SubType as typObjektu
     from 
    livelink.DTree
    
    left join Livelink.DVersData dvers on 
    dvers.DocID = DataID
    where (dvers.FileName <> '200x200-1.JPG' and dataID in (
		select  dt.DataID
		from Livelink.dtree as dt
		left join Livelink.KUAF kuafusers on
		dt.UserID = kuafusers.id
		left join Livelink.KUAF kuafgroups on 
		kuafgroups.ID = dt.GroupID

		left join Livelink.DVersData dvers on 
		(dt.DataID = dvers.DocID and dt.VersionNum = dvers.Version) 
		left join Livelink.ProviderData ProvData on 
		ProvData.providerID = dvers.ProviderId 
		where 
		( dt.SubType=144) and 
		 dt.DataID in 
		(select DataID from [Custom_getChildren](1,$parentID) 
	)))"
    

    $server =  $DBServerInstance
    $database = $DB
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$server;Database=$database;User Id=$DBUser;Password=$DBPassword;"
  #  Write-Host  $SqlConnection.ConnectionString
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $sql
    $SqlCmd.Connection = $SqlConnection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet
    $SqlAdapter.Fill($DataSet)
    $SqlConnection.Close()
    Write-Log -FilePath $logFileMain -Level "Info" -Message "|Mam data z DB|Pocet itemu k migraci : $($DataSet.Tables[0].Rows.Count.ToString())" -MutexName $MutexName 

    return $DataSet.Tables[0]

}



Function Get-DataFromDB([int]$parentID)
{
   # $parentID = 1537165
 
   Write-Log -FilePath $logFileMain -Level "Info" -Message "|Pripojuji do DB - dtree data" -MutexName $MutexName 




   $sql="select 
iif ((CHARINDEX('.',dt.name)>0), dt.name,dt.name + '.' +dvers.FileType) as Name, 
dt.Name as nameOLD,  
 replace(replace([Livelink].[GetFullPath](DataID) + ':','/','_'),'.:',':')  + (iif ((CHARINDEX('.',dt.name)>0), dt.name,dt.name + '.' +dvers.FileType)) as fullPath,

	  dt.OwnerID, dt.ParentID, dt.DataID, dt.CreatedBy,dt.CreateDate,dt.ModifiedBy,dt.ModifyDate, dt.MaxVers, dt.Reserved, dt.ReservedBy,dt.VersionNum,dt.SubType, 



     dt.SubType as typObjektu, 
    kuafusers.Name as dtreeKuafUser,
     kuafgroups.Name as dtreeKuafGroup,
    

    dvers.DataSize as dversFileSize, 
    dvers.FileName as dversFileName, 
    dvers.FileType as dversFileType, 
    dvers.MimeType as dversMimeType, 
    dvers.ProviderId as dversProviderData,
    ProvData.providerData as ProviderDataText

    from Livelink.dtree as dt
    left join Livelink.KUAF kuafusers on
    dt.UserID = kuafusers.id
    left join Livelink.KUAF kuafgroups on 
    kuafgroups.ID = dt.GroupID

    left join Livelink.DVersData dvers on 
    (dt.DataID = dvers.DocID and dt.VersionNum = dvers.Version) 
    left join Livelink.ProviderData ProvData on 
    ProvData.providerID = dvers.ProviderId 
    where 
    ((dt.SubType=749 or dt.SubType=144) and dvers.FileName <> '200x200-1.JPG') and      
    dt.DataID in 
    (select DataID from [Custom_getChildren](1, $parentID))"



    

    $server =  $DBServerInstance
    $database = $DB
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$server;Database=$database;User Id=$DBUser;Password=$DBPassword;"
  #  Write-Host  $SqlConnection.ConnectionString
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $sql
    $SqlCmd.Connection = $SqlConnection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet
    $SqlAdapter.Fill($DataSet)
    $SqlConnection.Close()
    Write-Log -FilePath $logFileMain -Level "Info" -Message "|Mam data z DB|Pocet itemu k migraci:$($DataSet.Tables[0].Rows.Count.ToString())" -MutexName $MutexName 

    return $DataSet.Tables[0]

}




#region CreateFolders

    Write-Log -FilePath $logFileMain -Level "Info"  -Message "|Main - Start|Creating folder structure" -MutexName $MutexName 
    $dataFolders = $null

    $dataFolders = Get-DataForFolderStructure -parentID $ParentIDSource



    $itemFolder = $null


    #$siteurl = "https://tenant.sharepoint.com/sites/site"

     $connection2 = Connect-PnPOnline   -ClientId "xxxx-xxxxx-x-xxxx-x-xxxxx"  `
         -Url  $siteurl `
         -Tenant "tenant.onmicrosoft.com"  `
         -Thumbprint "Thumbprint" `
         -ReturnConnection

     $currentcount=0 
     $vytvoreno = ""
     $CestaKvytvoreni  = $null
     $cestaSplit=$null


    foreach ($itemFolder in $dataFolders) 
    {
        $CestaKvytvoreni = $itemFolder.onlyPath.Replace($FolerPrefixNull,"")
    
        $CestaKvytvoreni  = $CestaKvytvoreni.Replace(":","/")

        if($CestaKvytvoreni -ne "")  #prvni je vetsinou root 
        {
    
         Write-Host "Vytvoreni folderu : $CestaKvytvoreni"
         Write-Log -FilePath $logFileMain -Level "Info"  -Message "|Main - Creating folder structure|Vytvoreni folderu : $($CestaKvytvoreni)" -MutexName $MutexName 
         
<#
            $CestaKvytvoreni = $CestaKvytvoreni.Substring(0,$CestaKvytvoreni.Length -1)

            $lastPart = $CestaKvytvoreni -split('([^\/]+$)')
            $lastPart = $lastPart[1] 


         if ($lastPart.Contains('#')) 
         {
           # $CestaKvytvoreni = $CestaKvytvoreni.Substring(0,$CestaKvytvoreni.Length -1)

          #  $lastPart = $CestaKvytvoreni -split('([^\/]+$)')
           # $lastPart = $lastPart[1] 


            $CestaKvytvoreni = $CestaKvytvoreni.Replace("/" + $lastpart,"")

            $CestaKvytvoreni = $CestaKvytvoreni +"/" +  $lastPart.Replace("#","_HASH_")


            Write-Host "LastPart :  $lastPart ; CestaKvytvoreni : $CestaKvytvoreni " -ForegroundColor Red
            
             Resolve-PnPFolder -SiteRelativePath "$(($TargetLibrary) + "/" + $CestaKvytvoreni + "/")" 
             Rename-PnPFolder -Folder "$($TargetLibrary + "/" + $CestaKvytvoreni)" -TargetFolderName $lastpart 

             $CestaKvytvoreniwithHash = $null

         }
         else
         {


             Resolve-PnPFolder -SiteRelativePath "$(($TargetLibrary) + "/" + $CestaKvytvoreni + "/")" 
         }

         #>


             $CestaKvytvoreni = $CestaKvytvoreni.Replace("#","_")
             $CestaKvytvoreni = $CestaKvytvoreni.Replace("%","_percent_")
             
             if ($TargerLibraryFolder -ne "") 
             {
                
                $CestaKvytvoreni =$TargerLibraryFolder  + $CestaKvytvoreni
             }


             Resolve-PnPFolder -SiteRelativePath "$(($TargetLibrary) + "/"  + $CestaKvytvoreni )" 


        }
           $CestaKvytvoreni = $null
 
    }


    $connection2 = $null
#endregion CreateFolders


$scriptBlockDownload =   {
   # Wait-Debugger 
    $intI = 0

    $guidPath = (New-Guid).Guid

     Import-Module 'c:\work\JS-Functions.psm1' -Force -Verbose -ArgumentList ($args[6],$args[5],$args[4],$args[1],$guidPath)   
     Import-Module 'C:\work\LoggingFunction.psm1' -Force -Verbose

      #($item,$CSURL,$CSUser,$secureStringPath,$logFileMain,$MutexName,$CSType,$TargetLibrary,$TargerLibraryFolder,$SiteURL,$FolerPrefixNull,$logFileMainexception,$true)
       
     
     #region threadVariables 

     $logFileMain = $args[4]
     $MutexName = $args[5]
     $TargetLibrary =$args[7]
     $TargerLibraryFolder =$args[8]

     $CSURL = $args[1] 
     $CSUser = $args[2]
     $secureStringPath =  $args[3]
     $FolerPrefixNull = $args[10]
     $logFileMainexception=$args[11]
     $versionsMigration=$args[12]

     $siteurl = $args[9]
     

     $item = $args[0]   


     



     Initialize-Log -FilePath $logFileMain -NewMutex  $MutexName 
     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread started|$($item.Name) "   -MutexName  $MutexName 
     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info logFileMain|$($logFileMain)"   -MutexName  $MutexName 
     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info MutexName|$($MutexName)"   -MutexName  $MutexName 
     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info TargetLibrary|$($TargetLibrary)"   -MutexName  $MutexName 

     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info TargerLibraryFolder|$($TargerLibraryFolder)"   -MutexName  $MutexName 
     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info CSURL|$($CSURL)"   -MutexName  $MutexName 
     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info secureStringPath|$($secureStringPath)"   -MutexName  $MutexName 
     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info FolerPrefixNull|$($FolerPrefixNull)"   -MutexName  $MutexName 
     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info FolerPrefixNull|$($FolerPrefixNull)"   -MutexName  $MutexName 
     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info versionsMigration|$($versionsMigration)"   -MutexName  $MutexName 

     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info siteurl|$($siteurl)"   -MutexName  $MutexName 
     Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|thread info item|$($item)"   -MutexName  $MutexName 
  
     New-Item -Path "c:\work\out\$guidPath" -ItemType Directory

      #endregion threadVariables 


     # $siteurl = "https://tenant.sharepoint.com/sites/sitename/"

     $connection = Connect-PnPOnline   -ClientId "xxxx-xxxx-xxxxx-x-xxxxx-x"  `
     -Url  $siteurl `
     -Tenant "-Tenant.onmicrosoft.com"  `
     -Thumbprint "certificatethumbprint" `
     -ReturnConnection

     $ticket=CS-Authenticate -CSURL $CSURL -CSUser $CSUser -SecureStringFile $secureStringPath  #Opravit
     
     Invoke-PnPQuery -RetryCount 10 -Connection $connection




     #region testConnection 


         if ( $connection.ConnectionType) 
         {
             Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|Connection OK"   -MutexName  $MutexName 
         }
          else
          {
             Write-Log -FilePath $logFileMainexception  -Level "Error" -Message "|$guidPath|Connection to Shp not exist" -MutexName $MutexName2 
             return
          }


     try {
         if (!($ticket))
         {
             throw "Opentext ticket is null"
         }
     }
     catch {
         Write-Log -FilePath $logFileMain -Level "Error" -Message "|Exception|$($item.Name)|$guidPath|$($Error[0].ToString())" -MutexName $MutexName 
         return
        }
     
     #endregion testConnection 

         $FileNameForSharepoint=TestFileName -FileName $item.Name

         if  ($versionsMigration -eq $true)
         {

             Write-Log -FilePath $logFileMain -Level "Info" -Message  "Generate Name |$($item.Name)|$($item.FileType)|$($item.MimeType)|$guidPath "   -MutexName  $MutexName

            $jmenoFileFinal = ""

            try {

                [string]$fileDate = ""
                $fileDate = ($item.VerMDate) | Get-Date -Format "_yyyy-MM-dd_"   # upravuju z $item.FileMDate na 



                $suffix = $null

                if ($item.FileType -eq "") 
                {
                  switch ($item.MimeType)  
                  {
                  "application/pdf" {$suffix="pdf" ;break;}
                  "application/vnd.openxmlformats-officedocument.wordprocessingml.document" {$suffix="docx" ;break;}
                  "image/pjpeg" {$suffix="jpg" ;break;}
                   default { Write-Log -FilePath $logFileMain -Level "Error" -Message  "Cant create suffix |$($item.Name)|$guidPath "   -MutexName  $MutexName }
                  }

                }
                else
                {
                  $suffix = $item.FileType
                }

                
             
                $jmenoFileFinal = $FileNameForSharepoint + "_" + $fileDate + "v_" + $item.Version.ToString() + "." + $suffix
                $FileNameForSharepoint =  $jmenoFileFinal

                Write-Log -FilePath $logFileMain -Level "Info" -Message  "Generate Name |JmenoFinal:$jmenoFileFinal|$guidPath "   -MutexName  $MutexName

            }
            catch {
                Write-Log -FilePath $logFileMain -Level "Error" -Message "Problem with creating Final FileName|$guidPath|$($Error[0].ToString())" -MutexName $MutexName 
                return
            }

         }



         $pouzeCesta= GenerujFinalPathZFullName -FullPath $item.fullPath -JmenoFile  $item.Name -TargetLibrary $TargetLibrary -TargerLibraryFolder $TargerLibraryFolder -FolerPrefixNull $FolerPrefixNull
       
         Write-Log -FilePath $logFileMain -Level "Info" -Message "|Procesing file|Full path :$($item.fullPath)|TargetLibrary:$TargetLibrary|FolderPrefixNUll:$FolerPrefixNull|Folder:$TargerLibraryFolder|itemName:$($item.Name)|vysledek z GenerujFinalPathZFullName:$pouzeCesta|$guidPath" -MutexName $MutexName 
        
        if ($pouzeCesta -eq "" -or $pouzeCesta -eq $null)
        {
             Write-Log -FilePath $logFileMain -Level "Error" -Message "GenerujFinalPathZFullName NULL|$guidPath|" -MutexName $MutexName 
            
            throw  "GenerujFinalPathZFullName is null or empty"
            return

        }

         $urlfinal = "/" +  $pouzeCesta

         $urlfinalProGetItems = $urlfinal.SubString(0,$urlfinal.Length-1)


        Write-Log -FilePath $logFileMain -Level "Info" -Message "|CreatingFolderStructure|PouzeCesta:$pouzeCesta|PouzeCestaProvytvareni:$pouzeCestaProVytvareni|$guidPath" -MutexName $MutexName 
      
        $topLevelRoot =  $TargetLibrary

 
       $pouzeCestaProVytvareni =  $pouzeCesta.Substring($topLevelRoot.Length + 1, $pouzeCesta.Length - $topLevelRoot.Length -1)

      
        $tmpFilesInFolder = $null
        try {
             Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Getting files in folder $($urlfinalProGetItems)" -MutexName $MutexName 
             $tmpFilesInFolder = Get-PnPFolderItem -FolderSiteRelativeUrl $urlfinalProGetItems  -ItemType File -Connection $connection
 
             Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Getting files in folder pocet items : $($tmpFilesInFolder.Count)" -MutexName $MutexName 
        }
        catch {
            Write-Log -FilePath $logFileMainexception  -Level "Error" -Message "|$guidPath|Exception in Get-PnPFolderItem|$($item.fullPath)|$($Error[0].ToString())" -MutexName $MutexName2 
        }


         if  ($versionsMigration -eq $true)
         {
        
          $modFields =  @{Created=$item.CreateDate; Modified=$item.ModifyDate;Title=$jmenoFileFinal;Author=$createdby;Editor=$modifiedBy;}
         }
         else
         {
            $modFields =  @{Created=$item.CreateDate; Modified=$item.ModifyDate;Title=$item.Name;Author=$createdby;Editor=$modifiedBy;}
         }

         Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Prepare ModFields|$($item.fullPath)" -MutexName $MutexName 

         if ($tmpFilesInFolder) {      #podaril se GET nad knihovnou  a folderem 
              Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Podaril se GET nad knihovnou  a folderem|$($item.fullPath)" -MutexName $MutexName 

             if (!$tmpFilesInFolder.Name.Contains($FileNameForSharepoint))  #Pokud neexistuje soubor v final dokumentove knihovne nahraj 
             {
                Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Stahuji soubor $($item.Name)" -MutexName $MutexName 
                Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Pouze cesta pro urceni final path $pouzeCesta" -MutexName $MutexName 


                 try {
                    # $x = CS-Node-Download-withoutSave -ticket $ticket -nodeid $item.DataID -CSURL $CSURL 
                    $jmenoFile = "c:\work\out\$guidPath" +"\" + $FileNameForSharepoint
                   
                        if  ($versionsMigration -eq $true)
                         {
                                  #[string]$ticket = $(throw "need"),
		                           # [string]$nodeid,
		                           #[string]$verNumber,
 		                           # [string]$CSURL,
                                   # [string]$FileOut   
                               CS-Node-Download-version-ToFile  -ticket $ticket -nodeid $item.DataID -verNumber $item.Version.ToString() -CSURL $CSURL -FileOut $jmenoFile 
                          }
                          else
                          {    
                                CS-Node-Download -ticket $ticket -nodeid $item.DataID -CSURL $CSURL -FileOut  $jmenoFile 
                          }

                     #$jmenoFile = "c:\work\out\" + $FileNameForSharepoint
                     #Set-Content -path  $jmenoFile -Value $x.Content -AsByteStream 
                 }
                 catch {
                     Write-Log -FilePath $logFileMain -Level "Error" -Message "|Download se nezdaril|$($item.DataID)|$($Error[0].ToString())|removeItem|$guidPath" -MutexName $MutexName    
                     Write-Log -FilePath $logFileMainexception  -Level "Error" -Message "|$guidPath|Download se nezdaril|$($item.DataID)|$($Error[0].ToString())" -MutexName $MutexName2 
                     
                     Remove-Item -Path "c:\work\out\$guidPath" -Force -Recurse
                     return     
                     }

                      $createdby = "SuperAdmin@tenant.onmicrosoft.com"


                     if (Test-Path -LiteralPath $jmenoFile) # Podarilo se stahnout File
                     {
                         $modifiedBy = "SuperAdmin@tenant.onmicrosoft.com"
                         Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|Soubor v cilove knihovne nenalezen, ukladame znovu, soubor existuje na FS|$($FileNameForSharepoint)" -MutexName $MutexName 
                         try {
                            Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload Start|$pouzeCesta|$jmenoFile" -MutexName $MutexName 
                          
                            
                            $result = $null
                            $chybakopie = $true

                            for ($num = 1 ; ($num -le 10) -and ($chybakopie -eq $true); $num++)
                            
                            {    
                              Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload starting n=$($num.tostring())|$jmenoFile" -MutexName $MutexName
                             
                             
                             try {
                              $result= Add-PnPFile -Path $jmenoFile -Folder $pouzeCesta -Values $modFields -Connection $connection -ErrorAction SilentlyContinue #-Verbose  
                              }
                              catch
                              {
                               #toto asi nenastane 
                               Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload trycatchError |$(Get-Error -newest 5)|$jmenoFile" -MutexName $MutexName
                              }
 
                              if (-not $result) 
                              {
                                    $chybakopie = $true
                                    Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload result not set, start SLEEP|$jmenoFile" -MutexName $MutexName
                                    Start-Sleep -Seconds 5
                              }
                              else 
                              {
                                    Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload result $($result.ToString())|$jmenoFile" -MutexName $MutexName
                                    $chybakopie = $false
                              }

                            }
                                if($result){
                                    Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload done|$($result.ToString())" -MutexName $MutexName
                                    Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload done|$($result.Path.Identity.ToString())" -MutexName $MutexName
                                }
                                else
                                {

                                     Write-Log -FilePath $logFileMain -Level "Error" -Message "|$guidPath|Upload Error|$($_.Exception.Message)" -MutexName $MutexName
                                     Write-Log -FilePath $logFileMain -Level "Error" -Message "|$guidPath|Upload Error|$((Get-PnPException).message)|$($(Get-PnPException).stacktrace)|" -MutexName $MutexName

                                     throw "Upload Error|$jmenoFile|$pouzeCesta"
                                }

                            }
                            catch {
                                Write-Log -FilePath $logFileMainexception  -Level "Error" -Message  "|Upload se nezdaril|removeItem|$jmenoFile|$($_.Exception.Message)|$(Get-PnPException)|$(Get-Error -newest 5)|$guidPath" -MutexName $MutexName2
                
                                Remove-Item -Path "c:\work\out\$guidPath" -Recurse -Force 
                                return
                            }

                          Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|RemoveFolder And Item, END|$($result.Path.Identity.ToString())" -MutexName $MutexName
                          Remove-Item -Path $jmenoFile -Force
                          Remove-Item -Path "c:\work\out\$guidPath" -Force 

                     }
                     else { #neni stazeny soubor z LL 
                         Write-Log -FilePath $logFileMain -Level "Error" -Message "|$guidPath|Problem with reading file from disk, continue with next, END|RemoveItem|$($jmenoFile) " -MutexName $MutexName 
                         Remove-Item -Path "c:\work\out\$guidPath" -Force 
                         return  # Konec procesovani Itemu 
                     }
             } # endif Pokud neexistuje soubor v final dokumentove knihovne nahraj 
             else {  # else Pokud neexistuje soubor v final dokumentove knihovne nahraj 
                Write-Log -FilePath $logFileMain -Level "Error" -Message "|$guidPath|File already in library exiting|RemoveFolder, END|$($FileNameForSharepoint)" -MutexName $MutexName 
                Remove-Item -Path "c:\work\out\$guidPath" -Force 
              return
             } #podaril se GET nad knihovnou 

         }   #end podaril se GET nad knihovnou  

         else {  # nepodaril se get nad knihovnou a folderem jedeme full upload vcetne folderu 
             
            Write-Log -FilePath $logFileMain -Level "Info" -Message  " |$guidPath|nepodaril se get nad knihovnou a folderem jedeme full upload vcetne folderu|$($item.Name.ToString())" -MutexName $MutexName          
            Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Compute Path for final path|$($pouzeCesta)" -MutexName $MutexName 

            try {
                  Write-Log -FilePath $logFileMain -Level "Info" -Message  "|$guidPath|Download data from LL|$($item.Name.ToString())" -MutexName $MutexName          
         
                $jmenoFile = "c:\work\out\$guidPath" + "\" + $FileNameForSharepoint
              




                         if  ($versionsMigration -eq $true)
                         {
                               CS-Node-Download-version-ToFile  -ticket $ticket -nodeid $item.DataID -verNumber $item.Version.ToString() -CSURL $CSURL -FileOut $jmenoFile
                          }
                          else
                          {    
                                CS-Node-Download -ticket $ticket -nodeid $item.DataID -CSURL $CSURL -FileOut $jmenoFile 
                          }






                           #CS-Node-Download -ticket $ticket -nodeid $item.DataID -CSURL $CSURL -FileOut $jmenoFile 

                           # $jmenoFile = "c:\work\out\" + $FileNameForSharepoint
                          #  Set-Content -path  $jmenoFile -Value $x.Content -AsByteStream 
            
            }
            catch {
                Write-Log -FilePath $logFileMain -Level "Error" -Message "|$guidPath|Download z LL se nezdaril|$($item.DataID)|$($Error[0].ToString())|$guidPath" -MutexName $MutexName  
                Write-Log -FilePath $logFileMainexception  -Level "Error" -Message  "|$guidPath|Download se nezdaril|$($item.DataID)|$($_.Exception.Message)" -MutexName $MutexName2
                Write-Log -FilePath $logFileMain -Level "Info" -Message "|RemoveFolder|$guidPath" -MutexName $MutexName
           
                Remove-Item -Path "c:\work\out\$guidPath" -Force 

                return
               }

     
              $createdby = "SuperAdmin@tenant.onmicrosoft.com"


        try {
            if ((Test-Path  $jmenoFile) -eq $false) 
                {
                   throw "File not found in tmp folder."
                }

        }
        catch {
            Write-Log -FilePath $logFileMain -Level "Error" -Message "|$guidPath|Exception END|$($jmenoFile)|RemoveFolder|$($_.Exception.Message)" -MutexName $MutexName 
            Write-Log -FilePath $logFileMainexception  -Level "Error" -Message  "|$guidPath|Exception|$($jmenoFile)|RemoveFolder|$($_.Exception.Message)" -MutexName $MutexName2
            Remove-Item -Path "c:\work\out\$guidPath" -Force 
            return
        }


           $modifiedBy = "SuperAdmin@tenant.onmicrosoft.com"

 
        try {
           Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload start|$($FileNameForSharepoint.ToString())|$pouzeCesta|$jmenoFile|$guidPath" -MutexName $MutexName 
           


           
         if  ($versionsMigration -eq $true)
         {
        
          $modFields =  @{Created=$item.CreateDate; Modified=$item.ModifyDate;Title=$jmenoFileFinal;Author=$createdby;Editor=$modifiedBy;}
         }
         else

         {
            $modFields =  @{Created=$item.CreateDate; Modified=$item.ModifyDate;Title=$item.Name;Author=$createdby;Editor=$modifiedBy;}
         }


          
            Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload start 2|$($item.CreateDate)|$($item.ModifyDate)|$($item.Name)|$($createdby)|$($modifiedBy)|$($FileNameForSharepoint.ToString())|$pouzeCesta|$jmenoFile" -MutexName $MutexName 
          
            Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload start 3|$connection.Tostring()|$($FileNameForSharepoint.ToString())|$pouzeCesta|$jmenoFile|$guidPath" -MutexName $MutexName 
          
       #31.01    if ((Test-Path  $jmenoFile) -eq $false) 
       #31.01           {
       #31.01            Write-Log -FilePath $logFileMain -Level "Error" -Message "|Upload start 4|soubor nenalezen|$pouzeCesta|$jmenoFile|$guidPath" -MutexName $MutexName 
        #31.01    
       #31.01           }
            
            $result = $null
           

         
                            $chybakopie = $true

                            for ($num = 1 ; ($num -le 10) -and ($chybakopie -eq $true); $num++)
                            
                            {    
                              Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload starting N=$($num.tostring())|$jmenoFile" -MutexName $MutexName
                              try {
                                $result= Add-PnPFile -Path $jmenoFile -Folder $pouzeCesta -Values $modFields -Connection $connection -ErrorAction SilentlyContinue #-Verbose  
                              }
                              catch
                              {
                                   #Toto asi nenastane
                                   Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload trycatchError |$(Get-Error -newest 5)|$jmenoFile" -MutexName $MutexName
                              }



                             # Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload Result $($result.ToString())|$jmenoFile" -MutexName $MutexName 
                               if (-not $result) 
                              {
                                     $chybakopie = $true
                                     Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload result not set sleep 5|$jmenoFile" -MutexName $MutexName
                                     Start-Sleep -Seconds 5
                     
                              }
                              else 
                              { 
                                 Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload result $($result.ToString())|ElseChyba|$jmenoFile" -MutexName $MutexName
                                 $chybakopie = $false
                              }

                            
                            }


         

           
            if($result){
                Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload done|$($result.ToString())" -MutexName $MutexName
                Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Upload done|$($result.Path.Identity.ToString())" -MutexName $MutexName
            }
            else
            {
                 Write-Log -FilePath $logFileMain -Level "Error" -Message "|$guidPath|Upload Error|$($_.Exception.Message)" -MutexName $MutexName
                 Write-Log -FilePath $logFileMain -Level "Error" -Message "|$guidPath|Upload Error|$((Get-PnPException).message)|$($(Get-PnPException).stacktrace)|" -MutexName $MutexName

                 throw "Upload Error|$jmenoFile|$pouzeCesta"
            }


            
            }
            catch {
                Write-Log -FilePath $logFileMainexception  -Level "Error" -Message  "|$guidPath|Upload se nezdaril, V casti s adresarema|$jmenoFile|$($_.Exception.Message)|$(Get-PnPException)|$(Get-Error)" -MutexName $MutexName2
            }

            Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|RemoveFolder And Item Final" -MutexName $MutexName
           
            Remove-Item -Path $jmenoFile -Force
            Remove-Item -Path "c:\work\out\$guidPath" -Force 
            Write-Log -FilePath $logFileMain -Level "Info" -Message "|$guidPath|Processing complete|$($item.Name)" -MutexName $MutexName 

        }
}


#Variables

#$NumberofJobs = 8


Write-Log -FilePath $logFileMain -Level "Info"  -Message "Pripojuji do Azure tenant:$($connection.Tenant)" -MutexName $MutexName 


    if ($MigrateVersions -eq $true) 
    {
        
        $data = Get-DataFromDBwithVersions -parentID $ParentIDSource
    }
    else
    {
        $data = Get-DataFromDB -parentID $ParentIDSource
    }




$item = $null

foreach ($item in $data) 
{
    #Region variables cleanup 
        $urlfinal = $null 
        $pouzeCesta = $null
        $modFields = $null
        $urlfinalProGetItems = $null
        $jmenoFile = $null
        $ticket= $null
    #EndRegion

    [string]$FileNameForSharepoint
    $FileNameForSharepoint=$item.Name
   
    Write-Host $item.fullPath
  #  $item  = $null  # testing only 

    try {
        if ((!($item.fullPath)) -or (!($item)))
        {
            throw "FullPath or item is null"
        }
    }
    catch {
        Write-Log -FilePath $logFileMain -Level "Warning" -Message "Exception|$($Error[0].ToString())" -MutexName $MutexName 
        continue
    }
 
            
        Write-Log -FilePath $logFileMain -Level "Info" -Message "Processing file Main|$($item.Name.ToString())|$($item.fullPath.ToString())" -MutexName $MutexName 


        #write-host ($item.DataID, $item.Name, $item.SubType)


        try {
            if ($item.SubType -ne 144 -and $item.SubType -ne 749)
                {
                    throw "Not subtype 144 or 749, continue to next"
                } 
        }
        catch {
            Write-Log -FilePath $logFileMain -Level "Info" -Message "|Item is Folder|$($Error[0].ToString())" -MutexName $MutexName 
            continue
        }

        Write-Host ("DataID:$($item.DataID)")

        #Call script block 

        $executed = $false
        do {
           
             if ( ((get-job -State Running).count) -le ($NumberofJobs + 1))
             {

                $executed = $true
               
            if ($MigrateVersions -eq $true) 
            { 
    
                $job = Start-Job -Name $item.DataID -ScriptBlock $scriptBlockDownload -ArgumentList ($item,$CSURL,$CSUser,$secureStringPath,$logFileMain,$MutexName,$CSType,$TargetLibrary,$TargerLibraryFolder,$SiteURL,$FolerPrefixNull,$logFileMainexception,$true)
              }
              else
              {

                $job = Start-Job -Name $item.DataID -ScriptBlock $scriptBlockDownload -ArgumentList ($item,$CSURL,$CSUser,$secureStringPath,$logFileMain,$MutexName,$CSType,$TargetLibrary,$TargerLibraryFolder,$SiteURL,$FolerPrefixNull,$logFileMainexception,$false)

              }
                
                
                #debug-job -Job $job
                #Wait-Debugger


            }
            remove-job -State Completed
            Start-Sleep -Seconds 1
        } while ( $executed -eq $false )

}


do {
    write-host "------------------------------------------------------------------------------------"
    get-job -State Running   
    Start-Sleep -Seconds 1

  } while (((get-job -State Running).count) -ne 0 )

    remove-job -State Completed
    Write-Log -FilePath $logFileMain -Level "Info" -Message "Konec" -MutexName $MutexName 