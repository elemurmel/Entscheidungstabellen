Class Regel{
    [string] $name;
    [String[]] $bedingungen;
    [bool[]] $aktionen;

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

#CSV-Export der konsolidierten Entscheidungstabelle (WIP)
function exportETtoCsv ([Regel[]] $regeln, [String] $path){
    [IO.Directory]::SetCurrentDirectory($pwd);
    $stream = [System.IO.StreamWriter] $path;
	
	#Befüllen der Header-Zeile
    for($i = 0; $i -lt $regeln.Count; $i++){
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
			if($k -eq ($regeln.Count - 1)){
				$stream.Write($regeln[$k].bedingungen[$i]);
				$stream.WriteLine();
			}else{
				$stream.Write($regeln[$k].bedingungen[$i] + ",");
			}
		}
	}

    $stream.Close();
}

# Startfunktion
function konsolidiereEntscheidungstabelle ([String] $inputPath){
    $readCsv = Get-Content -Path $inputPath;
    $ruleNames = $readCsv[0].Split(',');
    $countRules = $ruleNames.Count;
    switch ($countRules){
        4 {$countConditions = 2};
        8 {$countConditions = 3};
        16 {$countConditions = 4};
        default {"Es werden nur zwischen 2 und 4 Bedingungen unterstützt.";exit;};
    }
    $countActions = ($readCsv.Count - 1) - $countConditions;
    [Regel[]] $rules = @();



    #Erzeugen des Regel-Arrays
    foreach ($ruleName in $ruleNames){
        $tmpRule = [Regel]::new($ruleName);
        $rules += $tmpRule;
    }

    #Einlesen der Bedingungen
    for($y = 1; $y -lt ($countConditions + 1); $y++){
        $tmpLine = $readCsv[$y].Split(',');
        for($x = 0; $x -lt $tmpLine.Count; $x++){
            if($tmpLine[$x] -eq 1){
                $rules[$x].bedingungen += $true;
            } else{
                $rules[$x].bedingungen += $false;
            }
        }
    }

    #Einlesen der Aktionen
    for($y = ($countConditions + 1); $y -lt $readCsv.Count; $y++){
        $tmpLine = $readCsv[$y].Split(',');
        for($x = 0; $x -lt $tmpLine.Count; $x++){
            if($tmpLine[$x] -eq 1){
                $rules[$x].aktionen += $true;
            } else{
                $rules[$x].aktionen += $false;
            }
        }
    }


    #Konsolidieren der Tabelle
    do{
        $result = consolidate $rules $countActions;
        $rules = $result[1..($rules.Count)];
    } until($result[0] -eq 0)

    #Export to CSV funktioniert noch nicht
    exportETtoCsv $rules ($inputPath.Replace(".csv", "-cons.csv"));

    #Debug-Ausgabe
    #$rules;
}