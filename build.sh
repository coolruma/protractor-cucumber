#!/bin/bash
# set -x
set -e
set -o pipefail
trap "on-exit" EXIT

basedir=$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd )
source $basedir/common.sh

ddsBasicAuth="Basic YmZzX2FwaWdhdGV3YXlfMDE6RDNmdEBwaQ=="
batchAuth="Basic YmZzX2JhdGNoXzAxOnplcjAtZW50cm9weQ=="
xeroAPIAuth="Basic bG9iUnZlVkRxZHhpc3FUbzE4RnRHcEppc0RjQXdqVVQ6RWhvekFYN3JWV3dBamc5NA=="
# proxy=${http_proxy:-"http://proxy.pilot.deft.bfsbanking.syd.non.c1.macquarie.com:3129"}
proxy="http://proxy.pilot.deft.bfsbanking.syd.non.c1.macquarie.com:3129"
read proxysvr proxyport <<< $(echo $proxy | sed 's~.\+://\([^:]\+\):\(.\+\)$~\1 \2~g')
echo "using proxy $proxysvr on $proxyport"
noproxy="--noproxy .macquarie.com"
http_noproxy="localhost|appserver.*|*.internal.macquarie.com|*.macquarie.com"
log=/tmp/build.log
nextYear=`date -d next-year +%Y`
next2Years=`date -d "+2 years" +%Y`
visa_card=45455674576
card_ccv=222
amex_card=378282246310005
amex_card_cvv=1234
diners_club_card=30123456789019
diners_club_card_cvv=123
master_card=5142500000000023
master_card_cvv=123

function on-exit () {
    ev=$?
    if [[ $ev -ne 0 ]]; then
        cat $log
    fi
    exit $ev
}

# env configs
function getAccessToken () {
    accessToken=$(curl -A 'rester' -k -x $proxy $noproxy -u$1 -H'Content-Type:application/json' -qs -XPOST "$urlV2/auth/accessToken?grant_type=client_credentials" -d '{}' -o- | tee $log | jq -r '.access_token')
    if [[ $? -ne 0 ]]; then
        echo "failed creating access token with $1" >> $log
        exit 1;
    fi
    echo "Bearer $accessToken"
}

function getApigeeJWT () {
    jwt=$(curl -A 'rester' -k -x $proxy $noproxy -u$1 -qs -H'Content-Type:application/json' -XPOST "$urlV2/auth/token?ttl=3600000&grant_type=client_credentials&subject=$2" -d '' -o- | tee $log | jq -r '.token')
    if [[ $? -ne 0 ]]; then
        echo "failed creating JWT with $1 for $2" >> $log
        exit 1;
    fi
    echo "$jwt"
}

function getDDSJWT () {
    jwt=$(curl -A 'rester' -x "" -H"Authorization: $ddsBasicAuth" -H'Content-Type:application/json' -qs -XPOST "$urlV2/auth/token?ttl=3600000&subject=$1" -d '' -o- | tee $log | jq -r '.token')
    if [[ $? -ne 0 ]]; then
        echo "failed creating DDS JWT for $1" >> $log
        exit 1;
    fi
    echo "$jwt"
}
function getXeroAccessToken () {
    #xeroaccessToken=$(curl -x "" -H'grant_type:client_credentials' -H'Content-Type:application/json' -H"Username: lobRveVDqdxisqTo18FtGpJisDcAwjUT" -H"Password: EhozAX7rVWwAjg94" $proxy $noproxy -qs -XPOST "$url/api/partner/xero/v1/token" -d '{}' -o- | tee $log | jq -r '.access_token')
    xeroaccessToken=$(curl -k -x $proxy $noproxy -qs -H'grant_type:client_credentials' -H'Content-Type:application/json' -H"Authorization: $xeroAPIAuth" -XPOST "$url/api/partner/xero/v1/token" -d '{}' -o- | tee $log | jq -r '.access_token')
    if [[ $? -ne 0 ]]; then
        echo "failed creating access token for xero/v1" >> $log
        exit 1;
    fi
    echo "Bearer $xeroaccessToken"
}

