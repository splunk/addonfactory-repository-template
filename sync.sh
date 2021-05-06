#!/bin/bash
# echo all the commands 
set -x 


BRANCH=$(git rev-parse --abbrev-ref HEAD -- | head -n 1)
INPUTFILE=repositories_$BRANCH.csv
echo Working branch $BRANCH - $INPUTFILE
REPOORG=splunk
if [[  $GITHUB_USER && ${GITHUB_USER-x} ]]
then
    echo "GITHUB_USER Found"
else
    echo "GITHUB_USER Not found"
    exit 1
fi
if [[  $GITHUB_TOKEN && ${GITHUB_TOKEN-x} ]]
then
    echo "GITHUB_TOKEN Found"
else
    echo "GITHUB_TOKEN Not found"
    exit 1
fi
if [[  $CIRCLECI_TOKEN && ${CIRCLECI_TOKEN-x} ]]
then
    echo "CIRCLECI_TOKEN Found"
else
    echo "CIRCLECI_TOKEN Not found"
    exit 1
fi

command -v hub >/dev/null 2>&1 || { echo >&2 "I require hub but it's not installed.  Aborting."; exit 1; }
command -v gh >/dev/null 2>&1 || { echo >&2 "I require gh but it's not installed.  Aborting."; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "I require git but it's not installed.  Aborting."; exit 1; }
command -v crudini >/dev/null 2>&1 || { echo >&2 "I require crudini but it's not installed.  Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo >&2 "I require rsync but it's not installed.  Aborting."; exit 1; }

while IFS=, read -r REPO TAID REPOVISIBILITY TITLE BRANCH OTHER || [ -n "$REPO" ]
do
    echo "Working on:$REPO|$TAID|$REPOVISIBILITY|$TITLE|$BRANCH|$OTHER"
    #Things we want to do no matter what
    #Create RP Project
    curl -X POST "$RP_ENDPOINT/api/v1/project" -H "accept: */*" -H "Content-Type: application/json" -H "Authorization: bearer $RP_UUID" -d "{ \"entryType\": \"INTERNAL\", \"projectName\": \"${REPO}\"}" || true
    #Assign service and admin accounts note if this has already been done an error will be returned indicating can not be done twice
    curl -X PUT  "$RP_ENDPOINT/api/v1/project/${REPO}/assign" -H "accept: */*" -H "Content-Type: application/json" -H "Authorization: bearer $RP_UUID" -d "{ \"userNames\": { \"circleci\": \"PROJECT_MANAGER\" }}"  || true
    curl -X PUT  "$RP_ENDPOINT/api/v1/project/${REPO}/assign" -H "accept: */*" -H "Content-Type: application/json" -H "Authorization: bearer $RP_UUID" -d "{ \"userNames\": { \"default\": \"PROJECT_MANAGER\" }}"  || true
    #Conditional work
    if ! gh repo view $REPOORG/${REPO} >/dev/null
    then
        rm -rf work/$REPO
        echo Repository is new
        mkdir -p work/$REPO || true
        pushd work/$REPO
        rsync -avh --include ".*" ../../seed/ .
        rsync -avh --include ".*" ../../enforce/ .

        crudini --set package/default/app.conf launcher description "$TITLE"
        crudini --set package/default/app.conf ui label "$TITLE"
        crudini --set package/default/app.conf package id $TAID
        crudini --set package/default/app.conf id name $TAID

        tmpf=$(mktemp)
        jq --arg TITLE "${TITLE}" '.info.title = $TITLE' package/app.manifest >$tmpf
        mv -f $tmpf package/app.manifest
        tmpf=$(mktemp)
        jq --arg TITLE "${TITLE}" '.info.description = $TITLE' package/app.manifest >$tmpf
        mv -f $tmpf package/app.manifest
        jq --arg TAID "${TAID}" '.info.id.name = $TAID' package/app.manifest >$tmpf
        mv -f $tmpf package/app.manifest

        git init
        git config  user.email "addonfactory@splunk.com"
        git config  user.name "Addon Factory template"
        git submodule add https://github.com/$REPOORG/addonfactory_test_matrix_splunk.git deps/build/addonfactory_test_matrix_splunk
        git submodule add https://github.com/$REPOORG/addonfactory-splunk_sa_cim.git deps/apps/Splunk_SA_CIM
        git submodule add https://github.com/$REPOORG/addonfactory-splunk_env_indexer.git deps/apps/splunk_env_indexer

        git add .
        git commit -am "base"
        git tag -a v0.2.0 -m "CI base"

        hub create -p $REPOORG/$REPO
        hub api orgs/$REPOORG/teams/products-shared-services-all/repos/$REPOORG/$REPO --raw-field 'permission=maintain' -X PUT
        hub api orgs/$REPOORG/teams/productsecurity/repos/$REPOORG/$REPO --raw-field 'permission=read' -X PUT
        hub api orgs/$REPOORG/teams/products-gdi-addons/repos/$REPOORG/$REPO --raw-field 'permission=maintain' -X PUT
        hub api orgs/$REPOORG/teams/products-gdi-addons-adminrepo/repos/$REPOORG/$REPO --raw-field 'permission=admin' -X PUT
        hub api orgs/$REPOORG/$REPO -X PATCH --field default_branch=main
        hub api /repos/$REPOORG/$REPO --raw-field 'visibility=${REPOVISIBILITY}' -X PATCH
        hub api /repos/$REPOORG/$REPO  -H 'Accept: application/vnd.github.nebula-preview+json' -X PATCH -F visibility=$REPOVISIBILITY
        echo "Adding branch protection"
        hub api -X PATCH -H "Accept: application/vnd.github.v3+json" /repos/$REPOORG/$REPO/branches/main/protection --raw-field '{"dismissal_restrictions": {},"dismiss_stale_reviews": false,"require_code_owner_reviews": true,"required_approving_review_count": 1}'

        curl -X POST https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/follow?circle-token=${CIRCLECI_TOKEN}
        curl -X POST --header "Content-Type: application/json" -d '{"type":"github-user-key"}' https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/checkout-key?circle-token=${CIRCLECI_TOKEN}
        curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"GH_USER\", \"value\":\"${GITHUB_USER}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}
        curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"GITHUB_TOKEN\", \"value\":\"${GITHUB_TOKEN}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}

        git remote set-url origin https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$REPOORG/$REPO.git
        git push --set-upstream origin main
        git tag -a v$(crudini --get package/default/app.conf launcher version) -m "Release"
        git push --follow-tags
        git checkout -b develop
        git push --set-upstream origin develop

    else
        echo Repository is existing
        
        hub api repos/$REPOORG/$REPO --raw-field 'visibility=${REPOVISIBILITY}' -X PATCH || true
        
        echo "adding permission for teams"
        hub api orgs/$REPOORG/teams/products-gdi-addons/repos/$REPOORG/$REPO --raw-field 'permission=maintain' -X PUT
        hub api orgs/$REPOORG/teams/products-gdi-addons-adminrepo/repos/$REPOORG/$REPO --raw-field 'permission=admin' -X PUT
        echo "Adding branch protection"
        hub api -X PUT -H "Accept: application/vnd.github.v3+json" /repos/$REPOORG/$REPO/branches/main/protection --raw-field '{"dismissal_restrictions": {},"dismiss_stale_reviews": false,"require_code_owner_reviews": true,"required_approving_review_count": 1}'
        # hub api -X PATCH -H "Accept: application/vnd.github.v3+json" /repos/splunk/addonfactory-repository-template/environments/test_environment --raw-field '{"reviewers": [{"type": "User", "id": 60528866}]}'
        curl -X PATCH -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/splunk/addonfactory-repository-template/environments/test_environment -d '{"reviewers": [{"type": "User", "id": 60528866}]}'
        curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/splunk/addonfactory-repository-template/environments
        if [ ! -d "$REPO" ]; then
            #hub clone $REPOORG/$REPO work/$REPO
            git clone https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$REPOORG/$REPO.git work/$REPO
            pushd work/$REPO
            git checkout develop
        else
            pushd work/$REPO
            git pull
        fi
        git config  user.email "addonfactory@splunk.com"
        git config  user.name "Addon Factory template"

        ( git checkout test/common-template-rollout-changes  && git checkout develop && git branch -D test/common-template-rollout-changes ) || true
        git checkout -B "test/common-template-rollout-changes" $BRANCH
        # Changing global URLs from SSH to using HTTPS so that script does not fail
        git config --global url.https://github.com/.insteadOf git@github.com:
        git submodule update --init --recursive
        #fi
        rsync -avh --include ".*" --ignore-existing ../../seed/ .
        rsync -avh --include ".*" ../../enforce/ .




        #Cleanup of bad module
        # Remove the submodule entry from .git/config
        git submodule deinit -f deps/script || true
        # Remove the submodule directory from the superproject's .git/modules directory
        rm -rf .git/modules/deps/script || true

        # Remove the entry in .gitmodules and remove the submodule directory located at path/to/submodule
        git rm -f deps/script || true
        #Updates for pytest-splunk-add-on >=1.2.2a1
        if [ ! -d "tests/data" ]; then
            mkdir -p tests/data
        fi
        if [ -f "tests/data/wordlist.txt" ]; then
            git rm tests/data/wordlist.txt
        fi
        if [ -f "package/default/eventgen.conf" ]; then
            git mv package/default/eventgen.conf tests/data/eventgen.conf
        fi
        if [ -d "package/samples" ]; then
            git mv package/samples tests/data/samples
        fi
        if [ -d ".dependabot" ]; then
            git rm -rf .dependabot
        fi
        if [ -d "deps/apps/splunk_env_indexer" ]; then
            git submodule deinit -f deps/apps/splunk_env_indexer
            rm -rf .git/modules/deps/apps/splunk_env_indexer
            git rm -f deps/apps/splunk_env_indexer
            git add deps/apps/splunk_env_indexer
            git commit -m "Deprecate splunk_env_indexer submodule"
        fi       
        if [[ -f "requirements.txt" ]]; then
          mkdir -p package/lib || true
          git mv requirements.txt package/lib/
        fi
        if [[ -f "requirements_py2.txt" ]]; then
          mkdir -p package/lib/py2 || true
          git mv requirements.txt package/lib/py2/
        fi        
        if [[ -f "requirements_py3.txt" ]]; then
          mkdir -p package/lib/py3 || true
          git mv requirements.txt package/lib/py3/
        fi
        if [[ -f "splver.py" ]]; then
          git rm splver.py
        fi
        if [[ -f "packagingScript.sh" ]]; then
          git rm packagingScript.sh          
        fi
        git rm splunk_add_on_ucc_framework-* || true        
        if [[ -f "build.sh" ]]; then
          git rm build.sh          
        fi
        if [ -d "deps/build/disable_popup" ]; then
            git rm -f deps/build/disable_popup
            git submodule update --remote --merge deps/build/addonfactory_test_matrix_splunk
            git add deps/build/disable_popup
            git commit -m "Deprecate disable_popup"
        fi
        if [[ -d "tests/data" ]]; then
            mkdir -p tests/knowledge || true
            git mv tests/data/* tests/knowledge
        fi
        if [[ -f "tests/knowledge/requirements.txt" ]]; then
            git rm tests/knowledge/requirements.txt || true
        fi
        if [[ -f "tests/knowledge/wordlist.txt" ]]; then
            git rm tests/knowledge/wordlist.txt || true
        fi
        if [[ -f "tests/ui/requirements.txt" ]]; then
            git rm tests/ui/requirements.txt || true
        fi     
        if [[ -f "tests/pytest.ini" ]]; then
            git rm tests/pytest.ini || true
        fi
        if [[ -f "tests/test_addon.py" ]]; then
            git rm tests/test_addon.py || true
        fi
        if [[ -f "tests/__init__.py" ]]; then
            git rm tests/__init__.py || true
        fi
        if [[ -f "tests/pytest-ci.ini" ]]; then
            git rm tests/pytest-ci.ini || true
        fi
        if [[ -f "tests/conftest.py" ]]; then
            git rm tests/conftest.py || true
        fi
        if [[ -f "tests/requirements.txt" ]]; then
            git rm tests/requirements.txt || true
        fi
        if [[ -f "requirements.txt" ]]; then
            git rm requirements.txt || true
        fi
        if [[ -f ".python-version" ]]; then
            git rm .python-version || true
        fi
        if [[ -f "tests/backend_entrypoint.sh" ]]; then
            git rm tests/backend_entrypoint.sh || true
        fi        
        if [[ -d "tests/ui" ]]; then
            rsync -avh --include ".*" ../../conditional/ .
        fi
        git add . || true
        git commit -am "test: common template rollout changes" || true

        git push -f --set-upstream origin test/common-template-rollout-changes
        hub pull-request -b $BRANCH "Bump repository configuration from template" --no-edit
        hub api /repos/$REPOORG/$REPO  -H 'Accept: application/vnd.github.nebula-preview+json' -X PATCH -F visibility=$REPOVISIBILITY

    fi
    popd
done < $INPUTFILE
