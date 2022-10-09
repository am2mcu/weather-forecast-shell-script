#!/bin/bash

API_URL="http://api.weatherapi.com/v1/forecast.json?key=$WEATHER_API_KEY&q="

a_flag=''
f_flag=''

print_usage() {
  echo "Usage: weather [city]" # TODO: complete usage message
}

while getopts 'a:f' flag; do
  case "${flag}" in
    a) a_flag='true'
       days="${OPTARG} " ;; # average (arg: days)
    f) f_flag='true' ;; # full weather broadcast
    *) print_usage
       exit 1 ;;
  esac
done
shift $(( OPTIND - 1 ))

if (($# == 0))
then
    print_usage
    exit 1 # aborting execution
fi

city=${1//' '/'%20'} # url encoding (space)
API_URL+=$city

# Check conectivity
if nc -zw1 google.com 443 2> /dev/null
then
  : # pass
else
  echo "No network"
  exit 1
fi

curl -s "$API_URL" > /tmp/retrieved-json

if [[ $(grep "error" /tmp/retrieved-json -om1) == 'error' ]] # TODO: iterates whole file when no error (not effective), find a better way
then
    echo "No matching location found."
    exit 1
fi

# retrieve json data
json_helper() {
  script=$(cat <<EOF
import sys, json
with open('/tmp/retrieved-json') as f:
    data = json.load(f)
for arg in sys.argv[1:]:
    if (type(data)==type([])):
      arg = int(arg)
    data = data[arg]
print(data)
EOF
)
  python3 -c "$script" "$@"
}

# default (when no flag)
current_weather() {
  printf '%s\n%s °C | %s °F\n%s%% (Humidity)\n' "$(json_helper current condition text)" "$(json_helper current temp_c)" "$(json_helper current temp_f)" "$(json_helper current humidity)"
}

# when f flag is set
detailed_weather() {
    printf '%s, %s, %s\n%s %s\n' "$(json_helper location name)" "$(json_helper location region)" "$(json_helper location country)" "$(json_helper location localtime)" "$(json_helper location tz_id)"
    current_weather
    printf '%s kph | %s mph (Wind speed)\n' "$(json_helper current wind_kph)" "$(json_helper current wind_mph)"
}

if [[ $f_flag ]]
then
    detailed_weather

    rm /tmp/retrieved-json
    exit 0
fi

if [[ $a_flag ]]
then
    API_URL+="&days=$days"
    curl -s "$API_URL" > /tmp/retrieved-json

    for (( i=0 ; i<days ; i++ ))
    do
      printf '%s\n%s\n' "$(json_helper forecast forecastday "$i" date)" "$(json_helper forecast forecastday "$i" day condition text)"
      printf '%s° C %s° C %s° C\n' "$(json_helper forecast forecastday "$i" day mintemp_c)" "$(json_helper forecast forecastday "$i" day maxtemp_c)" "$(json_helper forecast forecastday "$i" day avgtemp_c)"
      printf '%s° F %s° F %s° F\n' "$(json_helper forecast forecastday "$i" day mintemp_f)" "$(json_helper forecast forecastday "$i" day maxtemp_f)" "$(json_helper forecast forecastday "$i" day avgtemp_f)"
      printf '%s kph | %s mph\n' "$(json_helper forecast forecastday "$i" day maxwind_kph)" "$(json_helper forecast forecastday "$i" day maxwind_mph)"
      printf 'chance of rain: %s%%\n' "$(json_helper forecast forecastday "$i" day daily_chance_of_rain)"
      printf 'chance of snow: %s%%\n' "$(json_helper forecast forecastday "$i" day daily_chance_of_snow)"
      printf 'uv: %s\n' "$(json_helper forecast forecastday "$i" day uv)"
      printf '\n'
    done

    rm /tmp/retrieved-json
    exit 0
fi

current_weather

rm /tmp/retrieved-json
