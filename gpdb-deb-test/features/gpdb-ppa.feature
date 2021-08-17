Feature: ppa install and remove works
  Scenario: gpdb ppa can be installed
    When install gpdb
    Then gpdb installed
    And gpdb ppa installed as expected
  Scenario: gpdb ppa can be removed
    Given gpdb installed
    When remove gpdb
    Then gpdb ppa removed as expected