## Functions
function Get-PossibleAnswers {
    param (
        [string[]]$Lines
    )

    $answers = $Lines | Select-String -Pattern '^(\w)\.\s(.*)$'
    $possibleAnswers = [ordered]@{}

    foreach ($answer in $answers) {
        $groups = $answer.Matches.Groups
        $letter = $groups[1].Value.ToUpper()
        $text = $groups[2].Value

        if (-not $possibleAnswers[$letter]) {
            $possibleAnswers.Add($letter, $text)
        } else {
            Write-Warning "Duplicate answer key: $letter"
        }
    }

    return $possibleAnswers
}

function Get-CorrectAnswer {
    param (
        [string[]]$Lines
    )

    # Find the line starting with "Choice"
    [array]$correctAnswerLine = $Lines | Where-Object { $_ -match '^Choice' }

    if (-not $correctAnswerLine) {
        Write-Warning "No correct answer line found."
        return $null
    }

    # Use the first matching line (if multiple)
    $line = $correctAnswerLine[0]

    # Try to match the expected pattern
    if ($line -match '^Choice\s\S([a-dA-D])\S\s(.+)$') {
        return [pscustomobject]@{
            Letter      = $matches[1].ToUpper()
            Explanation = $matches[2]
        }
    } else {
        Write-Warning "Correct answer line format unexpected."
        return $null
    }
}

# use get-content and select-string to get lines and line numbers
$content = Get-Content C:\Users\David\Documents\Git\Repositories\reddit-share\QuizTextParser\source.txt | Select-String -Pattern "."

# find all the lines that are questions
$questionLines = $content | select-string -Pattern "(^\d{1,4})"

# loop over each question line and build out powershell object.
$questions = for ($i = 0; $i -lt $questionLines.Count; $i++) {
    $question = $questionLines[$i]
    $index = $i  # Explicit index tracking
    
    # only define $nextQuestionLine when it is safe to do so
    if ($index -eq ($questionLines.Count - 1)) {
        $endOfQuestionLine = $content[-1].LineNumber
    }
    else {
        $nextQuestionLine = $questionLines[$index + 1]
        $endOfQuestionLine = $nextQuestionLine.LineNumber - 2
    }

      
    # store the index of the question line
    $startOfQuestionLine = $question.linenumber - 1

    # store the current question line and all lines below until the line before the next question
    $questionBlock = $content[($startOfQuestionLine)..($endOfQuestionLine)]
    
    # extract the question from the current question block
    $theQuestion = $questionBlock | Select-String -Pattern "(^\d{1,4})"
    # extract the question number/id from the question line.
    $theQuestionNumber = $theQuestion.ToString().Substring(0, $theQuestion.ToString().IndexOf("."))

    ## Find the line relating to the question's subject
    $theSubjectLineGroups = ($questionBlock.Line | Select-String -Pattern "^(Subject:)\s(.+)").Matches.Groups
    $theSubject = $theSubjectLineGroups[2].Value

    # extract the answer options into groups (answer a,b,c,d) and the actual worded answer.
    $answers = ($($questionBlock).Line | Select-String -Pattern '^(\w)\.\s(.*)$')

    # initialise ordered hashtable
    $possibleAnswers = Get-PossibleAnswers -Lines $questionBlock.Line
    
    <# iterate over the answers and add them to the ordered hashtable
    foreach ($answer in $answers) {
        # get the groups from the regex matches
        $answerGroups = $answer.Matches.Groups
        # get the letter from the letter group        
        $answerLetter = ($answerGroups[1].Value).ToUpper()
        # get the answer text from the answer text
        $answerText = $answerGroups[2].Value

        # add answer to ordered hashtable if the key doesn't already exist.
        if (-not($possibleAnswers[$answerLetter])) {
            $possibleAnswers.Add($answerLetter, $answerText)
        }
        else {
            Write-Host "Answer $answerLetter already exists" -ForegroundColor Red
        }
    }
        #>

    ## answer and Explanation Section.
    # correct answer line: Find the line so the single letter answer and explanation can be extracted.    
    $answerAndExplanation = Get-CorrectAnswer -Lines $questionBlock.Line

    ## quick hints section.
    # find the quick hints line
    $quickHintsLine = ($questionBlock | Select-String -Pattern "^Quick").LineNumber
    # using some math find the range of lines including the quick hints.
    $firstQuickHintIndex = ($questionBlock.count - (($questionBlock[-1].LineNumber) - $quickHintsLine))
    $lastQuickHintsIndex = ($questionBlock.count - 1)
    # Select the quick hints lines using the indexes calculated above.
    $quickHints = $questionBlock[$firstQuickHintIndex..$lastQuickHintsIndex]
    
    # save the values into a pscustobject to be converted to JSON later on. The object is captured into the $questions variable.
    [pscustomobject]@{
        id = $theQuestionNumber
        subject = $theSubject
        Question = $theQuestion.Line
        Options = $possibleAnswers
        CorrectAnswer = $answerAndExplanation.Letter
        Explanation = $answerAndExplanation.Explanation
        QuickHints = $quickHints.Line
    }
    
}

# convert the powershell objects caught in the $questions variable to json. Could do any PowerShell related manipulation with the $questions object
$json = $questions | ConvertTo-Json

# display the json on the screen
$json