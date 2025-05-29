# use get-content and select-string to get lines and line numbers
$content = Get-Content C:\Users\David\source.txt | Select-String -Pattern "."

# find all the lines that are questions
$questionLines = $content | select-string -Pattern "(^\d{1,4})"

# loop over each question line and build out powershell object.
$questions = foreach ($question in $questionLines) {
    # store the index of the current question
    $index = [array]::IndexOf($questionLines, $question) 
    
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
    
    # extract the answer options into groups (answer a,b,c,d) and the actual word.
    $answerA = ($($questionBlock).Line | Select-String -Pattern '^(a).\s(.*)$').Matches.Groups
    $answerB = ($($questionBlock).Line | Select-String -Pattern '^(b).\s(.*)$').Matches.Groups
    $answerC = ($($questionBlock).Line | Select-String -Pattern '^(c).\s(.*)$').Matches.Groups
    $answerD = ($($questionBlock).Line | Select-String -Pattern '^(d).\s(.*)$').Matches.Groups 

    # create the possible answers ordered hashtable
    $possibleAnswers = [ordered]@{
        "$($answerA[1].Value)" = $answerA[2].Value
        "$($answerB[1].Value)" = $answerB[2].Value
        "$($answerC[1].Value)" = $answerC[2].Value
        "$($answerD[1].Value)" = $answerD[2].Value
    }

    ## answer and Explanation Section.
    # correct answer line: Find the line so the single letter answer and explanation can be extracted.
    $theCorrectAnswerLine = ($questionBlock | Select-String -Pattern "^Choice").Line
    # extract the a-d answer and explanation (save into regex groups)
    $theCorrectAnswerGroups = ($theCorrectAnswerLine | Select-String -Pattern "^(Choice\s)\S([a-d])\S\s(.+)$").Matches.Groups
    # get the single letter answer.
    $theCorrectAnswer = $theCorrectAnswerGroups[2].Value
    # get the explanation
    $theCorrectAnswerExplanation = $theCorrectAnswerGroups[3].Value

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
        CorrectAnswer = $theCorrectAnswer.ToUpper()
        Explanation = $theCorrectAnswerExplanation
        QuickHints = $quickHints.Line
    }
    
}

# convert the powershell objects caught in the $questions variable to json. Could do any PowerShell related manipulation with the $questions object
$json = $questions | ConvertTo-Json

# display the json on the screen
$json