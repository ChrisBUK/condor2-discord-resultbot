$livemode = 0;

# FUNCTIONS 

# Fire webhook to deliver results. Blocks of up to 2000 chars can go as one, otherwise it has to go by line.
function fireWebhook($content,$uri,$header,$titles) {    
   
    # If less than 2000 characters for a block, discord will take it so we give it.
    if ($content.Length -le 2000 -and $content.Length -gt 0) {
        $fields = @{ content = '```' + $header.replace('[]','') + $titles + $content + '```' };
        $out = Invoke-RestMethod -Uri $uri -Method Post -Body $fields 
        # Small pause after a chunk of data
        Start-Sleep -Seconds 1;
    } else {

        # Here is where we have to split things down into 2000 character chunks. We'll try to do it at sensible breakpoints.       
        $chunksTotal = [math]::Ceiling($content.Length / 2000)
        $splitContent = $content.replace('```','').split("`r`n");

        $chunkNumber = 1
        $chunk = $header.replace('[]','['+$chunkNumber+' of '+$chunksTotal+']') + $titles

        foreach ($line in $splitContent) {
                   
            # If adding a line doesn't bust the limit, add it (+2 for the newline and less 6 for the backticks hence 1996 not 2000).                            
            if ($line.Length + $chunk.Length -le 1900) { 
                if ($line.Length -gt 0) {
                    $chunk += $line + "`n" 
                }
            } else {               
                
                # If adding the line busts the limit, send the data and reset the chunk to be the header only, and begin looping again.         
                if ($line.Length -gt 0) {
                    $chunk += $line + "`n" 
                }
                $fields = @{ content = '```'+$chunk+'```' }
                $out = Invoke-Restmethod -Uri $uri -Method Post -Body $fields;
                
                # Increment and reset chunk content
                $chunkNumber++
                $chunk = $header.replace('[]','['+$chunkNumber+' of '+$chunksTotal+']') + $titles
                
                # Small pause after sending
                Start-Sleep -Seconds 1
            }
        }

        # Send the remaining data (if there is any) after we have exited the loop at the last line
        if ($chunk.Length -gt 0) {            
            $fields = @{ content = '```'+$chunk+'```' }
            $out = Invoke-Restmethod -Uri $uri -Method Post -Body $fields;
            # Small pause after sending
            Start-Sleep -Seconds 1
        }

    }
}

# ENVIRONMENT SETTINGS

if ($livemode -eq 1) { 
    $interval = 300 #seconds to pause inbetween checking for results
    $resultPath = 'C:\Dshelper_servers\RaceResults\' 
    $resultFile = 'VSC_Race_results.csv'
    $taskFile = 'C:\SampleTask.fpl'
    $webhook_discord_result = 'https://discord.com/api/webhooks/YOUR_WEBHOOK'
    $webhook_discord_general = 'https://discordapp.com/api/webhooks/YOUR_WEBHOOK'
    $webhook_ifttt = ''
} else {
    $interval = 10 #seconds to pause inbetween checking for results
    $resultPath = 'C:\Dshelper_servers\RaceResults\' 
    $resultFile = 'VSC_Race_results.csv'
    $taskFile = 'C:\SampleTask.fpl'
    $webhook_discord_result = 'https://discordapp.com/api/webhooks/804661711180922881/YOUR_WEBHOOK'
    $webhook_discord_general = 'https://discordapp.com/api/webhooks/804661711180922881/YOUR_WEBHOOK'
    $webhook_ifttt = ''
}

# GLIDER CLASSES - Enter exactly as they are referenced in the results file. A glider can feature in multiple classes.

$class_club      = 'ASW19','ASW20','DG101G','Libelle','LS4a','Pegase','StdCirrus','ASW15'
$class_18m       = 'Antares18s','ASG29-18','ASG29Es-18','DG808C-18','JS1-18','JS3-18','Ventus3-18','DG1000S'
$class_15m       = 'DG808C-15','Diana2','JS3-15', 'Ventus3-15'
$class_standard  = 'Discus2a','Genesis2','LS8neo'
$class_open      = 'Antares18s','Arcus','ASG29-18','ASG29Es-18','ASK21','ASW15','ASW19','ASW20','Blanik','DG1000S','DG101G','DG808C-15','DG808C-18','Diana2','Discus2a','DuoDiscus','EB29R','Genesis2','GrunauBaby','JS1-18','JS1-21','JS3-15','JS3-18','K8','Ka6CR','Libelle','LS4a','LS8Neo','Pegase','PilatusB4','SG38','SGS1-26','StdCirrus','StemmeS12','SwiftS1','Ventus3-15','Ventus3-18'
$class_20m_multi = 'Arcus','DuoDiscus'
$class_vintage   = 'Ka6CR','Blanik','K8','GrunauBaby','SG38','SGS1-26'
$class_school	 = 'ASK21','Blanik','DG1000S','GrunauBaby','K8','Ka6CR','PilatusB4','SG38','SGS1-26'

