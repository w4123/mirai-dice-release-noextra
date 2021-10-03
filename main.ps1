﻿$JreURL = "https://download.fastgit.org/w4123/mirai-dice-release-noextra/releases/download/dep/OpenJDK11U-Windows-x86.zip"
$GitURL = "https://download.fastgit.org/w4123/mirai-dice-release-noextra/releases/download/dep/MinGit-Windows-x86.zip"

$JAVA = ""
$GIT = ""

if ($PSVersionTable.PSVersion.Major -Le 2)
{
    Write-Host "Powershell版本过旧，程序可能无法正常运行，但程序将尝试继续运行。请升级WMF，详见论坛。" -ForegroundColor red
    Read-Host -Prompt "按回车键继续 ----->" 
}

if (!$PSScriptRoot)
{
	$PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

cd "$PSScriptRoot"

function DownloadFile($url, $targetFile)
{
   [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
   $uri = New-Object "System.Uri" "$url"
   $request = [System.Net.HttpWebRequest]::Create($uri)
   $request.set_Timeout(15000) #15 second timeout
   $response = $request.GetResponse()
   $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
   $responseStream = $response.GetResponseStream()
   $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
   $buffer = new-object byte[] 256KB
   $count = $responseStream.Read($buffer,0,$buffer.length)
   $downloadedBytes = $count
   while ($count -gt 0)
   {
       $targetStream.Write($buffer, 0, $count)
       $count = $responseStream.Read($buffer,0,$buffer.length)
       $downloadedBytes = $downloadedBytes + $count
       Write-Progress -activity "正在下载文件 '$($url.split('/') | Select -Last 1)'" -Status "已下载 ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
   }
   Write-Progress -activity "文件 '$($url.split('/') | Select -Last 1)' 下载已完成" -Status "下载已完成" -Completed
   $targetStream.Flush()
   $targetStream.Close()
   $targetStream.Dispose()
   $responseStream.Dispose()
}

Write-Host "Mirai Dice 启动脚本"
Write-Host "初始化"

if (-Not (Test-Path -Path "$PSScriptRoot\.git" -PathType Container))
{
	Write-Host "警告：.git文件夹不存在" -ForegroundColor red
	Write-Host "这可能代表你未使用正确方式安装此程序" -ForegroundColor red
	Write-Host "虽然大多数功能仍将正常工作，但更新功能将无法正常使用" -ForegroundColor red
	Write-Host "请尝试使用正确方式重新安装以解决此问题" -ForegroundColor red
}

Try 
{
	Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
	function Unzip
	{
		param([string]$zipfile, [string]$outpath)

		[System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
	}
}
Catch {
	if (-Not (Test-Path -Path "$PSScriptRoot\unzip.exe" -PathType Leaf))
	{
		$ZipURL = "https://download.fastgit.org/w4123/mirai-dice-release-noextra/releases/download/dep/unzip.exe"
		DownloadFile $ZipURL "$PSScriptRoot\unzip.exe"
	}
	
	if (-Not (Test-Path -Path "$PSScriptRoot\unzip.exe" -PathType Leaf))
	{
		Write-Host "无法加载Unzip" -ForegroundColor red
		Exit
	}
	
	function Unzip
	{
		param([string]$zipfile, [string]$outpath)

		& .\unzip.exe $zipfile -d $outpath
	}
}


Write-Host "检测Java"

Try 
{
	$Command = Get-Command -Name java -ErrorAction Stop
	if (($Command | Select-Object -ExpandProperty FileVersionInfo | Select-Object ProductMajorPart).ProductMajorPart -ge 11)
	{
		$JAVA = "java"
	}
}
Catch {}

Try {
	$Command = Get-Command -Name "$PSScriptRoot\jre\bin\java" -ErrorAction Stop
	if (($Command | Select-Object -ExpandProperty FileVersionInfo | Select-Object ProductMajorPart).ProductMajorPart -ge 11)
	{
		$JAVA = "$PSScriptRoot\jre\bin\java"
	}
}
Catch {}

if ($JAVA -eq "")
{
	DownloadFile $JreURL "$PSScriptRoot\java.zip"
	Remove-Item "$PSScriptRoot\jre\" -Recurse -ErrorAction SilentlyContinue
	Unzip "$PSScriptRoot\java.zip" "$PSScriptRoot\jre\"
	Remove-Item "$PSScriptRoot\java.zip" -ErrorAction SilentlyContinue
	Try 
	{
		$Command = Get-Command -Name "$PSScriptRoot\jre\bin\java" -ErrorAction Stop
		if (($Command | Select-Object -ExpandProperty FileVersionInfo | Select-Object ProductMajorPart).ProductMajorPart -ge 11)
		{
			$JAVA = "$PSScriptRoot\jre\bin\java"
		}
	}
	Catch 
	{
		Write-Host "无法加载Java!" -ForegroundColor red
		Exit
	}
}



Write-Host "Java: $JAVA" -ForegroundColor green
Write-Host "检测Git"

Try 
{
	$Command = Get-Command -Name git -ErrorAction Stop
	$GIT = "git"
}
Catch {}

Try 
{
	$Command = Get-Command -Name "$PSScriptRoot\git\cmd\git" -ErrorAction Stop
	$GIT = "$PSScriptRoot\git\cmd\git"
}
Catch {}

if ($GIT -eq "")
{
	DownloadFile $GitURL "$PSScriptRoot\git.zip"
	Remove-Item "$PSScriptRoot\git\" -Recurse -ErrorAction SilentlyContinue
	Unzip "$PSScriptRoot\git.zip" "$PSScriptRoot\git\"
	Remove-Item "$PSScriptRoot\git.zip" -ErrorAction SilentlyContinue
	Try 
	{
		$Command = Get-Command -Name "$PSScriptRoot\git\cmd\git" -ErrorAction Stop
		$GIT = "$PSScriptRoot\git\cmd\git"
	}
	Catch 
	{
		Write-Host "无法加载Git!" -ForegroundColor red
		Exit
	}
}

Write-Host "Git: $GIT" -ForegroundColor green

if (($args[0] -eq "--update") -or ($args[0] -eq "-u"))
{
	& "$GIT" fetch --depth=1
	& "$GIT" reset --hard origin/master
	Write-Host "更新操作已执行完毕" -ForegroundColor green
}
elseif (($args[0] -eq "--revert") -or ($args[0] -eq "-r"))
{
	& "$GIT" reset --hard "HEAD@{1}"
	Write-Host "回滚操作已执行完毕" -ForegroundColor green
}
elseif (($args[0] -eq "--fullautoslider") -or ($args[0] -eq "-f")) 
{
	del -Path "$PSScriptRoot\plugins\mirai-automatic-slider*"
	del -Path "$PSScriptRoot\plugins\mirai-login-solver-selenium*"
	copy -Path "$PSScriptRoot\fslider\mirai-automatic-slider*" "$PSScriptRoot\plugins\"
	& "$JAVA" -jar mcl.jar
}
elseif (($args[0] -eq "--autoslider") -or ($args[0] -eq "-a")) 
{
	del -Path "$PSScriptRoot\plugins\mirai-automatic-slider*"
	del -Path "$PSScriptRoot\plugins\mirai-login-solver-selenium*"
	copy -Path "$PSScriptRoot\slider\mirai-login-solver-selenium*" "$PSScriptRoot\plugins\"
	& "$JAVA" -jar mcl.jar
}
elseif (($args[0] -eq "--slider") -or ($args[0] -eq "-s")) 
{
	del -Path "$PSScriptRoot\plugins\mirai-automatic-slider*"
	del -Path "$PSScriptRoot\plugins\mirai-login-solver-selenium*"
	& "$JAVA" "-Dmirai.slider.captcha.supported" "-jar" "mcl.jar"
}
else
{
	del -Path "$PSScriptRoot\plugins\mirai-automatic-slider*"
	del -Path "$PSScriptRoot\plugins\mirai-login-solver-selenium*"
	& "$JAVA" -jar mcl.jar
}

