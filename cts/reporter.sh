#!/bin/bash

#TODO: read this from a file/folder structure
#echo "json=$testsJSON"
#echo "$testsJSON" > json

WORKSPACE=$(pwd)

jtrfileList=$WORKSPACE/getlogs_failurelist.txt
result=$WORKSPACE/tck_results/tckresult.txt
delayedresult=$WORKSPACE/tck_results/delayedresult.txt
sortresult=$WORKSPACE/tck_results/sortinputresult.txt
mkdir -p $WORKSPACE/tck_results
touch $sortresult
touch $WORKSPACE/failures.count
sortresultoutput=$WORKSPACE/tck_results/sortoutputresult.txt
summary=$WORKSPACE/tck_results/summary.txt
output=$WORKSPACE/tck_results
tckfiles=$WORKSPACE/tck_work
categories=$WORKSPACE/categories

#TODO: do we need jq?
#which jq

mkdir -p $WORKSPACE/tck_results
mkdir -p $WORKSPACE/tck_work
mkdir -p $categories
#TODO: replace with mv after testing
cp -r "${WORKSPACE}"/results "${WORKSPACE}/tck_work/"
cd $WORKSPACE/tck_work

echo "Jakarta EE 8 Platform TCK result report:<br><br>" >> $result
lastCategory=""
# reset total number of EE platform test failures
count=0
# reset total number of EE platform passing tests
passingCount=0

standalonesaajPassingCount=0
standalonesaajFailureCount=0
standalonesaajTests=0

standalonejaxb23PassingCount=0
standalonejaxb23FailureCount=0
standalonejaxb23Tests=0

standalonewebsocketPassingCount=0
standalonewebsocketFailureCount=0
standalonewebsocketTests=0

standaloneAtInjectionPassingCount=0
standaloneAtInjectionFailureCount=0
standaloneAtInjectionTests=0

standalonejaxwsPassingCount=0
standalonejaxwsFailureCount=0
standalonejaxwsTests=0

standaloneCDIFailureCount=0
standaloneCDIPassingCount=0
standaloneCDItests=0;

standaloneBeanValidationFailureCount=0
standaloneBeanValidationPassingCount=0
standaloneBeanValidationtests=0;


