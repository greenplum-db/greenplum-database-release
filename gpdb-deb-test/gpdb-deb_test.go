package main

import (
	"fmt"
	"github.com/cucumber/godog"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func gpdbDebHasCorrectMetadata() error {
	// get Homepage from debian package field and check it's reacheable
	homePage, err := GetDebField("Homepage", "gpdb_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb")
	if err != nil {
		return err
	}
	if !CheckUrlReachable(homePage) {
		return fmt.Errorf("Homepage: %s is not reachable", homePage)
	}
	return nil
}

func gpdbInstalled() error {
	return CheckPackageInstalled("greenplum-db-6")
}

func gpdbInstalledAsExpected() error {
	// get gpdbVersion
	gpbdVersion, err := GetDebField("Version", "gpdb_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb")
	if err != nil {
		return err
	}
	// /usr/local/greenplum-db is a link to greenplum-db-#{gpdb_version}
	linkDestination, err := os.Readlink("/usr/local/greenplum-db")
	if err != nil {
		return err
	}
	if linkDestination != "greenplum-db-"+gpbdVersion {
		return fmt.Errorf("/usr/local/greenplum-db links to %s != %s", linkDestination, "greenplum-db-"+gpbdVersion)
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
		fmt.Errorf("postgres --gp-version: %s should contains %s", string(postgresGpbdVersion), string(gpbdVersion))
	}
	return nil
}

func gpdbRemovedAsExpected() error {
	_, err := os.Stat("/usr/local/greenplum-db")
	if os.IsNotExist(err) {
		return nil
	}
	return fmt.Errorf("/usr/local/greenplum-db should not exist")
}

func installGpdb() error {
	return InstallPackage("gpdb_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb")
}

func removeGpdb() error {
	return RemovePackage("greenplum-db-6")
}

func gpdbClientDebHasCorrectMetadata() error {
	// get Homepage from debian package field and check it's reacheable
	homePage, err := GetDebField("Homepage", "gpdb_client_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb")
	if err != nil {
		return err
	}
	if !CheckUrlReachable(homePage) {
		return fmt.Errorf("Homepage: %s is not reachable", homePage)
	}
	// get Package from debian package field and it should equal to greenplum-db-clients
	pacakge, err := GetDebField("Package", "gpdb_client_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb")
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
	gpdbClientVersion, err := GetDebField("Version", "gpdb_client_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb")
	if err != nil {
		return err
	}
	// /usr/local/greenplum-db-clients is a link to /usr/local/greenplum-db-clients-#{gpdb_client_version}
	linkDestination, err := os.Readlink("/usr/local/greenplum-db-clients")
	if err != nil {
		return err
	}
	if linkDestination != "greenplum-db-clients-" + gpdbClientVersion {
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
	return nil
}

func gpdbClientRemovedAsExpected() error {
	_, err := os.Stat("/usr/local/greenplum-db-clients")
	if os.IsNotExist(err) {
		return nil
	}
	return fmt.Errorf("/usr/local/greenplum-db-clients should not exist")
}

func installGpdbClient() error {
	return InstallPackage("gpdb_client_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb")
}

func removeGpdbClient() error {
	return RemovePackage("greenplum-db-clients")
}

func InitializeScenario(ctx *godog.ScenarioContext) {
	ctx.Step(`^gpdb deb has correct metadata$`, gpdbDebHasCorrectMetadata)
	ctx.Step(`^gpdb installed$`, gpdbInstalled)
	ctx.Step(`^gpdb installed as expected$`, gpdbInstalledAsExpected)
	ctx.Step(`^gpdb removed as expected$`, gpdbRemovedAsExpected)
	ctx.Step(`^install gpdb$`, installGpdb)
	ctx.Step(`^remove gpdb$`, removeGpdb)
	ctx.Step(`^gpdb client deb has correct metadata$`, gpdbClientDebHasCorrectMetadata)
	ctx.Step(`^gpdb client installed$`, gpdbClientInstalled)
	ctx.Step(`^gpdb client installed as expected$`, gpdbClientInstalledAsExpected)
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
	cmd = exec.Command("apt-get", "install", "--yes", "./" + filepath.Base(fullDebPath))
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
