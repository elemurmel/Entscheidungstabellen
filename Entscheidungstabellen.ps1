Class Regel{
    [string] $name;
    [String[]] $bedingungen;
    [String[]] $aktionen;

    Regel([string] $name){
        $this.name = $name;
        $this.bedingungen = @();
        $this.aktionen = @();
    }
}

#Konsolidiert max. 2 Regeln auf einmal (wird rekursiv aufgerufen)
function consolidate([Regel[]] $inputTable, [int] $countActions){
    [Regel[]]$output = @();
    $result = 0;
    $alreadyMerged = @();

    for($y = 0; $y -lt $inputTable.Count; $y++){
        if($alreadyMerged -notcontains $y){
            for($z = ($y + 1); $z -lt $inputTable.Count; $z++){
                [Regel] $tmpRule = $inputTable[$y] | foreach {$_};
                $actionCounter = 0;
                $countSameActions = 0;
                for($x = 0; $x -lt $inputTable[$y].aktionen.Count; $x++){
                    if(($inputTable[$y].aktionen[$x] -eq $inputTable[$z].aktionen[$x]) -and ($inputTable[$y].name -notmatch $inputTable[$z].name)){
                        $countSameActions++;
                        if($countSameActions -eq $countActions){
                            $counter = 0;
                            $differenceIndex = 0;
                            for($k = 0; $k -lt $inputTable[$y].bedingungen.Count; $k++){
                                if(($alreadyMerged -notcontains $y) -and ($alreadyMerged -notcontains $z)){
                                    if(($inputTable[$y].bedingungen[$k] -notmatch $inputTable[$z].bedingungen[$k]) -and ($inputTable[$y].bedingungen -notmatch '-') -and ($inputTable[$z].bedingungen -notmatch '-')){
                                        $counter++;
                                        $differenceIndex = $k;
                                    }
                                    if(($counter -eq 1) -and ($k -eq ($inputTable[$y].bedingungen.Count - 1))){
                                        $result = 1;
                                        for($l = 0; $l -lt $inputTable[$y].bedingungen.Count; $l++){
                                            if($l -eq $differenceIndex){
                                                $tmpRule.bedingungen[$l] = '-';
                                                $tmpRule.name += "+" + ($inputTable[$z].name);
                                                $alreadyMerged += $y,$z;
                                            }
                                        }
                                        if(!$output.Contains($tmpRule)){
                                            $output += $tmpRule;
                                        }
                                    }
                                    if(($k -eq ($inputTable[$y].bedingungen.Count - 1)) -and ($counter -ne 1) -and (!$output.Contains($tmpRule))){
                                        $output += $tmpRule;
                                    }
                                }else{
                                    break;
                                }
                            }
                        }
                    }else{
                        $countSameActions--;
                    }
                }
            }
            if(($alreadyMerged -notcontains $y) -and (!$output.Contains($inputTable[$y]))){
                $output += $inputTable[$y];
            }   
        }
    }

    $result;
    $output;
}

#CSV-Export der konsolidierten Entscheidungstabelle
function exportETtoCsv ([Regel[]] $regeln, [String] $path, [String[]] $conditionNames, [String[]] $actionNames){
    [IO.Directory]::SetCurrentDirectory($pwd);
    $stream = [System.IO.StreamWriter] $path;
	
	#Befüllen der Header-Zeile
    for($i = 0; $i -lt $regeln.Count; $i++){
		if($i -eq 0){
			$stream.Write(",");
		}
		if($i -eq ($regeln.Count - 1)){
            $stream.Write($regeln[$i].name);
			$stream.WriteLine();
        }else{
            $stream.Write($regeln[$i].name + ",");
        }
    }
	
	#Befüllen der Bedingungs-Zeilen
	for($i = 0; $i -lt $regeln[$i].bedingungen.Count; $i++){
		for($k = 0; $k -lt $regeln.Count; $k++){
			if($k -eq 0){
				$stream.Write($conditionNames[$i] + ",");
			}
			if($k -eq ($regeln.Count - 1)){
				if($regeln[$k].bedingungen[$i] -eq $true){
					$stream.Write("1");
				}elseif($regeln[$k].bedingungen[$i] -eq $false){
					$stream.Write("0");
				}else{
					$stream.Write("-");
				}
				$stream.WriteLine();
			}else{
				if($regeln[$k].bedingungen[$i] -eq $true){
					$stream.Write("1,");
				}elseif($regeln[$k].bedingungen[$i] -eq $false){
					$stream.Write("0,");
				}else{
					$stream.Write("-,");
				}
			}
		}
	}

	#Befüllen der Aktionen
	for($i = 0; $i -lt $regeln[$i].aktionen.Count; $i++){
		for($k = 0; $k -lt $regeln.Count; $k++){
			if($k -eq 0){
				$stream.Write($actionNames[$i] + ",");
			}
			if($k -eq ($regeln.Count - 1)){
				if($regeln[$k].aktionen[$i] -eq $true){
					$stream.Write("x");
				}
				$stream.WriteLine();
			}else{
				if($regeln[$k].aktionen[$i] -eq $true){
					$stream.Write("x,");
				}elseif($regeln[$k].aktionen[$i] -eq $false){
					$stream.Write(",");
				}
			}
		}
	}

    $stream.Close();
}

# Startfunktion
function konsolidiereEntscheidungstabelle ([String] $inputPath){
    $readCsv = Get-Content -Path $inputPath;
    $ruleNames = $readCsv[0].Split(',');
    $countRules = ($ruleNames.Count - 1);
    switch ($countRules){
        4 {$countConditions = 2};
        8 {$countConditions = 3};
        16 {$countConditions = 4};
		32 {$countConditions = 5};
        default {"Es werden nur zwischen 2 und 5 Bedingungen unterstützt.";exit;};
    }
    $countActions = ($readCsv.Count - 1) - $countConditions;
	[String[]] $actionNames = @();
	[String[]] $conditionNames = @();
    [Regel[]] $rules = @();



    #Erzeugen des Regel-Arrays
    foreach ($ruleName in $ruleNames){
		if($ruleName -match "R"){
			$tmpRule = [Regel]::new($ruleName);
			$rules += $tmpRule;
		}
    }

    #Einlesen der Bedingungen
    for($y = 1; $y -lt ($countConditions + 1); $y++){
        $tmpLine = $readCsv[$y].Split(',');
		$conditionNames += $tmpLine[0];
        for($x = 1; $x -lt $tmpLine.Count; $x++){
			if($tmpLine[$x] -eq 1){
                $rules[($x - 1)].bedingungen += $true;
            } else{
                $rules[($x - 1)].bedingungen += $false;
            }
        }
    }

    #Einlesen der Aktionen
    for($y = ($countConditions + 1); $y -lt $readCsv.Count; $y++){
        $tmpLine = $readCsv[$y].Split(',');
		$actionNames += $tmpLine[0];
        for($x = 1; $x -lt $tmpLine.Count; $x++){
            if($tmpLine[$x] -eq 'x'){
                $rules[($x - 1)].aktionen += $true;
            } else{
                $rules[($x - 1)].aktionen += $false;
            }
        }
    }


    #Konsolidieren der Tabelle
    do{
        $result = consolidate $rules $countActions;
        $rules = $result[1..($rules.Count)];
    } until($result[0] -eq 0)

    #Export to CSV funktioniert noch nicht
    exportETtoCsv $rules ($inputPath.Replace(".csv", "-cons.csv")) $conditionNames $actionNames;
}