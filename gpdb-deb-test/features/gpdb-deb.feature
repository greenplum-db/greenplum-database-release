Feature: deb install and remove works

  Scenario: gpdb server deb can be installed
    Given gpdb deb has correct metadata
    When install gpdb
    Then gpdb installed
    And gpdb installed as expected
  Scenario: gpdb server deb can be removed
    Given gpdb installed
    When remove gpdb
    Then gpdb link removed as expected
    And gpdb removed as expected