for jobDir in "${WORKSPACE}"/tck_work/results/*; do
    pushd "${jobDir}" > /dev/null
    buildId="$(basename ${jobDir})"

    # TODO: check results are present

    testName="$(cat ${jobDir}/name.txt)"
    echo "testName: ${testName}"

    # generate list of jaxb standalone tck JTR files with failures (indicated by "Failed.")
    if [[ "$testName" == standalonejaxb23 ]]; then
        set +e;grep -lir --include *.jtr "test.*result\:.*Failed\." . > $jtrfileList;set -e
    else  
        # generate list of JTR files inside of $testName folder with failures 
        set +e;grep -lir --include *.jtr "test.*result\:.*Failed\|test.*result\:.*Error" . > $jtrfileList;set -e
    fi

    numberofjtrfiles=0
    if [ -e "$jtrfileList" ]; then
        numberofjtrfiles=$(wc -l < $jtrfileList)
    fi  
    # count the number of tests that passed (equal to the number of jtr files that passed, one test per jtr file).
    set +e;passed=$(grep -lir --include *.jtr "test.*result\:.*Passed\|test.*result\:.*Pass" . | wc -l);set -e  

    if [[ "$testName" == standalonewebsocket ]]; then
        standalonewebsocketPassingCount=$passed
        standalonewebsocketFailureCount=$numberofjtrfiles
        standalonewebsocketTests=$((standalonewebsocketPassingCount+standalonewebsocketFailureCount))
    elif [[ "$testName" == standalonejaxb23 ]]; then    
        standalonejaxb23PassingCount=$passed
        standalonejaxb23FailureCount=$numberofjtrfiles
        standalonejaxb23Tests=$((standalonejaxb23PassingCount+standalonejaxb23FailureCount))
    elif [[ "$testName" == standalonejaxws ]]; then    
        standalonejaxwsPassingCount=$passed
        standalonejaxwsFailureCount=$numberofjtrfiles
        standalonejaxwsTests=$((standalonejaxwsPassingCount+standalonejaxwsFailureCount))
    elif [[ "$testName" == standalonesaaj ]]; then    
        standalonesaajPassingCount=$passed
        standalonesaajFailureCount=$numberofjtrfiles
        standalonesaajTests=$((standalonesaajPassingCount+standalonesaajFailureCount))
    else
        # add to the total number of passing tests
        passingCount=$((passingCount+passed))  
    fi

    echo "$numberofjtrfiles JTR files with errors found, $passed tests for $testName"

    if [ ! -z "$lastCategory" ]; then
        echo "break into new category, print lastCategory=$lastCategory iteration=$iteration"
        # started a new category, report on number of failures in last category 
        # and include link to per category html file that contains all of the .jtr + log links
        printf '%s has %d failure(s) - <a href=\"%s/%s.html\">failures</a><br/> \n' "$lastCategory" "$iteration" "$categoriesLink" "$category"  >> $sortresult
        printf '<br><br>%s <a href=\"%s\"> zipped logs </a>' "$category" "$lastlogsLink" >> "$categories/$category.html"

        # TODO: move print of log link to here.
        # reset iteration counter for next category
        iteration=0
        lastCategory=""
    fi

    if [ $numberofjtrfiles -gt 0 ]; then
        count=$((count+numberofjtrfiles))
        echo "numberofjtrfiles = $numberofjtrfiles"
        # process each line in list of .JTR files
        while IFS= read -r line || [[ -n $line ]]; do
        detailtestname=$(grep '^test\=' "$line")
        path=${line/\.\/tests/}
        failingjtr="${testLink}${jtrTestsFolder}${path}"
        testdirectory=$(grep '^test_directory\=' "$line"| cut -d'=' -f2)

        # category=$(echo $line | cut -d/ -f3);
        category=$testName
        
        if [ "$lastCategory" != "$category" ]; then
            if [ ! -z "$lastCategory" ]; then
            echo "break into new category, print lastCategory=$lastCategory iteration=$iteration newCategory=$category"
            # started a new category, report on number of failures in last category 
            # and include link to per category html file that contains all of the .jtr + log links
            printf '%s has %d failure(s) - <a href=\"%s/%s.html\">failures</a><br/> \n' "$lastCategory" "$iteration" "$categoriesLink" "$category"  >> $sortresult
            printf '<br><br>%s <a href=\"%s\"> zipped logs </a>' "$category" "$lastlogsLink" >> "$categories/$category.html"          
            # reset iteration counter for next category
            iteration=0
            fi
        fi
        lastCategory=$category
        iteration=$((iteration+1))

        printf '<br><a href=\"%s/*view*/\"> %s</a>  <a href=\"%s%s\"> test source</a>' "$failingjtr" "$detailtestname" "https://github.com/eclipse-ee4j/jakartaee-tck/tree/master/src/" "$testdirectory" >> "$categories/$category.html"
        done < "$jtrfileList"
    elif [[ "$testName" == standalonedependencyinjection ]]; then
        # TODO: do the standalonedependencyinjection check 
    elif [[ "$testName" == standalonecdi ]]; then
        # TODO: do the standalonecdi check
    elif [[ "$testName" == standalonebeanvalidation ]]; then
        # TODO: do the standalonebeanvalidation check
    else
        echo "no errors found in JTR files for ${testName} ${testLink} ${jtrTestsFolder}"
    fi

    popd > /dev/null
done

cd $WORKSPACE

if [ ! -z "$lastCategory" ]; then
  echo "break into new category, print lastCategory=$lastCategory iteration=$iteration"
  # started a new category, report on number of failures in last category 
  # and include link to per category html file that contains all of the .jtr + log links
    printf '%s has %d failure(s) - <a href=\"%s/%s.html\">failures</a><br/> \n' "$lastCategory" "$iteration" "$categoriesLink" "$category"  >> $sortresult  
    printf '<br><br>%s <a href=\"%s\"> zipped logs </a>' "$category" "$logsLink" >> "$categories/$category.html"
  # reset iteration counter for next category
  iteration=0
  lastCategory=""
fi

# sort tck results
if [ -e "$sortresult" ]; then
  echo "sorting $sortresult"
  sort $sortresult --output=$sortresultoutput
  echo "sort output written to $sortresultoutput"
  cat $sortresultoutput >> $result
fi

echo "process $delayedresult file if it exists"

echo "<br>" >> $result
if [ -e "$delayedresult" ]; then
  cat $delayedresult >> $result
fi  

echo "print Jakarta EE platform stats"

totalfailurecount=$((count+standalonejaxb23FailureCount+standalonewebsocketFailureCount+standaloneAtInjectionFailureCount+standalonejaxwsFailureCount+standaloneCDIFailureCount+standaloneBeanValidationFailureCount+standalonesaajFailureCount))
totalpassedcount=$((passingCount+standalonejaxb23PassingCount+standalonewebsocketPassingCount+standaloneAtInjectionPassingCount+standalonejaxwsPassingCount+standaloneCDIPassingCount+standaloneBeanValidationPassingCount+standalonesaajPassingCount))

