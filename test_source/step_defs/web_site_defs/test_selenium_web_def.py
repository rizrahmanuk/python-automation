import pytest
from test_source.step_defs.data_table_feature import data_table
from pytest_bdd import scenarios, given, when, then, parsers
from pytest_bdd import feature
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import NoAlertPresentException
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.firefox.firefox_binary import FirefoxBinary
from parse_type import TypeBuilder
import re

# Constants


# Scenarios

scenarios('../../features/web-driven.feature')


# Fixtures


@pytest.fixture
def browser():
    firefox_bin = FirefoxBinary('/usr/bin')
    fox_webdriver = webdriver.Firefox(executable_path='/usr/local/bin/geckodriver')
    fox_webdriver.implicitly_wait(20)
    yield fox_webdriver
    fox_webdriver.quit()


@pytest.fixture
def wait(browser):
    w = WebDriverWait(browser, 20)
    yield w


# Given Steps


@given(parsers.parse('the {web_site} page is displayed'))
def go_to_site(browser, web_site):
    browser.get(web_site)


# When Steps
@when(parsers.parse('the user searches for {phrase}'))
def search_phrase(browser, wait, phrase):
    search_input = browser.find_element_by_id('site-search-text')
    search_input.send_keys(Keys.CLEAR)
    search_input.send_keys(phrase + Keys.RETURN)
    # search.submit()


@when(data_table('the following links exist:', fixture='links_displayed', orient='dict'))
def process_row(links_displayed):
    row = links_displayed
    for column in row:
        print('column_data=' + str(column))
    return links_displayed


# Then Steps
@then(data_table('the following text is displayed:', fixture='result_display', orient='columns'))
def results_displayed(result_display, links_displayed, wait):
    # for link in links_displayed:
    print('(display=' + str(result_display[1]) + 'url=' + str(links_displayed[0]["url"]))

    # item_titles = wait.until(EC.presence_of_all_elements_located((By.CLASS_NAME, 'gem-c-document-list__item-title')))
    wait.until(EC.presence_of_all_elements_located((By.CLASS_NAME, 'gem-c-document-list__item')))

    # Original XPath=/html/body/div[6]/main/div/form/div[2]/div/div[2]/div[4]/div/ol/li[1]
    tag_a_list_of = wait.until(EC.presence_of_all_elements_located((By.XPATH,
                                                                    '//*[@id="js-results"]/div/ol/li/a')))

    for index, web_element in enumerate(tag_a_list_of):
        href = web_element.get_attribute('href')
        text = web_element.get_attribute('innerHTML')

        # matched_text = next(b for b in result_display[1] if text in b)
        ##tuple_result_display_tup = tuple(item for item in result_display[1])
        # if tuple_result_display_tup.__contains__(text):
        ##filtered_list = list(filter(lambda x: text in x, result_display[1]))
        for expected_text in result_display[0]:
            if str(text).__eq__(expected_text):
                print('Found expected result text=' + text)
        if len(result_display) == index+1:
            print('Found All expected display text' + text)
            return True
        else:
            continue

    print('could not find expected result text=' + str(filtered_list[0][1]))
    assert False


##@given(parsers.re(r'expected url list:(?P<textual>.*|$)', flags=re.DOTALL))
##@given(parsers.cfparse('there are {start:Number} cucumbers', extra_types=dict(Number=int)))   ##example
##@given(parsers.cfparse('expected url list:\n|{url:Url*}|{data:Text*}|', extra_types=dict(Url=str, Text=str))) ##WIP

##@given(parsers.re(r'expected url list:(?P<url>(![\n\|]).*\|)(?P<data>.*)', flags=re.DOTALL))  ##WIP v1.0
##@then(parsers.re(r'expected url list:\n(?P<url>([\|\sa-zA-Z\|\n]+).$)', flags=re.DOTALL))     ##WIP v1.1
##@then(parsers.re(r'expected url list:\n(?P<url>(\|)([\sa-zA-Z0-9]).*(\|\n)).(?P<data>([\|\sa-zA-Z0-9\|]+).*)', flags=re.DOTALL)) ##WIP v1.2

###Experimental design for a generic DataTable fixture####
#  Author: Riz Rahman
####################################################
@pytest.fixture(name="expected_results")
@then(parsers.re(r'expected url list:\n(?P<data>.*)',
                 flags=re.DOTALL))
def expected_results(data):

    headers = list()
    rows = list()
    for counter, line in enumerate(data.splitlines(keepends=False)):
        split_line = line.strip('|').split('|')
        if counter == 0:
            for hcount, header in enumerate(split_line):
                headers.insert(hcount, header)
        else:
            for rcount, row in enumerate(split_line):
                rows.insert(rcount, row)

    return dict(Headers=headers, Rows=rows)

    ### RegEx examples:
    # ^/(?!ignoreme|ignoreme2|ignoremeN)([a-z0-9]+)$
    # (?![\|\n])(?![\|$]).(?!\|{1}$)(?![\n\|])  ##regex101.com

    ### Selenium reference samples:
    # assert str(paragraph_p.text) == result
    # link_tag=item.find_element(By.TAG_NAME, 'a')
    # links_div = browser.find_element_by_id('links')
    # assert len(links_div.find_elements_by_xpath('//div')) > 0
    ## search_input = browser.find_element_by_name('q')
    # assert search_input.get_attribute('value') == result
