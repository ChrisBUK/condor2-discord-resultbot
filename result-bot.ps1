$interval = 300
$resultPath = 'C:\YOUR_PATH\'
$resultFile = 'result.txt'
$webhook = 'https://discordapp.com/api/webhooks/YOUR_WEBHOOK_ID'

do {
	if(Test-Path ($resultPath + $resultFile)) {
		#sleep to hanlde if the file has just been created but not finished being written to - PS
		Start-Sleep -Milliseconds 500
		
		### DELETE OLD RESULT UPLOAD AND RECREATE

		if (Test-Path ($resultPath + 'upload.txt')) {
			Remove-Item ($resultPath + 'upload.txt')
		}		

		New-Item -Path $resultPath -Name "upload.txt" -ItemType "file" -Value "RACE RESULTS:`r`n"

		# initialise results variables to make sure they are empty

		$finishers = ''
		$crashed = ''
		$other = ''

		### PARSE RESULT LOG FILE INTO SOMETHING MORE READABLE AND IN CORRECT CATEGORIES

		$header = '1'

		[System.IO.File]::ReadLines($resultPath + $resultFile) | ForEach-Object {

			If ($header -eq '0') {
				$parts = $_ -split ","
					
				$formatted =	(	'`' + 
							$parts[0].padRight(3,' ') + ' | ' +
							$parts[10].replace(' p',' ').padLeft(7,' ') + ' | ' +	
							$parts[5].padRight(16,' ') + ' | ' +
							$parts[3].padRight(6,' ') + ' | ' +
							$parts[2].replace('.',' ').padRight(32,' ') + ' | ' +
							$parts[6].padLeft(9,' ') + ' | ' +	
							$parts[8].padLeft(11,' ') + ' | ' + 
							$parts[7].padRight(9,' ') + ' | ' +
							$parts[1].padRight(9,' ') + ' | ' +
							$parts[9].replace(' p',' ').padLeft(7,' ') + ' | ' +
#							$parts[11].padRight(16,' ') + ' | ' +
#							$parts[12].padRight(12,' ') +  
							'`' + "`r`n"
						)
			

				switch ($parts[1]) {
					'Finished' { $finishers += $formatted }
					'Crashed' { $crashed += $formatted }
					default { $other += $formatted }
				}
				
			}
			
			$header = '0'			
		}
	
		### CREATE THE FILE TO SEND TO DISCORD 		

		$resultData  = "`FINISHERS:`r`n" + $finishers + "`r`n"
		$resultData += "`NON-FINISHERS:`r`n" + $crashed + "`r`n"
		$resultData += "`DID NOT START:`r`n" + $other + "`r`n"

		Add-Content -Path $resultPath\upload.txt  -Value $resultData 
		
		### SEND TO DISCORD
		### IT HAS TO BE LINE BY LINE
		### WE SLOW DOWN THE SENDING SO WE DON'T MAKE THEM RATE-LIMIT US
		
		[System.IO.File]::ReadLines($resultPath + 'upload.txt') | ForEach-Object {

			$Form = @{
			content = $_
			}
			
			#send results to the webhook and ignore any errors (will give empty errors if no try catch) - PS
			$Result = try { 
				Invoke-WebRequest -Uri $webhook -Method Post -Body $Form
			} catch [System.Net.WebException] { 
				Write-Verbose "An exception was caught: $($_.Exception.Message)"
				$_.Exception.Response 
			} 

			Start-Sleep -Milliseconds 500
		}	

		### ARCHIVE THE OLD RESULT FILE AND CLEAN UP

		#rename the DSH results file so we don't process it again - PS

		if (Test-Path ($resultPath + $resultFile)) {
			Rename-Item -Path ($resultPath + $resultFile) -NewName ($resultPath + $resultFile + [DateTime]::Now.ToString("yyyyMMdd-HHmmss"))
		}

		#remove upload txt file to clean up -PS

		if (Test-Path ($resultPath + 'upload.txt')) {
			Remove-Item ($resultPath + 'upload.txt')
		}

		### SLEEP FOR A BIT BEFORE LOOKING FOR MORE RESULTS TO UPLOAD

		Start-Sleep -Seconds $interval

	}		

} while($true) 