# show Jakarta EE platform stats
printf '<br><br>Platform TCK %s failure(s) occurred.' "${count}" >> $result
printf '<br><br>Platform TCK %s passed test(s).' "${passingCount}" >> $result
printf '<br><br>Platform TCK %s test(s) run' "$((${passingCount}+${count}))" >> $result
printf '<br><br>Total %s test(s) run' "$((${totalpassedcount}+${totalfailurecount}))" >> $result
printf '<br><br>Platform TCK %s failure(s) occurred<br>' "${count}" >> $summary
printf '<br><br>Platform TCK %s passed test(s).' "${passingCount}" >> $summary
printf '<br><br>Platform TCK %s test(s) run' "$((${passingCount}+${count}))" >> $summary

echo "print standalone JAX-WS tck stats"
# standalone JAX-WS tck stats
printf '<br><br>Standalone JAX-WS TCK %s failure(s) occurred.' "${standalonejaxwsFailureCount}" >> $result
printf '<br><br>Standalone JAX-WS TCK %s passed test(s).' "${standalonejaxwsPassingCount}" >> $result
printf '<br><br>Standalone JAX-WS TCK %s failure(s) occurred<br>' "${standalonejaxwsFailureCount}" >> $summary
printf '<br><br>Standalone JAX-WS TCK %s passed test(s).' "${standalonejaxwsPassingCount}" >> $summary
printf 'Standalone JAX-WS TCK %s failure(s) occurred' "${standalonejaxwsFailureCount}"> $WORKSPACE/standaloneJAXWSfailures.count
printf 'Standalone JAX-WS TCK %s test(s) passed' "${standalonejaxwsPassingCount}"> $WORKSPACE/standaloneJAXWSpassed.count

echo "print standalone jaxb tck stats"
# standalone jaxb tck stats
printf '<br><br>Standalone JAXB TCK %s failure(s) occurred.' "${standalonejaxb23FailureCount}" >> $result
printf '<br><br>Standalone JAXB TCK %s passed test(s).' "${standalonejaxb23PassingCount}" >> $result
printf '<br><br>Standalone JAXB TCK %s failure(s) occurred<br>' "${standalonejaxb23FailureCount}" >> $summary
printf '<br><br>Standalone JAXB TCK %s passed test(s).' "${standalonejaxb23PassingCount}" >> $summary
printf 'Standalone JAXB TCK %s failure(s) occurred' "${standalonejaxb23FailureCount}"> $WORKSPACE/standaloneJAXBfailures.count
printf 'Standalone JAXB TCK %s test(s) passed' "${standalonejaxb23PassingCount}"> $WORKSPACE/standaloneJAXBpassed.count

echo "print standalone websocket tck stats"
# standalone websocket tck stats
printf '<br><br>Standalone WebSocket TCK %s failure(s) occurred.' "${standalonewebsocketFailureCount}" >> $result
printf '<br><br>Standalone WebSocket TCK %s passed test(s).' "${standalonewebsocketPassingCount}" >> $result
printf '<br><br>Standalone WebSocket TCK %s failure(s) occurred<br>' "${standalonewebsocketFailureCount}" >> $summary
printf '<br><br>Standalone WebSocket TCK %s passed test(s).' "${standalonewebsocketPassingCount}" >> $summary
printf 'Standalone WebSocket TCK %s failure(s) occurred' "${standalonewebsocketFailureCount}"> $WORKSPACE/standaloneWebSocketfailures.count
printf 'Standalone WebSocket TCK %s test(s) passed' "${standalonewebsocketPassingCount}"> $WORKSPACE/standaloneWebSocketpassed.count

echo "print standalone atinjection tck stats"
# standalone atinjection tck stats
printf '<br><br>Standalone AtInjection TCK %s failure(s) occurred.' "${standaloneAtInjectionFailureCount}" >> $result
printf '<br><br>Standalone AtInjection TCK %s passed test(s).' "${standaloneAtInjectionPassingCount}" >> $result
printf '<br><br>Standalone AtInjection TCK %s failure(s) occurred<br>' "${standaloneAtInjectionFailureCount}" >> $summary
printf '<br><br>Standalone AtInjection TCK %s passed test(s).' "${standaloneAtInjectionPassingCount}" >> $summary
printf 'Standalone AtInjection TCK %s failure(s) occurred' "${standaloneAtInjectionFailureCount}"> $WORKSPACE/standaloneAtInjectionfailures.count
printf 'Standalone AtInjection TCK %s test(s) passed' "${standaloneAtInjectionPassingCount}"> $WORKSPACE/standaloneAtInjectionpassed.count

echo "print standalone CDI tck stats"
# standalone CDI tck stats
printf '<br><br>Standalone CDI TCK %s failure(s) occurred.' "${standaloneCDIFailureCount}" >> $result
printf '<br><br>Standalone CDI TCK %s passed test(s).' "${standaloneCDIPassingCount}" >> $result
printf '<br><br>Standalone CDI TCK %s failure(s) occurred<br>' "${standaloneCDIFailureCount}" >> $summary
printf '<br><br>Standalone CDI TCK %s passed test(s).' "${standaloneCDIPassingCount}" >> $summary
printf 'Standalone CDI TCK %s failure(s) occurred' "${standaloneCDIFailureCount}"> $WORKSPACE/standaloneCDIfailures.count
printf 'Standalone CDI TCK %s test(s) passed' "${standaloneCDIPassingCount}"> $WORKSPACE/standaloneCDIpassed.count

