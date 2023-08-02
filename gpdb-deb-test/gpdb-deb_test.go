package main

import (
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/cucumber/godog"
)

func gpdbDebHasCorrectMetadata() error {
	// get Homepage from debian package field and check it's reacheable
	homePage, err := GetDebField("Homepage", "gpdb_deb_installer/greenplum-db-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	if !CheckUrlReachable(homePage) {
		return fmt.Errorf("Homepage: %s is not reachable", homePage)
	}
	return nil
}

func gpdbInstalled() error {
	gpbdVersion, err := GetDebField("Version", "gpdb_deb_installer/greenplum-db-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	gpdbMajorVersion := strings.Split(gpbdVersion, ".")[0]
	return CheckPackageInstalled("greenplum-db-" + gpdbMajorVersion)
}

func ppaInstalledAsExpected() error {
	// get gpdbVersion
	gpbdVersion, err := GetDebField("Version", "gpdb_deb_installer/greenplum-db-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	// Remove package revision number
	gpbdVersion = strings.TrimSuffix(gpbdVersion, "-1")
	versionCmd := fmt.Sprintf("source /opt/greenplum-db-%s/greenplum_path.sh; postgres --gp-version", gpbdVersion)
	// postgres --gp-version has same Version from debian package
	cmd := exec.Command("/bin/bash", "-c", versionCmd)
	postgresGpbdVersion, err := cmd.Output()
	if err != nil {
		return err
	}
	if !strings.Contains(string(postgresGpbdVersion), string(gpbdVersion)) {
		return fmt.Errorf("postgres --gp-version: %s should contains %s", string(postgresGpbdVersion), string(gpbdVersion))
	}

	err = gpdb6GeneratedPythonBytecode(fmt.Sprintf("/opt/greenplum-db-%s/ext/python/lib/python2.7/cmd.py", gpbdVersion))
	if err != nil {
		return err
	}
	return nil
}

func gpdbInstalledAsExpected() error {
	// get gpdbVersion
	gpbdVersion, err := GetDebField("Version", "gpdb_deb_installer/greenplum-db-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	// /usr/local/greenplum-db is a link to greenplum-db-#{gpdb_version}
	linkDestination, err := os.Readlink("/usr/local/greenplum-db")
	if err != nil {
		return err
	}
	if linkDestination != filepath.Join("/usr/local", "greenplum-db-"+gpbdVersion) {
		return fmt.Errorf("/usr/local/greenplum-db links to %s != %s", linkDestination, filepath.Join("/usr/local", "greenplum-db-"+gpbdVersion))
	}
	// GPHOME is set
	gpHome, err := GetEnvFromGreenplumPathFile("/usr/local/greenplum-db/greenplum_path.sh", "GPHOME")
	if err != nil {
		return err
	}
	if gpHome != "/usr/local/greenplum-db-"+gpbdVersion {
		return fmt.Errorf("GPHOME:%s is not set to %s", gpHome, "/usr/local/greenplum-db-"+gpbdVersion)
	}

	// postgres --gp-version has same Version from debian package
	cmd := exec.Command("/bin/bash", "-c", "source /usr/local/greenplum-db/greenplum_path.sh; postgres --gp-version")
	postgresGpbdVersion, err := cmd.Output()
	if err != nil {
		return err
	}
	if !strings.Contains(string(postgresGpbdVersion), string(gpbdVersion)) {
		return fmt.Errorf("postgres --gp-version: %s should contains %s", string(postgresGpbdVersion), string(gpbdVersion))
	}

	gpdbMajorVersion := strings.Split(gpbdVersion, ".")[0]
	if gpdbMajorVersion == "6" {
		err = CheckHasExpectedPythonBytecodeFileNumber()
		if err != nil {
			return err
		}
		err = gpdb6GeneratedPythonBytecode("/usr/local/greenplum-db/ext/python/lib/python2.7/cmd.py")
		if err != nil {
			return err
		}

		err = gpdb6GeneratedPythonBytecode("/usr/local/greenplum-db/lib/python/subprocess32.py")
		if err != nil {
			return err
		}
	} else if gpdbMajorVersion == "7" {
		err = gpdb7GeneratedPythonBytecode("/usr/local/greenplum-db/lib/python/pg.py")
		if err != nil {
			return err
		}
	}

	return nil
}

func CheckHasExpectedPythonBytecodeFileNumber() error {
	cmd := exec.Command("/bin/bash", "-c", "sort -o expected python2-compiled-file-list-ubuntu; find /usr/local/greenplum-db/ -name *.pyc | grep -v python3.9 | sort | diff -uw - expected")
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("expect has there is no diff for python2 pyc file name list, actual is %s", strings.TrimSpace(string(output)))
	}

	cmd = exec.Command("/bin/bash", "-c", "sort -o expected python3-compiled-file-list; find /usr/local/greenplum-db/ext/python3.9/ -name *.pyc | sort | diff -uw - expected")
	output, err = cmd.Output()
	if err != nil {
		return fmt.Errorf("expect has there is no diff for python3.9 pyc file name list, actual is %s", strings.TrimSpace(string(output)))
	}
	return nil
}

func gpdb7GeneratedPythonBytecode(fileName string) error {
	// Check that vendored .pyc files were created after their associated .py files

	pyFile, err := os.Stat(fileName)
	if os.IsNotExist(err) {
		return fmt.Errorf(pyFile.Name() + " should exist")
	}
	lastInd := strings.LastIndex(fileName, "/")
	pycNameInd := strings.LastIndex(fileName[lastInd+1:], ".")
	pycFile, err := os.Stat(fileName[:lastInd] + "/__pycache__/" + fileName[lastInd+1:][:pycNameInd] + ".cpython-36" + ".pyc")
	if os.IsNotExist(err) {
		return fmt.Errorf(pycFile.Name() + " should exist")
	}
	if pycFile.ModTime().Before(pyFile.ModTime()) {
		return fmt.Errorf(pycFile.Name() + " should have modified time after " + pyFile.Name())
	}
	return nil
}

func gpdb6GeneratedPythonBytecode(fileName string) error {
	// Check that vendored .pyc files were created after their associated .py files

	pyFile, err := os.Stat(fileName)
	if os.IsNotExist(err) {
		return fmt.Errorf(pyFile.Name() + " should exist")
	}
	pycFile, err := os.Stat(fileName + "c")
	if os.IsNotExist(err) {
		return fmt.Errorf(pycFile.Name() + " should exist")
	}
	if pycFile.ModTime().Before(pyFile.ModTime()) {
		return fmt.Errorf(pycFile.Name() + " should have modified time after " + pyFile.Name())
	}
	return nil
}

func gpdbLinkRemovedAsExpected() error {
	_, err := os.Stat("/usr/local/greenplum-db")
	if os.IsNotExist(err) {
		return nil
	}
	return fmt.Errorf("/usr/local/greenplum-db should not exist")
}

func ppaRemovedAsExpected() error {
	// get gpdbVersion
	gpbdVersion, err := GetDebField("Version", "gpdb_deb_installer/greenplum-db-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	_, err = os.Stat("/opt/greenplum-db-6-" + gpbdVersion)
	if os.IsNotExist(err) {
		return nil
	}
	return fmt.Errorf("/opt/greenplum-db-6-" + gpbdVersion + " should not exist")
}

func gpdbRemovedAsExpected() error {
	// get gpdbVersion
	gpbdVersion, err := GetDebField("Version", "gpdb_deb_installer/greenplum-db-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	_, err = os.Stat("/usr/local/greenplum-db-" + gpbdVersion)
	if os.IsNotExist(err) {
		return nil
	}
	return fmt.Errorf("/usr/local/greenplum-db-" + gpbdVersion + " should not exist")
}

func installGpdb() error {
	return InstallPackage("gpdb_deb_installer/greenplum-db-ubuntu-amd64.deb")
}

func installPreviousVersionGpdb() error {
	return InstallPackage("gpdb_deb_installer/previous-greenplum-db-ubuntu-amd64.deb")
}

func removeGpdb() error {
	gpbdVersion, err := GetDebField("Version", "gpdb_deb_installer/greenplum-db-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	gpdbMajorVersion := strings.Split(gpbdVersion, ".")[0]
	return RemovePackage("greenplum-db-" + gpdbMajorVersion)
}

func gpdbClientDebHasCorrectMetadata() error {
	// get Homepage from debian package field and check it's reacheable
	homePage, err := GetDebField("Homepage", "gpdb_client_deb_installer/greenplum-db-6-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	if !CheckUrlReachable(homePage) {
		return fmt.Errorf("Homepage: %s is not reachable", homePage)
	}
	// get Package from debian package field and it should equal to greenplum-db-clients
	pacakge, err := GetDebField("Package", "gpdb_client_deb_installer/greenplum-db-6-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	if pacakge != "greenplum-db-clients" {
		return fmt.Errorf("Package: %s != greenplum-db-clients", pacakge)
	}
	return nil
}

func gpdbClientInstalled() error {
	return CheckPackageInstalled("greenplum-db-clients")
}

func gpdbClientInstalledAsExpected() error {
	// get gpdb client debian Version
	gpdbClientVersion, err := GetDebField("Version", "gpdb_client_deb_installer/greenplum-db-6-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	// /usr/local/greenplum-db-clients is a link to /usr/local/greenplum-db-clients-#{gpdb_client_version}
	linkDestination, err := os.Readlink("/usr/local/greenplum-db-clients")
	if err != nil {
		return err
	}
	if linkDestination != "greenplum-db-clients-"+gpdbClientVersion {
		return fmt.Errorf("/usr/local/greenplum-db-clients links to %s != %s", linkDestination, "greenplum-db-clients-"+gpdbClientVersion)
	}
	// GPHOME_CLIENT is set
	gpClientHome, err := GetEnvFromGreenplumPathFile("/usr/local/greenplum-db-clients/greenplum_clients_path.sh", "GPHOME_CLIENTS")
	if err != nil {
		return err
	}
	if gpClientHome != "/usr/local/greenplum-db-clients-"+gpdbClientVersion {
		return fmt.Errorf("GPHOME_CLIENTS:%s is not set to %s", gpClientHome, "/usr/local/greenplum-db-clients-"+gpdbClientVersion)
	}

	if os.Getenv("GPDB_MAJOR_VERSION") == "7" {
		err = gpdb7GeneratedPythonBytecode("/usr/local/greenplum-db-clients/bin/gpload.py")
	} else {
		err = gpdb6GeneratedPythonBytecode("/usr/local/greenplum-db-clients/ext/python/lib/python2.7/cmd.py")
	}
	if err != nil {
		return err
	}

	return nil
}

func gpdbClientLinkRemovedAsExpected() error {
	_, err := os.Stat("/usr/local/greenplum-db-clients")
	if os.IsNotExist(err) {
		return nil
	}
	return fmt.Errorf("/usr/local/greenplum-db-clients should not exist")
}

func gpdbClientRemovedAsExpected() error {
	// get gpdb client debian Version
	gpdbClientVersion, err := GetDebField("Version", "gpdb_client_deb_installer/greenplum-db-6-ubuntu-amd64.deb")
	if err != nil {
		return err
	}
	_, err = os.Stat("/usr/local/greenplum-db-" + gpdbClientVersion)
	if os.IsNotExist(err) {
		return nil
	}
	return fmt.Errorf("/usr/local/greenplum-db-" + gpdbClientVersion + " should not exist")
}

func installGpdbClient() error {
	return InstallPackage("gpdb_client_deb_installer/greenplum-db-6-ubuntu-amd64.deb")
}

func removeGpdbClient() error {
	return RemovePackage("greenplum-db-clients")
}

func InitializeScenario(ctx *godog.ScenarioContext) {
	ctx.Step(`^gpdb deb has correct metadata$`, gpdbDebHasCorrectMetadata)
	ctx.Step(`^gpdb installed$`, gpdbInstalled)
	ctx.Step(`^gpdb installed as expected$`, gpdbInstalledAsExpected)
	ctx.Step(`^gpdb ppa installed as expected$`, ppaInstalledAsExpected)
	ctx.Step(`^gpdb link removed as expected$`, gpdbLinkRemovedAsExpected)
	ctx.Step(`^gpdb removed as expected$`, gpdbRemovedAsExpected)
	ctx.Step(`^gpdb ppa removed as expected$`, ppaRemovedAsExpected)
	ctx.Step(`^install gpdb$`, installGpdb)
	ctx.Step(`^^install previous version gpdb$`, installPreviousVersionGpdb)
	ctx.Step(`^remove gpdb$`, removeGpdb)
	ctx.Step(`^gpdb client deb has correct metadata$`, gpdbClientDebHasCorrectMetadata)
	ctx.Step(`^gpdb client installed$`, gpdbClientInstalled)
	ctx.Step(`^gpdb client installed as expected$`, gpdbClientInstalledAsExpected)
	ctx.Step(`^gpdb client link removed as expected$`, gpdbClientLinkRemovedAsExpected)
	ctx.Step(`^gpdb client removed as expected$`, gpdbClientRemovedAsExpected)
	ctx.Step(`^install gpdb client$`, installGpdbClient)
	ctx.Step(`^remove gpdb client$`, removeGpdbClient)
}

func GetDebField(field string, debPakcage string) (string, error) {
	// get Homepage from debian package field
	cmd := exec.Command("dpkg-deb", "--field", debPakcage, field)
	fieldValue, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(fieldValue)), nil
}

func CheckUrlReachable(url string) bool {
	response, err := http.Get(url)
	if err != nil {
		return false
	}
	if response.StatusCode == 200 {
		return true
	}
	return false
}

func CheckPackageInstalled(packageName string) error {
	cmd := exec.Command("apt", "list", packageName)
	isPackageInstalled, err := cmd.Output()
	if err != nil {
		return err
	}
	if strings.Contains(string(isPackageInstalled), "installed") {
		return nil
	}
	return fmt.Errorf("%s is not installed", packageName)
}

func GetEnvFromGreenplumPathFile(greenplumPathFile string, envName string) (string, error) {
	cmdStr := fmt.Sprintf("source %s; echo $%s", greenplumPathFile, envName)
	cmd := exec.Command("/bin/bash", "-c", cmdStr)
	envValue, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(envValue)), nil
}

func InstallPackage(debPath string) error {
	cmd := exec.Command("apt-get", "--quiet", "update")
	_, err := cmd.Output()
	if err != nil {
		return err
	}
	fullDebPath, err := filepath.Abs(debPath)
	if err != nil {
		return err
	}
	cmd = exec.Command("apt-get", "install", "--yes", "./"+filepath.Base(fullDebPath))
	cmd.Env = append(os.Environ(),
		"DEBIAN_FRONTEND=noninteractive",
	)
	cmd.Dir = filepath.Dir(fullDebPath)
	_, err = cmd.Output()
	if err != nil {
		return err
	}
	return nil
}

func RemovePackage(pacakgeName string) error {
	cmd := exec.Command("apt-get", "remove", "--yes", pacakgeName)
	_, err := cmd.Output()
	if err != nil {
		return err
	}
	return nil
}
