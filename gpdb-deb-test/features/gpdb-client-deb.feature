Feature: deb install and remove works
  Scenario: gpdb client deb can be installed
    Given gpdb client deb has correct metadata
    When install gpdb client
    Then gpdb client installed
    And gpdb client installed as expected
  Scenario: gpdb client deb can be removed
    Given gpdb client installed
    When remove gpdb client
    Then gpdb client link removed as expected
    And gpdb client removed as expected