function mod9num () {
    prefix=$1
    weights=(2 3 5 7 11 13 1 2 3 5)
    sum=0 && i=0 && len=${#prefix} && while [[ $i -lt $len ]]
        do
            digit=${prefix:$(($len - i -1)):1}
            value=$(($digit * ${weights[$i]}))
            sum=$(($sum + $value))
            i=$(($i + 1))
        done

    rem=$(($sum % 9))
    if [ $rem -eq 0 ]; then
        echo "${prefix}0"
    else
        echo "$prefix$((9 - $rem))"
    fi
}

function rndLunhNumber () {
    rand=$(< /dev/urandom tr -dc 0-9 | head -c7)
    prefix=${rand##+(0)}
    sum=0 && i=0 && len=${#prefix} && while [[ $i -lt $len ]]
        do
            digit=${prefix:$(($len - i -1)):1}
            value=$(($digit * (2 - $i % 2)))
            [[ $value -gt 9 ]] && sum=$(($sum + $value - 9)) || sum=$(($sum + $value))
            i=$(($i + 1))
        done
    rem=$(($sum % 10))
    echo "$prefix$(($rem == 0 ? 0 : 10 - $rem))"
}

function mkLongDrn () {
    rand=$(< /dev/urandom tr -dc 0-9 | head -c5)
    prefix=${rand##+(0)}
    echo "$1$(mod9num $prefix)"
}

function setTestUsers () {
    mglTestUser="api_test_mgl_user"
    case $target in
        dev|sit|uat)
            mglRoleAdmUser="dev.role.admin@macquarie.com"
            mglUserAdmUser="abhijeet.davids.dev@macquarie.com"
            mglOpsUser="dev.service.operations@macquarie.com"
            payerUserName1="payer1"
            payerUserName2="payer2"
            xero="Xero"
            ;;
        svp|nft)
            mglRoleAdmUser="nkraljev"
            mglUserAdmUser="rthekkad"
            mglOpsUser="sflak"
            payerUserName1="61864959"
            payerUserName2="64470623"
            xero="Xero"
            ;;
        sandbox)
            mglRoleAdmUser="nkraljev"
            mglUserAdmUser="rthekkad"
            mglOpsUser="sflak"
            payerUserName1="payer1"
            payerUserName2="payer2"
            ddsBasicAuth="Basic YmZzX2FwaWdhdGV3YXlfMDE6RDNGVEdAdDN3"
            ;;
        *)
            echo "unsupported target $target"
            ;;
    esac
}
# baseUrl="https://api.dev.deft.com.au"
# token=$(getAccessToken "LRAO5QhwIwuMxGeaA0atlyuclXRfmbM5:LUWSD7u9DSu4e4EY")
# echo "token -> $token"
# exit

