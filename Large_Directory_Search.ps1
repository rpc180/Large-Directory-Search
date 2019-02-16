$startscript = get-date
$shortdate = get-date -format MM-dd-yy
$systemrunning = hostname
$shortdate = get-date -format MM-dd-yy
$runpath = get-location
$runlog = $runpath.path+"\runlog_"+$shortdate+".txt"

Write-output "Starting script at $startscript" | Tee-object -filepath $runlog
Write-output "log file location: $logfile" | Tee-Object -filepath $runlog -append
Write-output "This script is executing on $systemrunning" | Tee-Object -filepath $runlog -append
Write-output "in directory $runpath"

$erroractionpreference = "continue"
$sizearray = @()
$summaryarray = @()


Function Get-FolderSize {
  PROCESS{
  $path = $_.fullname
  $size = (get-childitem $path -recurse | measure-object -property length -sum).sum
  $lastaccess = ($_.lastaccesstime).ToString("yyyy-MM-dd")
  If ( $size -ge 10mb )
  {
  $path = ($path -replace "\\", "/")
  $path = ($path -replace "\(", "{")
  $path = ($path -replace "\)", "}")
  $path = ($path -replace "\]", ">")
  $path = ($path -replace "\[", "<")
  $newobj = [PSCustomObject]@{‘Name’ = $path;’Size’ = [decimal]$size ; 'LastAccess' = $lastaccess }
  $global:sizearray += $newobj
  $outtxt = $sizearray[-1]
  write-output "ADDED: $outtxt"
  }
  }
}


$target = read-host -prompt 'Path to search (Examples: C:\ or D:\DirName)'
$cutoff = read-host -prompt 'Size of folders to return (in MB)'
$readablecriteria = "{0:N2}" -f [int]$cutoff


write-output "
GATHERING DIRECTORIES
" | tee-object $runlog -append
get-childitem $target -recurse | where-object { $_.PSIsContainer } | get-foldersize | tee-object $runlog -append


$tempsize = $NULL
foreach ( $line in $sizearray ) { $tempsize += $line.size }
$tempsize = "{0:N2}" -f ($tempsize/1mb)+" MB"


write-output "
RAW POPULATED ARRAY Total Elements: $($sizearray.length) Total Size: $tempsize
" | tee-object $runlog -append
$sizearray | ft size,name | tee-object $runlog -append


write-output "
NAME SORT, BEFORE SUBDIRECTORY SIZE REDUCTION Total Elements: $($sizearray.length) Total Size: $tempsize
"  | tee-object $runlog -append
$sizearray = $sizearray | sort name -descending
$sizearray | ft size,name | tee-object $runlog -append


write-output "
SUBDIRECTORY SIZE DEDUPLICATION
" | tee-object $runlog -append
For ($child=0;$child-lt$SizeArray.Length;$child++){
  For ($parent=($child+1);$parent-lt$SizeArray.Length;$parent++){
  If ($SizeArray[$child].Name -match ($SizeArray[$parent].Name+"/")){
  $SizeArray[$parent].size -= $SizeArray[$child].size
  }
  }
}


$tempsize = $NULL
foreach ( $line in $sizearray ) { $tempsize += $line.size }
$tempsize = "{0:N2}" -f ($tempsize/1mb)+" MB"
Write-output "
Total Elements: $($sizearray.length) Total Size: $tempsize
" | tee-object $runlog -append


$sizearray | ft size,name | tee-object $runlog -append
$totalsize = $NULL
$qualrank = $NULL


$sizearray = $sizearray | sort size -Descending | tee-object $runlog -append


write-output "
OUTPUTTING PATHS OVER $readablecriteria MB TO SCREEN AND RUNLOG
" | tee-object $runlog -append


write-output "Size|LastAccess|Path" | tee-object -filepath $runlog -append


foreach ( $line in $sizearray ) {
  if ( $line.size/1mb -gt $cutoff ) {
  $global:totalsize += $line.size
  $qualrank ++
  $qualdir = ($line.name -replace "/", "\")
  $qualdir = ($qualdir -replace "{", "(")
  $qualdir = ($qualdir -replace "}", ")")
  $qualdir = ($qualdir -replace ">", "]")
  $qualdir = ($qualdir -replace "<", "[")
  $qualsize = "{0:N2}" -f ($line.size/1mb)
  $quallastaccess = $line.lastaccess
  $qualobj = [PSCustomObject]@{ ’Size’ = $qualsize+" MB"; 'LastAccess' = $quallastaccess; ‘Name’ = $qualdir; 'Rank' = $qualrank }
  $global:summaryarray += $qualobj
  write-output $qualsize"|"$quallastaccess"|"$qualdir | tee-object $runlog -append
  }
}


$totalsize = "{0:N2}" -f ($totalsize/1mb)
write-output "
Total elements $($summaryarray.length) Total size $totalsize MB
" | tee-object $runlog -append


$summaryarray | sort-object rank | ft Size, Name, Rank | tee-object $runlog -append