import pytest
from pytest_bdd import scenarios, given, when, then, parsers
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
@when(parsers.parse('the user searches for "{phrase}"'))
def search_phrase(browser, wait, phrase):
    search_input = browser.find_element_by_id('site-search-text')
    search_input.send_keys(phrase + Keys.RETURN)
    # search.submit()


@given(parsers.re(r'expected url list:(?P<textual>.*)', flags=re.DOTALL))
def expected_results(textual):
    return textual

# Then Steps
@then(parsers.cfparse('results are shown for listed results'))
def search_results(expected_results, browser, wait):
    # div =browser.find_element_by_id('js-results')x
    # paragraph_p=div.find_element_by_xpath('div/ol/li/p')
    # print('\nparagraph_li='+str(paragraph_p.text))

    # item_titles = wait.until(EC.presence_of_all_elements_located((By.CLASS_NAME, 'gem-c-document-list__item-title')))
    wait.until(EC.presence_of_all_elements_located((By.CLASS_NAME, 'gem-c-document-list__item')))

    # browser.find_element(by, hook)
    # original XPath=/html/body/div[6]/main/div/form/div[2]/div/div[2]/div[4]/div/ol/li[1]
    tag_a_list_of = wait.until(EC.presence_of_all_elements_located((By.XPATH,
                                                                    '//*[@id="js-results"]/div/ol/li/a')))

    for web_element in tag_a_list_of:
        print('expected result text=' + expected_results)
        return True
    print('could not find expected result text=' + expected_results)
    assert False

    # reference samples
    # assert str(paragraph_p.text) == result
    # link_tag=item.find_element(By.TAG_NAME, 'a')
    # links_div = browser.find_element_by_id('links')
    # assert len(links_div.find_elements_by_xpath('//div')) > 0
    ## search_input = browser.find_element_by_name('q')
    # assert search_input.get_attribute('value') == result