function setApigeeTokens () {
    #    apiAuth="Bearer MUAkOWnN0xpnrbBL6FoscgT9PcnU"
    # apiAggAuth="Bearer Hm6m7d8Be1EgBOUjcWyQdKoz5qE9"
    oldApiUsername=LJHooker
    oldApiPassword=Password
    oldApiTestUser=DEFT1234
    oldApiTestPass=L33TPL@Y3R

    mglTestUserToken=$(getApigeeJWT "Aq6qydZPBj4oyv0VcL3HtMRFR371GrBI:Brb3lbeYHLTV8hxN" "$mglTestUser")

    case $target in
        dev|sit|uat)
            legacyApiAuth=$(getAccessToken "kDogQOXM2BfKo7GywbImRcJHhDWRJ5v7:bL6vaBv1qxobLDaV") # DEFT-Legacy-API-Consumer
            apiBillerAuth=$(getAccessToken "2XhQwAFE0zQGmFenPMGCSdPDnYASibrk:VbUyEWnLoTSdwJKW") # DEFT-Basic-Api-Consumer
            personalAuth=$(getAccessToken "zHCMyAie3gYKYjx6KYBvnzqU8UybgGf2:U7YGRDNr1pHWTWwb") # BFS - DEFT - Payer Portal Application
            payonceAuth=$(getAccessToken "GqgZgJOviz2SKy0N1UF2O5WqidvyCgbo:Wx3wjEDsanTKq5b6") # BFS - DEFT - Payonce Application
            regoAuth=$(getAccessToken "GqgZgJOviz2SKy0N1UF2O5WqidvyCgbo:Wx3wjEDsanTKq5b6") # BFS - DEFT - Registration Application
            mglAuth=$(getAccessToken "Aq6qydZPBj4oyv0VcL3HtMRFR371GrBI:Brb3lbeYHLTV8hxN") # BFS - DEFT - MGL Admin Application
            ivrAuth=$(getAccessToken "5qAOPl6XEKMERzV3xwGklyssPd6DTpj7:KgmW9o3aGFkjAsat") # BFS - DEFT - IVR App
            auctionAuth=$(getAccessToken "mVUdAWFwDsz2dpODtCuZ4zKGikGoASAM:cGrGdwCtimBKw1uN") # BFS - DEFT - AuctionPay App
            personalCred="Basic $(echo -n 'zHCMyAie3gYKYjx6KYBvnzqU8UybgGf2:U7YGRDNr1pHWTWwb'| base64)"
            apiAggAuth=$(getAccessToken "MaE0Z2v0PRamW92wjAhg7qFRyQAhcR3e:8Gpa8unmIrbG06Ar") #DBFS-DEFT-API-Aggregator-Consumer
            apiDdaAuth=$(getAccessToken "wWGDPJW3GgomaKYH17GorRh4Z0AQZYJC:tfOhwNtc4Z6Yxxat") #DBFS-DEFT-API-DDA-Payment
            # mgl user JWT -> X-XSRF-TOKEN
            mglRoleAdm=$(getApigeeJWT "Aq6qydZPBj4oyv0VcL3HtMRFR371GrBI:Brb3lbeYHLTV8hxN" "$mglRoleAdmUser")
            mglUserAdm=$(getApigeeJWT "Aq6qydZPBj4oyv0VcL3HtMRFR371GrBI:Brb3lbeYHLTV8hxN" "$mglUserAdmUser")
            mglOps=$(getApigeeJWT "Aq6qydZPBj4oyv0VcL3HtMRFR371GrBI:Brb3lbeYHLTV8hxN" "$mglOpsUser")
            payerUser=$(getApigeeJWT "zHCMyAie3gYKYjx6KYBvnzqU8UybgGf2:U7YGRDNr1pHWTWwb" "$payerUserName1")
            payerUser2=$(getApigeeJWT "zHCMyAie3gYKYjx6KYBvnzqU8UybgGf2:U7YGRDNr1pHWTWwb" "$payerUserName2")
            xeroAuth=$(getXeroAccessToken)
            #        billerUser=$(getApigeeJWT  "james.smith@gmail.com") # biller portal user
            ;;
        svp|nft)
            legacyApiAuth=$(getAccessToken "2BEgP21hWXwffjEtXoAOetHMBIjmtzwG:xHSPsMpdElzwslaP") # DEFT-Legacy-API-Consumer - SVP
            apiBillerAuth=$(getAccessToken "5q7m0yMvg0mTY5p8hitUZAWkGICjj04V:MpvW7QmX0GnkOrkm") # DEFT-Basic-Api-Consumer - SVP
            personalAuth=$(getAccessToken "zGrE104QlrqD0XRpZIfd3Ls0PdLZ55eC:R3MqFMkkTPu8GqEl") # BFS - DEFT - Payer Portal Application - SVP
            payonceAuth=$(getAccessToken "a1z2PcPGTXAVveLtLReSBJN21eJo8iXd:fL6GzEzd0hgz5bsa") # BFS - DEFT - Payonce Application - SVP
            regoAuth=$(getAccessToken "b76dlVPpJkXkszjyZGIXCjZ9OIQKTFyB:0Q7KbAf0AtUA5qfN") # BFS - DEFT - Registration Application
            mglAuth=$(getAccessToken "EfIIAxoXUW1aKYRosUKlI9BU2qsu8rWC:DaGWNhXjclSGtY3n") # BFS - DEFT - MGL Admin Application - SVP
            ivrAuth=$(getAccessToken "RvpmkX1FWvbQO249Jn97CoIM1kmx5tqo:8iSiV3DJc8udegIB") # BFS - DEFT - IVR App - SVP
            auctionAuth=$(getAccessToken "MCR8zvDBmG9WMh8Ift5O7PrQMBebxqes:cCMNJHM1Tn2RAEtF") # BFS - DEFT - AuctionPay App - SVP
            personalCred="Basic $(echo -n 'zGrE104QlrqD0XRpZIfd3Ls0PdLZ55eC:R3MqFMkkTPu8GqEl'| base64)"
            apiAggAuth=$(getAccessToken "ta4wG7Hn5KWCl0oB6M7ySErYwKsObWrA:lhcjfdAbaFHeN3Gv") #DBFS-DEFT-API-Aggregator-Consumer - SVP
            # mgl user JWT -> X-XSRF-TOKEN
            mglRoleAdm=$(getApigeeJWT "EfIIAxoXUW1aKYRosUKlI9BU2qsu8rWC:DaGWNhXjclSGtY3n" "$mglRoleAdmUser")
            mglUserAdm=$(getApigeeJWT "EfIIAxoXUW1aKYRosUKlI9BU2qsu8rWC:DaGWNhXjclSGtY3n" "$mglUserAdmUser")
            mglOps=$(getApigeeJWT "EfIIAxoXUW1aKYRosUKlI9BU2qsu8rWC:DaGWNhXjclSGtY3n" "$mglOpsUser")
            payerUser=$(getApigeeJWT "zGrE104QlrqD0XRpZIfd3Ls0PdLZ55eC:R3MqFMkkTPu8GqEl" "$payerUserName1")
            payerUser2=$(getApigeeJWT "zGrE104QlrqD0XRpZIfd3Ls0PdLZ55eC:R3MqFMkkTPu8GqEl" "$payerUserName2")
            xeroAuth=$(getXeroAccessToken)
            ;;
        sandbox)
            legacyApiAuth=$(getAccessToken "${bamboo_LegacyAPIPassword}") # DEFT-Legacy-API-Consumer - SVP
            apiBillerAuth=$(getAccessToken "${bamboo_BasicAPIConsumerPassword}") # DEFT-Basic-Api-Consumer - SVP
            personalAuth=$(getAccessToken "${bamboo_PayerAppPassword}") # BFS - DEFT - Payer Portal Application - SVP
            payonceAuth=$(getAccessToken "${bamboo_PayonceAppPassword}") # BFS - DEFT - Payonce Application - SVP
            mglAuth=$(getAccessToken "${bamboo_MGLAppPassword}") # BFS - DEFT - MGL Admin Application - SVP
            ivrAuth=$(getAccessToken "${bamboo_IVRAPPPassword}") # BFS - DEFT - IVR App - SVP
            auctionAuth=$(getAccessToken "${bamboo_AuctionPayAppPassword}") # BFS - DEFT - AuctionPay App - SVP
            personalCred="Basic $(echo -n 'bamboo_PayerAppPassword'| base64)"
            apiAggAuth=$(getAccessToken "${bamboo_APIAggregatorPassword}") #DBFS-DEFT-API-Aggregator-Consumer - SVP
            # mgl user JWT -> X-XSRF-TOKEN
            mglRoleAdm=$(getApigeeJWT "${bamboo_MGLAppPassword}"  "$mglRoleAdmUser")
            mglUserAdm=$(getApigeeJWT "${bamboo_MGLAppPassword}"  "$mglUserAdmUser")
            mglOps=$(getApigeeJWT "${bamboo_MGLAppPassword}" "$mglOpsUser")
            payerUser=$(getApigeeJWT "${bamboo_PayerAppPassword}" "$payerUserName1")
            payerUser2=$(getApigeeJWT "${bamboo_PayerAppPassword}" "$payerUserName2")
            xeroAuth=$(getXeroAccessToken)
            oldApiUsername="DEFT1234"
            oldApiPassword="NsM8N82rePFSsTAs"
            oldApiTestUser=DEFT1234
            oldApiTestPass=NsM8N82rePFSsTAs
            ;;
        *)
            ;;
    esac

}

