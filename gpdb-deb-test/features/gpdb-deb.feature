Feature: deb install, remove and upgrade works
  @GPDB6 @GPDB7 @UBUNTU20
  Scenario: gpdb server deb can be installed
    Given gpdb deb has correct metadata
    When install gpdb
    Then gpdb installed
    And gpdb installed as expected
  @GPDB6 @GPDB7 @UBUNTU20
  Scenario: gpdb server deb can be removed
    Given gpdb installed
    When remove gpdb
    Then gpdb link removed as expected
    And gpdb removed as expected
  @GPDB6
  Scenario: gpdb server deb can be upgraded
    When install previous version gpdb
    Then install gpdb
    And gpdb installed as expected
