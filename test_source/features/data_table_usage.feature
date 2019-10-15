Scenario Outline: I use datatables
    Given the following users exist:
      | name   | email              | twitter         |
      | Aslak  | aslak@cucumber.io  | @aslak_hellesoy |
      | Julien | julien@cucumber.io | @jbpros         |
      | Matt   | matt@cucumber.io   | @mattwynne      |
    Then I should see the following names:
      | name   |
      | Aslak  |
      | Julien |
      | Matt   |

For each step which has a data table, the implementation can use a datatable argument which is a list of two lists: the list of headers and the list of rows.

@given('the following users exist:')
def the_following_users_exist(datatable):
    """the following users exist:."""
    return datatable[1]

@then('I should see the following names:')
def i_should_see(datatable, the_following_users_exist):
    names = [row[0] for row in the_following_users_exist]
    assert names == sum(datatable[1], [])