usage="Usage: $0 {apigee|dds|local|ALL} <test-cases-file|ALL> {dev|sit|uat|svp}"

function getVersion () {
    case "$1" in
        *v1*) echo "v1";;
        *v2*) echo "v2";;
        *v3*) echo "v3";;
        *) echo "";
    esac
}

function setVariables () {
    version=$(getVersion $1)
    J_OPTS="${JAVA_OPTS} -DproxySet=true -DproxyHost=$proxysvr -DproxyPort=$proxyport -Dhttp.nonProxyHosts=$http_noproxy"
    case $server in
        dds)
            url="http://appserver.${target}.deft.bfsbanking.syd.non.c1.macquarie.com/gateway/$version"
            urlV1="http://appserver.${target}.deft.bfsbanking.syd.non.c1.macquarie.com/gateway/v1"
            urlV2="http://appserver.${target}.deft.bfsbanking.syd.non.c1.macquarie.com/gateway/v2"
            skip=dds
            ;;
        local)
            [[ -z "$HOST" ]] && {
                HOST=localhost
            }
            url="http://$HOST:8280/gateway/$version"
            urlV1="http://$HOST:8280/gateway/v1"
            urlV2="http://$HOST:8280/gateway/v2"
            skip=dds
            ;;
        apigee)
            case $mpcMode in
                true)
                    if [[ "$version" = "v1" || "$version" = "" ]]; then
                        url="https://deft${target}.uat.apigeedmz.digitalplatforms.syd.non.c1.macquarie.com"
                    else
                        url="https://deft${target}.uat.apigeedmz.digitalplatforms.syd.non.c1.macquarie.com/$version"
                    fi
                    urlV1=$url
                    urlV2="https://deft${target}.uat.apigeedmz.digitalplatforms.syd.non.c1.macquarie.com/v2"
                    ;;
                *)
                    if [[ "$version" = "v1" || "$version" = "" ]]; then
                        url="https://api.${target}.deft.com.au"
                    else
                        url="https://api.${target}.deft.com.au/$version"
                    fi
                    urlV1=$url
                    urlV2="https://api.${target}.deft.com.au/v2"
                    ;;
            esac
            setApigeeTokens
            authHeader=$apiAuth
            basicHeader="Basic ekhDTXlBaWUzZ1lLWWp4NktZQnZuenFVOFV5YmdHZjI6VTdZR1JETnIxcEhXVFd3Yg=="
            schedulePath="payment-schedule/direct-debit"
            ddPaymentPath="payment/direct-debit"
            J_OPTS="${J_OPTS} -Dthread-pool-size=2"
            skip=apigee
            ;;
        *)
            echo $usage
            exit 1
    esac

    [[ "$server" == "apigee" ]] || {

        authHeader="$ddsBasicAuth"
        basicHeader="$ddsBasicAuth"
        legacyApiAuth="$ddsBasicAuth"
        legacyApiAuth="$ddsBasicAuth"
        apiBillerAuth="$ddsBasicAuth"
        apiAggAuth=$ddsBasicAuth
        apiDdaAuth=$ddsBasicAuth
        personalAuth=$ddsBasicAuth
        payonceAuth=$ddsBasicAuth
        mglAuth=$ddsBasicAuth
        ivrAuth=$ddsBasicAuth
        personalCred=$ddsBasicAuth
        auctionAuth=$ddsBasicAuth

        mglTestUserToken=$(getDDSJWT "$mglTestUser")
        mglRoleAdm=$(getDDSJWT "$mglRoleAdmUser")
        mglUserAdm=$(getDDSJWT "$mglUserAdmUser")
        mglOps=$(getDDSJWT "$mglOpsUser")
        payerUser=$(getDDSJWT "$payerUserName1")
        payerUser2=$(getDDSJWT "$payerUserName2")
        schedulePath="payment-schedule"
        ddPaymentPath="transaction/direct-debit"
    }
}


