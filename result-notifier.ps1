$interval = 300
$resultPath = 'C:\YOUR_PATH\'
$resultFile = 'result.txt'
$webhook = 'https://discordapp.com/api/webhooks/YOUR_WEBHOOK_ID'
$livemode= $true #are we wanting to send the data to discord for the public?

do {
	if(Test-Path ($resultPath + $resultFile)) {
		#sleep to hanlde if the file has just been created but not finished being written to
		Start-Sleep -Milliseconds 500
		
		### DELETE OLD RESULT UPLOAD AND RECREATE

		if (Test-Path ($resultPath + 'upload.txt')) {
			Remove-Item ($resultPath + 'upload.txt')
		}		

		New-Item -Path $resultPath -Name "upload.txt" -ItemType "file" -Value "RACE RESULTS:`r`n"

		#initialise results variables to make sure they are empty
		$finishers = ''
		$finisherCount = 0
		$crashed = ''
		$other = ''

		### PARSE RESULT LOG FILE INTO SOMETHING MORE READABLE AND IN CORRECT CATEGORIES

		$header = '1'

		[System.IO.File]::ReadLines($resultPath + $resultFile) | ForEach-Object {

			If ($header -eq '0') {
				$parts = $_ -split ","
				
				$formatted =	(	'`' + 
							$parts[0].padRight(2,' ') + '| ' + #position
							$parts[10].replace(' p',' ').padLeft(7,' ') + '| ' +	# points
							$parts[5].padRight(14,' ') + '| ' + # glider
							$parts[3].padRight(4,' ') + '| ' + # trigraph
							$parts[2].replace('.','').padRight(21,' ') + '|' + # name
 							$parts[6].padLeft(9,' ') + ' | ' + # distance
							$parts[8].padLeft(10,' ') + ' | ' + # speed
							$parts[7].padRight(9,' ') + '| ' + # time
							$parts[1].padRight(9,' ') + # status
							$parts[9].replace(' p','').padLeft(7,' ') + # penalties
#							$parts[11].padRight(16,' ') + ' | ' +
#							$parts[12].padRight(12,' ') +  
							'`' + "`r`n"
						)
			

				switch ($parts[1]) {
					'Finished' { 
								$finishers += $formatted 
								$finisherCount++
					}
					'Crashed'  { $crashed   += $formatted }
					'Landed'   { $crashed   += $formatted }
					default    { $other     += $formatted }
				}
				
			}
			
			$header = '0'			
		}
	
		### CREATE THE FILE TO SEND TO DISCORD 		

		$resultData  = "`FINISHERS:`r`n" + $finishers + "`r`n"
		$resultData += "`NON-FINISHERS:`r`n" + $crashed + "`r`n"
		$resultData += "`DID NOT START:`r`n" + $other + "`r`n"

		Add-Content -Path $resultPath\upload.txt  -Value $resultData 
		
		
	### SEND TO DISCORD IF THERE ARE FINISHERS
	### IT HAS TO BE LINE BY LINE
	### WE SLOW DOWN THE SENDING SO WE DON'T MAKE THEM RATE-LIMIT US

		if ($finisherCount -ge 1 ){ 

			[System.IO.File]::ReadLines($resultPath + 'upload.txt') | ForEach-Object {

				$Form = @{
				content = $_
				}
				
				#send results to the webhook if in live mode and ignore any errors (will give empty errors if no try catch)
				$Result = try { 
					if($livemode) {
                        Invoke-WebRequest -Uri $webhook -Method Post -Body $Form -UseBasicParsing
                     } else {
                        Write-Host $_
                     }
				} catch [System.Net.WebException] { 
					Write-Verbose "An exception was caught: $($_.Exception.Message)"
					$_.Exception.Response 
				} 

				Start-Sleep -Milliseconds 500
			}	
		} else {
			Write-Host "Not enough finishers to upload - " + $finisherCount + " finishers"
		}

		### DELETE/ARCHIVE THE OLD RESULT FILE
		
		#rename the DSH results file so we don't process it again
		if (Test-Path ($resultPath + $resultFile)) {
			Rename-Item -Path ($resultPath + $resultFile) -NewName ($resultPath + $resultFile + [DateTime]::Now.ToString("yyyyMMdd-HHmmss") + ".csv")
		}

		#remove upload txt file to clean up
		if (Test-Path ($resultPath + 'upload.txt')) {
			Remove-Item ($resultPath + 'upload.txt')
		}
	}		

	### SLEEP FOR A BIT BEFORE LOOKING FOR MORE RESULTS TO UPLOAD
	Start-Sleep -Seconds $interval

} while($true) 