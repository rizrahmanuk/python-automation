Feature: Verify data after triage
  This area is for whatever description regarding the feature

  Background:
    Given the following tables "customer,inventory,rental,film" are not empty in "sandpit_rahmanr"

  Scenario Outline: Selection of customers have outstanding_rentals Y/N
    When a customer with {firstname},{lastname} exists
    Then do they {firstname},{lastname} have any {outstanding_rentals}
    Examples: customers with yes and no rentals
      | firstname | lastname  | outstanding_rentals |
      | Terrence  | Gunderson | N                   |
      | Heather   | Morris    | Y                   |
      | Freddie   | Duggan    | Y                   |
      | Wade      | Delvalle  | N                   |
      | Tammy     | Sanders   | Y                   |


  Scenario Outline: search by customer first who are movie addicts
    Then check if the customer with {first_name} has taken out gte {number_of_movies}
    Then reward them with {5} free movies to watch
    Examples: customers watches number_of_movies
      | first_name | number_of_movies |
      | Terrence   | 20               |
      | Wade       | 20               |
