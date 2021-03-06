#!/bin/bash
# Brainhole-level implementations for anonomous functions and more.
# TODO: add mktemp-dir-file-based GNU parallel impl for 
shopt -s extglob expand_aliases
argprint(){ printf '%q ' "$@"; }
# typeof _varname_
typeof(){ local _p _t _s; read _p _t _s <<< "$(declare -p "$1")"; echo "${_t:1}"; }
# typeof_ref _varname_
# typeof p == *n* => typeof_ref unref(p)
typeof_ref(){ :; }
# λ func-def <command>
# VARIABLES:
# _lambda_defs=(,[[:digits:]])*,	Defined lambda funcs
# _lambda_func=[[:digits:]]*    	Current lambda funname
# _lambda_head=_λ_	
# EXAMPLE:
# λ '{ ((${#1}==1)); }; echo lambda loaded' filter λ g
: ${_lambda_defs=_} ${_lambda_head=_λ_}
λ(){
	local _lambda_func _lambda_exit _lambda_body="$1"
	shift
	# Assign lambda
	while _lambda_func=$RANDOM; do
		[[ "$_lambda_defs" != *,${_lambda_func},* ]] && break
	done
	_lambda_defs+="${_lambda_func},"
	# Complete the function body
	# _lambda_body = ( commands ';'? ) | { commands; } | ((expr))
	case "${_lambda_body:0:1}" in
		(\(|\{) ;;
		(*) _lambda_body="{ $(_lambda_semi "$_lambda_body") }"
	esac
#	case "${_lambda_body::-1}" in
#		(\}|\)) ;;
#		(*)  warn ..HEY # Wow you want to do bad things
#	esac
	# Create the function in an evil way
	eval "$_lambda_head$_lambda_func()$_lambda_body"
	# Execute the command
	"$@"
	_lambda_exit=$?
	_lambda_defs="${_lambda_defs/${_lambda_func},}"
	unset -f $_lambda_head$_lambda_func
	return $_lambda_exit
}
_λ(){ "$_lambda_head$_lambda_func" "$@"; } # calls the current lambda func
alias lambda=λ _lambda=_λ
_lambda_semi(){ echo -n "$1"; [ "$1" == *\; ] || echo -n \;; }
# alias for Importing Lambdas
# todo split up lambda alloc-free for this to work happily
alias _lambda_funname_conv_1='
if [[ "$1" == @(λ|lambda)'>'* ]]; then
	local __lambda_import_body=${1#@(λ|lambda)>}
	printf "notimpl: lambda_func_imp_lit(){\\n%s\\n}" "$__lambda_import_body"
	return 3
fi'
# foreach funcname [array-args]
foreach(){
	[ "$1" ] || return 2
	_lambda_funname_conv_1
	local _fe_fun="$1" _mem
	shift
	for _mem; do "$_fe_fun" "$_mem"; done;
}
# filter funcname simple-array-name
filter(){
	[ "$2" ] || return 2
	_lambda_funname_conv_1
	declare -n _filter_arr="$2"
	local _fe_funname="_fe_$1"
	eval "${_fe_funname}(){ $(argprint "$1") \"\${_filter_arr[\$1]}\" || unset \"_filter_arr[\$1]\" }"
	foreach "$_fe_funname" "${!_filter_arr[@]}"
	unset _filter_tmparr $_fe_funname
}
# forall funcname args[] => (all? funcname? args)
# VARIABLES:
# _fa_index	The first occorance found to disobey funcname.
# _fa_exit	The exit val of the disobey.
forall(){
	[ "$2" ] || return 2
	_lambda_funname_conv_1
	local _fa_funname="$1" _fa_needle
	_fa_index=0
	shift
	for _fa_needle; do
		"$_fa_funname" "$_fa_needle" || ! _fa_exit=$? || break
		((++_fa_index))
	done
	((_fa_index==$#))
}
# forone funcname args[] => (not (all? (not funcname?) args))
# VARIABLES: _fa_index: The first occorance found to match funcname.
forone(){
	[ "$2" ] || return 2
	_lambda_funname_conv_1
	local _fo_fn="$1"; shift;
	! λ "{ ! $(argprint "$_fo_fn") \"\$@\"; }" forall λ "$@"
}
# map mapfun oldarr_name [newarr_name=oldarr_name]
map(){
	[ "$2" ] || return 2
	[ "$3" ] || set -- "$1" "$2" "$2"
	_lambda_funname_conv_1
	declare -n _map_old="$2" _map_new="$3"
	local _map_tmp=() _map_needle
	for _map_needle in "${!_map_old[@]}"; do
		_map_new["$_map_needle"]=("$("$1" "${_map_old[$_map_needle]}")")
	done
}
# reduce funname args[]
reduce(){
	[ "$1" ] || return 2
	_lambda_funname_conv_1
	local _reduce_cur _reduce_pre _reduce_fun="$1"
	shift
	for _reduce_cur; do
		_reduce_pre="$("$_reduce_fun" "$_reduce_pre" "$_reduce_cur")"
	done
	printf '%s' "$_reduce_pre"
}
return &>/dev/null # End Library
## BEGIN TEST
export PASS=$'\e[32mPASS\e[0m' FAIL=$'\e[31mFAIL\e[0m' TEST=$'\e[33mTEST\e[0m'
testpass(){ echo "$PASS	$*" >&2; ((pass++)); ((trys++)); }
testfail(){ echo "$FAIL	$*" >&2; ((trys++)); }
# testchk [expected retval=0]
testchk(){
	local testret="$testret" test="${BASH_LINENO[teststk]}	${test=$(argprint "$testprog" "${testargs[@]}")}" tchkret=$?
	: ${testret:=${1:-0}}
	case $tchkret in
		($testret)
			testpass "$test	$tchkret==$testret";;
		(*)
			testfail "$test	$tchkret!=$testret";;
	esac
}
# testcmd test-cmd[]
testcmd(){
    local testout teststk=1 test="$test"
	: ${test:=$(argprint "$@")}
	test="${test:0:22}"
	testout="$("$@")"
	testchk
	test="=> $testexp"
	if [[ "$test" != "$(head -n 1 <<< "$test")" ]]; then
		test="$(head -n 1 <<< "$test").."
	fi
	if ((testpat)); then
		[[ "$testout" == $testexp ]]
	else
		[[ "$testout" == "$testexp" ]]
	fi
	testchk 0
}
returns(){ return "$1"; }
testend(){ echo "$TEST	$_testname	$pass/$trys
"; }
testnew(){ echo "$TEST	$1"; _testname="$1"; pass=0; trys=0; }

testnew typeof
i=a
testexp=- testcmd typeof i
export i
testexp=x testcmd typeof i
testend
unset i

testnew lambda_illegal
for i in foreach filter forall forone map reduce; do
	"$i" λ f o o
	test="$i	λ_illegal" testchk 3
done
testend

testnew lambda_create
lp(){ echo "$_lambda_body"; }
test="λ '{ echo MISAKA \"$1\"; }; echo RAILGUN' foreach _λ a b c" \
testexp=$'RAILGUN\nMISAKA a\nMISAKA b\nMISAKA c' testcmd \
	λ '{ echo MISAKA "$1"; }; echo RAILGUN' \
		foreach _λ a b c
testexp=$'a\nb' testcmd \
	λ 'cut -d" " -f 1 <<< "$1"' \
		foreach _λ 'a b e' 'b c'
testexp="{ foo; }; :" testcmd \
	λ "{ foo; }; :" lp
testexp="((a))" testcmd \
	λ "((a))" lp
testexp="{ g; }" testcmd \
	λ g lp
testend

testnew mapreduce
from=(1 3 5 2 3) to=()
λ 'local i=$1; echo $((i*(i+5)))' map _λ from to
test='(1 3 5 2 3) -> i*(i+5)' testchk 0
test='reduce acc' testexp=118 testcmd \
	λ 'echo $(($1 + $2))' \
		reduce _λ "${to[@]}"
testend

testnew forall-forone
λ '(($1%2==0))' forall _λ "${to[@]}";	test='(all? odd? to)  ' testchk
λ '(($1%2==0))' forone _λ "${from[@]}";	test='(one? odd? from)' testchk
[ "$_fa_index" == 3 ];			test='=> $_fa_index == 3' testchk
testend
