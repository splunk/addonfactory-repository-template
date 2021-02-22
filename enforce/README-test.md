
# Run Addon tests with Docker in local Environment

### Prerequisitory:
- Git
- Python3 (>=3.7)
- Python2
- crudini
- Docker
- Docker-compose

## Steps:

1. Clone the repository
```bash
git clone git@github.com:splunk/<repo name>.git
cd <repo dir>
git submodule update --init --recursive
```

2. Install Requirements and Generate Addon
```bash
pip3 install -r requirements_dev.txt
ucc-gen

# Execute only if TEST_TYPE is modinput_functional or modinput_others
curl -s https://api.github.com/repos/splunk/splunk-add-on-for-modinput-test/releases/latest | grep "Splunk_TA.*tar.gz" | grep -v search_head | grep -v indexer | grep -v forwarder | cut -d : -f 2,3 | tr -d \" | wget -qi -; tar -xvzf *.tar.gz -C deps/apps/
```

3. Set Variables
```bash
export SPLUNK_VERSION=<splunk_version> [i.e. latest, 8.1.0]
export SPLUNK_APP_ID=$(crudini --get package/default/app.conf id name) [i.e. Splunk_TA_addon-name]
export SPLUNK_APP_PACKAGE=output/$(ls output/) [i.e. output/Splunk_TA_addon-name]
export TEST_TYPE=<knowledge|ui|modinput_functional|modinput_others>
export TEST_SET=tests/$TEST_TYPE [i.e. tests/knowledge]
export IMAGE_TAG="3.7-browsers"
export SC4S_VERSION=<sc4s_version> [i.e. latest, 1.51.0]

# If TEST_TYPE is ui also set the following variables
export TEST_BROWSER=<browser_name> [i.e. chrome, firefox]
export JOB_NAME=<LocalRun::[addon_name]-[browser]>
export SAUCE_USERNAME=<sauce_username>
export SAUCE_PASSWORD=<sauce_password>
export SAUCE_IDENTIFIER=$SAUCE_IDENTIFIER-$(cat /proc/sys/kernel/random/uuid)
export UI_TEST_HEADLESS="true"
```
**Note:** If TEST_TYPE is `modinput_functional`, `modinput_others` or `ui`, also set all variables in [test_credentials.env](test_credentials.env) file with appropriate values encoded with base64.

4. Docker Build and test execution:
```bash
docker-compose -f docker-compose.yml build

# Execute only if TEST_TYPE is ui
[ -z $BROWSER ] || [ "$UI_TEST_HEADLESS" = "true" ] || docker-compose -f docker-compose-ci.yml up -d sauceconnect

docker-compose -f docker-compose.yml up -d splunk
until docker-compose -f docker-compose.yml logs splunk | grep "Ansible playbook complete" ; do sleep 1; done
docker-compose -f docker-compose.yml up --abort-on-container-exit test
```
