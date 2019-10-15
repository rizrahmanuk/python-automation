from pytest_bdd import given, then, scenarios, parsers
import functools

def parse_data_table(text, orient='dict'):
    parsed_text = [
        # Split each line on | and trim whitespace
        [x.strip() for x in line.split('|')]
        # Split the text into an array of lines with leading and trailing | removed
        for line in [x.strip('|') for x in text.splitlines()]
    ]

    # The first line is the header, the rest is the data
    header, *data = parsed_text

    if orient == 'dict':
        # Combine the header with each line to create a list of dicts
        return [
            dict(zip(header, line))
            for line in data
        ]
    # Otherwise we want a list
    else:
        # Columnar
        if orient == 'columns':
            data = [
                [line[i] for line in data]
                for i in range(len(header))
            ]
        return header, data


def data_table(name, fixture='data', orient='dict'):
    formatted_str = '{name}\n{{{fixture}:DataTable}}'.format(
        name=name,
        fixture=fixture,
    )
    data_table_parser = functools.partial(parse_data_table, orient=orient)

    return parsers.cfparse(formatted_str, extra_types=dict(DataTable=data_table_parser))


# Example of reading in a dict
@given(data_table('the following users exist:', fixture='users'))
def the_following_users_exist(users):
    """the following users exist:."""
    return users


# Example of reading in a tuple of [header, columns]
@then(data_table('I should see the following names:', fixture='name_data', orient='columns'))
def i_should_see(name_data, the_following_users_exist):
    expected = [x['name'] for x in the_following_users_exist]
    _, columns = name_data
    assert columns[0] == expected