#!/usr/bin/env bash

# Prepare environment

environment_file="$(pwd)/test/environment.sh"

if [ -e ${environment_file} ] ; then
	source ${environment_file}
	echo "Applied environment settings from ${environment_file}"
fi

export APPLICATION_NAME=${APPLICATION_NAME:-"Default"}

export NODE_ENV=${NODE_ENV:-"test"}
export DEBUG=${DEBUG:-"*,-express:*,-finalhandler,-follow-redirects,-mocha:*,-mquery,-retry-as-promised,-send"}

# Color codes

c_gray="\033[1;30m"
c_redd="\033[1;31m"
c_gree="\033[1;32m"
c_yell="\033[1;33m"
c_blue="\033[1;34m"
c_purp="\033[1;35m"
c_cyan="\033[1;36m"
c_whit="\033[1;37m"
c_norm="\033[0m"

# Print help

printUsage()
{
	echo "${0} [options]"
	echo
	echo -e "The '${c_cyan}check${c_norm}' phase:"
	echo
	echo -e " ${c_whit} --lint        ${c_norm} Run the linter script"
	echo
	echo -e "The '${c_cyan}test${c_norm}' phase:"
	echo
	echo -e " ${c_whit} --app         ${c_norm} Only test the application code"
	echo -e " ${c_whit} --db          ${c_norm} Only test database code"
	echo -e " ${c_whit} --libs        ${c_norm} Only execute library tests"
	echo -e " ${c_whit} --base        ${c_norm} Only test base modules"
	echo -e " ${c_whit} --api         ${c_norm} Only test API endpoints"
	echo -e " ${c_whit} --frontend    ${c_norm} Only execute frontend tests"
	echo
	echo "Other commands and parameters:"
	echo
	echo -e " ${c_whit} --kill-all    ${c_norm} Clean up leftover processes after E2E tests (like Chromedriver, Chrome, etc.)"
	echo "                 Terminates whole process group but does not touch (for example) user browsers"
	echo -e " ${c_whit} -h|--help     ${c_norm} Print this sermon"
	echo
	exit
}

### Process command line parameters and configure test suite

kill_e2e_processes=false

while [ $# -gt 0 ]; do	# Until you run out of parameters
	case "$1" in
		# General help
		-h)
			printUsage
			;;
		--help)
			printUsage
			;;

		# Checks to be run before the actual test suites
		--lint)
			do_not_test_all=true
			do_run_linters=true
			;;

		# Tests suites
		--app)
			do_not_test_all=true
			do_test_app=true
			;;
		--libs)
			do_not_test_all=true
			do_test_libs=true
			;;
		--base)
			do_not_test_all=true
			do_test_base=true
			;;
		--db)
			do_not_test_all=true
			do_test_database=true
			;;
		--api)
			do_not_test_all=true
			do_test_api=true
			;;
		--frontend)
			do_not_test_all=true
			do_test_frontend=true
			;;

		# Tags for Nightwatch tests
		--tags)
			shift
			if [ $# -lt 1 ]; then
				echo "The --tags parameter expects a following string declaring the test tags"
				exit 3
			fi
			IFS=',' read -r -a nightwatch_tags <<< "$1"
			;;

		# Other options
		--kill-all)
			kill_e2e_processes=true
			;;
	esac
	shift
done

# Clear screen and print intro

clear
echo -e "\033[38;1m#### ${APPLICATION_NAME} Test Suite ####\033[0m"
echo

### Global test runners, save return code

global_exit_code=0
number_of_executed_suites=0

### Generic test runner

genericScriptRunner()
{
	stage_type=${1}
	stage_name=${2}

	test_script_path="$(pwd)/test/${stage_type}_${stage_name}.sh"
	echo -e "${c_gray}${test_script_path}${c_norm}"
	if [ ! -e ${test_script_path} ] ; then return ; fi

	echo -e "Running ${stage_type}: \033[1;33m${stage_name}\033[0m"
	local_return_value=$?

	# Catch exit code
	if [ ${local_return_value} -ne 0 ] ; then
		global_exit_code=${local_return_value}
	fi
}

### Checks to be run before the actual test suites

checkLinter()
{
	if [ $global_exit_code -ne 0 ] || ($do_not_test_all && ! $do_test_app) ; then return ; fi
	genericScriptRunner "check" "linter"
}

### Test suites

testApplication()
{
	if [ $global_exit_code -ne 0 ] || ($do_not_test_all && ! $do_test_app) ; then return ; fi
	genericScriptRunner "test" "application"
}

testLibraries()
{
	if [ $global_exit_code -ne 0 ] || ($do_not_test_all && ! $do_test_libs) ; then return ; fi
	genericScriptRunner "test" "libraries"
}

testBaseSource()
{
	if [ $global_exit_code -ne 0 ] || ($do_not_test_all && ! $do_test_base) ; then return ; fi
	genericScriptRunner "test" "base"
}

testDatabase()
{
	if [ $global_exit_code -ne 0 ] || ($do_not_test_all && ! $do_test_database) ; then return ; fi
	genericScriptRunner "test" "database"
}

testAPI()
{
	if [ $global_exit_code -ne 0 ] || ($do_not_test_all && ! $do_test_api) ; then return ; fi
	genericScriptRunner "test" "api"
}

testFrontend()
{
	if [ $global_exit_code -ne 0 ] || ($do_not_test_all && ! $do_test_frontend) ; then return ; fi
	genericScriptRunner "test" "frontend"
}

### Execute all test suites

if [[ ! -z "${param// }" ]] ; then
	export NIGHTWATCH_TAGS=${nightwatch_tags}
fi

checkLinter
testLibraries
testBaseSource
testApplication
testDatabase
testAPI
testFrontend

### Return global exit code for CI service

echo
exit ${global_exit_code}
