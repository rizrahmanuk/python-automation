@web
Feature: Home Office Web Browsing
  As a web surfer,
  I want to find information online,
  So I can learn new things and get tasks done.

  # The "@" annotations are tags
  # One feature can have multiple scenarios
  # The lines immediately after the feature title are just comments

  Scenario: Home Office Search for brexit
    Given the "http://homeoffice.gov.uk" page is displayed
    When the user searches for "brexit"
    Then results are shown for "How to prepare if the UK leaves the EU with no deal"
    Then results are shown for "Visit Europe after Brexit"

  Scenario: Home Office Search tax
    Given the "http://homeoffice.gov.uk" page is displayed
    When the user searches for "tax"
    Then results are shown for "Income Tax rates and Personal Allowances"