echo "print standalone beanvalidation tck stats"
# standalone BeanValidation stats
printf '<br><br>Standalone BeanValidation TCK %s failure(s) occurred.' "${standaloneBeanValidationFailureCount}" >> $result
printf '<br><br>Standalone BeanValidation TCK %s passed test(s).' "${standaloneBeanValidationPassingCount}" >> $result
printf '<br><br>Standalone BeanValidation TCK %s failure(s) occurred<br>' "${standaloneBeanValidationFailureCount}" >> $summary
printf '<br><br>Standalone BeanValidation TCK %s passed test(s).' "${standaloneBeanValidationPassingCount}" >> $summary
printf 'Standalone BeanValidation TCK failure(s) occurred' "${standaloneBeanValidationFailureCount}"> $WORKSPACE/standaloneBVfailures.count
printf 'Standalone BeanValidation TCK %s test(s) passed' "${standaloneBeanValidationPassingCount}"> $WORKSPACE/standaloneBVpassed.count

echo "print standalone saaj tck stats"
# standalone saaj tck stats
printf '<br><br>Standalone SAAJ TCK %s failure(s) occurred.' "${standalonesaajFailureCount}" >> $result
printf '<br><br>Standalone SAAJ TCK %s passed test(s).' "${standalonesaajPassingCount}" >> $result
printf '<br><br>Standalone SAAJ TCK %s failure(s) occurred<br>' "${standalonesaajFailureCount}" >> $summary
printf '<br><br>Standalone SAAJ TCK %s passed test(s).' "${standalonesaajPassingCount}" >> $summary
printf 'Standalone SAAJ TCK %s failure(s) occurred' "${standalonesaajFailureCount}"> $WORKSPACE/standaloneJAXBfailures.count
printf 'Standalone SAAJ TCK %s test(s) passed' "${standalonesaajPassingCount}"> $WORKSPACE/standaloneJAXBpassed.count

# show totals (platform tck tests + standalone tck tests)
printf '<br><br>Total %s test(s) run' "$((${totalpassedcount}+${totalfailurecount}))" >> $summary
printf 'Total %s failure(s) occurred' "${totalfailurecount}"> $WORKSPACE/failures.count
printf 'Total %s test(s) passed' "${totalpassedcount}"> $WORKSPACE/passed.count
printf 'Total %s test(s) run' "$((${totalfailurecount}+${totalpassedcount}))"> $WORKSPACE/testsrun.count

echo "done printing stats"

cd $WORKSPACE

echo "copy build.txt to result output"
echo "" >> $result
if [ -e "build.txt" ]; then
  echo "<br>Application Server build details:<br><pre>" >> $result
  cat build.txt >> $result
  echo "</pre>" >> $result
fi   
echo "" >> $result

echo "copy jakartaeetck.fingerprint to result output"
if [ -e "jakartaeetck.fingerprint" ]; then
  echo "Jakarta EE Platform TCK SHA-256 fingerprint:" >> $result
  cat jakartaeetck.fingerprint >> $result
fi 

echo "<br><br>Security configuration used: $security" >> $result

security=`echo $additionalParams | jq -r '.security'`
testChoices=`echo $additionalParams | jq -r '.testChoices'`
singletest=`echo $additionalParams | jq -r '.singletest'`

if [ $testChoices != 'null' ]; then
  if  [ $testChoices == 'single' ]; then
    echo "<br><br>Run single testsuite $singletest with $security configuration." >> $result
  else
    echo "<br><br>Run $testChoices testsuites with $security configuration."  >> $result
  fi
fi

export custombranch=""

echo "write build details to summary"
if [ -e "build.txt" ]; then
  echo "look for custom branch"
  set +e;matchinglines="$(grep -c 'Building with' build.txt)";set -e
  echo "matchinglines = $matchinglines"
  if [ $matchinglines -gt 0 ]; then
    echo "number of matching lines is greater than zero, look for actual branch name"
    set +e;custombranch="$(grep -i 'Building with' build.txt)";set -e
    echo "custombranch = $custombranch"
  fi 
  echo "add build.txt details to $summary"
  echo "" >> $summary
  echo "Application Server build details:" >> $summary
  cat build.txt >> $summary
fi

echo "create testfiles.zip"
zip $WORKSPACE/tck_results/testfiles.zip $result

if [ "$skipEmail" = "true" ];then 
  echo "skip sending email"
else   
 echo "reporting is complete, raise a failure to cause the email summary report to be sent"
 exit 1
fi