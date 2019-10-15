@web
Feature: Home Office Web Browsing
  As a web surfer,
  I want to find information online,
  So I can learn new things and get tasks done.

  # The "@" annotations are tags
  # One feature can have multiple scenarios
  # The lines immediately after the feature title are just comments

  Scenario Outline: Home Office Search for brexit
    Given the http://homeoffice.gov.uk page is displayed
    When the user searches for income tax
    When the following links exist:
      | link |url                                                                                                       |
      | link1|https://www.gov.uk/government/publications/income-tax-personal-allowance-and-basic-rate-limit-for-2016-to-2017 |
      | link2|https://www.gov.uk/income-tax-rates                                                                            |
    Then the following text is displayed:
      | display                                                              |
      | Income Tax: personal allowance and basic rate limit for 2016 to 2017 |
      | Income Tax rates and Personal Allowances                             |




#      | https://homeoffice.gov.uk/jobs    | How to prepare if the UK leaves the EU with no deal |
#      | https://homeoffice.gov.uk/tax     | Visit Europe after Brexit                           |
#      | https://homeoffice.gov.uk/pension | pension after brexit                                |

##    Then results are shown for listed results



#  Scenario: Home Office Search tax
#    Given the http://homeoffice.gov.uk page is displayed
#    When the user searches for "tax"
#    Then results are shown for Income Tax rates and Personal Allowances
#    Then results are shown for Estimate your Income Tax for the current year