function execFile () {
    testFile=$1
    rester=rester-beta28.jar
    [[ -f $rester ]] || {
        echo "downloading framework..."
        rm -f rester*.jar
        curl -x $proxy -kLo $rester "https://github.com/rinconjc/rester/releases/download/v0.1.0-beta28/rester.jar"
    }
    setTestUsers
    setVariables $testFile
    report="target/$server-${testFile%*.csv}-$version.xml"
    echo "running tests cases in ${testFile} against: $url"
    cat /dev/null > $log
    set +e
    java -Djava.util.logging.config.file=logging.properties ${J_OPTS} -jar $rester "${testFile}" :skip "$skip" \
         :report.file "$report" :baseUrl "$url" \
         :basicHeader "${basicHeader}" :authHeader "${authHeader}" :mglRoleAdm "$mglRoleAdm" :mglUserAdm "$mglUserAdm" :mglOps "$mglOps" \
         :payerUser "$payerUser" :payerUser2 "$payerUser2" :billerUser "$billerUser" :aggregatorAuth "$apiAggAuth" \
         :ljHookerAuth "$legacyApiAuth" :apiAggAuth "$apiAggAuth" :apiBillerAuth "$apiBillerAuth" \
         :baseUrlV1 "${urlV1}" :baseUrlV2 "${urlV2}" :schedulePath "$schedulePath" :personalAuth "$personalAuth" :ddPaymentPath "$ddPaymentPath" \
         :nextYear "$nextYear" :next2Years "$next2Years" :oldApiUsername "$oldApiUsername" :oldApiPassword "$oldApiPassword" \
         :oldApiTestUser "$oldApiTestUser" :oldApiTestPass "$oldApiTestPass" :personalCred "$personalCred" :apiDdaAuth "$apiDdaAuth" \
         :mglAuth "$mglAuth" :payonceAuth "$payonceAuth" :ivrAuth "$ivrAuth" :batchAuth "$batchAuth" :xeroAuth "$xeroAuth" :auctionAuth "$auctionAuth" \
         :dbcDRN "400028$(rndLunhNumber)" :ddaDRN "$(mkLongDrn 600000301)" :mglTestUser "$mglTestUserToken" \
         :encodedVisaCard "$(apcEncrypt $visa_card)" :encodedVisaCardCVV "$(apcEncrypt $card_ccv)" \
         :encodedAmexCard "$(apcEncrypt $amex_card)" :encoded_amex_card_cvv "$(apcEncrypt $amex_card_cvv)" \
         :encodedDinersClubCard "$(apcEncrypt $diners_club_card)" \
         :encoded_diners_club_card_cvv "$(apcEncrypt $diners_club_card_cvv)" \
         :encoded_master_card "$(apcEncrypt $master_card)" \
         :encoded_master_card_cvv "$(apcEncrypt $master_card_cvv)"

    count=$?
    errorCount=$((errorCount + count))
}

