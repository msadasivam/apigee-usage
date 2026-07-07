#! /bin/bash
# Works on GNU bash, version 3.2.57(1)-release (x86_64-apple-darwin20)
# Author: Kurt Kanaskie, Google (PII Removed by Staff)
# Updated: 2022-12-14

Help()
{
   # Display Help
   echo
   echo "Reports total API traffic for a specific year or for current year to date."
   echo "Defaults to report on an Apigee X organization."
   echo "Uses environment variables for ORG and TOKEN if set."
   echo
   echo "Syntax: $0 [-h|-l|-m|-o|-t|-y|-v"
   echo "options:"
   echo "    -h    Print this help"
   echo "    -l    Legacy Apigee Edge"
   echo "    -o    Organization name"
   echo "    -q    Quiet, don't show progress output"
   echo "    -s    Summary, don't show monthly details"
   echo "    -t    Access token"
   echo "    -y    Year"
   echo
   echo 'Usage X:     ./api-usage-org.sh -o apigeex-org-name -t $(gcloud auth print-access-token) | jq'
   echo 'Usage Edge:  ./api-usage-org.sh -l -o edge-org-name -t $(get_token) | jq'
   echo
   echo 'Save output: ./api-usage-org.sh -o x-org-name -t $(gcloud auth print-access-token) | jq > x-org-name.json'
   echo
}

ShowProgress()
{
	if [ $QUIET == false ]
	then
		>&2 echo $1
	fi
}

YEAR=`date "+%Y"`
MONTH=`date "+%m"`
APIGEE_API=apigee.googleapis.com
SHOW_MONTH_COUNT=true
QUIET=false

while getopts "o:y:t:hlsq" flag
do
	case "${flag}" in
		h) Help
			exit;;
		l) APIGEE_API="api.enterprise.apigee.com";;
		o) ORG=${OPTARG};;
		s) SHOW_MONTH_COUNT=false;;
		t) TOKEN=${OPTARG};;
		y) YEAR=${OPTARG}; MONTH=12;;
		q) QUIET=true;;
			\?) # Invalid option
			echo "Error: Invalid option"
			Help
		exit;;
	esac
done

if [ "$ORG" == "" ]
then
	echo
	echo "ERROR: Organization is required."
	Help
	exit
fi

DATE=`date`
AUTH="Authorization: Bearer $TOKEN"
ShowProgress "ORG: $ORG"
ENVS=$(curl -s -H "$AUTH" https://$APIGEE_API/v1/organizations/$ORG/environments | jq -r .)
if [ "$ENVS" == "" ] || [[ "$ENVS" == *'"error":'* ]]
then
	echo
	echo "ERROR: No environments or unauthorized."
	echo "ENVS: $ENVS"
	Help
	exit
fi

ShowProgress "ENVS: $ENVS"
ORG_TOTAL=0
ORG_USAGE='{"datetime":"'"$DATE"'","name":"'"$ORG"'","environments":['

for E in $ENVS
do
	# ENVS: [ "config", "dev", "prod", "test" ]
	# Skip square brackets
	if [ "$E" != "[" ] && [ "$E" != "]" ]
	then
		# E: "config",
		# remove any " or , characters
		temp1="${E#\"}"; temp2="${temp1%\,}"; ENV="${temp2%\"}"
		
		# echo ENV: $ENV
		ENV_TOTAL=0
		ENV_USAGE='"months":['
		for M in {1..12}
		do
			if [ "$M" -le "$MONTH" ]
			then
				if [ $M -lt "12" ]
				then
					TR=$M/01/$YEAR%2000:00~$(($M+1))/01/$YEAR%2000:00
				else
					TR=$M/01/$YEAR%2000:00~$M/31/$YEAR%2023:59
				fi

				MONTH_VALUE=$(curl -s -H "$AUTH" "https://$APIGEE_API/v1/organizations/$ORG/environments/$ENV/stats?select=sum(message_count)&timeRange=$TR" | jq -r .environments[0].metrics[0].values[0])
				# Bug Fix start: Edge returns exponential value so pipe to jq to convert to an integer, drop any ".0" or convert 4.7025005E7 to 47025005
				if [ "$MONTH_VALUE" == "null" ] || [ -z "$MONTH_VALUE" ]
				then
					MONTH_VALUE=0
				else
					MONTH_VALUE=$(echo "$MONTH_VALUE" | jq -r 'if . == null then 0 else floor end' 2>/dev/null)
					MONTH_VALUE=${MONTH_VALUE:-0}
				fi
				# Bug Fix end
				ENV_TOTAL=$(( $ENV_TOTAL + $MONTH_VALUE ))
				ENV_USAGE="${ENV_USAGE}${MONTH_VALUE},"
			fi
		done
		# Remove trailing , from last run through the loop
		ENV_USAGE="${ENV_USAGE%?}"
		if [ $SHOW_MONTH_COUNT == true ]
		then
			ENV_USAGE="{\"name\":\"${ENV}\",${ENV_USAGE}],\"total\":${ENV_TOTAL}}"
		else
			ENV_USAGE="{\"name\":\"${ENV}\",\"total\":${ENV_TOTAL}}"
		fi
		ShowProgress "ENV_USAGE: $ENV_USAGE"
		ORG_USAGE="${ORG_USAGE}${ENV_USAGE},"
		ORG_TOTAL=$(( $ORG_TOTAL + $ENV_TOTAL ))
	fi
done
# Output to stderr to show progress
ShowProgress "ORG_TOTAL: $ORG_TOTAL"
# Remove trailing , from last run through the loop
ORG_USAGE="${ORG_USAGE%?}"
ORG_USAGE="${ORG_USAGE}],\"total\":${ORG_TOTAL}}"
echo $ORG_USAGE
