import pytest
from pytest_bdd import scenarios, given, when, then, parsers
import pytest_bdd
from product_source.available_media import doQuery
import psycopg2

hostname = 'localhost'
username = 'rahmanr'
password = 'saif@4200'
database = 'cucumber_db'
# Constants


# Scenarios

scenarios('../../features/data-analysis-scenarios.feature')


# Fixtures

@pytest.fixture
def connection():
    c = psycopg2.connect(host=hostname, user=username, password=password, dbname=database)
    yield c
    ##c.quit()


# Given Steps

@given(parsers.parse('the following tables "{tables}" are not empty in "{schema}"'))
def table_not_empty(connection, tables: str, schema: str):
    for table in tables.split(","):
        query = 'SELECT count(*) FROM {schema}.{table} LIMIT 1'.format(schema=schema, table=table)
        results = doQuery(connection, query)

        if len(results) > 0:
            print('\n' + schema + '.' + table + ' is NOT empty')
        else:
            print(schema + '.' + table + ' is empty')

    ##connection.close()


# When Steps
@when(parsers.parse('a customer with "{firstname}","{lastname}" exists'))
def query_films_by_customer(connection, firstname, lastname):
    print('\nfirstname=' + firstname + ' lastname=' + lastname)


# Then Steps
@then(parsers.parse('do they "{firstname}","{lastname}" have any "{outstanding_rentals}"'))
def query_films_by_customer(connection, firstname, lastname, outstanding_rentals):
    print('\nfirstname=' + firstname + ' lastname=' + lastname + ' outstanding_rentals=' + outstanding_rentals)
    assert outstanding_rentals == 'Y' or outstanding_rentals =='N'
    # customer_id = 75 has 3 unreturned films
    query = """
    SELECT c.customer_id, c.first_name, f.title
    FROM sandpit_rahmanr.customer c, sandpit_rahmanr.rental r, sandpit_rahmanr.film f, sandpit_rahmanr.inventory i
    WHERE
    --c.customer_id = 75
    c.first_name='{firstname}'
    AND c.last_name='{lastname}'
    AND c.customer_id = r.customer_id
    AND r.return_date is null
    AND r.inventory_id = i.inventory_id
    AND i.film_id = f.film_id
    """.format(firstname=firstname, lastname=lastname)

    print("query=" + query)
    results = doQuery(connection, query)

    if isinstance(results, list):
        if outstanding_rentals == 'Y':
            assert len(results) > 0
            print("results=" + str(results))
        else:
            assert len(results) == 0
    else:
        print("results is not an instance of list")
        assert not isinstance(results, list)


@then(parsers.parse('check if the customer with "{first_name}" has taken out gte "{number_of_movies}"'))
def firstnames_total(connection, first_name, number_of_movies: int):
    query = """
        SELECT count(*)
        FROM sandpit_rahmanr.customer c, sandpit_rahmanr.rental r, sandpit_rahmanr.film f, sandpit_rahmanr.inventory i
        WHERE c.first_name = '{first_name}'
        AND c.customer_id = r.customer_id
        AND r.inventory_id = i.inventory_id
        AND i.film_id = f.film_id
        AND r.return_date is not null
        HAVING count(*) >= '{number_of_movies}'
        """.format(first_name=first_name, number_of_movies=number_of_movies)

    print("query=" + query)
    results = doQuery(connection, query)
    assert len(results) != 0


@then(parsers.parse('reward them with "{num}" free movies to watch'))
def offer_free_n_movies(connection, num: int):
    print("rewarded movies="+str(num))