function execAll () {
    _server=$server

    function runIt () {
        echo "running tests in $f against $server"
        set -e
        execFile $f
    }

    for f in *.csv; do
        server=""
        case $f in
            *dds*)
                if [[ "$_server" == "ALL" || "$_server" == "dds" || "$_server" == "local" ]]; then
                    server=$([ "$_server" == "local" ] && echo local || echo dds)
                    runIt
                fi;;
            *apigee*)
                if [[ "$_server" == "ALL" || "$_server" == "apigee" ]]; then
                    server=apigee
                    runIt
                fi;;
            *)
                if [[ "$_server" == "ALL" || "$_server" == "dds" || "$_server" == "local" ]]; then
                    server=$([ "$_server" == "local" ] && echo local || echo dds)
                    runIt
                fi
                if [[ "$_server" == "ALL" || "$_server" == "apigee" ]]; then
                    server=apigee
                    runIt
                fi;;
        esac
    done;
}

server=$1
tests=$2
target=$3
build=$4

if [[ -z "$server" || -z "$tests" || -z "$target" ]]; then
    echo "$usage"
    exit 1
fi

if [[ "$target" = "prod" ]]; then
    echo "sorry testing against prod is not allowed!"
    exit 1
fi

errorCount=0

if [[ "$tests" == "ALL" ]]; then
    execAll
else
    execFile $tests
fi

if [[ $errorCount -gt 0 ]]; then
    touch target/failed
fi
