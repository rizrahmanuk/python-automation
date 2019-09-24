import pytest
from pytest_bdd import scenarios, given, when, then, parsers
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.firefox.firefox_binary import FirefoxBinary

# Constants


# Scenarios

scenarios('../../features/web-driven.feature')


# Fixtures

@pytest.fixture
def browser():
    firefox_bin=FirefoxBinary('/usr/bin')
    b = webdriver.Firefox(executable_path='/usr/local/bin/geckodriver')
    b.implicitly_wait(20)
    yield b
    b.quit()


# Given Steps


@given(parsers.parse('the "{web_site}" page is displayed'))
def go_to_site(browser, web_site):
    browser.get(web_site)


# When Steps
@when(parsers.parse('the user searches for "{phrase}"'))
def search_phrase(browser, phrase):
    search_input = browser.find_element_by_id('site-search-text')
    search_input.send_keys(phrase + Keys.RETURN)
    browser.implicitly_wait(10)


# Then Steps
@then(parsers.parse('results are shown for "{phrase}"'))
def search_results(browser, phrase):
    #div =browser.find_element_by_id('js-results')
    #paragraph_p=div.find_element_by_xpath('div/ol/li/p')
    #print('\nparagraph_li='+str(paragraph_p.text))

    item_titles=browser.find_elements_by_class_name("gem-c-document-list__item-title")

    for item_title in item_titles:
        print('\nlist='+str(item_title.text))

    # assert str(paragraph_p.text) == phrase
    #links_div = browser.find_element_by_id('links')
    #assert len(links_div.find_elements_by_xpath('//div')) > 0
    ## search_input = browser.find_element_by_name('q')
    #assert search_input.get_attribute('value') == phrase