# MAIN LOOP

do {
	if (Test-Path ($resultPath + $resultFile)) {			
        
		# Initialise results variables to make sure they are empty        

        $disconnectedCount = 0;
        $nonfinisherCount = 0;

        $formatted = '';
	$result_all = ''; 
        $result_club = '';
        $result_18m = '';
        $result_15m = '';
        $result_standard = '';
        $result_open = '';
        $result_20m_multi = '';
        $result_vintage = '';
	$result_school = '';

        $start_all = 0;
        $finish_all = 0;
        $finish_club = 0;
        $finish_18m = 0;
        $finish_15m = 0;
        $finish_standard = 0;
        $finish_open = 0;
        $finish_20m_multi = 0;
        $finish_vintage = 0;
	$finish_school = 0;

		$firstPlace = ''
		$placings= ''

		### PARSE RESULT LOG FILE TO BE HUMAN READABLE

		$lineNumber = 0

		$scoresHeader  = ('POS| POINTS |    GLIDER     | ID  |        PILOT         |   DIST   |   SPEED    |   TIME   |  STATUS  |  PEN    '+"`r`n")
        $scoresHeader += ('-----------------------------------------------------------------------------------------------------------------'+"`r`n")


		[System.IO.File]::ReadLines($resultPath + $resultFile) | ForEach-Object {

			If ($lineNumber -ge 1) {
				$parts = $_ -split ","

                # Change statuses to reflect reality  
                $niceStatus = $parts[1];              
                $niceStatus = $niceStatus.replace('Racing','Disconn');
                $niceStatus = $niceStatus.replace('Landed','Landout');

				# Build line
				$formatted =	(
							'???' + '| ' +                      # position placeholder
							$parts[10].replace(' p',' ').padLeft(7,' ') + '| ' +	# points
							$parts[5].padRight(14,' ') + '| ' + 			        # glider
							$parts[3].padRight(4,' ') + '| ' + 			            # trigraph
							$parts[2].replace('.',' ').padRight(21,' ') + '|' + 	# name
 							$parts[6].padLeft(9,' ') + ' | ' + 			            # distance
							$parts[8].padLeft(10,' ') + ' | ' + 			        # speed
							$parts[7].padRight(9,' ') + '| ' + 			            # time
							$niceStatus.padRight(9,' ') + '| ' + 	                # status
							$parts[9].replace(' p','').padLeft(6,' ') + 		    # penalties
#							$parts[11].padRight(16,' ') + ' | ' +
#							$parts[12].padRight(12,' ') +  
							"`r`n"
						)		

                # Update counts of statuses                

				switch ($parts[1]) {
					'Finished' { $finish_all++; $start_all++; }
					'Racing'   { $disconnectedCount++; $start_all++; }
					'Crashed'  { $nonfinisherCount++; $start_all++; }
					'Landed'   { $nonfinisherCount++; $start_all++;}
					default    { $nonfinisherCount++; }
				}

				# Shortened/Friendly result text for winner for social media or non-result channel

                if ($lineNumber -eq 1) {
					$firstPlace = 'Congratulations to ' + $parts[2].replace('.',' ') + ' on a race win in their ' + $parts[5] + ', completing ' + $parts[6] + ' in ' + $parts[7] + ', achieving a speed of ' + $parts[8] + '. See #race-results for the full classification.'
					$placings = '1st Place: ' + $parts[2] + " ("+$parts[8]+")`r`n"
				}
				if ($lineNumber -eq 2) {				
					$placings += '2nd Place: ' + $parts[2] + " ("+$parts[8]+")`r`n"
				}
				if ($lineNumber -eq 3) {
					$placings += '3rd Place: ' + $parts[2] + ' ('+$parts[8]+')'
				}	
				
			
                # Build the results output by class.

                $result_all += $formatted.replace('???', $lineNumber.toString().padRight(3,' '));
                        
                if ($parts[5] -in $class_club) {
                    $finish_club++;
                    $result_club += $formatted.replace('???',$finish_club.toString().padRight(3,' '));
                }

                if ($parts[5] -in $class_18m) {
                    $finish_18m++;
                    $result_18m += $formatted.replace('???',$finish_18m.toString().padRight(3,' '));
                }

                if ($parts[5] -in $class_15m) {
                    $finish_15m++;
                    $result_15m += $formatted.replace('???',$finish_15m.toString().padRight(3,' '));
                }

                if ($parts[5] -in $class_standard) {
                    $finish_standard++;
                    $result_standard += $formatted.replace('???',$finish_standard.toString().padRight(3,' '));
                }

                if ($parts[5] -in $class_open) {
                    $finish_open++;
                    $result_open += $formatted.replace('???',$finish_open.toString().padRight(3,' '));
                }

                if ($parts[5] -in $class_20m_multi) {
                    $finish_20m_multi++;
                    $result_20m_multi += $formatted.replace('???',$finish_20m_multi.toString().padRight(3,' '));
                }

                if ($parts[5] -in $class_vintage) {
                    $finish_vintage++;
                    $result_vintage += $formatted.replace($parts[0],$finish_vintage.toString().padRight(3,' '));
                }

                if ($parts[5] -in $class_school) {
                    $finish_school++;
                    $result_school += $formatted.replace($parts[0],$finish_vintage.toString().padRight(3,' '));
                }
	
            }
            
			$lineNumber++;
		}
	
		### SEND RESULTS TO DISCORD WEBHOOK	
        ### Never send results of a 'race' where only one person started it - a race needs two!
        ### Never send a class of results that is empty.
        ### If a race is single class, do not send 'all' as it will be the same as the class.	 
        
        $num_classes = 0;
        if ($finish_club -ge 1) { $num_classes++ }
        if ($finish_15m -ge 1) { $num_classes++ }
        if ($finish_18m -ge 1) { $num_classes++ }
        if ($finish_standard -ge 1) { $num_classes++ }
        if ($finish_open -ge 1) { $num_classes++ }
        if ($finish_20m_multi -ge 1) { $num_classes++ }
        if ($finish_vintage -ge 1) { $num_classes++ }
	if ($finish_school -ge 1) { $num_classes++ }


        if ($start_all -gt 1) {       

            # ALL results for a multi-class race.
            if ($num_classes -gt 1) {             
                fireWebhook -content $result_all -uri $webhook_discord_result -header "FULL RESULTS (ALL CLASSES) []:`r`n`r`n" -titles $scoresHeader
            }

            if ($finish_club -ge 1) {            
                fireWebhook -content $result_club -uri $webhook_discord_result -header "CLUB CLASS []:`r`n`r`n" -titles $scoresHeader
            }

            if ($finish_15m -ge 1) {
                fireWebhook -content $result_15m -uri $webhook_discord_result -header "15 METRE CLASS []:`r`n`r`n" -titles $scoresHeader
            }

            if ($finish_18m -ge 1) {
                fireWebhook -content $result_18m -uri $webhook_discord_result -header "18 METRE CLASS []:`r`n`r`n" -titles $scoresHeader           
            }

            if ($finish_standard -ge 1) {
                fireWebhook -content $result_standard -uri $webhook_discord_result -header "STANDARD CLASS []:`r`n`r`n" -titles $scoresHeader
            }

            if ($finish_open -ge 1) {
                fireWebhook -content $result_open -uri $webhook_discord_result -header "OPEN CLASS []:`r`n`r`n" -titles $scoresHeader
            }

            if ($finish_20m_multi -ge 1) {
                fireWebhook -content $result_20m_multi -uri $webhook_discord_result -header "20 METRE MULTISEAT CLASS []:`r`n`r`n" -titles $scoresHeader
            }

            if ($finish_vintage -ge 1) {
                fireWebhook -content $result_vintage -uri $webhook_discord_result -header "VINTAGE CLASS []:`r`n`r`n" -titles $scoresHeader
            }

            if ($finish_school -ge 1) {
                fireWebhook -content $result_school -uri $webhook_discord_result -header "SCHOOL CLASS []:`r`n`r`n" -titles $scoresHeader
            }

            ### WRITE THE QUICKRESULT OUT TO DISCORD
		    $Form = @{
			    content = $firstPlace;
		    }

            $out = Invoke-Restmethod -Uri $webhook_discord_general -Method Post -Body $Form 
        }
        
        ### WRITE THE QUICKRESULT FILE OUT TO FACEBOOK / TWITTER / IFTTT OR WHATEVER
        ### [[ TODO ]]

		### DELETE/ARCHIVE THE OLD RESULT FILE
		
		#rename the DSH results file so we don't process it again
		
        if ($livemode -eq 1) {
            if (Test-Path ($resultPath + $resultFile)) {
			    Rename-Item -Path ($resultPath + $resultFile) -NewName ($resultPath + $resultFile.Replace('.csv','') + '_' + [DateTime]::Now.ToString("yyyyMMdd-HHmmss") + ".csv")
            }
		}

	}		

	### SLEEP FOR A BIT BEFORE LOOKING FOR MORE RESULTS TO UPLOAD
	Start-Sleep -Seconds $interval

} while($true) 
