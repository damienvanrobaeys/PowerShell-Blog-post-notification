$ProgData = $env:PROGRAMDATA
$SD_Blog_News_Folder = "$ProgData\SD_Blog_News"
$XML_File = "$SD_Blog_News_Folder\Blogs_List.xml"
$User_Profile = $env:USERPROFILE
$User_Desktop = [Environment]::GetFolderPath("Desktop")
$Resume_Post_TXT = "$User_Desktop\New_Blog_Posts.txt"
$Blogs_List_XML = [xml] (get-content $XML_File)
$Blog_to_check = $Blogs_List_XML.Blogs.Blog 
$Config = $Blogs_List_XML.Blogs.Config
$Days_To_Check = $Config.DateToCheck
$Notification_Type = $Config.Notification
$Current_Date = (Get-Date).adddays(-$Days_To_Check)
$Export_Date = Get-Date -format 'd MMM yyyy'

If ($Notification_Type -eq "WindowsNotif")
	{
		[reflection.assembly]::loadwithpartialname("System.Windows.Forms")
		[reflection.assembly]::loadwithpartialname("System.Drawing")	
		$path = Get-Process -id $pid | Select-Object -ExpandProperty Path            		
		$icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)  
		$notify = new-object system.windows.forms.notifyicon
		$notify.icon = $icon
		$notify.visible = $true	
	}
ElseIf ($Notification_Type -eq "BurntToast")
	{
		Install-Module BurntToast 
	}
	
If (test-path $Resume_Post_TXT)
	{
		remove-item $Resume_Post_TXT -force	
	}
	
new-item $Resume_Post_TXT -type file
Add-content $Resume_Post_TXT $Export_Date
Add-content $Resume_Post_TXT "--------------------------"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

ForEach ($Blog in $Blog_to_check)
	{
		$Blog_Name = $Blog.Name
		$Blog_Path = $Blog.Path
		$Blog_RSS = $Blog.RSS	
		$Blog_Logo = $Blog.Logo	
		$Full_Logo_Path = "$SD_Blog_News_Folder\logos"
		
		If ($Blog_Logo -eq "")
			{
				$Blog_Logo = "SD.jpg"			
			}			
		$Current_Logo = "$Full_Logo_Path\$Blog_Logo"

		Try
			{
				$Get_Site_RSS = Invoke-RestMethod $Blog_RSS				
				$Get_Site_Infos = ForEach ($RSS_Value in $Get_Site_RSS) 
					{
						$Post_Title = $RSS_Value.title
						$Post_Date = $RSS_Value.pubdate
						$Post_Link = $RSS_Value.link							
					
						$Global:Get_Site_Infos = @{
						'Title' = $Post_Title
						'Link' = $Post_Link
						'Publish_Date' = $Post_Date
						}
						New-Object -Type PSObject -Property $Get_Site_Infos			
					}		
					
					
				ForEach ($infos in $Get_Site_Infos)
					{				
						[datetime]$Post_Date_Infos = $infos.Publish_Date
						$Infos_Post_Title = $infos.Title
						$Infos_Post_Link = $infos.Link

						# If (($Current_Date - $Post_Date_Infos).TotalHours -lt 300) 												
						If (($Current_Date -lt $Post_Date_Infos)) 						
							{
								Add-content $Resume_Post_TXT $Infos_Post_Link
								If ($Notification_Type -eq "WindowsNotif")
									{
										$title = "New post on: $Blog_Name"								
										$message = "$Infos_Post_Title"							
										$notify.showballoontip(10,$title,$Message,[system.windows.forms.tooltipicon]::info)	
									}
								ElseIf ($Notification_Type -eq "BurntToast")
									{
										New-BurntToastNotification  -Text "New post on: $Blog_Name", $Infos_Post_Title -applogo $Current_Logo	
									}
								ElseIf ($Notification_Type -eq "WPF")
									{
										cd $SD_Blog_News_Folder
										powershell -sta -windowstyle hidden ".\WPF_notif.ps1" -Title "'$Infos_Post_Title'"  -Link "'$Infos_Post_Link'" -Name "'$Blog_Name'" -Logo "'$Current_Logo'" 									
									}									
							}					
					}										
			}
		Catch
			{}	
	}
	
If ($Notification_Type -eq "WindowsNotif")
	{
		If (($notify.visible) -eq $true)
			{
				$notify.dispose()
			}
	}	